//
//  OnboardingViewModel.swift
//  diewithoutregrets
//
//  Onboarding v2 ("sg_v2") — mirrors the OneThing V4 emotional arc:
//  Discovery (hook, villain, hope, mascot, 4-question quiz) → Reality check
//  (auto-choreographed, personalized from quiz answers) → Convert (science,
//  mechanics, social proof, hard paywall) → Post-purchase setup.
//
//  Every screen advances through nextStep(); quiz questions auto-advance on
//  selection. All funnel analytics carry flow_version "sg_v2".
//

import SwiftUI
import CoreHaptics
import PostHog

enum OnboardingStep: CaseIterable {
    // Phase 1 — Discovery
    case hook
    case notYourFault
    case fightingBack
    case meetYourGuard
    case quizAge
    case quizStudentType
    case quizScreenTime
    case quizScrollTimes
    // Phase 2 — Reality check
    case calculating
    case lifeDrain
    case studyVsScroll
    case hoursLost
    case reclaim
    case afterChart
    // Phase 3 — Convert
    case science
    case coreMechanic
    case moreFeatures
    case founderStory
    case reviews
    case paywall
    // Phase 4 — Post-purchase setup
    case screenTimeExplainer
    case screenTimePermission
    case guardedApps
    case usageInterval
    case notificationPrimer
    case unlockMethod
    case createFirstCards
    case completion

    /// Quiz steps share the floating clipboard mascot + progress capsule.
    var isQuizStep: Bool {
        switch self {
        case .quizAge, .quizStudentType, .quizScreenTime, .quizScrollTimes:
            return true
        default:
            return false
        }
    }

    /// Night-sky steps: the villain arc through the reality check. The dawn
    /// breaks on .reclaim (the turn) and stays daylight after.
    var isNight: Bool {
        switch self {
        case .notYourFault, .fightingBack, .meetYourGuard,
             .quizAge, .quizStudentType, .quizScreenTime, .quizScrollTimes,
             .calculating, .lifeDrain, .studyVsScroll, .hoursLost:
            return true
        default:
            return false
        }
    }

    /// Hardcoded quiz progress, OneThing-style (the bar only exists inside
    /// the quiz, so it doesn't map to the full 28-step index).
    var quizProgress: Double {
        switch self {
        case .quizAge: return 0.10
        case .quizStudentType: return 0.16
        case .quizScreenTime: return 0.24
        case .quizScrollTimes: return 0.30
        default: return 0
        }
    }
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .hook {
        didSet {
            // Fire `onboarding_step_viewed` whenever the step changes so we
            // can build the full funnel in PostHog from a single event.
            trackStepViewed()
        }
    }

    // Quiz answers — every one is a personalization input.
    @Published var selectedAge: String = ""
    @Published var studentType: String = ""
    @Published var screenTime: String = ""
    @Published var peakScrollTime: String = ""

    @Published var newDeckName: String = "My First Deck"

    /// Bumped on every quiz answer so the floating clipboard mascot replays
    /// its "taking a note" animation.
    @Published var quizNoteKey: Int = 0

    /// Tracks when each step was first shown so we can compute time-on-step
    /// when the user advances. Keyed by step name.
    private var stepStartTimes: [String: Date] = [:]

    private var hapticEngine: CHHapticEngine?

    init() {
        prepareHaptics()
        // Fire for the initial step (didSet doesn't run during init).
        trackStepViewed()
    }

    // MARK: - Personalized math (OneThing formula)

    /// Life expectancy for the dots grid: 80 squares, one per year.
    static let lifeYears = 80
    /// Years of "actual free time" after sleep/work/commute/eating/chores.
    static let freeYears = 20
    /// Fraction of phone time assumed to eat pure free time.
    static let freeTimeFraction = 0.6

    /// Midpoint hours/day from the self-reported range ("6-8 hours" → 7).
    var dailyHours: Double {
        let digits = screenTime.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Double($0) }
        if screenTime.contains("+"), let low = digits.first { return low + 1 }
        if digits.count >= 2 { return (digits[0] + digits[1]) / 2 }
        return digits.first ?? 5
    }

    var phoneMinutesPerDay: Int { Int(dailyHours * 60) }

    /// Years of free time the phone will eat over a lifetime.
    var phoneYears: Int {
        let raw = dailyHours / 24.0 * Double(Self.lifeYears) * Self.freeTimeFraction
        return min(Int(raw.rounded()), Self.freeYears)
    }

    var phonePercentOfFree: Int {
        guard Self.freeYears > 0 else { return 0 }
        return Int((Double(phoneYears) / Double(Self.freeYears) * 100).rounded())
    }

    /// The product promise: win back 80% of what the phone takes.
    var reclaimYears: Int {
        max(1, Int((Double(phoneYears) * 0.8).rounded()))
    }

    // MARK: - Funnel analytics

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
    func timeOnStep(_ step: OnboardingStep) -> Double? {
        let key = "\(step)"
        guard let start = stepStartTimes[key] else { return nil }
        return Date().timeIntervalSince(start)
    }

    var totalSteps: Int { OnboardingStep.allCases.count }

    var currentStepIndex: Int {
        OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0
    }

    /// Beat-level analytics for choreographed screens (locks revealed,
    /// cascade finished, rating requested...) — OneThing's
    /// onboarding_screen_action pattern.
    func screenAction(_ action: String, properties: [String: Any] = [:]) {
        var props: [String: Any] = [
            "action": action,
            "step_name": "\(currentStep)",
            "flow_version": "sg_v2",
        ]
        props.merge(properties) { current, _ in current }
        Analytics.capture("onboarding_screen_action", properties: props)
    }

    // MARK: - Advancement

    /// Reentrancy guard: CTAs stay hit-testable through the 0.3s crossfade,
    /// so a double-tap (or a timer racing a tap) must not advance two steps.
    private var lastAdvanceAt = Date.distantPast

    func nextStep() {
        guard Date().timeIntervalSince(lastAdvanceAt) > 0.45 else { return }
        lastAdvanceAt = Date()

        triggerHapticFeedback()

        // Emit a step-specific completion event with the data we just
        // captured, then the generic duration event.
        trackStepCompleted()

        // Persist quiz answers + person properties the moment the unlock
        // method is chosen (last configuration step before first cards).
        if currentStep == .unlockMethod {
            saveUserData()
        }

        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: currentStep), index + 1 < all.count else { return }
        currentStep = all[index + 1]
    }

    /// Quiz answers auto-advance shortly after the tap (no continue button),
    /// with the clipboard mascot visibly taking a note. The delayed advance
    /// only fires if the user is still on the step they answered (a back
    /// tap in the window must not get bounced forward).
    func selectQuizAnswer(_ assign: @escaping () -> Void) {
        assign()
        quizNoteKey += 1
        SGTheme.tapHaptic()
        let stepAtSelection = currentStep
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.currentStep == stepAtSelection else { return }
            self.nextStep()
        }
    }

    /// Back navigation, quiz-only, and only WITHIN the quiz: question 1 has
    /// no back (stepping into meetYourGuard would replay its whole reveal).
    func backStep() {
        guard currentStep.isQuizStep else { return }
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: currentStep), index > 0,
              all[index - 1].isQuizStep else { return }
        currentStep = all[index - 1]
    }

    /// Whether backStep() has anywhere to go from the current step.
    var canGoBack: Bool {
        guard currentStep.isQuizStep else { return false }
        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: currentStep), index > 0 else { return false }
        return all[index - 1].isQuizStep
    }

    private func trackStepCompleted() {
        let stepName = "\(currentStep)"
        let durationSec = timeOnStep(currentStep)

        switch currentStep {
        case .quizAge:
            if !selectedAge.isEmpty {
                Analytics.onboardingAgeSelected(selectedAge)
            }
        case .quizStudentType:
            if !studentType.isEmpty {
                Analytics.capture("onboarding_student_type_selected", properties: [
                    "student_type": studentType
                ])
            }
        case .quizScreenTime:
            if !screenTime.isEmpty {
                Analytics.onboardingScreenTimeSelected(screenTime)
            }
        case .quizScrollTimes:
            if !peakScrollTime.isEmpty {
                Analytics.capture("onboarding_scroll_times_selected", properties: [
                    "peak_scroll_time": peakScrollTime
                ])
            }
        case .unlockMethod:
            let method = UserDefaults.standard.string(forKey: "unlockMethod") ?? "flashcards"
            Analytics.onboardingUnlockMethodSelected(method)
        // .screenTimePermission, .guardedApps and .usageInterval fire their
        // own richer events from their views (screen_time_auth_result,
        // guarded_apps_selected, screen_time_setup_completed), and
        // .createFirstCards fires onboarding_create_cards_completed/_skipped
        // itself so skippers don't get counted as completers.
        default:
            break
        }

        var props: [String: Any] = [
            "step_name": stepName,
            "step_index": currentStepIndex,
            "flow_version": "sg_v2",
        ]
        if let durationSec = durationSec {
            props["duration_sec"] = durationSec
        }
        Analytics.capture("onboarding_step_completed", properties: props)
    }

    /// Restore path on the hook: an existing subscriber skips the funnel and
    /// lands straight in setup (Screen Time has to be configured per device).
    func skipToSetupAfterRestore() {
        Analytics.capture("onboarding_restored_subscriber", properties: [
            "flow_version": "sg_v2"
        ])
        currentStep = .screenTimeExplainer
    }

    // MARK: - Haptics

    func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        playHapticFeedback()
    }

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

    // MARK: - Persistence

    private func saveUserData() {
        UserDefaults.standard.set(selectedAge, forKey: "selectedAge")
        UserDefaults.standard.set(screenTime, forKey: "screenTime")
        UserDefaults.standard.set(studentType, forKey: "studentType")
        UserDefaults.standard.set(peakScrollTime, forKey: "peakScrollTime")
        UserDefaults.standard.set(true, forKey: "hasSeenPaywall")

        // Push the quiz answers as person properties so every future event
        // auto-segments by them in PostHog (no joins needed).
        var personProps: [String: Any] = [
            "unlock_method": UserDefaults.standard.string(forKey: "unlockMethod") ?? "flashcards",
            "onboarding_flow_version": "sg_v2",
        ]
        if !selectedAge.isEmpty { personProps["age_range"] = selectedAge }
        if !screenTime.isEmpty { personProps["screen_time"] = screenTime }
        if !studentType.isEmpty { personProps["student_type"] = studentType }
        if !peakScrollTime.isEmpty { personProps["peak_scroll_time"] = peakScrollTime }
        Analytics.setPersonProperties(personProps)
    }
}
