//
//  OnboardingViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

enum OnboardingStep {
    case welcome
    case averageScreenTime
    case age
    case name
    case breakdown
    case weCanHelp
    case regretQuestions
    case completion
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var userName: String = ""
    @Published var selectedAge: String = ""
    @Published var screenTime: String = ""
    @Published var regretEntries: [Regret] = [
        Regret(
        regretPrompt: "Not spending enough time with family",
        regret: "Not spending enough time with the people I love",
        choices: ["Option 1", "Option 2", "Option 3", "Option 4"],
        correctAnswerIndex: 0,
        backgroundExplanation: "Studies show people who prioritize family time report higher life satisfaction and lower end-of-life regrets."
        ),
        ]
    
    let regretPrompts = [
            "Imagine you’re 80, looking back on your life. What are the things you’d most regret not doing? What dreams did you leave behind? What opportunities did you waste?",
            "What’s one thing you’d regret not doing if you knew your time was limited?"
        ]
        
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .averageScreenTime
        case .averageScreenTime:
            currentStep = .age
        case .age:
            currentStep = .name
        case .name:
            currentStep = .breakdown
        case .breakdown:
            currentStep = .weCanHelp
        case .weCanHelp:
            currentStep = .regretQuestions
        case .regretQuestions:
                    saveRegretAnswers()
                    currentStep = .completion
        case .completion:
            break
        }
    }
    
    
    private func saveRegretAnswers() {
            RegretStore.shared.addRegrets(regretEntries)
        }
}
