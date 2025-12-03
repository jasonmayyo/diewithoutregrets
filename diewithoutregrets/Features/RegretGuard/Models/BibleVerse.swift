//
//  BibleVerse.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

struct BibleVerse: Identifiable, Codable, Equatable {
    let id: UUID
    let verse: String
    let reference: String
    let book: String
    let chapter: Int
    let verseNumber: Int
    let translation: String
    
    init(id: UUID = UUID(), verse: String, reference: String, book: String, chapter: Int, verseNumber: Int, translation: String = "KJV") {
        self.id = id
        self.verse = verse
        self.reference = reference
        self.book = book
        self.chapter = chapter
        self.verseNumber = verseNumber
        self.translation = translation
    }
    
    // Convenience initializer for simple verse creation
    init(id: UUID = UUID(), verse: String, reference: String, translation: String = "KJV") {
        self.id = id
        self.verse = verse
        self.reference = reference
        // Parse reference for book, chapter, verse
        let parts = reference.components(separatedBy: " ")
        if parts.count >= 2 {
            let lastPart = parts.last ?? ""
            let chapterVerse = lastPart.components(separatedBy: ":")
            self.book = parts.dropLast().joined(separator: " ")
            self.chapter = Int(chapterVerse.first ?? "1") ?? 1
            self.verseNumber = Int(chapterVerse.last ?? "1") ?? 1
        } else {
            self.book = "Unknown"
            self.chapter = 1
            self.verseNumber = 1
        }
        self.translation = translation
    }
}

// Sample Bible verses for display
extension BibleVerse {
    static let sampleVerses: [BibleVerse] = [
        BibleVerse(
            verse: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
            reference: "John 3:16",
            book: "John",
            chapter: 3,
            verseNumber: 16,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "I can do all things through Christ which strengtheneth me.",
            reference: "Philippians 4:13",
            book: "Philippians",
            chapter: 4,
            verseNumber: 13,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "Trust in the LORD with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
            reference: "Proverbs 3:5-6",
            book: "Proverbs",
            chapter: 3,
            verseNumber: 5,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "The LORD is my shepherd; I shall not want.",
            reference: "Psalms 23:1",
            book: "Psalms",
            chapter: 23,
            verseNumber: 1,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "Be strong and of a good courage; be not afraid, neither be thou dismayed: for the LORD thy God is with thee whithersoever thou goest.",
            reference: "Joshua 1:9",
            book: "Joshua",
            chapter: 1,
            verseNumber: 9,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
            reference: "Romans 8:28",
            book: "Romans",
            chapter: 8,
            verseNumber: 28,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.",
            reference: "Isaiah 41:10",
            book: "Isaiah",
            chapter: 41,
            verseNumber: 10,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
            reference: "Isaiah 40:31",
            book: "Isaiah",
            chapter: 40,
            verseNumber: 31,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "For I know the thoughts that I think toward you, saith the LORD, thoughts of peace, and not of evil, to give you an expected end.",
            reference: "Jeremiah 29:11",
            book: "Jeremiah",
            chapter: 29,
            verseNumber: 11,
            translation: "KJV"
        ),
        BibleVerse(
            verse: "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
            reference: "Matthew 11:28",
            book: "Matthew",
            chapter: 11,
            verseNumber: 28,
            translation: "KJV"
        )
    ]
}


