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
    case flashcardSources
    case retentionStudy
    case socialProof
    // Phase 5: Setup & Commitment
    case readyView
    case paywall
    case notificationPermission
    case unlockMethodChoice
    case appSelection
    case createFirstCards
    case completion
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .theHook {
        didSet {
            // Fire `onboarding_step_viewed` whenever the step changes so we can
            // build a 20-step funnel in PostHog from a single event.
            trackStepViewed()
        }
    }
    @Published var userName: String = ""
    @Published var selectedAge: String = ""
    @Published var screenTime: String = ""
    @Published var newDeckName: String = "My First Deck"
    @Published var regretEntries: [Regret] = []
    @Published var selectedApps: [RegretApp] = []
    @Published var selectedFeelings: Set<String> = []
    @Published var selectedObstacles: Set<String> = []

    /// Tracks when each step was first shown so we can compute time-on-step
    /// when the user advances. Keyed by step name.
    private var stepStartTimes: [String: Date] = [:]

    private var hapticEngine: CHHapticEngine?
    
    let regretPrompts = [
            "Create your first study flashcard. What's a concept you want to remember?",
            "Add a question about something you're currently studying."
        ]
        
    init() {
        prepareHaptics()
        // Fire for the initial step (didSet doesn't run during init).
        trackStepViewed()
    }

    private func trackStepViewed() {
        let stepName = "\(currentStep)"
        stepStartTimes[stepName] = Date()
        Analytics.onboardingStepViewed(
            step: stepName,
            stepIndex: currentStepIndex,
            totalSteps: totalSteps
        )
    }

    /// Time the user spent on the given step before advancing, in seconds.
    /// Returns nil if we never recorded an entry time for that step.
    func timeOnStep(_ step: OnboardingStep) -> Double? {
        let key = "\(step)"
        guard let start = stepStartTimes[key] else { return nil }
        return Date().timeIntervalSince(start)
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

        // Emit a step-specific completion event with the data we just captured.
        // This is what powers the "where did the user actually drop?" analysis
        // alongside the generic `onboarding_step_viewed` funnel.
        trackStepCompleted()

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
            currentStep = .flashcardSources
        case .flashcardSources:
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
            currentStep = .createFirstCards
        case .createFirstCards:
            currentStep = .completion
        case .completion:
            break
        }
    }

    /// Fire a step-specific event with whatever data the user just captured on
    /// that step. Lets you slice retention by *what they answered* rather than
    /// just *how far they got*.
    private func trackStepCompleted() {
        let stepName = "\(currentStep)"
        let durationSec = timeOnStep(currentStep)

        switch currentStep {
        case .theFeeling:
            Analytics.onboardingFeelingsSelected(Array(selectedFeelings))
        case .theObstacle:
            Analytics.onboardingObstaclesSelected(Array(selectedObstacles))
        case .yourScreenTime:
            if !screenTime.isEmpty {
                Analytics.onboardingScreenTimeSelected(screenTime)
            }
        case .yourName:
            Analytics.onboardingNameEntered(name: userName)
        case .yourAge:
            if !selectedAge.isEmpty {
                Analytics.onboardingAgeSelected(selectedAge)
            }
        case .unlockMethodChoice:
            let method = UserDefaults.standard.string(forKey: "unlockMethod") ?? "flashcards"
            Analytics.onboardingUnlockMethodSelected(method)
        case .appSelection:
            Analytics.onboardingAppsConfirmed(apps: selectedApps.map { $0.name })
        case .createFirstCards:
            Analytics.capture("onboarding_create_cards_completed")
        default:
            break
        }

        // Generic completion event so every step has duration data, not just
        // the ones with interactions above.
        var props: [String: Any] = [
            "step_name": stepName,
            "step_index": currentStepIndex
        ]
        if let durationSec = durationSec {
            props["duration_sec"] = durationSec
        }
        Analytics.capture("onboarding_step_completed", properties: props)
    }
    
    func skipToCompletion() {
        // Trigger haptic feedback
        triggerHapticFeedback()
        
        // Track skipping to completion in PostHog
        Analytics.capture("onboarding_skipped", properties: [
            "skipped_from_step": "\(currentStep)",
            "skipped_from_step_index": currentStepIndex,
            "user_name": userName.isEmpty ? "not_provided" : userName,
            "selected_age": selectedAge.isEmpty ? "not_provided" : selectedAge,
            "screen_time": screenTime.isEmpty ? "not_provided" : screenTime
        ])
        
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
            Telemetry.capture(error,
                              tags: ["feature": "onboarding", "operation": "haptic_engine_start"],
                              level: .warning)
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
            Telemetry.capture(error,
                              tags: ["feature": "onboarding", "operation": "haptic_play"],
                              level: .warning)
        }
    }
    
    private func saveUserData() {
        UserDefaults.standard.set(userName, forKey: "userName")
        UserDefaults.standard.set(selectedAge, forKey: "selectedAge")
        UserDefaults.standard.set(screenTime, forKey: "screenTime")
        UserDefaults.standard.set(true, forKey: "hasSeenPaywall")

        // Push the demographic answers as person properties so every future
        // event auto-segments by them in PostHog (no joins needed).
        var personProps: [String: Any] = [
            "selected_apps": selectedApps.map { $0.name },
            "selected_apps_count": selectedApps.count,
            "feelings": Array(selectedFeelings).sorted(),
            "obstacles": Array(selectedObstacles).sorted(),
            "unlock_method": UserDefaults.standard.string(forKey: "unlockMethod") ?? "flashcards"
        ]
        if !userName.isEmpty { personProps["name"] = userName }
        if !selectedAge.isEmpty { personProps["age_range"] = selectedAge }
        if !screenTime.isEmpty { personProps["screen_time"] = screenTime }
        Analytics.setPersonProperties(personProps)
    }
}
