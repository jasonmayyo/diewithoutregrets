//
//  BibleVerseEditorSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct BibleVerseEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    @State private var editedVerse: String
    @State private var editedReference: String
    let verse: BibleVerse
    
    init(verse: BibleVerse) {
        self.verse = verse
        _editedVerse = State(initialValue: verse.verse)
        _editedReference = State(initialValue: verse.reference)
    }
    
    var body: some View {
        VStack {
            // Top Bar with Cancel and Save Buttons
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.black)
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Tap to close the editor without saving")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
                
                Button(action: {
                    let updatedVerse = BibleVerse(
                        id: verse.id,
                        verse: editedVerse,
                        reference: editedReference,
                        book: verse.book,
                        chapter: verse.chapter,
                        verseNumber: verse.verseNumber,
                        translation: verse.translation
                    )
                    bibleVerseStore.updateVerse(updatedVerse)
                    dismiss()
                }) {
                    Text("Save")
                        .foregroundColor(Color(hex: 0x184449))
                        .bold()
                }
                .accessibilityLabel("Save")
                .accessibilityHint("Tap to save your changes")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
            
            // Title
            Text("Edit Bible Verse")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)
                .accessibilityLabel("Edit Bible Verse")
            
            // Reference Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Reference")
                    .font(.headline)
                    .accessibilityLabel("Reference")
                
                TextField("e.g., John 3:16", text: $editedReference)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: 0x184449), lineWidth: 1)
                    )
                    .accessibilityLabel("Edit reference")
                    .accessibilityValue(editedReference)
            }
            .padding(.horizontal)
            
            // Verse Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Verse Text")
                    .font(.headline)
                    .accessibilityLabel("Verse Text")
                
                TextEditor(text: $editedVerse)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: 0x184449), lineWidth: 1)
                    )
                    .accessibilityLabel("Edit verse text")
                    .accessibilityValue(editedVerse)
                    .accessibilityHint("Tap to edit the Bible verse")
            }
            .padding()
            
            Spacer()
        }
        .padding(.top)
        .preferredColorScheme(.light)
    }
}

// Backward compatibility alias
typealias RegretEditorSheet = BibleVerseEditorSheet

#Preview {
    BibleVerseEditorSheet(verse: BibleVerse.sampleVerses[0])
        .environmentObject(BibleVerseStore())
}
