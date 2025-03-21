import SwiftUI

struct NewFlashcardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var deck: Deck
    
    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var newExplanation = ""
    // Start with three incorrect answer fields; user can remove until only one remains
    @State private var choices = ["", "", ""]
    
    private let dwrGreen = Color(hex: 0x013B41)
    private let accentColor = Color(hex: 0x065961)
    private let bgColor = Color(.systemGroupedBackground)
    
    // Valid if the question and correct answer are non-empty, and at least one non-empty incorrect answer is provided.
    private var isValidInput: Bool {
        !newQuestion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newAnswer.trimmingCharacters(in: .whitespaces).isEmpty &&
        choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 1
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Question Section
                    InputCard(title: "Question", systemImage: "questionmark.circle") {
                        TextField("What's the main question?", text: $newQuestion)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(bgColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(newQuestion.isEmpty ? Color.gray.opacity(0.3) : accentColor, lineWidth: 1)
                            )
                    }
                    
                    // Correct Answer Section
                    InputCard(title: "Correct Answer", systemImage: "checkmark.circle") {
                        TextField("Enter the correct answer", text: $newAnswer)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(bgColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(newAnswer.isEmpty ? Color.gray.opacity(0.3) : accentColor, lineWidth: 1)
                            )
                    }
                    
                    // Incorrect Answers Section
                    InputCard(title: "Incorrect Answers", systemImage: "xmark.circle") {
                        VStack(spacing: 12) {
                            ForEach(choices.indices, id: \.self) { index in
                                HStack {
                                    TextField("Option \(index + 1)", text: $choices[index])
                                        .font(.body)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(bgColor)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(choices[index].isEmpty ? Color.gray.opacity(0.3) : accentColor, lineWidth: 1)
                                        )
                                    
                                    // Allow removal if there is more than one incorrect answer field
                                    if choices.count > 1 {
                                        Button(action: {
                                            removeOption(at: index)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                    }
                                }
                            }
                            
                            // Add Option Button (limit to a maximum of 5 incorrect answers)
                            if choices.count < 5 {
                                Button(action: addNewOption) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Option")
                                    }
                                    .foregroundColor(dwrGreen)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(dwrGreen.opacity(0.5), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    
                    // Explanation Section
                    InputCard(title: "Explanation", systemImage: "lightbulb") {
                        VStack(alignment: .leading) {
                            TextEditor(text: $newExplanation)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(bgColor)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            Text("\(newExplanation.count)/500")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("New Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(dwrGreen)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFlashcard() }
                        .fontWeight(.bold)
                        .foregroundColor(isValidInput ? .white : Color.gray.opacity(0.6))
                        .padding(8)
                        .background(isValidInput ? accentColor : Color.clear)
                        .cornerRadius(8)
                        .disabled(!isValidInput)
                }
            }
            .background(bgColor.ignoresSafeArea())
        }
    }
    
    private func addNewOption() {
        if choices.count < 5 {
            choices.append("")
        }
    }
    
    private func removeOption(at index: Int) {
        if choices.count > 1 {
            choices.remove(at: index)
        }
    }
    
    private func saveFlashcard() {
        // Combine the correct answer with non-empty incorrect answers.
        let incorrectChoices = choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allChoices = [newAnswer] + incorrectChoices
        // First, shuffle the answers…
        let shuffledChoices = allChoices.shuffled()
        // …then find the new index of the correct answer.
        let correctIndex = shuffledChoices.firstIndex(of: newAnswer) ?? 0
        
        let newRegret = Regret(
            regretPrompt: newQuestion,
            regret: newAnswer,
            choices: shuffledChoices,
            correctAnswerIndex: correctIndex,
            backgroundExplanation: newExplanation
        )
        deck.cards.append(newRegret)
        dismiss()
    }
}

// Reusable Input Card Component
struct InputCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(Color(hex: 0x065961))
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(hex: 0x013B41))
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct NewFlashcardSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Dummy deck for preview purposes
        NewFlashcardSheet(deck: .constant(Deck(name: "Sample Deck", cards: [])))
    }
}
