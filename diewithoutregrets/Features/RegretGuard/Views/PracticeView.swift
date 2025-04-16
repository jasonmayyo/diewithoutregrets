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
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack {
                // Added header with back button and progress bar
                HStack(spacing: 3) {
                                    // Back Button
                                    Button(action: { dismiss() }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Color(hex: 0x184449))
                                            .padding(8)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .padding(.leading, 10)
                                    
                                    // Updated ProgressBar
                    ProgressBar(questionResults: viewModel.questionResults)
                                    
                                    Spacer()
                                }
                                .padding(.top)
                                .padding(.horizontal, 10)
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
                viewModel.setup(deck: deckStore.selectedDeck)
            }
        }
    }
    
    // MARK: - Subviews
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
                                .padding()
                                .frame(maxWidth: .infinity)
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
    
    // MARK: - Subviews
    private struct ProgressBar: View {
        let questionResults: [Bool?]
        
        var body: some View {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(0..<questionResults.count, id: \.self) { index in
                        let segmentWidth = geometry.size.width / CGFloat(questionResults.count)
                        
                        Rectangle()
                            .frame(width: segmentWidth, height: 5)
                            .foregroundColor(colorForQuestion(at: index))
                            .cornerRadius(10)
                    }
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 10)
        }
        
        private func colorForQuestion(at index: Int) -> Color {
            guard index < questionResults.count else { return .gray }
            
            if let isCorrect = questionResults[index] {
                return isCorrect ? .green : .red
            }
            return .gray
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
                            .padding()
                            .frame(maxWidth: .infinity)
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
#Preview {
    PracticeView()
}
