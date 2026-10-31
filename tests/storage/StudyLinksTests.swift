import XCTest
@testable import StudyStorage

final class StudyLinksTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        suite = "StudyLinkTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testLegacyDecksAndExamsDecodeWithoutLosingTheirContents() throws {
        let deck = Deck(name: "Biology notes", cards: [card()])
        let exam = StudyExam(subject: "Biology", date: Date(), topics: ["Cells"])
        var oldDeck = try object(deck); oldDeck.removeValue(forKey: "subjectID")
        var oldExam = try object(exam)
        oldExam.removeValue(forKey: "subjectID"); oldExam.removeValue(forKey: "deckIDs")
        let decodedDeck = try JSONDecoder().decode(Deck.self, from: JSONSerialization.data(withJSONObject: oldDeck))
        let decodedExam = try JSONDecoder().decode(StudyExam.self, from: JSONSerialization.data(withJSONObject: oldExam))
        XCTAssertEqual(decodedDeck, deck)
        XCTAssertEqual(decodedExam, exam)
        XCTAssertNil(decodedDeck.subjectID)
        XCTAssertTrue(decodedExam.deckIDs.isEmpty)
    }

    func testSubjectMigrationRunsOnceAndDoesNotGuessDeckLinks() throws {
        let exams = [StudyExam(subject: "Biology", date: Date()), StudyExam(subject: " biology ", date: Date())]
        defaults.set(try JSONEncoder().encode(exams), forKey: "sg_studyExams")
        let subjects = StudySubjectStore(defaults: defaults)
        let store = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        XCTAssertEqual(subjects.subjects.count, 1)
        XCTAssertEqual(store.exams.map(\.id), exams.map(\.id))
        XCTAssertEqual(Set(store.exams.compactMap(\.subjectID)).count, 1)
        XCTAssertTrue(store.exams.allSatisfy { $0.deckIDs.isEmpty })
        var ungrouped = store.exams[0]; ungrouped.subjectID = nil; store.update(ungrouped)
        let reopened = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        XCTAssertNil(reopened.exams[0].subjectID, "Removing a subject must not be undone by migration on restart")
    }

    func testOnboardingExamMigratesWithItsDateAndSubjectIntact() throws {
        let date = Date().addingTimeInterval(172800)
        defaults.set("Anatomy", forKey: "studySubject")
        defaults.set(date.timeIntervalSince1970, forKey: "examDate")
        let subjects = StudySubjectStore(defaults: defaults)
        let store = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        XCTAssertEqual(try XCTUnwrap(store.exams.first?.date).timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(subjects.name(for: store.exams.first?.subjectID), "Anatomy")
        XCTAssertEqual(store.exams.first?.deckIDs, [])
    }

    func testSubjectNamesDeduplicateAndRenameWithoutChangingIdentity() throws {
        let subjects = StudySubjectStore(defaults: defaults)
        let subject = try XCTUnwrap(subjects.add(name: "  Cell   Biology  "))
        XCTAssertEqual(subject.name, "Cell Biology")
        XCTAssertEqual(subjects.add(name: "cell biology")?.id, subject.id)
        XCTAssertNil(subjects.add(name: " \n "))
        _ = subjects.add(name: "Chemistry")
        XCTAssertFalse(subjects.rename(subject, to: "chemistry"))
        XCTAssertTrue(subjects.rename(subject, to: "Biology"))
        let reopened = StudySubjectStore(defaults: defaults)
        XCTAssertEqual(reopened.name(for: subject.id), "Biology")
        XCTAssertEqual(reopened.subjects.count, 2)
    }

    func testLinksAreManyToManyAndPersistAcrossRestart() throws {
        let subjects = StudySubjectStore(defaults: defaults)
        let store = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        let firstDeck = UUID(), otherDeck = UUID()
        let midterm = StudyExam(subject: "Midterm", date: Date(), deckIDs: [otherDeck])
        let final = StudyExam(subject: "Final", date: Date())
        store.add(midterm); store.add(final)
        store.link([midterm.id, final.id], to: firstDeck)
        store.link([midterm.id, final.id], to: firstDeck)
        let reopened = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        XCTAssertEqual(Set(reopened.exams[0].deckIDs), [firstDeck, otherDeck])
        XCTAssertEqual(reopened.exams[0].deckIDs.count, 2)
        XCTAssertEqual(reopened.exams[1].deckIDs, [firstDeck])
        reopened.link([final.id], to: firstDeck)
        XCTAssertEqual(reopened.exams[0].deckIDs, [otherDeck])
        XCTAssertEqual(reopened.exams[1].deckIDs, [firstDeck])
    }

    func testRemovingSubjectPreservesDecksCardsAndExamLinks() throws {
        let subjects = StudySubjectStore(defaults: defaults)
        let subject = try XCTUnwrap(subjects.add(name: "Biology"))
        let decks = DeckStore(defaults: defaults)
        let deck = Deck(name: "Cells", cards: [card()], subjectID: subject.id)
        decks.addDeck(deck)
        let exams = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        let exam = StudyExam(subject: "Final", date: Date(), subjectID: subject.id, deckIDs: [deck.id])
        exams.add(exam)
        subjects.remove(subject, decks: decks, exams: exams)
        let reopenedDecks = DeckStore(defaults: defaults)
        let reopenedExams = ExamStore(defaults: defaults, sharedDefaults: nil, subjects: subjects)
        XCTAssertNil(reopenedDecks.decks.first?.subjectID)
        XCTAssertNil(reopenedExams.exams.first?.subjectID)
        XCTAssertEqual(reopenedDecks.decks.first?.cards, deck.cards)
        XCTAssertEqual(reopenedExams.exams.first?.deckIDs, [deck.id])
        XCTAssertEqual(reopenedDecks.selectedDeck?.id, deck.id)
    }

    func testExamUsesOnlyExplicitlyLinkedDecksEvenWhenNamesAndSubjectsMatch() {
        let subjectID = UUID()
        let linked = Deck(name: "Cells", subjectID: subjectID)
        let unrelated = Deck(name: "Cells", subjectID: subjectID)
        let exam = StudyExam(subject: "Biology", date: Date(), subjectID: subjectID, deckIDs: [linked.id, UUID()])
        XCTAssertEqual(StudyMaterialLinks.decks(for: exam, in: [linked, unrelated]), [linked])
        XCTAssertTrue(StudyLibraryFilter.subject(subjectID).includes(unrelated, exams: [exam]))
        XCTAssertFalse(StudyLibraryFilter.exam(exam.id).includes(unrelated, exams: [exam]))
        XCTAssertTrue(StudyLibraryFilter.exam(exam.id).includes(linked, exams: [exam]))
        XCTAssertEqual(StudyMaterialLinks.decks(for: exam, in: [unrelated]), [], "A deleted deck cannot leave phantom material")
    }

    func testExamChoiceIgnoresUnrelatedAndPastExamsAndIncludesToday() {
        let now = Date()
        let deck = Deck(name: "Cells")
        let past = StudyExam(subject: "Old", date: Calendar.current.date(byAdding: .day, value: -1, to: now)!, deckIDs: [deck.id])
        let unrelated = StudyExam(subject: "Math", date: now)
        let next = StudyExam(subject: "Bio final", date: Calendar.current.date(byAdding: .day, value: 4, to: now)!, deckIDs: [deck.id])
        XCTAssertEqual(StudyMaterialLinks.nextExam(for: deck, in: [past, unrelated, next], now: now)?.id, next.id)
        let today = StudyExam(subject: "Bio quiz", date: Calendar.current.startOfDay(for: now), deckIDs: [deck.id])
        XCTAssertEqual(StudyMaterialLinks.nextExam(for: deck, in: [next, today], now: now)?.id, today.id)
        XCTAssertNil(StudyMaterialLinks.nextExam(for: nil, in: [today]))
    }

    func testTopUpNeverFallsBackToAnUnlinkedSelectedDeck() {
        var item = card(); item.topic = "Cells"
        let linked = Deck(name: "Bio")
        let unrelated = Deck(name: "Other", cards: [item, item])
        var exam = StudyExam(subject: "Final", date: Date(), deckIDs: [linked.id])
        XCTAssertEqual(StudyMaterialLinks.topUpDeck(for: "Cells", exam: exam, decks: [unrelated, linked], selectedID: unrelated.id), linked.id)
        exam.deckIDs = []
        XCTAssertNil(StudyMaterialLinks.topUpDeck(for: "Cells", exam: exam, decks: [unrelated, linked], selectedID: unrelated.id))
    }

    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    private func card() -> Regret {
        Regret(regretPrompt: "Which organelle produces ATP?", regret: "Mitochondria", choices: ["Mitochondria", "Nucleus"], correctAnswerIndex: 0, backgroundExplanation: "Cell respiration.")
    }
}
