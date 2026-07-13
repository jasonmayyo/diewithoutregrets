
import SwiftUI

struct RegretEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var regret: Regret

    @State private var editedPrompt: String
    @State private var editedRegret: String
    @State private var editedExplanation: String
    @State private var editedChoices: [String]
    @State private var editedCorrectIndex: Int
    @State private var selectedTab = 0

    private let tabs = ["Question", "Explanation", "Answers"]
    private let tabIcons = ["questionmark.circle", "text.bubble", "checklist"]

    // Custom initializer that creates state values from the binding's current value
    init(regret: Binding<Regret>) {
        self._regret = regret
        _editedPrompt = State(initialValue: regret.wrappedValue.regretPrompt)
        _editedRegret = State(initialValue: regret.wrappedValue.regret)
        _editedExplanation = State(initialValue: regret.wrappedValue.backgroundExplanation)
        _editedChoices = State(initialValue: regret.wrappedValue.choices)
        _editedCorrectIndex = State(initialValue: regret.wrappedValue.correctAnswerIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header — flat ink, no gradient
            ZStack {
                SGTheme.ink

                VStack(spacing: 8) {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundColor(SGTheme.paperSecondary)
                        }

                        Spacer()

                        Text("Edit Flashcard")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(SGTheme.paper)

                        Spacer()

                        Button(action: { saveChanges() }) {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(SGTheme.mint)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                    // Tab selector
                    HStack(spacing: 5) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: { selectedTab = index }) {
                                HStack(spacing: 4) {
                                    Image(systemName: tabIcons[index])
                                        .font(.system(size: 14))
                                    Text(tabs[index])
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 5)
                                .background(
                                    selectedTab == index ?
                                    SGTheme.glaze(0.08) :
                                    Color.clear
                                )
                                .cornerRadius(50)
                            }
                            .foregroundColor(selectedTab == index ? SGTheme.mint : SGTheme.paperTertiary)
                        }
                    }

                    .background(SGTheme.glaze(0.04))
                    .cornerRadius(50)

                    .padding(.bottom, 8)
                    .padding(.top, 8)
                }.padding(.horizontal, 10)
            }
            .frame(height: 120)

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
                    Button(action: { selectedTab = max(0, selectedTab - 1) }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .foregroundColor(selectedTab > 0 ? SGTheme.paper : SGTheme.paperDisabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SGTheme.glaze(0.06))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                                )
                        )
                    }
                    .disabled(selectedTab == 0)

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

                    Button(action: {
                        if selectedTab < tabs.count - 1 {
                            selectedTab += 1
                        } else {
                            saveChanges()
                        }
                    }) {
                        HStack {
                            Text(selectedTab == tabs.count - 1 ? "Save" : "Next")
                            Image(systemName: selectedTab == tabs.count - 1 ? "" : "chevron.right")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(SGTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SGTheme.mint, in: Capsule(style: .continuous))
                    }
                }
                .padding()
            }
            .background(SGTheme.inkRaised)
        }
        .background(SGTheme.ink.ignoresSafeArea())
    }

    private func textEditorSection(title: String, subtitle: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(SGTheme.paperTertiary)
            }

            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .foregroundColor(SGTheme.paper)
                .frame(minHeight: 180)
                .padding()
                .background(SGTheme.ink)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(SGTheme.hairline, lineWidth: 1)
                )
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

    private var answerOptionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Answer Options")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Text("Select the correct answer and add options")
                    .font(.caption)
                    .foregroundColor(SGTheme.paperTertiary)
            }

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

                        TextField("Option \(index + 1)", text: $editedChoices[index])
                            .foregroundColor(SGTheme.paper)
                            .padding()
                            .background(SGTheme.ink)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(SGTheme.hairline, lineWidth: 1)
                            )

                        if editedChoices.count > 2 {
                            Button(action: { removeOption(at: index) }) {
                                Image(systemName: "minus.circle.fill")
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
                .disabled(editedChoices.count >= 6)
            }
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
        regret.choices = editedChoices
        regret.correctAnswerIndex = editedCorrectIndex
        // We don't have the deck context here so we just track the edit.
        Analytics.flashcardEdited(deckId: nil, deckName: nil)
        dismiss()
    }
}
#Preview {
    DeckListView()
        .environmentObject(DeckStore.shared)
}
