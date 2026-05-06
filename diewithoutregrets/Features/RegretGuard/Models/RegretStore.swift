//
//  RegretStore.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

class RegretStore: ObservableObject {
    static let shared = RegretStore()
    
    @Published var regrets: [Regret] {
        didSet {
            saveRegrets()
        }
    }
    @Published var selectedRegret: Regret?
    @Published var currentRegretIndex: Int = 0
    
    public init() {
        if let data = UserDefaults.standard.data(forKey: "SavedRegrets"),
           let savedRegrets = try? JSONDecoder().decode([Regret].self, from: data) {
            self.regrets = savedRegrets
        } else {
            self.regrets = []
        }
    }
    
    private func saveRegrets() {
        do {
            let encoded = try JSONEncoder().encode(regrets)
            UserDefaults.standard.set(encoded, forKey: "SavedRegrets")
        } catch {
            print("Error saving regrets: \(error)")
            Telemetry.capture(error,
                              context: ["regret_count": regrets.count],
                              tags: ["feature": "decks", "operation": "save_regrets"])
        }
    }
    
    func cycleRegret() {
        currentRegretIndex = (currentRegretIndex + 1) % regrets.count
    }
    
    func updateRegret(_ updatedRegret: Regret) {
        if let index = regrets.firstIndex(where: { $0.id == updatedRegret.id }) {
            regrets[index] = updatedRegret
            saveRegrets()
        }
    }
    
    func addRegrets(_ newRegrets: [Regret]) {
        regrets.append(contentsOf: newRegrets)
        saveRegrets()
    }
    
    func addRegret(_ regret: Regret) {
        regrets.append(regret)
        saveRegrets()
    }
    
    func selectRegret(_ regret: Regret) {
        selectedRegret = regret
        saveRegrets()
    }
}


class DeckStore: ObservableObject {
    static let shared = DeckStore()
    
    @Published var decks: [Deck] {
        didSet {
            saveDecks()
        }
    }
    
    @Published var selectedDeck: Deck? {
        didSet {
            saveSelectedDeck()
        }
    }
    
    private func saveSelectedDeck() {
        if let deck = selectedDeck {
            UserDefaults.standard.set(deck.id.uuidString, forKey: "SelectedDeckID")
        }
    }
    
    func selectDeck(_ deck: Deck) {
        if let index = decks.firstIndex(where: { $0.id == deck.id }) {
               selectedDeck = decks[index]
               print("Selected deck: \(selectedDeck?.name ?? "nil")")
               print("Cards count: \(selectedDeck?.cards.count ?? 0)")
           } else {
               print("⚠️ Failed to find deck in store: \(deck.name)")
           }    }
    
    func loadSelectedDeck() {
        if let deckID = UserDefaults.standard.string(forKey: "SelectedDeckID") {
            selectedDeck = decks.first { $0.id.uuidString == deckID }
        }
    }
    
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "SavedDecks"),
           let savedDecks = try? JSONDecoder().decode([Deck].self, from: data) {
            self.decks = savedDecks
        } else {
            self.decks = []
            addSampleData()
        }
        loadSelectedDeck()
        
        if decks.count == 1 && selectedDeck == nil {
                    selectedDeck = decks.first
                }
    }
    
     func saveDecks() {
        do {
            let encoded = try JSONEncoder().encode(decks)
            UserDefaults.standard.set(encoded, forKey: "SavedDecks")
        } catch {
            print("Error saving decks: \(error)")
            let totalCards = decks.reduce(0) { $0 + $1.cards.count }
            Telemetry.capture(error,
                              context: ["deck_count": decks.count, "total_cards": totalCards],
                              tags: ["feature": "decks", "operation": "save_decks"])
        }
    }
    
    func addDeck(_ deck: Deck) {
        decks.insert(deck, at: 0)
        
        if decks.count == 1 {
            selectedDeck = deck
        }
        
        // Force update to ensure proper state synchronization
        objectWillChange.send()
    }
    
    func updateDeck(_ updatedDeck: Deck) {
        if let index = decks.firstIndex(where: { $0.id == updatedDeck.id }) {
            decks[index] = updatedDeck
            
            // Update selectedDeck if it's the same deck that was updated
            if selectedDeck?.id == updatedDeck.id {
                selectedDeck = updatedDeck
            }
            
            // Force update to ensure proper state synchronization
            objectWillChange.send()
        }
    }
    
    // Add method to refresh deck state
    func refreshDeck(withId id: UUID) {
        if let index = decks.firstIndex(where: { $0.id == id }) {
            if selectedDeck?.id == id {
                selectedDeck = decks[index]
            }
            objectWillChange.send()
        }
    }
    
    func deleteDeck(at offsets: IndexSet) {
        // Get the deck being deleted before removal
        let deckToDelete = offsets.map { decks[$0] }
        
        decks.remove(atOffsets: offsets)
        
        // If the selected deck was deleted, select a new one
        if let deletedDeck = deckToDelete.first, 
           selectedDeck?.id == deletedDeck.id {
            selectedDeck = decks.first
        }
        
        // If only one deck remains, select it
        if decks.count == 1 {
            selectedDeck = decks.first
        }
    }
    
    private func addSampleData() {
    }
}
