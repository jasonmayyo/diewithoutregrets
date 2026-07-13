import SwiftUI

struct NewFlashcardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var deck: Deck

    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var newExplanation = ""
    // Start with three incorrect answer fields; user can remove until only one remains
    @State private var choices = ["", "", ""]

    /// Field wells sit one level below the raised input cards.
    private let fieldFill = SGTheme.ink

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
                            .foregroundColor(SGTheme.paper)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(fieldFill)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(newQuestion.isEmpty ? SGTheme.hairline : SGTheme.mint, lineWidth: 1)
                            )
                    }

                    // Correct Answer Section
                    InputCard(title: "Correct Answer", systemImage: "checkmark.circle") {
                        TextField("Enter the correct answer", text: $newAnswer)
                            .font(.body)
                            .foregroundColor(SGTheme.paper)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(fieldFill)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(newAnswer.isEmpty ? SGTheme.hairline : SGTheme.mint, lineWidth: 1)
                            )
                    }

                    // Incorrect Answers Section
                    InputCard(title: "Incorrect Answers", systemImage: "xmark.circle") {
                        VStack(spacing: 12) {
                            ForEach(choices.indices, id: \.self) { index in
                                HStack {
                                    TextField("Option \(index + 1)", text: $choices[index])
                                        .font(.body)
                                        .foregroundColor(SGTheme.paper)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(fieldFill)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(choices[index].isEmpty ? SGTheme.hairline : SGTheme.mint, lineWidth: 1)
                                        )

                                    // Allow removal if there is more than one incorrect answer field
                                    if choices.count > 1 {
                                        Button(action: {
                                            removeOption(at: index)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(SGTheme.ember.opacity(0.8))
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
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(SGTheme.mint)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(SGTheme.mint.opacity(0.08))
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(SGTheme.mint.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(SGPressStyle())
                            }
                        }
                    }

                    // Explanation Section
                    InputCard(title: "Explanation", systemImage: "lightbulb") {
                        VStack(alignment: .leading) {
                            TextEditor(text: $newExplanation)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(SGTheme.paper)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(fieldFill)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(SGTheme.hairline, lineWidth: 1)
                                )

                            Text("\(newExplanation.count)/500")
                                .font(.caption)
                                .foregroundColor(SGTheme.paperTertiary)
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
                        .foregroundColor(SGTheme.paperSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveFlashcard() }
                        .fontWeight(.bold)
                        .foregroundColor(isValidInput ? SGTheme.mint : SGTheme.paperDisabled)
                        .disabled(!isValidInput)
                }
            }
            .background(SGTheme.ink.ignoresSafeArea())
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
        Analytics.flashcardCreated(
            source: "manual",
            deckId: deck.id.uuidString,
            deckName: deck.name
        )
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
                    .foregroundColor(SGTheme.mint)
                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Spacer()
            }

            content()
        }
        .padding(SGTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
        )
    }
}

struct NewFlashcardSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Dummy deck for preview purposes
        NewFlashcardSheet(deck: .constant(Deck(name: "Sample Deck", cards: [])))
    }
}
