
import SwiftUI

struct RegretEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var regret: Regret

    @State private var editedPrompt: String
    @State private var editedRegret: String
    @State private var editedExplanation: String
    @State private var editedChoices: [String]
    @State private var editedCorrectIndex: Int
    @State private var editedMode: AnswerMode
    @State private var editedTypedAnswer: String
    @State private var selectedTab = 0

    private let tabs = ["Question", "Explanation", "Answers"]
    private let tabIcons = ["sticker-question", "sticker-text", "sticker-checkmark"]

    // Custom initializer that creates state values from the binding's current value
    init(regret: Binding<Regret>) {
        self._regret = regret
        _editedPrompt = State(initialValue: regret.wrappedValue.regretPrompt)
        _editedRegret = State(initialValue: regret.wrappedValue.regret)
        _editedExplanation = State(initialValue: regret.wrappedValue.backgroundExplanation)
        // A typed card keeps its answer in choices[correctAnswerIndex]; give
        // the choices editor a fresh scaffold in case the user switches modes.
        let value = regret.wrappedValue
        _editedMode = State(initialValue: value.answerMode)
        _editedTypedAnswer = State(initialValue: value.correctAnswer)
        if value.answerMode == .typed {
            _editedChoices = State(initialValue: [value.correctAnswer, ""])
            _editedCorrectIndex = State(initialValue: 0)
        } else {
            _editedChoices = State(initialValue: value.choices)
            _editedCorrectIndex = State(initialValue: value.correctAnswerIndex)
        }
    }

    // Saveable once the question and the correct answer have content.
    private var isValidInput: Bool {
        guard !editedPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if editedMode == .typed {
            return !editedTypedAnswer.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return editedChoices.indices.contains(editedCorrectIndex) &&
        !editedChoices[editedCorrectIndex].trimmingCharacters(in: .whitespaces).isEmpty &&
        editedChoices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — standard sheet anatomy in place of the old fixed bar
            SGSheetHeader(title: "Edit Flashcard", onClose: { dismiss() })
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 24)

            // Tab selector
            HStack(spacing: 5) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: { selectedTab = index }) {
                        HStack(spacing: 4) {
                            Image(tabIcons[index])
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                            Text(tabs[index])
                        }
                        .font(SGTheme.rowLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 5)
                        .background(
                            selectedTab == index ?
                            SGTheme.glaze(0.08) :
                            Color.clear
                        )
                        .clipShape(Capsule(style: .continuous))
                    }
                    .foregroundColor(selectedTab == index ? SGTheme.mint : SGTheme.paperTertiary)
                }
            }
            .background(SGTheme.glaze(0.04))
            .clipShape(Capsule(style: .continuous))
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Content
            TabView(selection: $selectedTab) {
                // Question Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        textEditorSection(
                            title: "Question",
                            subtitle: "Write a clear question for your flashcard",
                            text: $editedPrompt
                        )
                    }
                    .padding()
                }
                .tag(0)

                // Explanation Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        textEditorSection(
                            title: "Explanation",
                            subtitle: "Provide details that help understand the answer",
                            text: $editedExplanation
                        )
                    }
                    .padding()
                }
                .tag(1)

                // Answers Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        answerOptionsSection
                    }
                    .padding()
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .background(SGTheme.ink)

            // Bottom navigation
            VStack(spacing: 0) {
                Rectangle()
                    .fill(SGTheme.hairline)
                    .frame(height: 1)

                HStack {
                    SGButton(title: "Previous",
                             icon: "chevron.left",
                             variant: .ghost,
                             fullWidth: false,
                             enabled: selectedTab > 0) {
                        selectedTab = max(0, selectedTab - 1)
                    }

                    Spacer()

                    // Progress indicators
                    HStack(spacing: 6) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Circle()
                                .fill(selectedTab == index ? SGTheme.mint : SGTheme.glaze(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }

                    Spacer()

                    // Last page turns Next into Save; Save dims until the card is valid.
                    SGButton(title: selectedTab == tabs.count - 1 ? "Save" : "Next",
                             fullWidth: false,
                             enabled: selectedTab < tabs.count - 1 || isValidInput) {
                        if selectedTab < tabs.count - 1 {
                            selectedTab += 1
                        } else {
                            saveChanges()
                        }
                    }
                }
                .padding()
            }
            .background(SGTheme.inkRaised)
        }
        .background(SGTheme.ink.ignoresSafeArea())
    }

    private func textEditorSection(title: String, subtitle: String, text: Binding<String>) -> some View {
        SGCard(shadowed: false) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)

                    Text(subtitle)
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperTertiary)
                }

                SGField(placeholder: title, text: text, multiline: true, minHeight: 180)
            }
        }
    }

    private var answerOptionsSection: some View {
        SGCard(shadowed: false) {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Answer Options")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)

                    Text(editedMode == .typed
                         ? "In the quiz you'll type this answer from memory"
                         : "Select the correct answer and add options")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperTertiary)
                }

                AnswerModePicker(mode: $editedMode)

                if editedMode == .typed {
                    SGField(placeholder: "Enter the correct answer", text: $editedTypedAnswer)
                        .transition(.opacity)
                } else {
                    choicesEditor
                        .transition(.opacity)
                }
            }
            .animation(SGTheme.springFast, value: editedMode)
        }
    }

    private var choicesEditor: some View {
                VStack(spacing: 12) {
                    ForEach(0..<editedChoices.count, id: \.self) { index in
                        HStack {
                            Button(action: { editedCorrectIndex = index }) {
                                ZStack {
                                    Circle()
                                        .stroke(editedCorrectIndex == index ? SGTheme.mint : SGTheme.glaze(0.2), lineWidth: 2)
                                        .frame(width: 24, height: 24)

                                    if editedCorrectIndex == index {
                                        Circle()
                                            .fill(SGTheme.mint)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                            }

                            SGField(placeholder: "Option \(index + 1)", text: $editedChoices[index])

                            if editedChoices.count > 2 {
                                Button(action: { removeOption(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(SGTheme.display(20, weight: .regular))
                                        .foregroundColor(SGTheme.ember.opacity(0.8))
                                }
                            }
                        }
                    }

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
                    .disabled(editedChoices.count >= 6)
                }
    }

    private func addNewOption() {
        if editedChoices.count < 6 {
            editedChoices.append("")
        }
    }

    private func removeOption(at index: Int) {
        if editedChoices.count > 2 {
            editedChoices.remove(at: index)
            if editedCorrectIndex >= editedChoices.count {
                editedCorrectIndex = 0
            }
        }
    }

    private func saveChanges() {
        // Update the binding's value directly
        regret.regretPrompt = editedPrompt
        regret.regret = editedRegret
        regret.backgroundExplanation = editedExplanation
        regret.answerMode = editedMode
        if editedMode == .typed {
            // The single stored choice IS the answer (see AnswerMode).
            let answer = editedTypedAnswer.trimmingCharacters(in: .whitespaces)
            regret.regret = answer
            regret.choices = [answer]
            regret.correctAnswerIndex = 0
        } else {
            let kept = editedChoices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let correctText = editedChoices[editedCorrectIndex]
            regret.choices = kept
            regret.correctAnswerIndex = kept.firstIndex(of: correctText) ?? 0
        }
        // We don't have the deck context here so we just track the edit.
        Analytics.flashcardEdited(deckId: nil, deckName: nil)
        dismiss()
    }
}
#Preview {
    DeckListView()
        .environmentObject(DeckStore.shared)
}
