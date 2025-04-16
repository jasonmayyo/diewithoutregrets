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
        }
    }
    
    func addDeck(_ deck: Deck) {
        decks.insert(deck, at: 0)
        
        if decks.count == 1 {
                selectedDeck = deck
            }
    }
    
    func updateDeck(_ updatedDeck: Deck) {
        if let index = decks.firstIndex(where: { $0.id == updatedDeck.id }) {
            decks[index] = updatedDeck
        }
    }
    
    func deleteDeck(at offsets: IndexSet) {
        decks.remove(atOffsets: offsets)
        
        if decks.count == 1 {
                selectedDeck = decks.first
            }
    }
    
    private func addSampleData() {
    }
}
