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
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            if currentQuestionIndex < viewModel.regrets.count {
                QuestionCard(
                    regret: $viewModel.regrets[currentQuestionIndex],
                    onContinue: {
                        if currentQuestionIndex < viewModel.regrets.count - 1 {
                            withAnimation {
                                currentQuestionIndex += 1
                            }
                        } else {
                            onboardingViewModel.regretEntries = viewModel.regrets
                            onboardingViewModel.nextStep()
                        }
                    },
                    canContinue: viewModel.canContinue(for: currentQuestionIndex),
                    currentQuestionIndex: currentQuestionIndex,
                    totalQuestions: viewModel.regrets.count,
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
    @Binding var regret: Regret
    let onContinue: () -> Void
    let canContinue: Bool
    let currentQuestionIndex: Int
    let totalQuestions: Int
    @Binding var showQuestionCard: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Flashcard \(currentQuestionIndex + 1)")
                .font(.title2)
                .foregroundColor(.white)
                .bold()
                .accessibilityLabel("Regret \(currentQuestionIndex + 1)")
            
            ZStack(alignment: .topLeading) {
                TextField("Enter your Question...", text: $regret.regretPrompt)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                    .foregroundColor(.white)
                
                if regret.regretPrompt.isEmpty {
                    Text("Enter your Question...")
                        .foregroundColor(.white.opacity(0.6))
                        .padding()
                }
            }
            
            // Answer Input
            ZStack(alignment: .topLeading) {
                TextEditor(text: $regret.regret)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                    .foregroundColor(.white)
                
                if regret.regret.isEmpty {
                    Text("Type your answer here...")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(25)
                }
            }
            
            Spacer()
            
            Button(action: onContinue) {
                Text(currentQuestionIndex < totalQuestions - 1 ? "Continue" : "Finish")
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(50)
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.6)
        }
        .padding()
    }
}

#Preview {
    RegretQuestionView()
        .environmentObject(OnboardingViewModel())
}
