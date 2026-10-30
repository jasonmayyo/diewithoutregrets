import XCTest
@testable import StudyReliability

final class MonsterStudySheetTests: XCTestCase {
    private func cards(_ count: Int) -> [Regret] {
        (0..<count).map { index in
            Regret(regretPrompt: "Question \(index): plants absorb ___.", regret: "light",
                   choices: ["light", "sand", "soil", "wind"], correctAnswerIndex: 0,
                   backgroundExplanation: "Light supplies energy.", topic: "Plants")
        }
    }

    @MainActor private func make(_ cards: [Regret]) -> (MonsterSession, StudyGuardManager, DeckStore) {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Biology", cards: cards)
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, examStore: ExamStore(), studyGuard: manager,
                                     sharedDefaults: nil, method: .studySheet, loadBundle: { _, _, _ in nil })
        session.start()
        return (session, manager, store)
    }

    @MainActor private func complete(_ session: MonsterSession, correct: Int) throws {
        XCTAssertTrue(session.beginStudyRound())
        let count = try XCTUnwrap(session.studyRound?.questions.count)
        for index in 0..<count {
            let question = try XCTUnwrap(session.studyRound?.currentQuestion)
            session.answerStudyChoice(questionID: question.id, index: index < correct ? 0 : 1)
            XCTAssertEqual(session.advanceStudyRound(questionID: question.id), index == count - 1)
        }
    }

    func testInlineIsTheDefaultAndExplicitSheetPreferenceIsPreserved() {
        let suite = "MonsterStudySheetTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(MonsterStudyMethod.selected(in: defaults), .inChat)
        defaults.set("studySheet", forKey: MonsterStudyMethod.preferenceKey)
        XCTAssertEqual(MonsterStudyMethod.selected(in: defaults), .studySheet)
        defaults.set("invalid", forKey: MonsterStudyMethod.preferenceKey)
        XCTAssertEqual(MonsterStudyMethod.selected(in: defaults), .inChat)
    }

    @MainActor func testSheetDoesNotSendQuestionsOrAnswersIntoTheTranscript() throws {
        let (session, manager, _) = make(cards(8))
        XCTAssertEqual(session.studyRound?.questions.count, 4)
        XCTAssertFalse(session.messages.contains { $0.card != nil })
        let before = session.messages.count
        let question = try XCTUnwrap(session.studyRound?.currentQuestion)
        session.answerStudyChoice(questionID: question.id, index: 0)
        XCTAssertEqual(session.studyRound?.answers.count, 0, "An unopened sheet cannot be graded")
        XCTAssertTrue(session.beginStudyRound())
        XCTAssertFalse(session.advanceStudyRound(questionID: question.id), "An unanswered card cannot advance")
        session.answerStudyChoice(questionID: UUID(), index: 0)
        session.answerStudyChoice(questionID: question.id, index: 99)
        session.answerStudyTyped(questionID: question.id, text: "light")
        XCTAssertEqual(session.studyRound?.answers.count, 0)
        session.answerStudyChoice(questionID: question.id, index: 0)
        session.answerStudyChoice(questionID: question.id, index: 1)
        XCTAssertEqual(session.studyRound?.correctCount, 1)
        XCTAssertEqual(session.studyEarnedSeconds, session.secondsPerCorrectAnswer)
        XCTAssertEqual(session.messages.count, before)
        XCTAssertEqual(manager.grants, 0)
        XCTAssertFalse(session.advanceStudyRound(questionID: question.id))
        session.answerStudyChoice(questionID: question.id, index: 0)
        XCTAssertEqual(session.studyRound?.answers.count, 1, "A stale callback cannot answer the next card")
    }

    @MainActor func testThreeOfFourPassesAndGrantRequiresAnExplicitSingleClaim() throws {
        for hits in [3, 4] {
            let (session, manager, store) = make(cards(9))
            try complete(session, correct: hits)
            XCTAssertEqual(session.studySheetState, .readyToUnlock)
            XCTAssertFalse(session.studyRound!.isFollowUp)
            XCTAssertEqual(manager.grants, 0)
            XCTAssertFalse(session.isFinished)
            XCTAssertFalse(session.beginStudyRound())
            XCTAssertEqual(session.studyProjectedMinutes,
                           SGContract.completedQuizMinutes(results: Array(repeating: true, count: hits),
                                                           perCardSeconds: session.secondsPerCorrectAnswer))
            session.claimStudyTime(); session.claimStudyTime(); session.start()
            XCTAssertEqual(manager.grants, 1)
            XCTAssertTrue(session.isFinished)
            XCTAssertEqual(store.recorded.count, 4)
            XCTAssertEqual(store.recorded.values.filter { $0 }.count, hits)
        }
    }

    @MainActor func testLowScoreOffersExactlyOneFreshFollowupAndKeepsEarlierEarnings() throws {
        let (session, manager, _) = make(cards(10))
        let initial = Set(session.studyRound!.questions.map { $0.card.id })
        try complete(session, correct: 2)
        let followUp = try XCTUnwrap(session.studyRound)
        XCTAssertTrue(followUp.isFollowUp)
        XCTAssertEqual(followUp.questions.count, 3)
        XCTAssertEqual(followUp.freshCount, 3)
        XCTAssertTrue(initial.isDisjoint(with: followUp.questions.map { $0.card.id }))
        XCTAssertEqual(session.studySheetState, .offered)
        XCTAssertEqual(session.studyEarnedSeconds, 2 * session.secondsPerCorrectAnswer)
        session.claimStudyTime()
        XCTAssertEqual(manager.grants, 0)
        try complete(session, correct: 0)
        XCTAssertEqual(session.studySheetState, .readyToUnlock, "A failed follow-up must never create another round")
        XCTAssertEqual(session.studyRound?.id, followUp.id)
        XCTAssertEqual(session.studyEarnedSeconds, 2 * session.secondsPerCorrectAnswer)
        XCTAssertEqual(session.messages.filter { if case .studyRecap = $0.kind { return true }; return false }.count, 2)
        session.claimStudyTime()
        XCTAssertEqual(manager.grants, 1)
        XCTAssertGreaterThan(session.grantedMinutes, 0)
    }

    @MainActor func testSmallDuplicateAndInvalidDecksStayFiniteAndLabelReviewHonestly() throws {
        for count in 1...6 {
            var input = cards(count)
            var duplicate = input[0]; duplicate = Regret(regretPrompt: duplicate.regretPrompt, regret: "light",
                choices: duplicate.choices, correctAnswerIndex: 0, backgroundExplanation: "")
            var broken = input[0]; broken.correctAnswerIndex = 99
            input += [input[0], duplicate, broken]
            let (session, manager, store) = make(input)
            XCTAssertEqual(session.studyRound?.questions.count, min(count, 4))
            try complete(session, correct: 0)
            let followUp = try XCTUnwrap(session.studyRound)
            XCTAssertEqual(followUp.questions.count, min(3, count))
            XCTAssertEqual(followUp.freshCount, max(0, count - 4))
            XCTAssertTrue(followUp.cardDescription.contains("revisit"))
            XCTAssertEqual(Set(followUp.questions.map { $0.card.id }).count, followUp.questions.count)
            try complete(session, correct: 0)
            session.claimStudyTime()
            XCTAssertEqual(session.grantedMinutes, 0)
            XCTAssertTrue(session.isFinished)
            XCTAssertEqual(manager.grants, 1)
            XCTAssertEqual(store.selectedDeck?.cards.count, input.count)
        }
        let (empty, manager, _) = make([])
        XCTAssertTrue(empty.isFinished)
        XCTAssertFalse(empty.beginStudyRound())
        empty.claimStudyTime()
        XCTAssertEqual(manager.grants, 0)
    }

    @MainActor func testPausedTypedAnswerResumesWithoutRescoringAndStopBlocksMutations() throws {
        let item = Regret(regretPrompt: "What do plants absorb?", regret: "light", choices: ["light"],
                          correctAnswerIndex: 0, backgroundExplanation: "Light supplies energy.", answerMode: .typed)
        let (session, manager, _) = make([item])
        XCTAssertTrue(session.beginStudyRound())
        let question = try XCTUnwrap(session.studyRound?.currentQuestion)
        session.answerStudyChoice(questionID: question.id, index: 0)
        session.answerStudyTyped(questionID: question.id, text: "  ")
        XCTAssertNil(session.studyRound?.currentAnswer)
        session.answerStudyTyped(questionID: question.id, text: "LIGHT")
        XCTAssertEqual(session.studyRound?.currentAnswer?.correct, true)
        XCTAssertTrue(session.beginStudyRound(), "Reopening a paused sheet resumes the same state")
        session.answerStudyTyped(questionID: question.id, text: "light")
        XCTAssertEqual(session.studyRound?.answers.count, 1)
        session.stop()
        XCTAssertFalse(session.advanceStudyRound(questionID: question.id))
        XCTAssertFalse(session.beginStudyRound())
        session.start()
        XCTAssertTrue(session.advanceStudyRound(questionID: question.id))
        session.stop(); session.claimStudyTime()
        XCTAssertEqual(manager.grants, 0)
        session.start(); session.claimStudyTime()
        XCTAssertEqual(manager.grants, 1)
    }

    @MainActor func testSheetQuestionsSupportTutorFollowupsWithoutGrading() async throws {
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: cards(4))
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil, method: .studySheet,
            loadBundle: { _, _, _ in XCTFail("Sheet mode doesn't need a reaction bundle"); return nil },
            tutorReply: { _, _, _, _ in "Light supplies energy." })
        session.start(); XCTAssertTrue(session.beginStudyRound())
        let question = try XCTUnwrap(session.studyRound?.currentQuestion)
        session.ask("Why?", about: question.id)
        XCTAssertTrue(session.isThinking)
        session.answerStudyChoice(questionID: question.id, index: 0)
        while session.isThinking { await Task.yield() }
        XCTAssertEqual(session.studyRound?.answers.count, 0)
        XCTAssertEqual(session.studyRound?.currentQuestion?.id, question.id)
        XCTAssertEqual(manager.grants, 0)
        session.answerStudyChoice(questionID: question.id, index: 0)
        XCTAssertEqual(session.studyRound?.correctCount, 1)
        session.stop()
    }
}
