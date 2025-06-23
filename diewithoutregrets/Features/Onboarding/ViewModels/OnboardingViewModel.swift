//
//  OnboardingViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI
import CoreHaptics
import PostHog

enum OnboardingStep {
    case welcome
    case gradeObstacles
    case averageScreenTime
    case age
    case name
    case breakdown
    case studyConsistancy
    case longTermResults
    case studyTwice
    case aiFlashcardDemo
    case rating
    case readyView
    case paywall
    case weCanHelp
    case createFirstFlashcard
    case appSelection
    case completion
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var userName: String = ""
    @Published var selectedAge: String = ""
    @Published var screenTime: String = ""
    @Published var newDeckName: String = "My First Deck"
    @Published var regretEntries: [Regret] = []
    @Published var selectedApps: [RegretApp] = []

    
    // Haptic engine
    private var hapticEngine: CHHapticEngine?
    
    let regretPrompts = [
            "Create your first study flashcard. What's a concept you want to remember?",
            "Add a question about something you're currently studying."
        ]
        
    init() {
        prepareHaptics()
    }
    
    func nextStep() {
        // Trigger haptic feedback when moving to next step
        triggerHapticFeedback()
        
        switch currentStep {
        case .welcome:
            currentStep = .gradeObstacles
        case .gradeObstacles:
            currentStep = .averageScreenTime
        case .averageScreenTime:
            currentStep = .age
        case .age:
            currentStep = .name
        case .name:
            currentStep = .breakdown
        case .breakdown:
            currentStep = .studyConsistancy
        case .studyConsistancy:
            currentStep = .longTermResults
        case .longTermResults:
            currentStep = .studyTwice
        case .studyTwice:
            currentStep = .aiFlashcardDemo
        case .aiFlashcardDemo:
            currentStep = .rating
        case .rating:
            currentStep = .readyView
        case .readyView:
            currentStep = .paywall
        case .paywall:
            currentStep = .weCanHelp
        case .weCanHelp:
            currentStep = .createFirstFlashcard
        case .createFirstFlashcard:
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
        // Save user data
        UserDefaults.standard.set(userName, forKey: "userName")
        UserDefaults.standard.set(selectedAge, forKey: "selectedAge")
        UserDefaults.standard.set(screenTime, forKey: "screenTime")
        
        // Mark that user has seen paywall during onboarding
        UserDefaults.standard.set(true, forKey: "hasSeenPaywall")
        
        // Create first deck if we have flashcards
        if !regretEntries.isEmpty {
            let newDeck = Deck(name: newDeckName, cards: regretEntries)
            DeckStore.shared.addDeck(newDeck)
        }
    }
}
