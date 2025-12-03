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
    case bibleVerseQuestions
    case completion
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var userName: String = ""
    @Published var selectedAge: String = ""
    @Published var screenTime: String = ""
    @Published var bibleVerseAnswers: [String] = ["", ""]
    
    let bibleVersePrompts = [
        "What Bible verse gives you strength and guidance when you're feeling weak or lost?",
        "What Scripture helps you stay focused on what truly matters in life?"
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
            currentStep = .bibleVerseQuestions
        case .bibleVerseQuestions:
            saveBibleVerseAnswers()
            currentStep = .completion
        case .completion:
            break
        }
    }
    
    private func saveBibleVerseAnswers() {
        // Parse the user's answers into BibleVerse objects
        // For now, we'll create simple verses from the user input
        let newVerses = bibleVerseAnswers.enumerated().compactMap { index, answer -> BibleVerse? in
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return BibleVerse(
                verse: answer,
                reference: "Personal \(index + 1)",
                translation: "Personal"
            )
        }
        BibleVerseStore.shared.addVerses(newVerses)
    }
}
