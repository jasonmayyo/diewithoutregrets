//
//  BibleVerseViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/29.
//

import SwiftUI

class BibleVerseViewModel: ObservableObject {
    @Published var showVerse = false
    @Published var showFinalMessage = false
    @Published var verseText = ""
    @Published var verseReference = ""
    @Published var currentVerse: BibleVerse?
    
    @ObservedObject var bibleVerseStore: BibleVerseStore
    
    init(bibleVerseStore: BibleVerseStore) {
        self.bibleVerseStore = bibleVerseStore
    }
    
    func resetView() {
        showVerse = false
        showFinalMessage = false
        // Get a new random verse when resetting
        fetchRandomVerse()
    }
    
    /// Fetches a random verse from the Bible using the user's selected translation
    func fetchRandomVerse() {
        // Get random verse from BibleDataManager using the current translation
        if let verse = BibleDataManager.shared.getRandomVerse() {
            verseText = verse.verse
            verseReference = verse.reference
            currentVerse = verse
            
            // Add to recent verses
            bibleVerseStore.addToRecent(verse)
        } else {
            // Fallback if no Bible data loaded
            verseText = "Trust in the LORD with all thine heart; and lean not unto thine own understanding."
            verseReference = "Proverbs 3:5"
            currentVerse = BibleVerse(
                verse: verseText,
                reference: verseReference,
                book: "Proverbs",
                chapter: 3,
                verseNumber: 5,
                translation: BibleDataManager.shared.currentTranslation.rawValue
            )
            bibleVerseStore.addToRecent(currentVerse!)
        }
    }
    
    func updateVerseMessage() {
        // This now fetches a new random verse
        fetchRandomVerse()
    }
    
    func cycleVerse() {
        // Get a new random verse instead of cycling through stored ones
        fetchRandomVerse()
    }
}

// Backward compatibility alias
typealias RegretViewModel = BibleVerseViewModel
