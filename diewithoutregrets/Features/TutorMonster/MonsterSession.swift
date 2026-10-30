//
//  MonsterSession.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 1): the unlock state machine. Computes the mood from
//  app-observable pressure, draws a weakness/exam-weighted toll, runs the chat
//  (greet → demand → cards → settle), grades locally, and grants time through the
//  EXISTING earn economy. Fully offline: the live AI (Phase 2) only replaces the
//  spoken lines. See Docs/TutorMonsterPlan.md §4, §6a-§6e.
//

import SwiftUI

@MainActor
final class MonsterSession: ObservableObject {

    // MARK: Published chat state
    @Published private(set) var messages: [MonsterMessage] = []
    @Published private(set) var awaitingAnswer = false
    @Published private(set) var isFinished = false
    @Published private(set) var grantedMinutes = 0
    @Published private(set) var isThinking = false
    @Published private(set) var studyRound: MonsterStudyRound?
    @Published private(set) var studySheetState: MonsterStudySheetState = .offered

    // MARK: Session config (persona and earn rate stay fixed while switching decks)
    let persona: MonsterPersona
    let dials: SGContract.MoodDials
    @Published private(set) var totalQuestions: Int
    @Published private(set) var deckName: String
    @Published private(set) var roundID = UUID()
    let method: MonsterStudyMethod

    // MARK: Dependencies
    private let deckStore: DeckStore
    private let examStore: ExamStore
    private let studyGuard: StudyGuardManager
    private let loadBundle: (MonsterPersona, SGContract.MonsterMood, MonsterScriptVars) async -> MonsterScriptBundle?
    private let tutorReply: (String, MonsterTutorCard, String, [MonsterTutorTurn]) async throws -> String
    private let tutorTimeout: UInt64

    // MARK: Flow state
    private(set) var deckID: UUID?
    /// Frozen earn rate shared by grading, the per-answer counter and settlement.
    let secondsPerCorrectAnswer: Int
    private var queue: [Regret]
    private var currentCard: Regret?
    private var results: [Bool?] = []
    private var outcomes: [UUID: Bool] = [:]
    private var unrecordedOutcomes: [UUID: Bool] = [:]
    private var presented: [UUID: Regret] = [:]
    private var bundle: MonsterScriptBundle?
    private var scriptTask: Task<Void, Never>?
    private var tutorTask: Task<Void, Never>?
    private var tutorDeadline: Task<Void, Never>?
    private var pendingQuestion: UUID?
    private var tutorHistory: [UUID: [MonsterTutorTurn]] = [:]
    private var correctCount = 0
    private var lineSeed = 0
    private var reactionPicker: MonsterReactionPicker
    private var vars: MonsterScriptVars
    private var studyCards: [Regret]
    private var openingSources: [MonsterStudySource]
    private let openingDefaults: UserDefaults?
    private var sheetQuestionContexts: [UUID: Regret] = [:]
    private var stopped = false

    init(deckStore: DeckStore = .shared,
         examStore: ExamStore = .shared,
         personaStore: PersonaStore = .shared,
         studyGuard: StudyGuardManager = .shared,
         sharedDefaults: UserDefaults? = SGContract.sharedDefaults,
         now: Date = Date(),
         method: MonsterStudyMethod? = nil,
         loadBundle: ((MonsterPersona, SGContract.MonsterMood, MonsterScriptVars) async -> MonsterScriptBundle?)? = nil,
         tutorReply: ((String, MonsterTutorCard, String, [MonsterTutorTurn]) async throws -> String)? = nil,
         tutorTimeout: UInt64 = 20_000_000_000,
         reactionSeed: Int = Int.random(in: 0..<10_000)) {
        self.deckStore = deckStore
        self.examStore = examStore
        self.studyGuard = studyGuard
        self.openingDefaults = sharedDefaults
        self.reactionPicker = MonsterReactionPicker(seed: reactionSeed, defaults: sharedDefaults)
        self.loadBundle = loadBundle ?? { await MonsterAI.fetchBundle(persona: $0, mood: $1, vars: $2) }
        self.tutorReply = tutorReply ?? { try await FlashcardAPIClient.shared.askTutor(persona: $0, card: $1, question: $2, history: $3) }
        self.tutorTimeout = tutorTimeout
        self.persona = personaStore.persona
        let method = method ?? MonsterStudyMethod.selected()
        self.method = method

        let deck = deckStore.selectedDeck
        self.deckID = deck?.id
        var seenIDs: Set<UUID> = []
        var seenPrompts: Set<String> = []
        let cards = (deck?.cards ?? []).filter { card in
            guard card.isUsableForStudy else { return false }
            if method == .inChat { return true }
            return seenIDs.insert(card.id).inserted && seenPrompts.insert(
                card.quizPrompt.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
        }
        self.studyCards = cards
        self.deckName = deck?.name ?? "Study round"
        let exam = StudyMaterialLinks.nextExam(for: deck, in: examStore.exams, now: now)

        // Pressure → mood → dials (all app-observable signals).
        let pressure = SGContract.PressureInputs(
            gateEncountersToday: SGContract.gateEncountersToday(sharedDefaults, now: now),
            daysSinceStudy: Self.daysSinceLastStudy(cards: cards, now: now),
            nearestExamDays: exam?.daysUntil(from: now),
            weakCardLoad: cards.filter { $0.isWeak || $0.isDue(asOf: now) }.count,
            fastBurn: false
        )
        let dials = SGContract.dials(for: pressure)
        self.dials = dials
        self.secondsPerCorrectAnswer = SGContract.perCardSeconds(for: dials)

        // Toll: weakness + exam-topic weighted draw.
        let toll = CardSelection.pick(from: cards,
                                      count: method == .studySheet ? 4 : dials.questions,
                                      examTopics: Set(exam?.topics ?? []),
                                      now: now)
        self.queue = toll
        self.openingSources = MonsterStudySource.selected(cards: toll, deckName: deck?.name)
        self.totalQuestions = toll.count
        if method == .studySheet {
            self.studyRound = MonsterStudyRound(title: deck?.name ?? "Study round", cards: toll)
        }

        self.vars = MonsterScriptVars(
            app: "your apps",
            count: pressure.gateEncountersToday,
            exam: exam?.subject,
            examDays: exam?.daysUntil(from: now),
            topic: Self.dominantTopic(of: toll),
            deck: deck?.name,
            questions: toll.count,
            minutes: SGContract.earnedMinutes(cardCount: toll.count, perCardSeconds: SGContract.perCardSeconds(for: dials))
        )
    }

    /// True when there is a toll to run. An empty/absent deck receives local
    /// guidance in chat without granting an unlock.
    var canRun: Bool { !queue.isEmpty }

    /// The card currently awaiting an answer, for the input area.
    var activeCard: Regret? { awaitingAnswer ? currentCard : nil }

    // MARK: Flow

    /// Every study session opens offline. Voice enrichment may arrive later; it
    /// never delays the first question, grading, or the time grant.
    func start() {
        stopped = false
        guard messages.isEmpty else { return }
        guard canRun else {
            append(.monster("Add or check the flashcards in your selected deck, then come back and study with me."))
            isFinished = true
            return
        }
        lineSeed += 1
        let opening = MonsterOpeningRotation.next(personaID: persona.id,
            hasExam: MonsterScript.hasUpcomingExam(vars), defaults: openingDefaults)
        append(.monster(MonsterScript.openingGreeting(persona: persona, mood: dials.mood,
                                                     vars: vars, seed: opening.greeting)))
        append(.monster(MonsterScript.scrollCallout(persona: persona, seed: nextVoiceVariant("scrollCallout")),
                        reaction: reactionPicker.opening(persona: persona)))
        append(.monster(MonsterScript.openingPrompt(persona: persona, vars: vars,
                                                   studySheet: method == .studySheet, seed: opening.prompt),
                        sources: openingSources))
        if method == .studySheet, let round = studyRound {
            append(.init(sender: .monster, kind: .studyRound(round)))
            return
        }
        presentNextCard()
        refreshScriptBundle()
    }

    private func refreshScriptBundle() {
        let persona = persona, mood = dials.mood, vars = vars
        let loadBundle = loadBundle
        scriptTask = Task { [weak self] in
            let value = await loadBundle(persona, mood, vars)
            guard !Task.isCancelled else { return }
            self?.bundle = value
        }
    }

    /// Replaces only unanswered work. Existing verdicts keep their identity and
    /// earned seconds, and each deck receives only its own new review outcomes.
    /// A completed/empty chat starts a fresh round without paying the old one again.
    @discardableResult
    func switchToSelectedDeck() -> Bool {
        guard let deck = deckStore.selectedDeck, deck.id != deckID || isFinished else { return false }
        var ids: Set<UUID> = []
        var prompts: Set<String> = []
        let cards = deck.cards.filter { card in
            guard card.isUsableForStudy else { return false }
            return method == .inChat || (ids.insert(card.id).inserted && prompts.insert(
                card.quizPrompt.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted)
        }
        guard !cards.isEmpty else { return false }
        let restarting = isFinished
        let outstanding = method == .inChat ? queue.count + (awaitingAnswer ? 1 : 0)
            : (studyRound.map { $0.questions.count - $0.answers.count } ?? 0)
        let count = restarting || outstanding == 0 ? (method == .studySheet ? 4 : dials.questions) : outstanding
        let exam = StudyMaterialLinks.nextExam(for: deck, in: examStore.exams)
        let toll = CardSelection.pick(from: cards, count: count, examTopics: Set(exam?.topics ?? []))
        guard !toll.isEmpty else { return false }

        stop()
        writeBackCurrentDeck()
        stopped = false
        bundle = nil
        // Remove the abandoned prompt rather than counting it as another
        // question or leaving stale answer controls in the transcript.
        if awaitingAnswer, let currentCard,
           let index = messages.lastIndex(where: { $0.card?.id == currentCard.id }) {
            messages.remove(at: index)
        }
        if let round = studyRound, !round.isComplete {
            messages.removeAll { message in
                if case .studyRound(let offered) = message.kind { return offered.id == round.id }
                return false
            }
        }
        currentCard = nil
        awaitingAnswer = false
        if restarting {
            messages = []
            results = []
            outcomes = [:]
            presented = [:]
            tutorHistory = [:]
            sheetQuestionContexts = [:]
            correctCount = 0
            grantedMinutes = 0
            isFinished = false
            reactionPicker = MonsterReactionPicker(defaults: openingDefaults)
            roundID = UUID()
        }
        deckID = deck.id
        deckName = deck.name
        studyCards = cards
        queue = toll
        totalQuestions = results.count + toll.count
        openingSources = MonsterStudySource.selected(cards: toll, deckName: deck.name)
        vars.exam = exam?.subject
        vars.examDays = exam?.daysUntil()
        vars.topic = Self.dominantTopic(of: toll)
        vars.deck = deck.name
        vars.questions = totalQuestions
        vars.minutes = SGContract.earnedMinutes(cardCount: totalQuestions, perCardSeconds: secondsPerCorrectAnswer)
        vars.score = "\(correctCount)/\(totalQuestions)"
        studyRound = method == .studySheet ? MonsterStudyRound(title: deck.name, cards: toll) : nil
        studySheetState = .offered
        if restarting {
            start()
        } else {
            append(.system("Now studying \(deck.name)"))
            var nextVars = vars
            nextVars.questions = toll.count
            lineSeed += 1
            append(.monster(MonsterScript.openingPrompt(persona: persona, vars: nextVars,
                studySheet: method == .studySheet, seed: nextVoiceVariant("prompt")), sources: openingSources))
            if let round = studyRound {
                append(.init(sender: .monster, kind: .studyRound(round)))
            } else {
                presentNextCard()
                refreshScriptBundle()
            }
        }
        return true
    }

    private func writeBackCurrentDeck() {
        if let deckID, !unrecordedOutcomes.isEmpty {
            deckStore.recordOutcomes(unrecordedOutcomes, deckID: deckID)
        }
        unrecordedOutcomes = [:]
    }

    /// A follow-up is always an explicit action tied to a displayed card. It never
    /// enters answer grading, even if the question happens to contain the answer.
    func ask(_ question: String, about messageID: UUID) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stopped, pendingQuestion == nil, !text.isEmpty, text.utf16.count <= 1000,
              let card = messages.first(where: { $0.id == messageID })?.card ?? sheetQuestionContexts[messageID] else { return }
        let token = UUID()
        pendingQuestion = token
        isThinking = true
        append(.user(text))
        let context = MonsterTutorCard(card)
        let history = tutorHistory[messageID] ?? []
        let personaID = persona.id
        let tutorReply = tutorReply
        tutorTask = Task { [weak self] in
            do {
                let reply = try await tutorReply(personaID, context, text, history)
                guard !Task.isCancelled else { return }
                self?.finishQuestion(token, messageID: messageID, question: text, reply: reply, remember: true)
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishQuestion(token, messageID: messageID, question: text,
                    reply: Self.fallbackReply(for: card, error: error), remember: false)
            }
        }
        // A separate deadline also bounds non-cooperative Apple enrollment calls.
        // Do not use a task group: it waits for cancelled children to finish.
        let timeout = tutorTimeout
        tutorDeadline = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: timeout) } catch { return }
            self?.tutorTask?.cancel()
            self?.finishQuestion(token, messageID: messageID, question: text,
                reply: Self.fallbackReply(for: card, error: URLError(.timedOut)), remember: false)
        }
    }

    private func finishQuestion(_ token: UUID, messageID: UUID, question: String, reply: String, remember: Bool) {
        guard pendingQuestion == token else { return }
        pendingQuestion = nil
        tutorDeadline?.cancel()
        tutorDeadline = nil
        tutorTask = nil
        isThinking = false
        append(.monster(reply))
        if remember {
            var turns = tutorHistory[messageID] ?? []
            turns.append(MonsterTutorTurn(question: question, reply: reply))
            tutorHistory[messageID] = Array(turns.suffix(4))
        }
    }

    static func fallbackReply(for card: Regret, error: Error) -> String {
        let opening: String
        switch error as? FlashcardServiceError {
        case .dailyLimit, .serviceAtCapacity: opening = "Live tutor replies have reached their limit for now."
        case .alreadyGenerating, .rateLimited, .serviceBusy: opening = "I'm waiting for the AI service. Try your question again shortly."
        default: opening = "I can't reach the live tutor right now."
        }
        let saved = card.backgroundExplanation.trimmingCharacters(in: .whitespacesAndNewlines)
        return opening + (saved.isEmpty ? " You can still answer this card and keep studying." :
            " Here's the saved explanation for this card:\n\n" + String(saved.prefix(2000)))
    }

    func stop() {
        stopped = true
        scriptTask?.cancel()
        scriptTask = nil
        tutorTask?.cancel()
        tutorDeadline?.cancel()
        tutorTask = nil
        tutorDeadline = nil
        if pendingQuestion != nil { append(.system("That follow-up was cancelled. You can ask again.")) }
        pendingQuestion = nil
        isThinking = false
    }

    /// Answer a multiple-choice card by option index.
    func answer(choiceIndex: Int) {
        guard method == .inChat, !stopped, !isThinking, awaitingAnswer, let card = currentCard, card.answerMode == .choices,
              card.choices.indices.contains(choiceIndex) else { return }
        let echo = card.choices.indices.contains(choiceIndex) ? card.choices[choiceIndex] : ""
        append(.user(echo))
        grade(choiceIndex == card.correctAnswerIndex, card: card)
    }

    /// Answer a typed card.
    func answer(typed: String) {
        guard method == .inChat, !stopped, !isThinking, awaitingAnswer, let card = currentCard,
              !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        append(.user(typed.trimmingCharacters(in: .whitespacesAndNewlines)))
        grade(AnswerGrading.matches(typed, card.correctAnswer), card: card)
    }

    private func presentNextCard() {
        guard let next = queue.first else { finish(); return }
        queue.removeFirst()
        currentCard = next
        presented[next.id] = next
        awaitingAnswer = true
        append(MonsterMessage(sender: .monster, kind: .card(next)))
    }

    private func grade(_ correct: Bool, card: Regret) {
        awaitingAnswer = false
        results.append(correct)
        if correct {
            correctCount += 1
            outcomes[card.id] = true          // a later correct answer wins
        } else if outcomes[card.id] != true {
            outcomes[card.id] = false
        }
        if correct || unrecordedOutcomes[card.id] == nil { unrecordedOutcomes[card.id] = correct }

        let why = card.backgroundExplanation.isEmpty ? nil : card.backgroundExplanation
        append(MonsterMessage(sender: .monster,
                              kind: .reveal(correct: correct,
                                            answer: card.correctAnswer,
                                            why: correct ? nil : why)))
        vars.score = "\(correctCount)/\(vars.questions)"
        say(correct ? .correct : .wrong)

        // Harder pass bar at higher moods: annoyed and up re-queue misses, so you
        // must actually get them right. Chill/nudgy let a miss slide (earn less).
        if !correct, dials.mood >= .annoyed {
            queue.append(card)
        }
        presentNextCard()
    }

    private func finish() {
        guard !isFinished else { return }
        currentCard = nil
        awaitingAnswer = false

        // The real unlock: the existing economy validates completion and pays for
        // correct answers at the mood's per-card rate (this clears the shields).
        grantedMinutes = studyGuard.grantEarnedBudget(results: results, perCardSeconds: secondsPerCorrectAnswer)

        writeBackCurrentDeck()

        let reaction = grantedMinutes > 0
            ? reactionPicker.completedRound(correctAnswers: correctCount, totalAnswers: results.count)
            : nil
        let outcome = roundOutcome
        append(.monster(MonsterScript.roundReaction(persona: persona, outcome: outcome, vars: vars,
            seed: nextVoiceVariant("result.\(outcome.rawValue)"))))
        appendSendoff(reaction: reaction)
        appendRecap()
        if grantedMinutes > 0 {
            append(.init(sender: .monster, kind: .grant(minutes: grantedMinutes)))
            _ = QV2Streak.recordSuccess()
        }
        MonsterNudges.rescheduleAfterStudy(persona: persona)
        isFinished = true
    }

    // MARK: Study sheet

    var studyEarnedSeconds: Int {
        min(SGContract.maxEarnedMinutes * 60, correctCount * secondsPerCorrectAnswer)
    }

    var studyProjectedMinutes: Int {
        SGContract.completedQuizMinutes(results: results, perCardSeconds: secondsPerCorrectAnswer)
    }

    @discardableResult
    func beginStudyRound() -> Bool {
        guard method == .studySheet, !stopped, !isThinking, !isFinished,
              studySheetState == .offered || studySheetState == .active,
              let round = studyRound, let question = round.currentQuestion else { return false }
        studySheetState = .active
        sheetQuestionContexts[question.id] = question.card
        return true
    }

    func answerStudyChoice(questionID: UUID, index: Int) {
        guard let question = studyRound?.currentQuestion, question.id == questionID,
              question.card.answerMode == .choices, question.card.choices.indices.contains(index) else { return }
        recordStudyAnswer(questionID: questionID, correct: index == question.card.correctAnswerIndex,
                          text: question.card.choices[index], choiceIndex: index)
    }

    func answerStudyTyped(questionID: UUID, text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let question = studyRound?.currentQuestion, question.id == questionID,
              question.card.answerMode == .typed else { return }
        recordStudyAnswer(questionID: questionID, correct: AnswerGrading.matches(text, question.card.correctAnswer),
                          text: text, choiceIndex: nil)
    }

    private func recordStudyAnswer(questionID: UUID, correct: Bool, text: String, choiceIndex: Int?) {
        guard method == .studySheet, !stopped, !isThinking, studySheetState == .active,
              var round = studyRound, let question = round.currentQuestion,
              question.id == questionID, round.currentAnswer == nil else { return }
        round.answers.append(MonsterStudyAnswer(id: questionID, correct: correct, text: text, choiceIndex: choiceIndex))
        results.append(correct)
        if correct { correctCount += 1 }
        if correct || outcomes[question.card.id] == nil { outcomes[question.card.id] = correct }
        if correct || unrecordedOutcomes[question.card.id] == nil { unrecordedOutcomes[question.card.id] = correct }
        presented[question.card.id] = question.card
        studyRound = round
    }

    /// Returns true only when the completed sheet should dismiss back to chat.
    @discardableResult
    func advanceStudyRound(questionID: UUID) -> Bool {
        guard method == .studySheet, !stopped, !isThinking, studySheetState == .active,
              var round = studyRound, round.currentQuestion?.id == questionID,
              round.currentAnswer != nil else { return false }
        if round.index + 1 < round.questions.count {
            round.index += 1
            if let question = round.currentQuestion { sheetQuestionContexts[question.id] = question.card }
            studyRound = round
            return false
        }
        guard round.isComplete else { return false }
        append(.init(sender: .monster, kind: .studyRecap(.init(round: round, earnedSeconds: studyEarnedSeconds))))
        if !round.isFollowUp, round.correctCount < round.requiredCorrect {
            let previousIDs = Set(round.questions.map { $0.card.id })
            let missedIDs = Set(round.answers.filter { !$0.correct }.map(\.id))
            let missed = round.questions.filter { missedIDs.contains($0.id) }.map(\.card)
            let topics = Set(missed.compactMap(\.topic))
            let fresh = studyCards.filter { !previousIDs.contains($0.id) }
            var followUp = CardSelection.pick(from: fresh, count: 3, examTopics: topics)
            let freshCount = followUp.count
            // Small decks stay usable offline. Label reused material as review.
            for card in missed + studyCards where followUp.count < 3 && !followUp.contains(where: { $0.id == card.id }) {
                followUp.append(card)
            }
            if !followUp.isEmpty {
                let next = MonsterStudyRound(title: deckName, cards: followUp, isFollowUp: true, freshCount: freshCount)
                studyRound = next
                studySheetState = .offered
                append(.monster(MonsterScript.sheetRecap(persona: persona, round: round, followUp: next,
                    exam: vars.exam, examDays: vars.examDays,
                    seed: nextVoiceVariant("sheet.followUp"))))
                append(.init(sender: .monster, kind: .studyRound(next)))
                return true
            }
        }
        studySheetState = .readyToUnlock
        append(.monster(MonsterScript.sheetRecap(persona: persona, round: round, followUp: nil,
            exam: vars.exam, examDays: vars.examDays,
            seed: nextVoiceVariant("sheet.result.\(MonsterRoundOutcome(correctAnswers: round.correctCount, totalAnswers: round.questions.count).rawValue)"))))
        return true
    }

    func claimStudyTime() {
        guard method == .studySheet, !stopped, !isThinking, !isFinished,
              studySheetState == .readyToUnlock, studyRound?.isComplete == true else { return }
        studySheetState = .finished
        grantedMinutes = studyGuard.grantEarnedBudget(results: results, perCardSeconds: secondsPerCorrectAnswer)
        writeBackCurrentDeck()
        let reaction = grantedMinutes > 0
            ? reactionPicker.completedRound(correctAnswers: correctCount, totalAnswers: results.count) : nil
        appendSendoff(reaction: reaction)
        if grantedMinutes > 0 {
            append(.init(sender: .monster, kind: .grant(minutes: grantedMinutes)))
            _ = QV2Streak.recordSuccess()
        }
        MonsterNudges.rescheduleAfterStudy(persona: persona)
        isFinished = true
    }

    /// A post-session recap (Phase 2 adaptive): how many locked in and which to
    /// review. Keep this below the closing dialogue so it never splits the messages.
    private func appendRecap() {
        let total = outcomes.count
        guard total > 0 else { return }
        let correct = outcomes.values.filter { $0 }.count
        var recap = "Recap: \(correct)/\(total) locked in."
        let missed = presented.values
            .filter { outcomes[$0.id] == false }
            .map { $0.quizPrompt.text }
        if !missed.isEmpty {
            recap += " Worth another look: " + missed.prefix(2).joined(separator: "; ")
        }
        append(.system(recap))
    }

    // MARK: Voice

    private var roundOutcome: MonsterRoundOutcome {
        MonsterRoundOutcome(correctAnswers: correctCount, totalAnswers: results.count)
    }

    private func nextVoiceVariant(_ lane: String) -> Int {
        MonsterOpeningRotation.draw(personaID: persona.id, lane: lane, defaults: openingDefaults)
    }

    private func appendSendoff(reaction: MonsterReaction? = nil) {
        let outcome = roundOutcome
        let lane = grantedMinutes > 0 ? outcome.rawValue : "noGrant"
        append(.monster(MonsterScript.sendoff(persona: persona, outcome: outcome, minutes: grantedMinutes,
            seed: nextVoiceVariant("sendoff.\(lane)")), reaction: reaction))
    }

    private func say(_ context: MonsterContext, reaction: MonsterReaction? = nil) {
        lineSeed += 1
        let line = bundleLine(context) ?? MonsterScript.line(persona: persona,
                                                             mood: dials.mood,
                                                             context: context,
                                                             vars: vars,
                                                             seed: lineSeed)
        append(.monster(line, reaction: reaction))
    }

    /// A line from the AI bundle for this context, if one was fetched.
    private func bundleLine(_ context: MonsterContext) -> String? {
        guard let b = bundle else { return nil }
        let raw: String?
        switch context {
        case .greeting: raw = b.greeting
        case .demand:   raw = b.demand
        case .correct:  raw = b.correct.isEmpty ? nil : b.correct[abs(lineSeed) % b.correct.count]
        case .wrong:    raw = b.wrong.isEmpty ? nil : b.wrong[abs(lineSeed) % b.wrong.count]
        // Settlement copy must use the actual local grant, never a precomputed promise.
        case .pass, .fail, .sendoff: raw = nil
        }
        return raw.map { MonsterScript.fill($0, vars: vars) }
    }

    private func append(_ message: MonsterMessage) { messages.append(message) }

    // MARK: Pressure helpers

    private static func daysSinceLastStudy(cards: [Regret], now: Date) -> Int {
        guard let last = cards.compactMap({ $0.lastReviewedAt }).max() else { return 99 }
        return max(0, Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0)
    }

    private static func dominantTopic(of cards: [Regret]) -> String? {
        let topics = cards.compactMap { $0.topic }.filter { !$0.isEmpty }
        guard !topics.isEmpty else { return nil }
        return Dictionary(grouping: topics, by: { $0 })
            .max { $0.value.count < $1.value.count }?.key
    }
}
