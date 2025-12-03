//
//  BibleReaderTabView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

struct BibleReaderTabView: View {
    @EnvironmentObject var bibleDataManager: BibleDataManager
    
    @State private var showBookPicker = false
    @State private var showChapterPicker = false
    @State private var showTranslationPicker = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.16, blue: 0.22),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONTINUE READING")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("The Bible")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Navigation Controls
                    HStack(spacing: 12) {
                        Button(action: { showBookPicker = true }) {
                            HStack(spacing: 6) {
                                Text(bibleDataManager.currentBook)
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        
                        Button(action: { showChapterPicker = true }) {
                            HStack(spacing: 6) {
                                Text("Ch. \(bibleDataManager.currentChapter)")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        
                        Spacer()
                        
                        Button(action: { showTranslationPicker = true }) {
                            Text(bibleDataManager.currentTranslation.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                
                // Chapter Content
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            let verses = bibleDataManager.getVerses(
                                for: bibleDataManager.currentBook,
                                chapter: bibleDataManager.currentChapter,
                                translation: bibleDataManager.currentTranslation
                            )
                            
                            if verses.isEmpty {
                                // Empty state
                                VStack(spacing: 24) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.05))
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: "book.closed")
                                            .font(.system(size: 40, weight: .light))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    
                                    VStack(spacing: 8) {
                                        Text("Chapter Not Available")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text("This chapter hasn't been loaded yet.\nMore Bible content coming soon!")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.5))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                            } else {
                                // Chapter header
                                Text("\(bibleDataManager.currentBook) \(bibleDataManager.currentChapter)")
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                                    .padding(.bottom, 8)
                                    .id(0)
                                
                                ForEach(Array(verses.enumerated()), id: \.offset) { index, verse in
                                    let verseNumber = index + 1
                                    let isHighlighted = verseNumber == bibleDataManager.currentVerse
                                    
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(verseNumber)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(isHighlighted 
                                                ? Color(red: 0.4, green: 0.7, blue: 0.6) 
                                                : Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.7))
                                            .frame(width: 24, alignment: .trailing)
                                        
                                        Text(verse)
                                            .font(.system(size: 17, weight: .regular, design: .serif))
                                            .foregroundColor(isHighlighted ? .white : .white.opacity(0.9))
                                            .lineSpacing(6)
                                    }
                                    .padding(.vertical, isHighlighted ? 8 : 0)
                                    .padding(.horizontal, isHighlighted ? -8 : 0)
                                    .background(
                                        isHighlighted ?
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.15))
                                            .padding(.horizontal, -8)
                                        : nil
                                    )
                                    .id(verseNumber)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    .onAppear {
                        // Scroll to current verse if not the first one
                        if bibleDataManager.currentVerse > 1 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    proxy.scrollTo(bibleDataManager.currentVerse, anchor: .center)
                                }
                            }
                        }
                    }
                    .onChange(of: bibleDataManager.currentVerse) { newVerse in
                        if newVerse > 1 {
                            withAnimation {
                                proxy.scrollTo(newVerse, anchor: .center)
                            }
                        }
                    }
                }
                
                // Chapter Navigation
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            bibleDataManager.previousChapter()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Previous")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            bibleDataManager.nextChapter()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Next")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.7, blue: 0.6),
                                    Color(red: 0.3, green: 0.6, blue: 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0),
                                    Color(red: 0.08, green: 0.10, blue: 0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
            }
        }
        .sheet(isPresented: $showBookPicker) {
            BookPickerSheet(selectedBook: $bibleDataManager.currentBook)
                .environmentObject(bibleDataManager)
        }
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(
                book: bibleDataManager.currentBook,
                selectedChapter: $bibleDataManager.currentChapter
            )
            .environmentObject(bibleDataManager)
        }
        .sheet(isPresented: $showTranslationPicker) {
            TranslationPickerSheet(selectedTranslation: $bibleDataManager.currentTranslation)
        }
    }
}

// MARK: - Book Picker Sheet (Premium Style)
struct BookPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bibleDataManager: BibleDataManager
    @Binding var selectedBook: String
    
    var allBooks: [String] {
        bibleDataManager.getBookNames()
    }
    
    // Split into Old Testament (first 39) and New Testament (remaining)
    var oldTestamentBooks: [String] {
        Array(allBooks.prefix(39))
    }
    
    var newTestamentBooks: [String] {
        Array(allBooks.dropFirst(39))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.16, blue: 0.22)
                    .ignoresSafeArea()
                
                List {
                    Section {
                        ForEach(oldTestamentBooks, id: \.self) { book in
                            BookRow(book: book, isSelected: selectedBook == book) {
                                selectedBook = book
                                dismiss()
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    } header: {
                        Text("Old Testament")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Section {
                        ForEach(newTestamentBooks, id: \.self) { book in
                            BookRow(book: book, isSelected: selectedBook == book) {
                                selectedBook = book
                                dismiss()
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    } header: {
                        Text("New Testament")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                }
            }
            .toolbarBackground(Color(red: 0.12, green: 0.16, blue: 0.22), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct BookRow: View {
    let book: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var bibleDataManager: BibleDataManager
    
    var body: some View {
        Button(action: {
            // Reset chapter to 1 when changing books
            bibleDataManager.currentChapter = 1
            bibleDataManager.currentVerse = 1
            action()
        }) {
            HStack {
                Text(book)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Chapter Picker Sheet (Premium Style)
struct ChapterPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bibleDataManager: BibleDataManager
    let book: String
    @Binding var selectedChapter: Int
    
    var chapterCount: Int {
        return bibleDataManager.getChapterCount(for: book)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.16, blue: 0.22)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                        spacing: 12
                    ) {
                        ForEach(1...chapterCount, id: \.self) { chapter in
                            Button(action: {
                                selectedChapter = chapter
                                // Reset verse to 1 when changing chapters
                                bibleDataManager.currentVerse = 1
                                dismiss()
                            }) {
                                Text("\(chapter)")
                                    .font(.system(size: 16, weight: selectedChapter == chapter ? .bold : .regular))
                                    .frame(width: 54, height: 54)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedChapter == chapter 
                                                ? LinearGradient(
                                                    colors: [
                                                        Color(red: 0.4, green: 0.7, blue: 0.6),
                                                        Color(red: 0.3, green: 0.6, blue: 0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                                : LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                                            )
                                    )
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("\(book)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                }
            }
            .toolbarBackground(Color(red: 0.12, green: 0.16, blue: 0.22), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Translation Picker Sheet (Premium Style)
struct TranslationPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTranslation: BibleTranslation
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.16, blue: 0.22)
                    .ignoresSafeArea()
                
                List {
                    ForEach(BibleTranslation.allCases, id: \.self) { translation in
                        Button(action: {
                            selectedTranslation = translation
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(translation.rawValue)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(translation.displayName)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                if selectedTranslation == translation {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                }
            }
            .toolbarBackground(Color(red: 0.12, green: 0.16, blue: 0.22), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    BibleReaderTabView()
        .environmentObject(BibleDataManager.shared)
}

