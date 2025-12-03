//
//  BibleReaderView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

struct BibleReaderView: View {
    @EnvironmentObject var bibleDataManager: BibleDataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showBookPicker = false
    @State private var showChapterPicker = false
    @State private var showTranslationPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: 0x184449)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Navigation Header
                    HStack {
                        Button(action: { showBookPicker = true }) {
                            HStack {
                                Text(bibleDataManager.currentBook)
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        Button(action: { showChapterPicker = true }) {
                            HStack {
                                Text("Chapter \(bibleDataManager.currentChapter)")
                                    .font(.headline)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button(action: { showTranslationPicker = true }) {
                            Text(bibleDataManager.currentTranslation.rawValue)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    // Chapter Content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            let verses = bibleDataManager.getVerses(
                                for: bibleDataManager.currentBook,
                                chapter: bibleDataManager.currentChapter,
                                translation: bibleDataManager.currentTranslation
                            )
                            
                            if verses.isEmpty {
                                VStack(spacing: 20) {
                                    Image(systemName: "book.closed")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.5))
                                    
                                    Text("Chapter not available")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text("This chapter is not yet loaded in the app. More Bible content coming soon!")
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else {
                                ForEach(Array(verses.enumerated()), id: \.offset) { index, verse in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                            .frame(width: 30, alignment: .trailing)
                                        
                                        Text(verse)
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .lineSpacing(4)
                                    }
                                    .id(index + 1)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Chapter Navigation
                    HStack {
                        Button(action: {
                            bibleDataManager.previousChapter()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            bibleDataManager.nextChapter()
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(selectedBook: $bibleDataManager.currentBook)
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerView(
                book: bibleDataManager.currentBook,
                selectedChapter: $bibleDataManager.currentChapter
            )
        }
        .sheet(isPresented: $showTranslationPicker) {
            TranslationPickerView(selectedTranslation: $bibleDataManager.currentTranslation)
        }
    }
}

// MARK: - Book Picker
struct BookPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedBook: String
    
    var body: some View {
        NavigationView {
            List {
                Section("Old Testament") {
                    ForEach(BibleDataManager.oldTestamentBooks, id: \.self) { book in
                        Button(action: {
                            selectedBook = book
                            dismiss()
                        }) {
                            HStack {
                                Text(book)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedBook == book {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("New Testament") {
                    ForEach(BibleDataManager.newTestamentBooks, id: \.self) { book in
                        Button(action: {
                            selectedBook = book
                            dismiss()
                        }) {
                            HStack {
                                Text(book)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedBook == book {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Chapter Picker
struct ChapterPickerView: View {
    @Environment(\.dismiss) var dismiss
    let book: String
    @Binding var selectedChapter: Int
    
    // Simplified chapter counts for common books
    var chapterCount: Int {
        let counts: [String: Int] = [
            "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
            "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24,
            "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36, "Ezra": 10,
            "Nehemiah": 13, "Esther": 10, "Job": 42, "Psalms": 150, "Proverbs": 31,
            "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66, "Jeremiah": 52, "Lamentations": 5,
            "Ezekiel": 48, "Daniel": 12, "Hosea": 14, "Joel": 3, "Amos": 9,
            "Obadiah": 1, "Jonah": 4, "Micah": 7, "Nahum": 3, "Habakkuk": 3,
            "Zephaniah": 3, "Haggai": 2, "Zechariah": 14, "Malachi": 4,
            "Matthew": 28, "Mark": 16, "Luke": 24, "John": 21, "Acts": 28,
            "Romans": 16, "1 Corinthians": 16, "2 Corinthians": 13, "Galatians": 6, "Ephesians": 6,
            "Philippians": 4, "Colossians": 4, "1 Thessalonians": 5, "2 Thessalonians": 3, "1 Timothy": 6,
            "2 Timothy": 4, "Titus": 3, "Philemon": 1, "Hebrews": 13, "James": 5,
            "1 Peter": 5, "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1,
            "Jude": 1, "Revelation": 22
        ]
        return counts[book] ?? 10
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                    ForEach(1...chapterCount, id: \.self) { chapter in
                        Button(action: {
                            selectedChapter = chapter
                            dismiss()
                        }) {
                            Text("\(chapter)")
                                .font(.headline)
                                .frame(width: 50, height: 50)
                                .background(selectedChapter == chapter ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedChapter == chapter ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("\(book) - Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Translation Picker
struct TranslationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTranslation: BibleTranslation
    
    var body: some View {
        NavigationView {
            List {
                ForEach(BibleTranslation.allCases, id: \.self) { translation in
                    Button(action: {
                        selectedTranslation = translation
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(translation.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(translation.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedTranslation == translation {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BibleReaderView()
        .environmentObject(BibleDataManager.shared)
}

