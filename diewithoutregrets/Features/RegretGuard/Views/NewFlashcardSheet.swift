//
//  NewFlashcardSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/03/04.
//

import SwiftUI

struct NewFlashcardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var deck: Deck // Add this binding
    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var newExplanation = ""
    @State private var choices = ["", "", "", ""]
    
    private var isValidInput: Bool {
        !newQuestion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newAnswer.trimmingCharacters(in: .whitespaces).isEmpty &&
        choices.filter { !$0.isEmpty }.count >= 3
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Question")) {
                    TextField("Enter question", text: $newQuestion)
                }
                
                Section(header: Text("Correct Answer")) {
                    TextField("Enter correct answer", text: $newAnswer)
                }
                
                Section(header: Text("Explanation")) {
                    TextEditor(text: $newExplanation)
                        .frame(height: 120)
                }
                
                Section(header: Text("Incorrect Answers")) {
                    ForEach(0..<3, id: \.self) { index in
                        TextField("Incorrect answer \(index + 1)", text: $choices[index])
                    }
                }
            }
            .navigationTitle("New Flashcard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFlashcard() }
                        .disabled(!isValidInput)
                }
            }
        }
    }
    
    private func saveFlashcard() {
        let allChoices = [newAnswer] + choices.filter { !$0.isEmpty }
        let newRegret = Regret(
            regretPrompt: newQuestion,
            regret: newAnswer,
            choices: allChoices.shuffled(),
            correctAnswerIndex: allChoices.firstIndex(of: newAnswer) ?? 0,
            backgroundExplanation: newExplanation
        )
        
        // Add to the bound deck instead of the regretStore
        deck.cards.append(newRegret)
        dismiss()
    }
}

#Preview {
    // Update preview with sample deck
    NewFlashcardSheet(deck: .constant(Deck(name: "Sample Deck", cards: [])))
}
