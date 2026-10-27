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
    private let defaults: UserDefaults
    
    @Published var decks: [Deck] {
        didSet {
            saveDecks()
            if !decks.contains(where: { $0.id == selectedDeckID }) {
                selectedDeck = decks.first
            }
        }
    }
    
    // Keep only the selection identity. A second Deck value can go stale when
    // a card binding edits `decks`, then overwrite newer cards in the rescue flow.
    @Published private var selectedDeckID: UUID?
    var selectedDeck: Deck? {
        get { decks.first { $0.id == selectedDeckID } }
        set {
            selectedDeckID = newValue.flatMap { candidate in
                decks.contains(where: { $0.id == candidate.id }) ? candidate.id : nil
            }
            defaults.set(selectedDeckID?.uuidString, forKey: "SelectedDeckID")
        }
    }
    
    func selectDeck(_ deck: Deck) {
        guard decks.contains(where: { $0.id == deck.id }) else { return }
        selectedDeck = deck
    }
    
    func loadSelectedDeck() {
        let deckID = defaults.string(forKey: "SelectedDeckID")
        selectedDeck = decks.first { $0.id.uuidString == deckID } ?? decks.first
    }
    
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "SavedDecks"),
           let savedDecks = try? JSONDecoder().decode([Deck].self, from: data) {
            self.decks = savedDecks
        } else {
            self.decks = []
            addSampleData()
        }
        loadSelectedDeck()
    }
    
     func saveDecks() {
        do {
            let encoded = try JSONEncoder().encode(decks)
            defaults.set(encoded, forKey: "SavedDecks")
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

// MARK: - Exam store (tutor-monster foundation)

/// Stores the user's upcoming exams. Migrates the single write-only onboarding
/// exam (studySubject + examDate) into the first StudyExam on first run, and
/// mirrors the nearest upcoming exam's date into the app group for the extensions.
final class ExamStore: ObservableObject {
    static let shared = ExamStore()
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private let storeKey = "sg_studyExams"

    @Published var exams: [StudyExam] {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard,
         sharedDefaults: UserDefaults? = SGContract.sharedDefaults) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        if let data = defaults.data(forKey: storeKey),
           let saved = try? JSONDecoder().decode([StudyExam].self, from: data) {
            exams = saved
        } else {
            exams = ExamStore.migratedFromOnboarding(defaults)
        }
        save()   // persist any migration + mirror the nearest exam
    }

    /// The soonest upcoming exam (today or later), nil if none.
    var nextExam: StudyExam? {
        exams.filter { $0.isUpcoming }.min { $0.date < $1.date }
    }

    func add(_ exam: StudyExam) { exams.append(exam) }

    func update(_ exam: StudyExam) {
        if let i = exams.firstIndex(where: { $0.id == exam.id }) { exams[i] = exam }
    }

    func remove(_ exam: StudyExam) { exams.removeAll { $0.id == exam.id } }

    private func save() {
        if let data = try? JSONEncoder().encode(exams) {
            defaults.set(data, forKey: storeKey)
        }
        if let next = nextExam {
            sharedDefaults?.set(next.date.timeIntervalSince1970,
                                forKey: SGContract.Keys.onboardingExamDate)
        }
    }

    private static func migratedFromOnboarding(_ defaults: UserDefaults) -> [StudyExam] {
        let ts = defaults.double(forKey: "examDate")
        guard ts > 0 else { return [] }
        let raw = defaults.string(forKey: "studySubject")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = (raw?.isEmpty == false) ? raw! : "My exam"
        return [StudyExam(subject: subject,
                          date: Date(timeIntervalSince1970: ts),
                          topics: subject == "My exam" ? [] : [subject])]
    }
}

// MARK: - Persona store (selected tutor monster)

/// Holds the user's chosen tutor-monster persona by id. Defaults to the safe
/// fallback until onboarding sets one.
final class PersonaStore: ObservableObject {
    static let shared = PersonaStore()
    private let defaults: UserDefaults
    private let key = "sg_selectedPersonaID"

    @Published var selectedID: String {
        didSet { defaults.set(selectedID, forKey: key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedID = defaults.string(forKey: key) ?? MonsterPersona.fallback.id
    }

    var persona: MonsterPersona { MonsterPersona.with(id: selectedID) }

    func select(_ persona: MonsterPersona) { selectedID = persona.id }
}
