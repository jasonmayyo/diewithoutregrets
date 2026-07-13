//
//  PracticeView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/04/13.
//

import SwiftUI

struct PracticeView: View {
    @EnvironmentObject var deckStore: DeckStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PracticeViewModel()

    let deck: Deck

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack {
                // Added header with back button and progress bar
                PracticeHeaderView(
                    dismissAction: { dismiss() },
                    questionResults: viewModel.questionResults
                )
                Group {
                    if viewModel.showFinalMessage {
                        FinalMessageView(
                            hasIncorrectAnswers: viewModel.hasIncorrectAnswers,
                            dismissAction: { dismiss() },
                            retryAction: viewModel.retryQuestions
                        )
                    } else {
                        QuestionView(
                            currentRegret: viewModel.currentQuestion,
                            selectedAnswer: $viewModel.selectedAnswer,
                            showAnswer: viewModel.showAnswer,
                            explanation: viewModel.currentQuestion?.backgroundExplanation ?? ""
                        )
                    }
                }
                .frame(maxHeight: .infinity)

                Group {
                    if viewModel.showFinalMessage {

                    } else {
                        ControlButton(
                            text: viewModel.controlButtonText,
                            action: viewModel.handleTap,
                            disabled: viewModel.isControlButtonDisabled
                        )
                    }
                }
            }
            .onAppear {
                viewModel.setup(deck: deck)
            }
            .onDisappear {
                viewModel.trackAbandonIfNeeded()
            }
        }
    }

    // MARK: - Subviews
    private struct PracticeHeaderView: View {
        let dismissAction: () -> Void
        let questionResults: [Bool?]

        var body: some View {
            HStack(spacing: 12) {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SGTheme.paper)
                        .padding(10)
                        .background(SGTheme.glaze(0.08))
                        .clipShape(Circle())
                }

                // Use the enhanced ProgressBar
                EnhancedProgressBar(questionResults: questionResults)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 5)
        }
    }

    private struct EnhancedProgressBar: View {
        let questionResults: [Bool?]
        private let barHeight: CGFloat = 8

        var body: some View {
            let totalQuestions = questionResults.count
            let answeredQuestions = questionResults.compactMap { $0 }.count
            let progress = totalQuestions > 0 ? Double(answeredQuestions) / Double(totalQuestions) : 0.0

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(SGTheme.glaze(0.1))
                        .frame(height: barHeight)

                    // Progress Fill
                    Capsule()
                        .fill(SGTheme.mint)
                        .frame(width: geometry.size.width * progress, height: barHeight)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: barHeight)
        }
    }

    private struct QuestionView: View {
        let currentRegret: Regret?
        @Binding var selectedAnswer: Int?
        let showAnswer: Bool
        let explanation: String

        var body: some View {
            Group {
                if let currentRegret = currentRegret {
                    VStack(spacing: 0) {
                        Text(currentRegret.regretPrompt)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(SGTheme.paper)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding()

                        if showAnswer {
                            ScrollView {
                                Text(explanation)
                                    .font(.subheadline)
                                    .foregroundColor(SGTheme.paperSecondary)
                                    .padding()
                            }
                            .frame(maxHeight: 200)
                        }

                        Spacer()

                        AnswerOptionsView(
                            choices: currentRegret.choices,
                            selectedAnswer: $selectedAnswer,
                            showAnswer: showAnswer,
                            correctAnswer: currentRegret.correctAnswerIndex
                        )
                    }
                    .padding()
                } else {
                    ProgressView()
                        .tint(SGTheme.mint)
                }
            }
        }
    }

    private struct AnswerOptionsView: View {
        let choices: [String]
        @Binding var selectedAnswer: Int?
        let showAnswer: Bool
        let correctAnswer: Int

        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                        Button(action: {
                            if !showAnswer {
                                selectedAnswer = index
                            }
                        }) {
                            HStack {
                                Text(choice)
                                    .foregroundColor(textColor(for: index))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(background(for: index))
                                    .cornerRadius(SGTheme.tileRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SGTheme.tileRadius)
                                            .stroke(borderColor(for: index), lineWidth: borderWidth(for: index))
                                    )
                            }
                        }
                        .disabled(showAnswer)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 300) // Limit height to prevent overflow
        }

        private func textColor(for index: Int) -> Color {
            showAnswer ? (index == correctAnswer ? SGTheme.ink : SGTheme.paper) : SGTheme.paper
        }

        private func background(for index: Int) -> Color {
            if showAnswer {
                return index == correctAnswer
                    ? SGTheme.mint
                    : (index == selectedAnswer ? SGTheme.ember.opacity(0.22) : SGTheme.inkRaised)
            }
            return selectedAnswer == index ? SGTheme.mint.opacity(0.12) : SGTheme.inkRaised
        }

        private func borderColor(for index: Int) -> Color {
            if showAnswer {
                return index == correctAnswer
                    ? SGTheme.mint
                    : (index == selectedAnswer ? SGTheme.ember.opacity(0.6) : SGTheme.hairline)
            }
            return selectedAnswer == index ? SGTheme.mint : SGTheme.hairline
        }

        private func borderWidth(for index: Int) -> CGFloat {
            if showAnswer {
                return index == correctAnswer ? 2 : 1
            }
            return selectedAnswer == index ? 2 : 1
        }
    }

    private struct ControlButton: View {
        let text: String
        let action: () -> Void
        let disabled: Bool

        var body: some View {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(SGTheme.hairline)
                    .frame(height: 1)

                Button(action: action) {
                    Text(text)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(disabled ? SGTheme.paperTertiary : SGTheme.mint)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .disabled(disabled)
            }
            .background(SGTheme.inkRaised)
        }
    }

    private struct ExplanationView: View {
        let currentRegret: Regret
        let selectedAnswer: Int?

        var body: some View {
            VStack(spacing: 12) {
                ForEach(Array(currentRegret.choices.enumerated()), id: \.offset) { index, choice in
                    HStack {
                        Text(choice)
                            .foregroundColor(index == currentRegret.correctAnswerIndex ? SGTheme.ink : SGTheme.paper)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                index == currentRegret.correctAnswerIndex ?
                                SGTheme.mint :
                                    (index == selectedAnswer ? SGTheme.ember.opacity(0.22) : SGTheme.inkRaised)
                            )
                            .cornerRadius(SGTheme.tileRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: SGTheme.tileRadius)
                                    .stroke(
                                        index == currentRegret.correctAnswerIndex ?
                                        SGTheme.mint : SGTheme.hairline,
                                        lineWidth: index == currentRegret.correctAnswerIndex ? 2 : 1
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal)

            ScrollView {
                Text(currentRegret.backgroundExplanation)
                    .font(.subheadline)
                    .foregroundColor(SGTheme.paperSecondary)
                    .padding()
            }
            .frame(maxHeight: 150)
        }
    }

    private struct FinalMessageView: View {
        let hasIncorrectAnswers: Bool
        let dismissAction: () -> Void
        let retryAction: () -> Void

        var body: some View {
            VStack {
                Spacer()

                MascotView(pose: .teaching)
                    .frame(width: 160, height: 160)

                Text(hasIncorrectAnswers ?
                     "Looks like you need more practice!" :
                        "Well done! You've completed the deck!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding()

                Spacer()

                VStack(spacing: 15) {
                    Button(action: hasIncorrectAnswers ? retryAction : dismissAction) {
                        Text(hasIncorrectAnswers ? "Retry Questions" : "Finish Practice")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(SGTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(SGTheme.mint)
                            .cornerRadius(50)
                    }

                    Button(action: dismissAction) {
                        Text("Close")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SGTheme.paper)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(SGTheme.glaze(0.08))
                            .cornerRadius(50)
                    }
                }
                .padding()
            }
        }
    }


    // MARK: - View Model
    class PracticeViewModel: ObservableObject {
        @Published var currentStep = 0
        @Published var selectedAnswer: Int? = nil
        @Published var showFinalMessage = false
        @Published var hasIncorrectAnswers = false
        @Published var questions: [Regret] = []
        @Published var questionResults: [Bool?] = []

        private var originalDeck: Deck?
        private var sessionStartedAt: Date = Date()
        private var didTrackCompletion: Bool = false
        private var attemptCount: Int = 1

        var currentQuestion: Regret? {
            guard !questions.isEmpty else { return nil }
            let index = currentStep / 2
            return index < questions.count ? questions[index] : nil
        }

        var progress: Double {
            guard !questions.isEmpty else { return 0 }
            return Double(currentStep) / Double(questions.count * 2)
        }

        var controlButtonText: String {
            showAnswer ? "Next Question" : "Select Answer"
        }

        var isControlButtonDisabled: Bool {
            !showAnswer && selectedAnswer == nil
        }

        var showAnswer: Bool {
            currentStep % 2 == 1
        }

        func setup(deck: Deck?) {
            guard let deck = deck, !deck.cards.isEmpty else {
                showFinalMessage = true
                return
            }

            originalDeck = deck
            questions = deck.cards.shuffled()
            questionResults = Array(repeating: nil, count: questions.count) // Now works with the declared property
            currentStep = 0
            selectedAnswer = nil

            // Only track session start on the first setup call (not retries —
            // those reuse the same originalDeck via retryQuestions).
            if !didTrackCompletion {
                sessionStartedAt = Date()
                Analytics.practiceSessionStarted(
                    deckId: deck.id.uuidString,
                    deckName: deck.name,
                    cardCount: questions.count
                )
            }
        }


        func handleTap() {
            if showAnswer {
                currentStep += 1
                selectedAnswer = nil
                if currentStep >= questions.count * 2 {
                    showFinalMessage = true
                    trackCompletion()
                }
            } else if selectedAnswer != nil {
                checkAnswer()
                currentStep += 1
            }
        }

        func retryQuestions() {
            attemptCount += 1
            setup(deck: originalDeck)
            showFinalMessage = false
            hasIncorrectAnswers = false
        }

        /// Called by the view when the user dismisses without finishing.
        func trackAbandonIfNeeded() {
            guard !didTrackCompletion, let deck = originalDeck else { return }
            Analytics.practiceSessionAbandoned(
                deckId: deck.id.uuidString,
                deckName: deck.name,
                currentStep: currentStep,
                totalQuestions: questions.count
            )
            didTrackCompletion = true
        }

        private func trackCompletion() {
            guard !didTrackCompletion, let deck = originalDeck else { return }
            didTrackCompletion = true
            let correct = questionResults.compactMap { $0 }.filter { $0 }.count
            Analytics.practiceSessionCompleted(
                deckId: deck.id.uuidString,
                deckName: deck.name,
                correctCount: correct,
                totalQuestions: questions.count,
                hadRetries: attemptCount > 1,
                durationSec: Date().timeIntervalSince(sessionStartedAt)
            )
        }

        private func checkAnswer() {
               guard let currentQuestion = currentQuestion else { return }
               let isCorrect = selectedAnswer == currentQuestion.correctAnswerIndex
               let questionIndex = currentStep / 2

               if questionIndex < questionResults.count {
                   questionResults[questionIndex] = isCorrect
                   hasIncorrectAnswers = !isCorrect
               }
           }
    }
}
