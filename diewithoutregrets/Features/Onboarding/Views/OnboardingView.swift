//
//  OnboardingView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    
    var body: some View {
        Group {
            switch onboardingViewModel.currentStep {
            case .welcome:
                WelcomeView()
                    .environmentObject(onboardingViewModel)
            case .averageScreenTime:
                AverageScreenTime()
                    .environmentObject(onboardingViewModel)
            case .age:
                AgeSelectView()
                    .environmentObject(onboardingViewModel)
            case .name:
                NameView()
                    .environmentObject(onboardingViewModel)
            case .breakdown:
                BreakdownView()
                    .environmentObject(onboardingViewModel)
            case .weCanHelp:
                WecanhelpView()
                    .environmentObject(onboardingViewModel)
            case .regretQuestions:
                RegretQuestionView()
                    .environmentObject(onboardingViewModel)
            case .completion:
                CompletionView()
                    .environmentObject(onboardingViewModel)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
