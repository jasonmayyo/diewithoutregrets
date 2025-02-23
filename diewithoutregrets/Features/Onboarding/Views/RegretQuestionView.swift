//
//  RegretQuestionView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct RegretQuestionView: View {
    @StateObject private var viewModel = RegretQuestionViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var currentQuestionIndex = 0
    @State private var showQuestionCard = false
    
    let questions = [
        Question(
            title: "First Question",
            prompt: "Imagine you're 80, looking back on your life. What are the things you'd most regret not doing? What dreams did you leave behind? What opportunities did you waste?",
            placeholder: "Type your answer here (2 sentences max)"
        ),
        Question(
            title: "Second Question",
            prompt: "What's one thing you keep telling yourself you'll do 'someday'? What if that 'someday' never comes?",
            placeholder: "Describe your 'someday' dream"
        )
    ]
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true) // Hide decorative background color
            
            if currentQuestionIndex < questions.count {
                QuestionCard(
                    question: questions[currentQuestionIndex],
                    answer: $viewModel.answers[currentQuestionIndex],
                    onContinue: {
                        if currentQuestionIndex < questions.count - 1 {
                            withAnimation {
                                currentQuestionIndex += 1
                            }
                        } else {
                            // Save answers to onboardingViewModel
                            onboardingViewModel.regretAnswers = viewModel.answers
                            onboardingViewModel.nextStep()
                        }
                    },
                    canContinue: viewModel.canContinue(for: currentQuestionIndex),
                    currentQuestionIndex: currentQuestionIndex,
                    totalQuestions: questions.count,
                    showQuestionCard: $showQuestionCard
                )
            }
        }
        .onAppear {
            showQuestionCard = true
        }
    }
}

struct QuestionCard: View {
    let question: Question
    @Binding var answer: String
    let onContinue: () -> Void
    let canContinue: Bool
    let currentQuestionIndex: Int
    let totalQuestions: Int
    @Binding var showQuestionCard: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Question Title
            Text(question.title)
                .font(.title2)
                .foregroundColor(.white)
                .bold()
                .opacity(showQuestionCard ? 1 : 0)
                .offset(y: showQuestionCard ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                .accessibilityLabel("Question \(currentQuestionIndex + 1): \(question.title)")
            
            // Question Prompt
            Text(question.prompt)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.bottom, 20)
                .opacity(showQuestionCard ? 1 : 0)
                .offset(y: showQuestionCard ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                .accessibilityLabel(question.prompt)
            
            // Text Editor for Answer
            ZStack(alignment: .topLeading) {
                TextEditor(text: $answer)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .frame(minHeight: 100, maxHeight: 150)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .opacity(showQuestionCard ? 1 : 0)
                    .offset(y: showQuestionCard ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                    .accessibilityLabel("Answer field")
                    .accessibilityHint("Type your answer here")
                    .accessibilityValue(answer.isEmpty ? "Empty" : answer)
                
                if answer.isEmpty {
                    Text(question.placeholder)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        .opacity(showQuestionCard ? 1 : 0)
                        .offset(y: showQuestionCard ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                        .accessibilityHidden(true) // Hide placeholder from VoiceOver
                }
            }
            
            // Character Count
            HStack {
                Spacer()
                Text("\(answer.filter { !$0.isWhitespace }.count)/200")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showQuestionCard ? 1 : 0)
                    .offset(y: showQuestionCard ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                    .accessibilityLabel("Character count: \(answer.filter { !$0.isWhitespace }.count) out of 200")
            }
            
            Spacer()
            
            // Continue/Finish Button
            Button(action: onContinue) {
                Text(currentQuestionIndex < totalQuestions - 1 ? "Continue" : "Finish")
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(Color.white)
                    .cornerRadius(50)
            }
            .disabled(!canContinue)
            .buttonStyle(DisabledOpacityButtonStyle())
            .opacity(showQuestionCard ? 1 : 0)
            .offset(y: showQuestionCard ? 0 : 20)
            .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
            .accessibilityLabel(currentQuestionIndex < totalQuestions - 1 ? "Continue" : "Finish")
            .accessibilityHint("Tap to proceed to the next question")
            .accessibilityAddTraits(.isButton)
        }
        .padding()
    }
}

#Preview {
    RegretQuestionView()
        .environmentObject(OnboardingViewModel())
}
