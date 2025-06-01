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
            Color(.systemBackground).ignoresSafeArea()
            
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
            .preferredColorScheme(.light)
            .onAppear {
                viewModel.setup(deck: deck)
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
                        .foregroundColor(Color(hex: 0x184449).opacity(0.8))
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
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
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: barHeight)
                    
                    // Progress Fill
                    Capsule()
                        .fill(Color(hex: 0x184449))
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
                            .font(.title3)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .padding()
                        
                        if showAnswer {
                            ScrollView {
                                Text(explanation)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
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
            VStack(spacing: 12) {
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
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(background(for: index))
                        }
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor(for: index), lineWidth: 2)
                        )
                    }
                    .disabled(showAnswer)
                }
            }
            .padding(.horizontal)
        }
        
        private func textColor(for index: Int) -> Color {
            showAnswer ? (index == correctAnswer ? .white : .primary) : .primary
        }
        
        private func background(for index: Int) -> Color {
            if showAnswer {
                return index == correctAnswer ? .green : (index == selectedAnswer ? .red.opacity(0.2) : .clear)
            }
            return selectedAnswer == index ? .gray.opacity(0.2) : .clear
        }
        
        private func borderColor(for index: Int) -> Color {
            showAnswer ? (index == correctAnswer ? .green : .clear) : .gray.opacity(0.3)
        }
    }
    
    private struct ControlButton: View {
        let text: String
        let action: () -> Void
        let disabled: Bool
        
        var body: some View {
            Button(action: action) {
                Text(text)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(disabled ? Color.gray.opacity(0.5) : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(disabled)
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
                            .foregroundColor(index == currentRegret.correctAnswerIndex ? .white : .primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                index == currentRegret.correctAnswerIndex ?
                                Color.green :
                                    (index == selectedAnswer ? Color.red.opacity(0.2) : Color.clear)
                            )
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        index == currentRegret.correctAnswerIndex ?
                                        Color.green : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                Text(currentRegret.backgroundExplanation)
                    .font(.subheadline)
                    .foregroundColor(.gray)
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
                
                Text(hasIncorrectAnswers ?
                     "Looks like you need more practice!" :
                        "Well done! You've completed the deck!")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                
                Spacer()
                
                VStack(spacing: 15) {
                    Button(action: hasIncorrectAnswers ? retryAction : dismissAction) {
                        Text(hasIncorrectAnswers ? "Retry Questions" : "Finish Practice")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: dismissAction) {
                        Text("Close")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
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
        }
            
        
        func handleTap() {
            if showAnswer {
                currentStep += 1
                selectedAnswer = nil
                if currentStep >= questions.count * 2 {
                    showFinalMessage = true
                }
            } else if selectedAnswer != nil {
                checkAnswer()
                currentStep += 1
            }
        }
        
        func retryQuestions() {
            setup(deck: originalDeck)
            showFinalMessage = false
            hasIncorrectAnswers = false
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
