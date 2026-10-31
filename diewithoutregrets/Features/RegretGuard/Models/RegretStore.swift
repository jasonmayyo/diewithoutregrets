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

// MARK: - Subjects

final class StudySubjectStore: ObservableObject {
    static let shared = StudySubjectStore()
    private let defaults: UserDefaults
    private let storeKey = "sg_studySubjects"
    @Published private(set) var subjects: [StudySubject] {
        didSet { if let data = try? JSONEncoder().encode(subjects) { defaults.set(data, forKey: storeKey) } }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        subjects = defaults.data(forKey: storeKey).flatMap { try? JSONDecoder().decode([StudySubject].self, from: $0) } ?? []
    }

    var sorted: [StudySubject] { subjects.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    func name(for id: UUID?) -> String? { subjects.first { $0.id == id }?.name }

    @discardableResult func add(name: String) -> StudySubject? {
        let clean = StudySubject.cleanName(name)
        guard !clean.isEmpty else { return nil }
        if let existing = subjects.first(where: { StudySubject.nameKey($0.name) == StudySubject.nameKey(clean) }) { return existing }
        let subject = StudySubject(name: clean)
        subjects.append(subject)
        return subject
    }

    @discardableResult func rename(_ subject: StudySubject, to name: String) -> Bool {
        let clean = StudySubject.cleanName(name)
        guard !clean.isEmpty, let index = subjects.firstIndex(where: { $0.id == subject.id }),
              !subjects.contains(where: { $0.id != subject.id && StudySubject.nameKey($0.name) == StudySubject.nameKey(clean) }) else { return false }
        subjects[index].name = clean
        return true
    }

    func remove(_ subject: StudySubject, decks: DeckStore, exams: ExamStore) {
        // Removing a grouping never removes study material or its explicit exam links.
        decks.decks = decks.decks.map { deck in
            var copy = deck
            if copy.subjectID == subject.id { copy.subjectID = nil }
            return copy
        }
        exams.exams = exams.exams.map { exam in
            var copy = exam
            if copy.subjectID == subject.id { copy.subjectID = nil }
            return copy
        }
        subjects.removeAll { $0.id == subject.id }
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
         sharedDefaults: UserDefaults? = SGContract.sharedDefaults,
         subjects: StudySubjectStore = .shared) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        if let data = defaults.data(forKey: storeKey),
           let saved = try? JSONDecoder().decode([StudyExam].self, from: data) {
            exams = saved
        } else {
            exams = ExamStore.migratedFromOnboarding(defaults)
        }
        // Preserve existing exam names/dates. Do not guess which decks they cover.
        if !defaults.bool(forKey: "sg_examSubjectLinks_v1") {
            exams = exams.map { exam in
                var copy = exam
                if copy.subjectID == nil, copy.subject != "My exam" {
                    copy.subjectID = subjects.add(name: copy.subject)?.id
                }
                return copy
            }
            defaults.set(true, forKey: "sg_examSubjectLinks_v1")
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

    func link(_ examIDs: Set<UUID>, to deckID: UUID) {
        exams = exams.map { exam in
            var copy = exam
            copy.deckIDs.removeAll { $0 == deckID }
            if examIDs.contains(exam.id) { copy.deckIDs.append(deckID) }
            return copy
        }
    }

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

// MARK: - Mastery writeback (shared by the quiz and the monster chat)

extension DeckStore {
    /// Apply graded outcomes (card id → was it correct) to the live deck as Leitner
    /// mastery, and persist. Reads the current deck (not a stale snapshot) and only
    /// touches answered cards.
    func recordOutcomes(_ outcomes: [UUID: Bool], deckID: UUID, now: Date = Date()) {
        guard !outcomes.isEmpty,
              var deck = decks.first(where: { $0.id == deckID }) else { return }
        for i in deck.cards.indices {
            guard let correct = outcomes[deck.cards[i].id] else { continue }
            deck.cards[i].recordReview(correct: correct, now: now)
        }
        updateDeck(deck)
    }
}
