//
//  BibleVerseStore.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

class BibleVerseStore: ObservableObject {
    static let shared = BibleVerseStore()
    
    // Recent verses shown to user (max 5)
    @Published var recentVerses: [BibleVerse] = []
    
    // Legacy property for backward compatibility
    var bibleVerses: [BibleVerse] {
        get { recentVerses }
        set { recentVerses = newValue }
    }
    
    @Published var selectedVerse: BibleVerse?
    @Published var currentVerseIndex: Int = 0
    
    private let maxRecentVerses = 5
    private let recentVersesKey = "RecentBibleVerses"
    
    public init() {
        loadRecentVerses()
    }
    
    // MARK: - Recent Verses Management
    
    private func loadRecentVerses() {
        if let data = UserDefaults.standard.data(forKey: recentVersesKey),
           let savedVerses = try? JSONDecoder().decode([BibleVerse].self, from: data) {
            self.recentVerses = savedVerses
        } else {
            self.recentVerses = []
        }
    }
    
    private func saveRecentVerses() {
        do {
            let encoded = try JSONEncoder().encode(recentVerses)
            UserDefaults.standard.set(encoded, forKey: recentVersesKey)
        } catch {
            print("Error saving recent verses: \(error)")
        }
    }
    
    /// Add a verse to the recent list (keeps only last 5)
    func addToRecent(_ verse: BibleVerse) {
        // Remove if already exists (to avoid duplicates)
        recentVerses.removeAll { $0.reference == verse.reference }
        
        // Add to the beginning (most recent first)
        recentVerses.insert(verse, at: 0)
        
        // Keep only the last 5
        if recentVerses.count > maxRecentVerses {
            recentVerses = Array(recentVerses.prefix(maxRecentVerses))
        }
        
        saveRecentVerses()
    }
    
    /// Check if there are any recent verses
    var hasRecentVerses: Bool {
        return !recentVerses.isEmpty
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    func cycleVerse() {
        guard !recentVerses.isEmpty else { return }
        currentVerseIndex = (currentVerseIndex + 1) % recentVerses.count
    }
    
    func updateVerse(_ updatedVerse: BibleVerse) {
        if let index = recentVerses.firstIndex(where: { $0.id == updatedVerse.id }) {
            recentVerses[index] = updatedVerse
            saveRecentVerses()
        }
    }
    
    func addVerses(_ newVerses: [BibleVerse]) {
        for verse in newVerses {
            addToRecent(verse)
        }
    }
    
    func addVerse(_ verse: BibleVerse) {
        addToRecent(verse)
    }
    
    func selectVerse(_ verse: BibleVerse) {
        selectedVerse = verse
    }
    
    func removeVerse(_ verse: BibleVerse) {
        recentVerses.removeAll { $0.id == verse.id }
        saveRecentVerses()
    }
    
    func getCurrentVerse() -> BibleVerse? {
        guard !recentVerses.isEmpty else { return nil }
        let safeIndex = min(currentVerseIndex, recentVerses.count - 1)
        return recentVerses[safeIndex]
    }
    
    func getRandomVerse() -> BibleVerse? {
        return recentVerses.randomElement()
    }
    
    func clearRecentVerses() {
        recentVerses = []
        saveRecentVerses()
    }
}
