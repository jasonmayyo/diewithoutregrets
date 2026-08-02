//
//  OnboardingViewModel.swift
//  diewithoutregrets
//
//  Onboarding v3 ("sg_v3") — the Semester Comeback flow:
//  Pain (hook, 11pm feeling, villain, willpower lie, mascot, 5-question
//  quiz) → Semester receipt (auto-choreographed, every number scaled to the
//  student's 15-week semester) → Offer (Hormozi-framed: mechanism, effort
//  killer, proof, named-offer paywall) → Post-purchase setup.
//
//  Every screen advances through nextStep(); quiz questions auto-advance on
//  selection. All funnel analytics carry flow_version "sg_v3".
//

import SwiftUI
import CoreHaptics
import PostHog

enum OnboardingStep: CaseIterable {
    // Phase 1 — The pain
    case hook
    case theFeeling
    case notYourFault
    case willpowerLie
    case meetYourGuard
    case quizAge
    case quizStudentType
    case quizScreenTime
    case quizScrollTimes
    case quizExamDate
    // Phase 2 — The semester receipt
    case calculating
    case semesterDrain
    case daysLost
    case theImagine
    // Phase 3 — The offer
    case science
    case coreMechanic
    case noWillpower
    case moreFeatures
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
        case .quizAge, .quizStudentType, .quizScreenTime, .quizScrollTimes,
             .quizExamDate:
            return true
        default:
            return false
        }
    }

    /// Night-sky steps: night falls during .theFeeling (11pm) and holds
    /// through the semester receipt. The dawn breaks on .theImagine (the
    /// turn) and stays daylight after.
    var isNight: Bool {
        switch self {
        case .theFeeling, .notYourFault, .willpowerLie, .meetYourGuard,
             .quizAge, .quizStudentType, .quizScreenTime, .quizScrollTimes,
             .quizExamDate,
             .calculating, .semesterDrain, .daysLost:
            return true
        default:
            return false
        }
    }

    /// Hardcoded quiz progress, OneThing-style (the bar only exists inside
    /// the quiz, so it doesn't map to the full step index).
    /// Superseded by the flow-wide chrome bar; kept so quiz call sites
    /// stay source-stable until the Phase 5 sweep.
    var quizProgress: Double {
        switch self {
        case .quizAge: return 0.08
        case .quizStudentType: return 0.14
        case .quizScreenTime: return 0.20
        case .quizScrollTimes: return 0.26
        case .quizExamDate: return 0.32
        default: return 0
        }
    }

    /// Whether the flow-wide progress chrome shows on this step. Hidden on
    /// the marketing entry (hook), the paywall (its own header), and the
    /// celebration (chrome-free, like every completion screen).
    var showsFlowChrome: Bool {
        switch self {
        case .hook, .paywall, .completion:
            return false
        default:
            return true
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
    @Published var examTiming: String = ""

    @Published var newDeckName: String = "My First Deck"

    /// Tracks when each step was first shown so we can compute time-on-step
    /// when the user advances. Keyed by step name.
    private var stepStartTimes: [String: Date] = [:]

    private var hapticEngine: CHHapticEngine?

    init() {
        prepareHaptics()
        // Fire for the initial step (didSet doesn't run during init).
        trackStepViewed()
    }

    // MARK: - Personalized math (semester scale)

    // The unit of pain a student actually lives in is the semester, not the
    // lifetime: 15 weeks, 105 days, one square per day on the grid.
    static let semesterWeeks = 15
    static let semesterDays = 105
    /// Days of the semester spent asleep (7.5h/day).
    static let sleepDays = 33
    /// Days in class + homework (~4h/day).
    static let classDays = 18
    /// Days eating, commuting, on chores.
    static let choresDays = 17
    /// What's left: days that are actually theirs.
    static let freeDays = semesterDays - sleepDays - classDays - choresDays  // 37

    /// Midpoint hours/day from the self-reported range ("6-8 hours" → 7).
    var dailyHours: Double {
        let digits = screenTime.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Double($0) }
        if screenTime.contains("+"), let low = digits.first { return low + 1 }
        if digits.count >= 2 { return (digits[0] + digits[1]) / 2 }
        return digits.first ?? 5
    }

    var phoneMinutesPerDay: Int { Int(dailyHours * 60) }

    /// Full 24-hour days of this semester spent on the phone.
    /// 3h→13 · 5h→22 · 7h→31 · 9h→37 (capped at free days).
    var phoneDays: Int {
        let raw = dailyHours * Double(Self.semesterDays) / 24.0
        return min(Int(raw.rounded()), Self.freeDays)
    }

    var phonePctOfFree: Int {
        guard Self.freeDays > 0 else { return 0 }
        return Int((Double(phoneDays) / Double(Self.freeDays) * 100).rounded())
    }

    /// The user's own frame: "imagine if just HALF went to studying."
    /// The theImagine grid heals exactly this many squares.
    var reclaimDays: Int {
        max(1, Int((Double(phoneDays) / 2).rounded()))
    }

    /// Hours of studying gained if half the phone time flips (7h → 368).
    var halfStudyHours: Int {
        Int((dailyHours / 2 * Double(Self.semesterDays)).rounded())
    }

    /// halfStudyHours expressed as finals' worth of prep (~40h per final).
    var finalsPrepEquiv: Int {
        max(1, Int((Double(halfStudyHours) / 40).rounded()))
    }

    /// Weeks until the next big exam, from the quizExamDate answer.
    /// Nil = "No exams — just deadlines" (or unanswered): use the
    /// per-week fallback copy instead of a countdown.
    var weeksToExam: Int? {
        switch examTiming {
        case "Within a month": return 4
        case "1–2 months away": return 6
        case "3+ months away": return 12
        default: return nil
        }
    }

    /// Scrolling hours between now and the exam (7h/day, 6 weeks → 294).
    var scrollHoursToExam: Int? {
        weeksToExam.map { Int((dailyHours * 7 * Double($0)).rounded()) }
    }

    /// Scrolling hours per week (7h/day → 49) — the urgency fallback.
    var scrollHoursPerWeek: Int {
        Int((dailyHours * 7).rounded())
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

    /// The flow-wide chrome bar's fill: a pure function of step index, so
    /// the bar glides forward as one continuous thread through the funnel.
    var overallProgress: Double {
        Double(currentStepIndex) / Double(max(totalSteps - 1, 1))
    }

    /// Beat-level analytics for choreographed screens (locks revealed,
    /// cascade finished, rating requested...) — OneThing's
    /// onboarding_screen_action pattern.
    func screenAction(_ action: String, properties: [String: Any] = [:]) {
        var props: [String: Any] = [
            "action": action,
            "step_name": "\(currentStep)",
            "flow_version": "sg_v3",
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

    /// Quiz answers auto-advance shortly after the tap (no continue button).
    /// The delayed advance only fires if the user is still on the step they
    /// answered (a back tap in the window must not get bounced forward).
    func selectQuizAnswer(_ assign: @escaping () -> Void) {
        assign()
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
        case .quizExamDate:
            if !examTiming.isEmpty {
                Analytics.capture("onboarding_exam_timing_selected", properties: [
                    "exam_timing": examTiming,
                    "weeks_to_exam": weeksToExam as Any,
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
            "flow_version": "sg_v3",
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
            "flow_version": "sg_v3"
        ])
        currentStep = .screenTimeExplainer
    }

    // MARK: - Haptics

    func triggerHapticFeedback() {
        SGTheme.beat()
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
        UserDefaults.standard.set(examTiming, forKey: "examTiming")
        UserDefaults.standard.set(true, forKey: "hasSeenPaywall")

        // Push the quiz answers as person properties so every future event
        // auto-segments by them in PostHog (no joins needed).
        var personProps: [String: Any] = [
            "unlock_method": UserDefaults.standard.string(forKey: "unlockMethod") ?? "flashcards",
            "onboarding_flow_version": "sg_v3",
        ]
        if !selectedAge.isEmpty { personProps["age_range"] = selectedAge }
        if !screenTime.isEmpty { personProps["screen_time"] = screenTime }
        if !studentType.isEmpty { personProps["student_type"] = studentType }
        if !peakScrollTime.isEmpty { personProps["peak_scroll_time"] = peakScrollTime }
        if !examTiming.isEmpty { personProps["exam_timing"] = examTiming }
        Analytics.setPersonProperties(personProps)
    }
}
