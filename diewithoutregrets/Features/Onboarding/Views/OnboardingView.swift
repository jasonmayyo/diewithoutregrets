//
//  OnboardingView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct OnboardingView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    
    // Calculate progress based on current step
    private func progressValue() -> Float {
        switch onboardingViewModel.currentStep {
        case .welcome:
            return 0.0
        case .averageScreenTime:
            return 0.14
        case .age:
            return 0.28
        case .name:
            return 0.42
        case .breakdown:
            return 0.56
        case .longTermResults:
            return 0.65
        case .studyTwice:
            return 0.70
        case .rating:
            return 0.75
        case .readyView:
            return 0.80
        case .weCanHelp:
            return 0.85
        case .createFirstFlashcard:
            return 0.90
        case .appSelection:
            return 0.95
        case .completion:
            return 1.0
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar - only show if not on welcome or completion screen
            // Progress bar - only show if not on welcome or completion screen
            if onboardingViewModel.currentStep != .welcome && onboardingViewModel.currentStep != .completion {
                ZStack(alignment: .top) {
                    // Full green background that extends into safe area
                    Color(hex: 0x184449)
                        .ignoresSafeArea(.all, edges: .top)
                        .frame(height: 40) // Give it enough height to cover the safe area and progress bar
                    
                    // Progress indicator
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color(hex: 0x184449).opacity(0.3))
                                .frame(height: 6)
                                .cornerRadius(3)
                            
                            // Progress
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * CGFloat(progressValue()), height: 6)
                                .cornerRadius(3)
                                .animation(.easeInOut(duration: 0.6), value: progressValue())
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .padding(.top, 24) // Adjust based on your device's safe area height
                }
            }
            
            // Content
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
                case .longTermResults:
                    LongTermResultsView()
                        .environmentObject(onboardingViewModel)
                case .studyTwice:
                    StudyTwiceView()
                        .environmentObject(onboardingViewModel)
                case .rating:
                    RatingView()
                        .environmentObject(onboardingViewModel)
                case .readyView:
                    StudyGuardReadyView()
                        .environmentObject(onboardingViewModel)
                case .breakdown:
                    BreakdownView()
                        .environmentObject(onboardingViewModel)
                case .weCanHelp:
                    WecanhelpView()
                        .environmentObject(onboardingViewModel)
                        .presentPaywallIfNeeded(requiredEntitlementIdentifier: "Pro Acess")
                case .createFirstFlashcard:
                    CreateFirstFlashcardView()
                        .environmentObject(onboardingViewModel)
                case .appSelection:
                    AppSelectionOnboarding()
                        .environmentObject(onboardingViewModel)
                case .completion:
                    CompletionView()
                        .environmentObject(onboardingViewModel)
                }
            }
        }
    }
    
    // Helper to get the step number (1-based)
    private func stepNumber() -> Int {
        switch onboardingViewModel.currentStep {
        case .welcome:
            return 0 // Welcome isn't counted
        case .averageScreenTime:
            return 1
        case .age:
            return 2
        case .name:
            return 3
        case .breakdown:
            return 4
        case .longTermResults:
            return 5
        case .studyTwice:
            return 6
        case .rating:
            return 7
        case .readyView:
            return 8
        case .weCanHelp:
            return 9
        case .createFirstFlashcard:
            return 10
        case .appSelection:
            return 11
        case .completion:
            return 12
        }
    }
}

#Preview {
    OnboardingView()
}
