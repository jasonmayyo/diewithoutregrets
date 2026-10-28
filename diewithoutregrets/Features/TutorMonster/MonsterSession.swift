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

    // MARK: Session config (frozen at init)
    let persona: MonsterPersona
    let dials: SGContract.MoodDials

    // MARK: Dependencies
    private let deckStore: DeckStore
    private let studyGuard: StudyGuardManager

    // MARK: Flow state
    private let deckID: UUID?
    private let moodPerCardSeconds: Int
    private var queue: [Regret]
    private var currentCard: Regret?
    private var results: [Bool?] = []
    private var outcomes: [UUID: Bool] = [:]
    private var presented: [UUID: Regret] = [:]
    private var bundle: MonsterScriptBundle?
    private var correctCount = 0
    private var lineSeed = 0
    private var vars: MonsterScriptVars

    init(deckStore: DeckStore = .shared,
         examStore: ExamStore = .shared,
         personaStore: PersonaStore = .shared,
         studyGuard: StudyGuardManager = .shared,
         sharedDefaults: UserDefaults? = SGContract.sharedDefaults,
         now: Date = Date()) {
        self.deckStore = deckStore
        self.studyGuard = studyGuard
        self.persona = personaStore.persona

        let deck = deckStore.selectedDeck
        self.deckID = deck?.id
        let cards = deck?.cards ?? []
        let exam = examStore.nextExam

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
        self.moodPerCardSeconds = SGContract.perCardSeconds(for: dials)

        // Toll: weakness + exam-topic weighted draw.
        let toll = CardSelection.pick(from: cards,
                                      count: dials.questions,
                                      examTopics: Set(exam?.topics ?? []),
                                      now: now)
        self.queue = toll

        self.vars = MonsterScriptVars(
            app: "your apps",
            count: pressure.gateEncountersToday,
            exam: exam?.subject,
            examDays: exam?.daysUntil(from: now),
            topic: Self.dominantTopic(of: toll),
            questions: toll.count,
            minutes: dials.minutesBack
        )
    }

    /// True when there is a toll to run. The caller falls back to the legacy quiz
    /// when this is false (empty/absent deck).
    var canRun: Bool { !queue.isEmpty }

    /// The card currently awaiting an answer, for the input area.
    var activeCard: Regret? { awaitingAnswer ? currentCard : nil }

    // MARK: Flow

    /// Open the conversation: greeting + demand, then the first card.
    func start() {
        guard messages.isEmpty, canRun else { return }
        Task { await run() }
    }

    /// Fetch a personalized AI script (best-effort, time-boxed), then run the flow.
    /// On any failure the scripted banks are used — the gate never waits on the net.
    private func run() async {
        isThinking = true
        bundle = await MonsterAI.fetchBundle(persona: persona, mood: dials.mood, vars: vars)
        isThinking = false
        say(.greeting)
        say(.demand)
        // Surface WHY these cards: exam proximity + weakness (Phase 2 adaptive).
        if bundle != nil || vars.examDays != nil { sayReason() }
        presentNextCard()
    }

    private func sayReason() {
        lineSeed += 1
        if let b = bundle {
            append(.monster(MonsterScript.fill(b.reason, vars: vars)))
        } else {
            append(.monster(MonsterScript.reasonLine(persona: persona, vars: vars, seed: lineSeed)))
        }
    }

    /// Answer a multiple-choice card by option index.
    func answer(choiceIndex: Int) {
        guard awaitingAnswer, let card = currentCard, card.answerMode == .choices else { return }
        let echo = card.choices.indices.contains(choiceIndex) ? card.choices[choiceIndex] : ""
        append(.user(echo))
        grade(choiceIndex == card.correctAnswerIndex, card: card)
    }

    /// Answer a typed card.
    func answer(typed: String) {
        guard awaitingAnswer, let card = currentCard else { return }
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
        currentCard = nil
        awaitingAnswer = false

        // The real unlock: the existing economy validates completion and pays for
        // correct answers at the mood's per-card rate (this clears the shields).
        grantedMinutes = studyGuard.grantEarnedBudget(results: results, perCardSeconds: moodPerCardSeconds)

        if let deckID { deckStore.recordOutcomes(outcomes, deckID: deckID) }

        if grantedMinutes > 0 {
            vars.minutes = grantedMinutes
            append(MonsterMessage(sender: .monster, kind: .grant(minutes: grantedMinutes)))
            say(.pass)
            _ = QV2Streak.recordSuccess()
        } else {
            say(.fail)
        }
        appendRecap()
        say(.sendoff)
        isFinished = true
    }

    /// A post-session recap (Phase 2 adaptive): how many locked in and which to
    /// review. A neutral system line; the persona pass/fail + sendoff bracket it.
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

    private func say(_ context: MonsterContext) {
        lineSeed += 1
        let line = bundleLine(context) ?? MonsterScript.line(persona: persona,
                                                             mood: dials.mood,
                                                             context: context,
                                                             vars: vars,
                                                             seed: lineSeed)
        append(.monster(line))
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
        case .pass:     raw = b.pass
        case .fail:     raw = b.fail
        case .sendoff:  raw = b.sendoff
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
