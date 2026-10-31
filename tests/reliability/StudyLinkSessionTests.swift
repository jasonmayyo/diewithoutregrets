import XCTest
@testable import StudyReliability

final class StudyLinkSessionTests: XCTestCase {
    @MainActor func testMonsterMentionsOnlyTheSelectedDecksLinkedExamInBothModes() {
        for method in [MonsterStudyMethod.inChat, .studySheet] {
            let now = Date()
            let decks = DeckStore()
            let deck = Deck(name: "Cells", cards: [card()])
            decks.selectedDeck = deck
            let exams = ExamStore()
            exams.exams = [
                StudyExam(subject: "History", date: Calendar.current.date(byAdding: .day, value: 1, to: now)!),
                StudyExam(subject: "Biology", date: Calendar.current.date(byAdding: .day, value: 4, to: now)!, deckIDs: [deck.id])
            ]
            let session = MonsterSession(deckStore: decks, examStore: exams, studyGuard: StudyGuardManager(),
                sharedDefaults: nil, now: now, method: method, loadBundle: { _, _, _ in nil })
            session.start()
            let opening = session.messages.compactMap(\.text).joined(separator: " ")
            XCTAssertTrue(opening.contains("Biology"))
            XCTAssertFalse(opening.contains("History"))
            session.stop()
        }
    }

    @MainActor func testAnUnlinkedDeckDoesNotBorrowTheGlobalExamCountdown() {
        let decks = DeckStore(); decks.selectedDeck = Deck(name: "Biology", cards: [card()])
        let exams = ExamStore(); exams.exams = [StudyExam(subject: "Chemistry", date: Date())]
        let session = MonsterSession(deckStore: decks, examStore: exams, studyGuard: StudyGuardManager(),
            sharedDefaults: nil, method: .inChat, loadBundle: { _, _, _ in nil })
        session.start()
        XCTAssertFalse(session.messages.compactMap(\.text).joined().contains("Chemistry"))
        XCTAssertTrue(session.awaitingAnswer)
        session.stop()
    }

    @MainActor func testChangingDecksRefreshesAndClearsTheExamContextSentToTheTutor() async {
        let first = Deck(name: "Cells", cards: [card()])
        let second = Deck(name: "Chemistry", cards: [card()])
        let unlinked = Deck(name: "General recall", cards: [card()])
        let decks = DeckStore(); decks.selectedDeck = first
        let exams = ExamStore()
        exams.exams = [StudyExam(subject: "Biology final", date: Date(), deckIDs: [first.id]),
                       StudyExam(subject: "Chemistry quiz", date: Date(), deckIDs: [second.id])]
        let firstLoad = expectation(description: "First deck context")
        let secondLoad = expectation(description: "Second deck context")
        let thirdLoad = expectation(description: "Unlinked deck context")
        var contexts: [MonsterScriptVars] = []
        let session = MonsterSession(deckStore: decks, examStore: exams, studyGuard: StudyGuardManager(),
            sharedDefaults: nil, method: .inChat, loadBundle: { _, _, vars in
                contexts.append(vars)
                if contexts.count == 1 { firstLoad.fulfill() }
                if contexts.count == 2 { secondLoad.fulfill() }
                if contexts.count == 3 { thirdLoad.fulfill() }
                return nil
            })
        session.start()
        await fulfillment(of: [firstLoad], timeout: 2)
        decks.selectedDeck = second
        XCTAssertTrue(session.switchToSelectedDeck())
        await fulfillment(of: [secondLoad], timeout: 2)
        decks.selectedDeck = unlinked
        XCTAssertTrue(session.switchToSelectedDeck())
        await fulfillment(of: [thirdLoad], timeout: 2)
        XCTAssertEqual(contexts.map(\.exam), ["Biology final", "Chemistry quiz", nil])
        XCTAssertNil(contexts.last?.examDays)
        session.stop()
    }

    private func card() -> Regret {
        Regret(regretPrompt: "Which organelle produces ATP?", regret: "Mitochondria", choices: ["Mitochondria", "Nucleus"], correctAnswerIndex: 0, backgroundExplanation: "Cell respiration.")
    }
}
