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

        private var progress: Double {
            let total = questionResults.count
            guard total > 0 else { return 0 }
            return Double(questionResults.compactMap { $0 }.count) / Double(total)
        }

        var body: some View {
            HStack(spacing: 12) {
                // Same 32pt circle in a 44pt target as SGSheetHeader's close.
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(SGTheme.caption.weight(.bold))
                        .foregroundColor(SGTheme.paperSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(SGTheme.glaze(0.08)))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SGPressStyle())

                SGProgressBar(progress: progress)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 5)
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
                            .font(SGTheme.display(22))
                            .foregroundColor(SGTheme.paper)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding()

                        if showAnswer {
                            ScrollView {
                                Text(explanation)
                                    .font(SGTheme.body)
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
                        if showAnswer {
                            // The correct tile sweeps mint, the miss shakes,
                            // the rest dim.
                            QuizAnswerTile(
                                text: choice,
                                state: revealState(for: index)
                            )
                        } else {
                            QuizAnswerTile(
                                text: choice,
                                state: selectedAnswer == index ? .selected : .idle
                            ) {
                                QuizHaptics.selectTick()
                                selectedAnswer = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 300) // Limit height to prevent overflow
        }

        private func revealState(for index: Int) -> QuizTileState {
            if index == correctAnswer { return .revealedCorrect }
            if index == selectedAnswer { return .revealedWrong }
            return .dimmed
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

                SGButton(title: text, enabled: !disabled, action: action)
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.vertical, 16)
            }
            .background(SGTheme.inkRaised)
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
                .font(SGTheme.display(22))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding()

                Spacer()

                VStack(spacing: 15) {
                    SGButton(
                        title: hasIncorrectAnswers ? "Retry Questions" : "Finish Practice",
                        action: hasIncorrectAnswers ? retryAction : dismissAction
                    )

                    SGButton(title: "Close", variant: .ghost, action: dismissAction)
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
