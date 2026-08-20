import SwiftUI

struct NewFlashcardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var deck: Deck

    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var newExplanation = ""
    // Start with three incorrect answer fields; user can remove until only one remains
    @State private var choices = ["", "", ""]

    // Valid if the question and correct answer are non-empty, and at least one non-empty incorrect answer is provided.
    private var isValidInput: Bool {
        !newQuestion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newAnswer.trimmingCharacters(in: .whitespaces).isEmpty &&
        choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 1
    }

    var body: some View {
        VStack(spacing: 0) {
            SGSheetHeader(title: "New Flashcard", onClose: { dismiss() })
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 24)

            ScrollView {
                VStack(spacing: 24) {
                    // Question Section
                    InputCard(title: "Question", systemImage: "sticker-question") {
                        SGField(placeholder: "What's the main question?", text: $newQuestion)
                    }

                    // Correct Answer Section
                    InputCard(title: "Correct Answer", systemImage: "sticker-checkmark") {
                        SGField(placeholder: "Enter the correct answer", text: $newAnswer)
                    }

                    // Incorrect Answers Section
                    InputCard(title: "Incorrect Answers", systemImage: "sticker-error") {
                        VStack(spacing: 12) {
                            ForEach(choices.indices, id: \.self) { index in
                                HStack {
                                    SGField(placeholder: "Option \(index + 1)", text: $choices[index])

                                    // Allow removal if there is more than one incorrect answer field
                                    if choices.count > 1 {
                                        Button(action: {
                                            removeOption(at: index)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(SGTheme.display(20, weight: .regular))
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
                                    .font(SGTheme.buttonSmall)
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
                    InputCard(title: "Explanation", systemImage: "sticker-idea") {
                        VStack(alignment: .leading) {
                            SGField(placeholder: "Add context that explains the answer",
                                    text: $newExplanation,
                                    multiline: true,
                                    minHeight: 120)

                            Text("\(newExplanation.count)/500")
                                .font(SGTheme.caption)
                                .foregroundColor(SGTheme.paperTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .padding()
            }

            // Bottom save bar — replaces the old toolbar's Save action.
            SGButton(title: "Save", enabled: isValidInput) {
                saveFlashcard()
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 12)
        }
        .background(SGTheme.ink.ignoresSafeArea())
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

// Reusable Input Card Component — titled section on the standard card surface.
struct InputCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content

    var body: some View {
        SGCard(shadowed: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text(title)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                    Spacer()
                }

                content()
            }
        }
    }
}

struct NewFlashcardSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Dummy deck for preview purposes
        NewFlashcardSheet(deck: .constant(Deck(name: "Sample Deck", cards: [])))
    }
}
