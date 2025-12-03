//
//  BibleDataManager.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

// MARK: - JSON Decoding Structures (match the JSON file format)
struct BibleJSON: Codable {
    let translation: String
    let books: [BookJSON]
}

struct BookJSON: Codable {
    let name: String
    let chapters: [ChapterJSON]
}

struct ChapterJSON: Codable {
    let chapter: Int
    let verses: [VerseJSON]
}

struct VerseJSON: Codable {
    let verse: Int
    let text: String
}

// MARK: - App Data Structures
struct BibleBook: Identifiable {
    let id: String
    let name: String
    let chapters: [BibleChapter]
    
    init(id: String = UUID().uuidString, name: String, chapters: [BibleChapter]) {
        self.id = id
        self.name = name
        self.chapters = chapters
    }
}

struct BibleChapter: Identifiable {
    let id: String
    let number: Int
    let verses: [String]
    
    init(id: String = UUID().uuidString, number: Int, verses: [String]) {
        self.id = id
        self.number = number
        self.verses = verses
    }
}

// MARK: - Translation Enum
enum BibleTranslation: String, CaseIterable, Codable {
    case kjv = "KJV"
    case asv = "ASV"
    case akjv = "AKJV"
    
    var displayName: String {
        switch self {
        case .kjv: return "King James Version"
        case .asv: return "American Standard Version"
        case .akjv: return "American King James Version"
        }
    }
    
    var fileName: String {
        switch self {
        case .kjv: return "KJV"
        case .asv: return "ASV"
        case .akjv: return "AKJV"
        }
    }
}

// MARK: - Bible Data Manager
class BibleDataManager: ObservableObject {
    static let shared = BibleDataManager()
    
    @Published var currentTranslation: BibleTranslation = .kjv
    @Published var currentBook: String = "Genesis"
    @Published var currentChapter: Int = 1
    @Published var currentVerse: Int = 1
    @Published var isLoading: Bool = false
    
    // Bible data storage - Dictionary of translation -> books
    private var bibleData: [BibleTranslation: [BibleBook]] = [:]
    
    // Book names in order (matching JSON file format)
    static let oldTestamentBooks = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "I Samuel", "II Samuel",
        "I Kings", "II Kings", "I Chronicles", "II Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
        "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
        "Zephaniah", "Haggai", "Zechariah", "Malachi"
    ]
    
    static let newTestamentBooks = [
        "Matthew", "Mark", "Luke", "John", "Acts",
        "Romans", "I Corinthians", "II Corinthians", "Galatians", "Ephesians",
        "Philippians", "Colossians", "I Thessalonians", "II Thessalonians", "I Timothy",
        "II Timothy", "Titus", "Philemon", "Hebrews", "James",
        "I Peter", "II Peter", "I John", "II John", "III John",
        "Jude", "Revelation of John"
    ]
    
    static var allBooks: [String] {
        return oldTestamentBooks + newTestamentBooks
    }
    
    // Map common book name variations to JSON book names
    static func normalizeBookName(_ name: String) -> String {
        let mappings: [String: String] = [
            "1 Samuel": "I Samuel", "2 Samuel": "II Samuel",
            "1 Kings": "I Kings", "2 Kings": "II Kings",
            "1 Chronicles": "I Chronicles", "2 Chronicles": "II Chronicles",
            "1 Corinthians": "I Corinthians", "2 Corinthians": "II Corinthians",
            "1 Thessalonians": "I Thessalonians", "2 Thessalonians": "II Thessalonians",
            "1 Timothy": "I Timothy", "2 Timothy": "II Timothy",
            "1 Peter": "I Peter", "2 Peter": "II Peter",
            "1 John": "I John", "2 John": "II John", "3 John": "III John",
            "Revelation": "Revelation of John",
            "Psalm": "Psalms"
        ]
        return mappings[name] ?? name
    }
    
    init() {
        loadAllTranslations()
        loadBookmarks()
    }
    
    // MARK: - Data Loading
    func loadAllTranslations() {
        isLoading = true
        
        // Load all available translations
        for translation in BibleTranslation.allCases {
            loadTranslation(translation)
        }
        
        isLoading = false
    }
    
    private func loadTranslation(_ translation: BibleTranslation) {
        guard let url = Bundle.main.url(forResource: translation.fileName, withExtension: "json") else {
            print("Could not find \(translation.fileName).json in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let bibleJSON = try JSONDecoder().decode(BibleJSON.self, from: data)
            
            // Convert JSON structure to app structure
            let books = bibleJSON.books.map { bookJSON -> BibleBook in
                let chapters = bookJSON.chapters.map { chapterJSON -> BibleChapter in
                    let verses = chapterJSON.verses.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    return BibleChapter(number: chapterJSON.chapter, verses: verses)
                }
                return BibleBook(name: bookJSON.name, chapters: chapters)
            }
            
            bibleData[translation] = books
            print("Successfully loaded \(translation.displayName) with \(books.count) books")
            
        } catch {
            print("Error loading \(translation.fileName): \(error)")
        }
    }
    
    // MARK: - Data Access Methods
    func getBooks(for translation: BibleTranslation? = nil) -> [BibleBook] {
        let trans = translation ?? currentTranslation
        return bibleData[trans] ?? []
    }
    
    func getBookNames(for translation: BibleTranslation? = nil) -> [String] {
        return getBooks(for: translation).map { $0.name }
    }
    
    func getChapters(for book: String, translation: BibleTranslation? = nil) -> [BibleChapter] {
        let trans = translation ?? currentTranslation
        let books = bibleData[trans] ?? []
        let normalizedBook = BibleDataManager.normalizeBookName(book)
        return books.first(where: { $0.name == normalizedBook })?.chapters ?? []
    }
    
    func getChapterCount(for book: String, translation: BibleTranslation? = nil) -> Int {
        let count = getChapters(for: book, translation: translation).count
        return max(count, 1) // Return at least 1 to avoid empty ranges
    }
    
    func getVerses(for book: String, chapter: Int, translation: BibleTranslation? = nil) -> [String] {
        let chapters = getChapters(for: book, translation: translation)
        return chapters.first(where: { $0.number == chapter })?.verses ?? []
    }
    
    func getVerse(book: String, chapter: Int, verse: Int, translation: BibleTranslation? = nil) -> String? {
        let verses = getVerses(for: book, chapter: chapter, translation: translation)
        guard verse > 0, verse <= verses.count else { return nil }
        return verses[verse - 1]
    }
    
    func getVerseReference(book: String, chapter: Int, verse: Int) -> String {
        return "\(book) \(chapter):\(verse)"
    }
    
    func getCurrentVerses() -> [String] {
        return getVerses(for: currentBook, chapter: currentChapter, translation: currentTranslation)
    }
    
    // MARK: - Navigation State
    func navigateTo(book: String, chapter: Int, verse: Int = 1) {
        currentBook = book
        currentChapter = chapter
        currentVerse = verse
    }
    
    func navigateTo(verse: BibleVerse) {
        // Normalize book name to match JSON format
        currentBook = BibleDataManager.normalizeBookName(verse.book)
        currentChapter = verse.chapter
        currentVerse = verse.verseNumber
        if let translation = BibleTranslation(rawValue: verse.translation) {
            currentTranslation = translation
        }
    }
    
    func nextChapter() {
        let chapters = getChapters(for: currentBook, translation: currentTranslation)
        if let currentChapterIndex = chapters.firstIndex(where: { $0.number == currentChapter }) {
            if currentChapterIndex < chapters.count - 1 {
                currentChapter = chapters[currentChapterIndex + 1].number
                currentVerse = 1
            } else {
                // Move to next book
                let bookNames = getBookNames(for: currentTranslation)
                if let bookIndex = bookNames.firstIndex(of: currentBook),
                   bookIndex < bookNames.count - 1 {
                    currentBook = bookNames[bookIndex + 1]
                    currentChapter = 1
                    currentVerse = 1
                }
            }
        }
    }
    
    func previousChapter() {
        let chapters = getChapters(for: currentBook, translation: currentTranslation)
        if let currentChapterIndex = chapters.firstIndex(where: { $0.number == currentChapter }) {
            if currentChapterIndex > 0 {
                currentChapter = chapters[currentChapterIndex - 1].number
                currentVerse = 1
            } else {
                // Move to previous book
                let bookNames = getBookNames(for: currentTranslation)
                if let bookIndex = bookNames.firstIndex(of: currentBook),
                   bookIndex > 0 {
                    currentBook = bookNames[bookIndex - 1]
                    let prevChapters = getChapters(for: currentBook, translation: currentTranslation)
                    currentChapter = prevChapters.last?.number ?? 1
                    currentVerse = 1
                }
            }
        }
    }
    
    // MARK: - Bookmarks
    @Published var bookmarks: [BibleVerse] = [] {
        didSet {
            saveBookmarks()
        }
    }
    
    func addBookmark(_ verse: BibleVerse) {
        if !bookmarks.contains(where: { $0.reference == verse.reference }) {
            bookmarks.append(verse)
        }
    }
    
    func removeBookmark(_ verse: BibleVerse) {
        bookmarks.removeAll { $0.reference == verse.reference }
    }
    
    func isBookmarked(_ verse: BibleVerse) -> Bool {
        return bookmarks.contains(where: { $0.reference == verse.reference })
    }
    
    private func saveBookmarks() {
        do {
            let encoded = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(encoded, forKey: "BibleBookmarks")
        } catch {
            print("Error saving bookmarks: \(error)")
        }
    }
    
    func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: "BibleBookmarks"),
           let saved = try? JSONDecoder().decode([BibleVerse].self, from: data) {
            bookmarks = saved
        }
    }
    
    // MARK: - Random Verse
    func getRandomVerse(translation: BibleTranslation? = nil) -> BibleVerse? {
        let trans = translation ?? currentTranslation
        let books = bibleData[trans] ?? []
        
        guard !books.isEmpty else { return nil }
        
        // Pick a random book
        let randomBook = books.randomElement()!
        
        // Pick a random chapter
        guard !randomBook.chapters.isEmpty else { return nil }
        let randomChapter = randomBook.chapters.randomElement()!
        
        // Pick a random verse
        guard !randomChapter.verses.isEmpty else { return nil }
        let randomVerseIndex = Int.random(in: 0..<randomChapter.verses.count)
        let verseText = randomChapter.verses[randomVerseIndex]
        let verseNumber = randomVerseIndex + 1
        
        // Create BibleVerse object
        let reference = "\(randomBook.name) \(randomChapter.number):\(verseNumber)"
        
        return BibleVerse(
            verse: verseText,
            reference: reference,
            book: randomBook.name,
            chapter: randomChapter.number,
            verseNumber: verseNumber,
            translation: trans.rawValue
        )
    }
}
