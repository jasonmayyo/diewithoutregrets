//
//  CreateFirstFlashcardView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/04/06.
//

import SwiftUI

// Reusable Input Card Component from RegretGuard
struct InputCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(Color(hex: 0x065961))
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(hex: 0x013B41))
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CreateFirstFlashcardView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var newExplanation = ""
    @State private var choices = ["", "", ""]
    
    private let dwrGreen = Color(hex: 0x013B41)
    private let accentColor = Color(hex: 0x065961)
    private let bgColor = Color(.systemGroupedBackground)
    
    private var isValidInput: Bool {
        !newQuestion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !newAnswer.trimmingCharacters(in: .whitespaces).isEmpty &&
        choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 1
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: 0xF5F7FA)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Text
                Text("Create your first flashcard")
                    .font(.title3)
                    .bold()
                    .foregroundColor(dwrGreen)
                    .padding(.top)
                
                // Form
                ScrollView {
                    VStack(spacing: 24) {
                        // Question Section
                        InputCard(title: "Question", systemImage: "questionmark.circle") {
                            TextField("What's the main question?", text: $newQuestion)
                                .font(.body)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(bgColor)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(newQuestion.isEmpty ? Color.gray.opacity(0.3) : accentColor, lineWidth: 1)
                                )
                        }
                        
                        // Correct Answer Section
                        InputCard(title: "Correct Answer", systemImage: "checkmark.circle") {
                            TextField("Enter the correct answer", text: $newAnswer)
                                .font(.body)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(bgColor)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(newAnswer.isEmpty ? Color.gray.opacity(0.3) : accentColor, lineWidth: 1)
                                )
                        }
                        
                        // Incorrect Answers Section
                        InputCard(title: "Incorrect Answers", systemImage: "xmark.circle") {
                            VStack(spacing: 12) {
                                ForEach(choices.indices, id: \.self) { index in
                                    HStack {
                                        TextField("Option \(index + 1)", text: $choices[index])
                                            .font(.body)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 16)
                                            .background(bgColor)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(choices[index].isEmpty ? Color.gray.opacity(0.3) : accentColor, lineWidth: 1)
                                            )
                                        
                                        if choices.count > 1 {
                                            Button(action: {
                                                removeOption(at: index)
                                            }) {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(.red.opacity(0.7))
                                            }
                                        }
                                    }
                                }
                                
                                if choices.count < 5 {
                                    Button(action: addNewOption) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Option")
                                        }
                                        .foregroundColor(dwrGreen)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(dwrGreen.opacity(0.5), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        
                        // Explanation Section
                        InputCard(title: "Explanation", systemImage: "lightbulb") {
                            VStack(alignment: .leading) {
                                TextEditor(text: $newExplanation)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .background(bgColor)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Text("\(newExplanation.count)/500")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .padding()
                }
                
                // Continue Button
                Button(action: {
                    saveFlashcard()
                    onboardingViewModel.triggerHapticFeedback()
                    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(isValidInput ? Color(hex: 0x184449) : Color.gray.opacity(0.5))
                        .cornerRadius(28)
                        .padding(.horizontal, 24)
                }
                .disabled(!isValidInput)
                .padding(.bottom, 24)
            }
        }
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
        // Combine the correct answer with non-empty incorrect answers.
        let incorrectChoices = choices.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allChoices = [newAnswer] + incorrectChoices
        // First, shuffle the answers…
        let shuffledChoices = allChoices.shuffled()
        // …then find the new index of the correct answer.
        let correctIndex = shuffledChoices.firstIndex(of: newAnswer) ?? 0
        
        let newRegret = Regret(
            regretPrompt: newQuestion,
            regret: newAnswer,
            choices: shuffledChoices,
            correctAnswerIndex: correctIndex,
            backgroundExplanation: newExplanation
        )
        onboardingViewModel.regretEntries.append(newRegret)
    }
}

// We're reusing the InputCard component from NewFlashcardSheet
#Preview {
    CreateFirstFlashcardView()
        .environmentObject(OnboardingViewModel())
} 