import XCTest
@testable import diewithoutregrets

final class DeckStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "DeckStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func card(_ prompt: String) -> Regret {
        Regret(regretPrompt: prompt, regret: "Answer", choices: ["Answer"],
               correctAnswerIndex: 0, backgroundExplanation: "", answerMode: .typed)
    }

    func testDirectCardAppendIsImmediatelyAvailableToUnlockQuiz() throws {
        let store = DeckStore(defaults: defaults)
        let deck = Deck(name: "Biology", cards: [card("First")])
        store.addDeck(deck)
        let added = card("Second")
        // Same mutation as NewFlashcardSheet's binding; no view onChange needed.
        store.decks[0].cards.append(added)
        XCTAssertEqual(store.selectedDeck?.cards.map(\.id), [deck.cards[0].id, added.id])
        let saved = try JSONDecoder().decode([Deck].self, from: XCTUnwrap(defaults.data(forKey: "SavedDecks")))
        XCTAssertEqual(saved[0].cards, store.selectedDeck?.cards)
        XCTAssertEqual(DeckStore(defaults: defaults).selectedDeck?.cards, saved[0].cards)
    }

    func testRescueCardDoesNotOverwriteCardsAddedThroughDeckBinding() throws {
        let store = DeckStore(defaults: defaults)
        store.addDeck(Deck(name: "Biology"))
        let first = card("Created in deck editor")
        store.decks[0].cards.append(first)
        // Same read/update as the unlock flow's rescueDeckBinding.
        var rescueDeck = try XCTUnwrap(store.selectedDeck)
        let second = card("Created from unlock screen")
        rescueDeck.cards.append(second)
        store.updateDeck(rescueDeck)
        XCTAssertEqual(store.decks[0].cards.map(\.id), [first.id, second.id])
    }

    func testSelectingOldSnapshotReadsCurrentSavedDeck() {
        let store = DeckStore(defaults: defaults)
        let snapshot = Deck(name: "Biology")
        store.addDeck(snapshot)
        let added = card("New card")
        store.decks[0].cards.append(added)
        store.selectedDeck = snapshot
        XCTAssertEqual(store.selectedDeck?.cards, [added])
    }

    func testDeletingSelectedDeckFallsBackAndDeletingLastDeckClearsSavedSelection() {
        let store = DeckStore(defaults: defaults)
        let first = Deck(name: "First")
        let second = Deck(name: "Second")
        store.addDeck(first)
        store.addDeck(second)
        store.selectDeck(first)
        store.decks.removeAll { $0.id == first.id }
        XCTAssertEqual(store.selectedDeck?.id, second.id)
        XCTAssertEqual(DeckStore(defaults: defaults).selectedDeck?.id, second.id)
        store.decks.removeAll()
        XCTAssertNil(store.selectedDeck)
        XCTAssertNil(defaults.string(forKey: "SelectedDeckID"))
    }
}
