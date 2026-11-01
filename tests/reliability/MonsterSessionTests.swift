import XCTest
@testable import StudyReliability

final class MonsterSessionTests: XCTestCase {
    @MainActor func testConfirmedBuddyRuleControlsRealRoundAndGrant() {
        let suite = "BuddyEarnRule.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set(true, forKey: BuddyIdentity.ruleKey)
        preferences.set(5, forKey: "flashcardCount")
        BuddyIdentity(name: "Alex", pronouns: "They / them").save(in: preferences)
        let store = DeckStore()
        store.selectedDeck = Deck(name: "Biology", cards: (0..<8).map { _ in card() })
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
            creatorDefaults: preferences, method: .inChat, loadBundle: { _, _, _ in nil })
        XCTAssertEqual(session.totalQuestions, 5)
        XCTAssertEqual(session.secondsPerCorrectAnswer, 60)
        session.start()
        XCTAssertTrue(session.messages.first?.text?.hasPrefix("Alex, ") == true)
        for _ in 0..<5 { session.answer(choiceIndex: 0) }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.grantedMinutes, 5)
        XCTAssertEqual(manager.grants, 1)
        session.answer(choiceIndex: 0)
        XCTAssertEqual(manager.grants, 1)
        session.stop()
    }

    func testAnswerTurnShowsTypingBeforeEveryMonsterReply() {
        let answer = MonsterMessage.user("light")
        let verdict = MonsterMessage(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil))
        let reaction = MonsterMessage.monster("That's it! You've got this.")
        let question = MonsterMessage(sender: .monster, kind: .card(card()))
        let turn = [answer, verdict, reaction, question]
        var previous: MonsterMessage?
        for message in turn {
            let pacing = MonsterMessagePacing.before(message, after: previous)
            if message.sender == .user {
                XCTAssertEqual(pacing.readingPause + pacing.typingDuration, 0)
            } else {
                XCTAssertGreaterThanOrEqual(pacing.typingDuration, 1)
                XCTAssertLessThanOrEqual(pacing.typingDuration, 2)
                if previous?.sender == .monster {
                    XCTAssertGreaterThan(pacing.readingPause, 0, "Dots must disappear for a reading beat between replies")
                }
            }
            previous = message
        }
    }

    func testLongCorrectionGetsReadingTimeAndUserFollowupsRemainImmediate() {
        let short = MonsterMessage.monster("Try again.")
        let correction = MonsterMessage(sender: .monster, kind: .reveal(correct: false, answer: "light",
            why: String(repeating: "Photosynthesis turns light into chemical energy. ", count: 8)))
        let next = MonsterMessage.monster("Let's try another one.")
        XCTAssertGreaterThan(MonsterMessagePacing.before(next, after: correction).readingPause,
                             MonsterMessagePacing.before(next, after: short).readingPause)
        XCTAssertGreaterThanOrEqual(MonsterMessagePacing.before(correction, after: .user("sand")).typingDuration, 1)
        let followup = MonsterMessagePacing.before(.user("Why?"), after: correction)
        XCTAssertEqual(followup.readingPause + followup.typingDuration, 0)
        let grant = MonsterMessagePacing.before(.init(sender: .monster, kind: .grant(minutes: 3)), after: next)
        XCTAssertEqual(grant.typingDuration, 0)
        XCTAssertGreaterThan(grant.readingPause, 0)
    }

    func testQuietReadingPauseCannotEnableAnswersBeforeTheQueuedTurnFinishes() {
        let item = card()
        let question = MonsterMessage(sender: .monster, kind: .card(item))
        let messages = [question, .user("Why?"), .monster("Here is an explanation.")]
        XCTAssertNil(MonsterReplyTarget.current(messages: messages, revealed: 2,
            activeCard: item, isThinking: false), "No typing dots does not mean the queued reply is ready")
        XCTAssertEqual(MonsterReplyTarget.current(messages: messages, revealed: 3,
            activeCard: item, isThinking: false)?.messageID, question.id)
    }

    func testProgressWaitsForVisibleVerdictsAndIgnoresFollowups() {
        let first = card(), second = card()
        var messages = [MonsterMessage(sender: .monster, kind: .card(first)),
                        .user("Why?"), .monster("Here is a hint.")]
        func progress() -> MonsterRoundProgress {
            MonsterRoundProgress(messages: messages, total: 2, requiresCorrectAnswers: true)
        }
        XCTAssertEqual(progress().completed, 0)
        messages.append(.init(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil)))
        XCTAssertEqual(progress().fraction, 0.5)
        messages.append(.init(sender: .monster, kind: .card(second)))
        XCTAssertEqual(progress().completed, 1)
        messages.append(.init(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil)))
        XCTAssertEqual(progress().fraction, 1)
    }

    func testRetryProgressCountsEachCardOnceAndRespectsThePassRule() {
        let item = card()
        let question = MonsterMessage(sender: .monster, kind: .card(item))
        let wrong = MonsterMessage(sender: .monster, kind: .reveal(correct: false, answer: "light", why: nil))
        let right = MonsterMessage(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil))
        XCTAssertEqual(MonsterRoundProgress(messages: [question, wrong], total: 1, requiresCorrectAnswers: true).completed, 0)
        XCTAssertEqual(MonsterRoundProgress(messages: [question, wrong], total: 1, requiresCorrectAnswers: false).completed, 1)
        let retry = MonsterMessage(sender: .monster, kind: .card(item))
        XCTAssertEqual(MonsterRoundProgress(messages: [question, wrong, retry, right, right], total: 1,
                                           requiresCorrectAnswers: true).completed, 1)
        XCTAssertEqual(MonsterRoundProgress(messages: [], total: 0, requiresCorrectAnswers: true).fraction, 0)
    }

    func testLegacyFeedbackCannotMasqueradeAsTheNextQuestion() {
        for feedback in ["Wrong!", "That's not right!", "Close, but not right!"] {
            var item = card()
            item.regretPrompt = feedback
            item.regret = "What do plants absorb?"
            XCTAssertEqual(item.quizPrompt.text, "What do plants absorb?")
            XCTAssertTrue(item.isUsableForStudy)
            XCTAssertEqual(item.regretPrompt, feedback) // saved material stays untouched
            item.regret = "light" // an answer is never exposed as a recovered question
            XCTAssertFalse(item.isUsableForStudy)
        }
        var item = card()
        item.regretPrompt = "Why is this statement wrong?"
        XCTAssertEqual(item.quizPrompt.text, "Why is this statement wrong?")
        XCTAssertTrue(item.isUsableForStudy)
    }

    @MainActor func testPerAnswerEarningsBuildBeforeTheSingleFinalGrant() async throws {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [card(), card(), card(), card()])
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil, method: .inChat,
            loadBundle: { _, _, _ in nil }, tutorReply: { _, _, _, _ in "A helpful explanation." })
        func rewards() -> [MonsterAnswerReward] {
            MonsterAnswerReward.earned(in: session.messages, secondsPerCorrectAnswer: session.secondsPerCorrectAnswer)
        }
        session.start()
        XCTAssertTrue(rewards().isEmpty)
        session.answer(choiceIndex: 0)
        XCTAssertEqual(rewards().last?.totalSeconds, session.secondsPerCorrectAnswer)
        XCTAssertEqual(manager.grants, 0, "Showing earnings must not unlock an unfinished round")
        session.ask("Why?", about: try XCTUnwrap(session.messages.last(where: { $0.card != nil })?.id))
        while session.isThinking { await Task.yield() }
        XCTAssertEqual(rewards().count, 1, "A follow-up never earns time")
        session.answer(choiceIndex: 1)
        XCTAssertEqual(rewards().count, 1, "A wrong answer never earns time")
        for _ in 0..<12 where !session.isFinished { session.answer(choiceIndex: 0) }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(manager.grants, 1)
        let total = try XCTUnwrap(rewards().last?.totalSeconds)
        XCTAssertEqual(session.grantedMinutes * 60, ((total + 59) / 60) * 60)
        let before = rewards()
        session.answer(choiceIndex: 0); session.start()
        XCTAssertEqual(rewards(), before)
        XCTAssertEqual(manager.grants, 1)
        session.stop()
    }

    func testRewardProjectionIgnoresWrongAnswersFollowupsAndRepeatedMessageIDs() {
        let right = MonsterMessage(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil))
        let retry = MonsterMessage(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil))
        let wrong = MonsterMessage(sender: .monster, kind: .reveal(correct: false, answer: "light", why: nil))
        let messages = [wrong, .user("Why?"), .monster("Light is correct."), right, right, retry,
                        MonsterMessage(sender: .monster, kind: .grant(minutes: 3))]
        let rewards = MonsterAnswerReward.earned(in: messages, secondsPerCorrectAnswer: 75)
        XCTAssertEqual(rewards.map(\.id), [right.id, retry.id])
        XCTAssertEqual(rewards.map(\.totalSeconds), [75, 150])
        XCTAssertTrue(MonsterAnswerReward.earned(in: messages, secondsPerCorrectAnswer: 0).isEmpty)
    }

    @MainActor func testTypingAChoiceAnswerUsesTheSameRewardAndSingleGrantAsTappingIt() {
        var earned: [Int] = []
        for typed in [false, true] {
            let store = DeckStore()
            store.selectedDeck = Deck(name: "Test", cards: [card()])
            let manager = StudyGuardManager()
            let session = MonsterSession(deckStore: store, studyGuard: manager,
                sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil })
            session.start()
            if typed { session.answer(typed: "  light  ") }
            else { session.answer(choiceIndex: 0) }
            XCTAssertTrue(session.isFinished)
            XCTAssertEqual(manager.grants, 1)
            let rewards = MonsterAnswerReward.earned(in: session.messages,
                secondsPerCorrectAnswer: session.secondsPerCorrectAnswer)
            XCTAssertEqual(rewards.count, 1)
            earned.append(rewards.last?.totalSeconds ?? 0)
            let count = session.messages.count
            session.answer(typed: "light")
            session.answer(choiceIndex: 0)
            XCTAssertEqual(session.messages.count, count, "Switching input modes cannot submit twice")
            XCTAssertEqual(manager.grants, 1)
            session.stop()
        }
        XCTAssertGreaterThan(earned[0], 0)
        XCTAssertEqual(earned[0], earned[1])
    }

    func testEarningsStayWithinTheGrantCap() {
        let right = MonsterMessage(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil))
        XCTAssertEqual(MonsterAnswerReward.earned(in: [right], secondsPerCorrectAnswer: SGContract.maxEarnedMinutes * 60 + 1)
            .last?.totalSeconds, SGContract.maxEarnedMinutes * 60)
    }

    private func card() -> Regret {
        Regret(regretPrompt: "Plants absorb ___.", regret: "light", choices: ["light", "sand", "soil", "wind"],
               correctAnswerIndex: 0, backgroundExplanation: "Light supplies energy.")
    }
    @MainActor func testSessionStartsImmediatelyAndInvalidRepliesNeverGradeOrGrant() {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [card()])
        let guardManager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: guardManager, sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil })
        session.start(); session.start()
        XCTAssertEqual(session.totalQuestions, 1)
        XCTAssertNotNil(session.activeCard)
        XCTAssertEqual(session.messages.filter { $0.card != nil }.count, 1)
        let before = session.messages.count
        session.answer(choiceIndex: -1); session.answer(choiceIndex: 4); session.answer(typed: "  ")
        XCTAssertEqual(session.messages.count, before)
        XCTAssertEqual(guardManager.grants, 0)
        session.answer(choiceIndex: 0)
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(guardManager.grants, 1)
        session.answer(choiceIndex: 0); session.start()
        XCTAssertEqual(guardManager.grants, 1)
        session.stop()
    }
    @MainActor func testFollowupKeepsQuestionPendingAndDoesNotScore() async throws {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [card()])
        let manager = StudyGuardManager()
        var histories: [Int] = []
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil, method: .inChat,
            loadBundle: { _, _, _ in nil }, tutorReply: { _, _, question, history in
                histories.append(history.count)
                return "Light supplies energy for the plant."
            })
        session.start()
        let messageID = try XCTUnwrap(session.messages.last?.id)
        session.ask("Why?", about: messageID)
        XCTAssertTrue(session.isThinking)
        session.answer(choiceIndex: 0)
        while session.isThinking { await Task.yield() }
        XCTAssertFalse(session.isFinished)
        XCTAssertNotNil(session.activeCard)
        XCTAssertEqual(manager.grants, 0)
        XCTAssertEqual(MonsterReplyTarget.current(messages: session.messages, revealed: session.messages.count,
            activeCard: session.activeCard, isThinking: false)?.messageID, messageID)
        session.ask("Can you give an example?", about: messageID)
        while session.isThinking { await Task.yield() }
        XCTAssertEqual(histories, [0, 1])
        session.answer(choiceIndex: 0)
        XCTAssertEqual(manager.grants, 1)
        session.stop()
    }
    @MainActor func testDeadlineRestoresStudyAndIgnoresLateReplyEvenIfProviderIgnoresCancellation() async throws {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [card()])
        var continuation: CheckedContinuation<String, Never>?
        let session = MonsterSession(deckStore: store, sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil },
            tutorReply: { _, _, _, _ in await withCheckedContinuation { continuation = $0 } }, tutorTimeout: 10_000_000)
        session.start()
        session.ask("Why?", about: try XCTUnwrap(session.messages.last?.id))
        while continuation == nil { await Task.yield() }
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertFalse(session.isThinking)
        XCTAssertNotNil(session.activeCard)
        XCTAssertTrue(session.messages.last?.text?.contains("saved explanation") == true)
        let count = session.messages.count
        continuation?.resume(returning: "A late response")
        await Task.yield()
        XCTAssertEqual(session.messages.count, count)
        session.stop()
    }
    @MainActor func testClosingFollowupIgnoresLateReplyAndEmptyDeckFinishes() async throws {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [card()])
        var continuation: CheckedContinuation<String, Never>?
        let session = MonsterSession(deckStore: store, sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil },
            tutorReply: { _, _, _, _ in await withCheckedContinuation { continuation = $0 } })
        session.start(); session.ask("Why?", about: try XCTUnwrap(session.messages.last?.id))
        while continuation == nil { await Task.yield() }
        session.stop()
        let count = session.messages.count
        continuation?.resume(returning: "Late")
        await Task.yield()
        XCTAssertEqual(session.messages.count, count)
        XCTAssertFalse(session.isThinking)
        let empty = MonsterSession(deckStore: DeckStore(), sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil })
        empty.start()
        XCTAssertTrue(empty.isFinished)
        XCTAssertFalse(empty.messages.isEmpty)
    }
    @MainActor func testUnanswerableSavedCardsAreSkippedWithoutMutatingDeck() {
        var broken = card(); broken.correctAnswerIndex = 99
        var duplicate = card(); duplicate.choices = ["light", "LIGHT", "wind", "sand"]
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [broken, duplicate, card()])
        let session = MonsterSession(deckStore: store, sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil })
        session.start()
        XCTAssertEqual(store.selectedDeck?.cards.count, 3)
        XCTAssertTrue(session.activeCard?.isUsableForStudy == true)
        XCTAssertEqual(session.messages.filter { $0.card != nil }.count, 1)
        session.stop()
    }

    @MainActor func testReplyReadinessUsesNewestCardOccurrenceAfterFollowups() {
        let item = card()
        let first = MonsterMessage(sender: .monster, kind: .card(item))
        let second = MonsterMessage(sender: .monster, kind: .card(item))
        let messages = [first, .user("wrong"), second, .user("Why?"), .monster("Here is a hint.")]
        XCTAssertNil(MonsterReplyTarget.current(messages: messages, revealed: 2, activeCard: item, isThinking: false))
        XCTAssertNil(MonsterReplyTarget.current(messages: messages, revealed: messages.count, activeCard: item, isThinking: true))
        XCTAssertEqual(MonsterReplyTarget.current(messages: messages, revealed: messages.count,
            activeCard: item, isThinking: false)?.messageID, second.id)
    }

}

final class MonsterDeckSelectionTests: XCTestCase {
    @MainActor func testChosenDeckControlsBothStudyMethodsAndStaysFrozenForCurrentRound() throws {
        let biology = Regret(regretPrompt: "What do plants absorb?", regret: "Light",
                             choices: ["Light", "Sand"], correctAnswerIndex: 0,
                             backgroundExplanation: "", source: .init(kind: .pdf, title: "Biology.pdf"))
        let physics = Regret(regretPrompt: "What is the unit of force?", regret: "Newton",
                            choices: ["Newton", "Watt"], correctAnswerIndex: 0,
                            backgroundExplanation: "", source: .init(kind: .pdf, title: "Physics.pdf"))
        for method in [MonsterStudyMethod.inChat, .studySheet] {
            let store = DeckStore()
            store.selectedDeck = Deck(name: "Biology", cards: [biology])
            let existing = MonsterSession(deckStore: store, studyGuard: StudyGuardManager(), sharedDefaults: nil,
                                          method: method, loadBundle: { _, _, _ in nil })
            store.selectedDeck = Deck(name: "Physics", cards: [physics])
            let next = MonsterSession(deckStore: store, studyGuard: StudyGuardManager(), sharedDefaults: nil,
                                      method: method, loadBundle: { _, _, _ in nil })
            existing.start(); next.start()
            if method == .inChat {
                XCTAssertEqual(existing.activeCard?.id, biology.id)
                XCTAssertEqual(next.activeCard?.id, physics.id)
            } else {
                XCTAssertEqual(existing.studyRound?.questions.map { $0.card.id }, [biology.id])
                XCTAssertEqual(next.studyRound?.questions.map { $0.card.id }, [physics.id])
            }
            XCTAssertEqual(next.messages.flatMap(\.sources).map(\.title), ["Physics.pdf"])
            existing.stop(); next.stop()
        }
    }
}

final class MonsterChatDeckSwitchTests: XCTestCase {
    private func deck(_ name: String, count: Int = 4) -> Deck {
        Deck(name: name, cards: (0..<count).map { index in
            Regret(regretPrompt: "\(name) question \(index)?", regret: "Yes",
                   choices: ["Yes", "No"], correctAnswerIndex: 0, backgroundExplanation: "",
                   source: .init(kind: .pdf, title: "\(name).pdf"))
        })
    }

    @MainActor func testSwitchingInChatPreservesEarnedTimeAndWritesEachDeckOnce() throws {
        let first = deck("Biology"), second = deck("Physics")
        let store = DeckStore(); store.selectedDeck = first
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
            method: .inChat, loadBundle: { _, _, _ in nil })
        session.start()
        let firstCard = try XCTUnwrap(session.activeCard)
        session.answer(choiceIndex: 0)
        let earned = MonsterAnswerReward.earned(in: session.messages, secondsPerCorrectAnswer: session.secondsPerCorrectAnswer)
        let originalRound = session.roundID
        let abandonedPromptID = session.messages.last(where: { $0.card != nil })?.id
        let remaining = session.totalQuestions - 1
        store.selectedDeck = second
        XCTAssertTrue(session.switchToSelectedDeck())
        XCTAssertEqual(session.deckName, "Physics")
        XCTAssertFalse(session.messages.contains { $0.id == abandonedPromptID }, "An abandoned prompt must not inflate question numbering")
        XCTAssertEqual(session.roundID, originalRound)
        XCTAssertEqual(manager.grants, 0, "Choosing a deck cannot grant time")
        XCTAssertEqual(store.reviewWrites.count, 1)
        XCTAssertEqual(store.reviewWrites[0].deckID, first.id)
        XCTAssertEqual(store.reviewWrites[0].outcomes, [firstCard.id: true])
        XCTAssertEqual(MonsterAnswerReward.earned(in: session.messages, secondsPerCorrectAnswer: session.secondsPerCorrectAnswer), earned)
        XCTAssertEqual(session.messages.flatMap(\.sources).last?.title, "Physics.pdf")
        XCTAssertFalse(session.switchToSelectedDeck(), "Choosing the same deck cannot reset progress")
        for _ in 0..<remaining {
            XCTAssertTrue(second.cards.contains { $0.id == session.activeCard?.id })
            session.answer(choiceIndex: 0)
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(manager.grants, 1)
        XCTAssertEqual(session.grantedMinutes, SGContract.completedQuizMinutes(
            results: Array(repeating: true, count: remaining + 1), perCardSeconds: session.secondsPerCorrectAnswer))
        XCTAssertEqual(store.reviewWrites.count, 2)
        XCTAssertEqual(store.reviewWrites[1].deckID, second.id)
        XCTAssertTrue(Set(store.reviewWrites[1].outcomes.keys).isSubset(of: Set(second.cards.map(\.id))))
        session.stop()
    }

    @MainActor func testSwitchingStudySheetKeepsAnsweredTimeAndRejectsStaleQuestionCallbacks() throws {
        let first = deck("Biology"), second = deck("Physics")
        let store = DeckStore(); store.selectedDeck = first
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil, method: .studySheet)
        session.start()
        XCTAssertTrue(session.beginStudyRound())
        let oldQuestion = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
        session.answerStudyChoice(questionID: oldQuestion, index: 0)
        _ = session.advanceStudyRound(questionID: oldQuestion)
        store.selectedDeck = second
        XCTAssertTrue(session.switchToSelectedDeck())
        XCTAssertEqual(session.studyEarnedSeconds, session.secondsPerCorrectAnswer)
        XCTAssertEqual(session.studyRound?.questions.count, 3)
        XCTAssertEqual(session.studySheetState, .offered)
        XCTAssertTrue(session.beginStudyRound())
        session.answerStudyChoice(questionID: oldQuestion, index: 0)
        XCTAssertEqual(session.studyRound?.answers.count, 0)
        for index in 0..<3 {
            let question = try XCTUnwrap(session.studyRound?.currentQuestion)
            XCTAssertTrue(second.cards.contains { $0.id == question.card.id })
            session.answerStudyChoice(questionID: question.id, index: 0)
            XCTAssertEqual(session.advanceStudyRound(questionID: question.id), index == 2)
        }
        XCTAssertEqual(session.studyEarnedSeconds, 4 * session.secondsPerCorrectAnswer)
        session.claimStudyTime(); session.claimStudyTime()
        XCTAssertEqual(manager.grants, 1)
        XCTAssertEqual(store.reviewWrites.map(\.deckID), [first.id, second.id])
        session.stop()
    }

    @MainActor func testCompletedAndEmptyChatsCanStartSelectedDeckWithoutRegrantingOldAnswers() {
        let first = deck("Biology", count: 1), second = deck("Physics", count: 1)
        let store = DeckStore(); store.selectedDeck = first
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
            method: .inChat, loadBundle: { _, _, _ in nil })
        session.start(); session.answer(choiceIndex: 0)
        let originalRound = session.roundID
        store.selectedDeck = Deck(name: "Empty")
        XCTAssertFalse(session.switchToSelectedDeck())
        XCTAssertEqual(session.roundID, originalRound)
        store.selectedDeck = second
        XCTAssertTrue(session.switchToSelectedDeck())
        XCTAssertNotEqual(session.roundID, originalRound)
        XCTAssertEqual(manager.grants, 1)
        XCTAssertFalse(session.isFinished)
        XCTAssertEqual(session.activeCard?.id, second.cards[0].id)
        XCTAssertTrue(MonsterAnswerReward.earned(in: session.messages, secondsPerCorrectAnswer: session.secondsPerCorrectAnswer).isEmpty)
        session.answer(choiceIndex: 0)
        XCTAssertEqual(manager.grants, 2)
        XCTAssertEqual(session.grantedMinutes, SGContract.completedQuizMinutes(results: [true], perCardSeconds: session.secondsPerCorrectAnswer))
        session.stop()

        store.selectedDeck = nil
        let empty = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
            method: .inChat, loadBundle: { _, _, _ in nil })
        empty.start()
        XCTAssertTrue(empty.isFinished)
        store.selectedDeck = first
        XCTAssertTrue(empty.switchToSelectedDeck())
        XCTAssertEqual(empty.activeCard?.id, first.cards[0].id)
        XCTAssertEqual(manager.grants, 2)
        empty.stop()

        store.selectedDeck = Deck(name: "Fill this deck")
        let editableID = store.selectedDeck!.id
        let editable = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
            method: .inChat, loadBundle: { _, _, _ in nil })
        editable.start()
        store.selectedDeck?.cards = first.cards
        XCTAssertEqual(store.selectedDeck?.id, editableID)
        XCTAssertTrue(editable.switchToSelectedDeck(), "Adding cards to the same empty deck must recover inside chat")
        XCTAssertEqual(editable.activeCard?.id, first.cards[0].id)
        editable.stop()
    }
}
