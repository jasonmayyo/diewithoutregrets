import SwiftUI

struct NewFlashcardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var deck: Deck

    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var newExplanation = ""
    @State private var answerMode: AnswerMode = .choices
    // Start with three incorrect answer fields; user can remove until only one remains
    @State private var choices = ["", "", ""]

    // Valid if the question and correct answer are non-empty; multiple choice
    // additionally needs at least one non-empty incorrect answer.
    private var isValidInput: Bool {
        !newQuestion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newAnswer.trimmingCharacters(in: .whitespaces).isEmpty &&
        (answerMode == .typed ||
         choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 1)
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

                    // Answer Type Section
                    InputCard(title: "Answer Type", systemImage: "sticker-target") {
                        VStack(alignment: .leading, spacing: 10) {
                            AnswerModePicker(mode: $answerMode)

                            Text(answerMode == .typed
                                 ? "In the quiz you'll type the answer from memory."
                                 : "In the quiz you'll pick the answer from your options.")
                                .font(SGTheme.caption)
                                .foregroundColor(SGTheme.paperTertiary)
                        }
                    }

                    // Correct Answer Section
                    InputCard(title: "Correct Answer", systemImage: "sticker-checkmark") {
                        SGField(placeholder: "Enter the correct answer", text: $newAnswer)
                    }

                    // Incorrect Answers Section (multiple choice only)
                    if answerMode == .choices {
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
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
                .animation(SGTheme.springFast, value: answerMode)
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
        let newRegret: Regret
        if answerMode == .typed {
            // A typed card stores its answer as the single choice, so every
            // legacy surface still finds it at choices[correctAnswerIndex].
            let answer = newAnswer.trimmingCharacters(in: .whitespaces)
            newRegret = Regret(
                regretPrompt: newQuestion,
                regret: answer,
                choices: [answer],
                correctAnswerIndex: 0,
                backgroundExplanation: newExplanation,
                answerMode: .typed
            )
        } else {
            // Combine the correct answer with non-empty incorrect answers.
            let incorrectChoices = choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let allChoices = [newAnswer] + incorrectChoices
            // First, shuffle the answers…
            let shuffledChoices = allChoices.shuffled()
            // …then find the new index of the correct answer.
            let correctIndex = shuffledChoices.firstIndex(of: newAnswer) ?? 0

            newRegret = Regret(
                regretPrompt: newQuestion,
                regret: newAnswer,
                choices: shuffledChoices,
                correctAnswerIndex: correctIndex,
                backgroundExplanation: newExplanation
            )
        }
        deck.cards.append(newRegret)
        Analytics.flashcardCreated(
            source: "manual",
            deckId: deck.id.uuidString,
            deckName: deck.name
        )
        dismiss()
    }
}

/// The answer-type toggle shared by the create and edit sheets: the same
/// capsule segmented language as the editor's tab strip.
struct AnswerModePicker: View {
    @Binding var mode: AnswerMode

    private let options: [(mode: AnswerMode, label: String, icon: String)] = [
        (.choices, "Multiple Choice", "square.grid.2x2.fill"),
        (.typed, "Type It", "keyboard.fill"),
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options, id: \.mode) { option in
                Button {
                    guard mode != option.mode else { return }
                    SGTheme.tick()
                    withAnimation(SGTheme.springFast) { mode = option.mode }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(option.label)
                    }
                    .font(SGTheme.rowLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 5)
                    .background(mode == option.mode ? SGTheme.glaze(0.08) : Color.clear)
                    .clipShape(Capsule(style: .continuous))
                }
                .foregroundColor(mode == option.mode ? SGTheme.mint : SGTheme.paperTertiary)
            }
        }
        .background(SGTheme.glaze(0.04))
        .clipShape(Capsule(style: .continuous))
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
