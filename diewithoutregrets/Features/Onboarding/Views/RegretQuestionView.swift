//
//  BibleVerseQuestionView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct BibleVerseQuestionView: View {
    @StateObject private var viewModel = BibleVerseQuestionViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var currentQuestionIndex = 0
    @State private var showQuestionCard = false
    
    let questions = [
        Question(
            title: "Your Favorite Verse",
            prompt: "What Bible verse gives you strength and guidance when you're feeling weak or lost? Share a verse that speaks to your heart.",
            placeholder: "e.g., 'For God so loved the world...' - John 3:16"
        ),
        Question(
            title: "Your Anchor",
            prompt: "What Scripture helps you stay focused on what truly matters in life? What verse reminds you of your purpose?",
            placeholder: "Share a verse that keeps you grounded"
        )
    ]
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            if currentQuestionIndex < questions.count {
                BibleVerseQuestionCard(
                    question: questions[currentQuestionIndex],
                    answer: $viewModel.answers[currentQuestionIndex],
                    onContinue: {
                        if currentQuestionIndex < questions.count - 1 {
                            withAnimation {
                                currentQuestionIndex += 1
                            }
                        } else {
                            // Save answers to onboardingViewModel
                            onboardingViewModel.bibleVerseAnswers = viewModel.answers
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

struct BibleVerseQuestionCard: View {
    let question: Question
    @Binding var answer: String
    let onContinue: () -> Void
    let canContinue: Bool
    let currentQuestionIndex: Int
    let totalQuestions: Int
    @Binding var showQuestionCard: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cross icon
            HStack {
                Spacer()
                Image(systemName: "cross.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.bottom, 10)
            
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
                .foregroundColor(.white.opacity(0.9))
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
                    .accessibilityHint("Type your Bible verse here")
                    .accessibilityValue(answer.isEmpty ? "Empty" : answer)
                
                if answer.isEmpty {
                    Text(question.placeholder)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        .opacity(showQuestionCard ? 1 : 0)
                        .offset(y: showQuestionCard ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                        .accessibilityHidden(true)
                }
            }
            
            // Character Count
            HStack {
                Spacer()
                Text("\(answer.count)/300")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showQuestionCard ? 1 : 0)
                    .offset(y: showQuestionCard ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showQuestionCard)
                    .accessibilityLabel("Character count: \(answer.count) out of 300")
            }
            
            Spacer()
            
            // Continue/Finish Button
            Button(action: onContinue) {
                Text(currentQuestionIndex < totalQuestions - 1 ? "Continue" : "Finish")
                    .foregroundColor(.black)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white)
                    .cornerRadius(30)
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

// Backward compatibility alias
typealias RegretQuestionView = BibleVerseQuestionView
typealias QuestionCard = BibleVerseQuestionCard

#Preview {
    BibleVerseQuestionView()
        .environmentObject(OnboardingViewModel())
}
