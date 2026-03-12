//
//  OnboardingViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI
import CoreHaptics
import PostHog

enum OnboardingStep: CaseIterable {
    // Phase 1: Emotional Hook
    case theHook
    case theFeeling
    case theObstacle
    // Phase 2: Reality Check
    case screenTimeStudy
    case yourScreenTime
    case yourName
    case yourAge
    case theCost
    // Phase 3: The Shift
    case procrastinationStudy
    case consistencyReframe
    // Phase 4: The Solution
    case howItWorks
    case aiFlashcards
    case retentionStudy
    case socialProof
    // Phase 5: Setup & Commitment
    case readyView
    case paywall
    case notificationPermission
    case unlockMethodChoice
    case appSelection
    case completion
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .theHook
    @Published var userName: String = ""
    @Published var selectedAge: String = ""
    @Published var screenTime: String = ""
    @Published var newDeckName: String = "My First Deck"
    @Published var regretEntries: [Regret] = []
    @Published var selectedApps: [RegretApp] = []
    @Published var selectedFeelings: Set<String> = []
    @Published var selectedObstacles: Set<String> = []

    private var hapticEngine: CHHapticEngine?
    
    let regretPrompts = [
            "Create your first study flashcard. What's a concept you want to remember?",
            "Add a question about something you're currently studying."
        ]
        
    init() {
        prepareHaptics()
    }
    
    var totalSteps: Int { OnboardingStep.allCases.count }
    
    var currentStepIndex: Int {
        OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0
    }
    
    var progress: Float {
        guard totalSteps > 1 else { return 0 }
        return Float(currentStepIndex) / Float(totalSteps - 1)
    }
    
    func nextStep() {
        triggerHapticFeedback()
        
        switch currentStep {
        case .theHook:
            currentStep = .theFeeling
        case .theFeeling:
            currentStep = .theObstacle
        case .theObstacle:
            currentStep = .screenTimeStudy
        case .screenTimeStudy:
            currentStep = .yourScreenTime
        case .yourScreenTime:
            currentStep = .yourName
        case .yourName:
            currentStep = .yourAge
        case .yourAge:
            currentStep = .theCost
        case .theCost:
            currentStep = .procrastinationStudy
        case .procrastinationStudy:
            currentStep = .consistencyReframe
        case .consistencyReframe:
            currentStep = .howItWorks
        case .howItWorks:
            currentStep = .aiFlashcards
        case .aiFlashcards:
            currentStep = .retentionStudy
        case .retentionStudy:
            currentStep = .socialProof
        case .socialProof:
            currentStep = .readyView
        case .readyView:
            currentStep = .paywall
        case .paywall:
            currentStep = .notificationPermission
        case .notificationPermission:
            currentStep = .unlockMethodChoice
        case .unlockMethodChoice:
            saveUserData()
            currentStep = .appSelection
        case .appSelection:
            currentStep = .completion
        case .completion:
            break
        }
    }
    
    func skipToCompletion() {
        // Trigger haptic feedback
        triggerHapticFeedback()
        
        // Track skipping to completion in PostHog
        PostHogSDK.shared.capture(
            "onboarding_skipped", 
            properties: [
                "timestamp": Date().ISO8601Format(),
                "skipped_from_step": "\(currentStep)",
                "user_name": userName.isEmpty ? "not_provided" : userName,
                "selected_age": selectedAge.isEmpty ? "not_provided" : selectedAge,
                "screen_time": screenTime.isEmpty ? "not_provided" : screenTime
            ]
        )
        
        // Save user data before completing
        saveUserData()
        
        // Skip directly to completion
        currentStep = .completion
    }
    
    // Function to trigger haptic feedback
    func triggerHapticFeedback() {
        // Use UINotificationFeedbackGenerator for simpler feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Or use the more advanced CHHapticEngine for more customizable feedback
        playHapticFeedback()
    }
    
    // Prepare the haptic engine
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Play a simple button tap haptic pattern
    private func playHapticFeedback() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error.localizedDescription)")
        }
    }
    
    private func saveUserData() {
        UserDefaults.standard.set(userName, forKey: "userName")
        UserDefaults.standard.set(selectedAge, forKey: "selectedAge")
        UserDefaults.standard.set(screenTime, forKey: "screenTime")
        UserDefaults.standard.set(true, forKey: "hasSeenPaywall")
    }
}
