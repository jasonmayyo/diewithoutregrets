//
//  OnboardingViewModel.swift
//  diewithoutregrets
//
//  Onboarding v4 ("sg_v4") — the Ace the Semester flow (Rocapine
//  problem-first): Pain (hook, 11pm feeling, willpower lie, quiz with a
//  mid-quiz testimonial and the reality-check Screen Time ask) → Diagnosis
//  (exam verdict scaled to THEIR exam date, the imagine turn) → Solution
//  shown, not told (live flashcard demo, social proof) → Commitment (the
//  unlock rule) → Personalized plan reveal → paywall → post-purchase setup.
//
//  Every screen advances through nextStep(); quiz questions auto-advance on
//  selection. All funnel analytics carry flow_version "sg_v4".
//

import SwiftUI
import CoreHaptics
import FamilyControls
import PostHog

enum OnboardingStep: CaseIterable {
    // Phase 1 — The pain
    case hook
    case theFeeling
    case willpowerLie
    case meetYourGuard
    case quizName
    case quizAge
    case quizStudentType
    case quizScreenTime
    case quizScrollTimes
    case quizSymptoms
    case quizTestimonial
    case quizExamDate
    case quizPreparedness
    case realityCheck
    // Phase 2 — The diagnosis
    case calculating
    case examVerdict
    case theImagine
    // Phase 3 — The solution, shown
    case tryIt
    case reviews
    // Phase 4 — Commitment + plan
    case commitment
    case planBuilding
    case planReveal
    case paywall
    // Phase 5 — Post-purchase setup
    case screenTimeExplainer
    case screenTimePermission
    case guardedApps
    case usageInterval
    case notificationPrimer
    case createFirstCards
    case completion

    /// Quiz steps share the floating clipboard mascot + progress capsule.
    /// The testimonial and reality check are mid-quiz moments, not
    /// questions — no interviewer, no back nav.
    var isQuizStep: Bool {
        switch self {
        case .quizName, .quizAge, .quizStudentType, .quizScreenTime,
             .quizScrollTimes, .quizSymptoms, .quizExamDate, .quizPreparedness:
            return true
        default:
            return false
        }
    }

    /// Night-sky steps: night falls during .theFeeling (11pm) and holds
    /// through the diagnosis. The dawn breaks on .theImagine (the turn)
    /// and stays daylight after.
    var isNight: Bool {
        switch self {
        case .theFeeling, .willpowerLie, .meetYourGuard,
             .quizName, .quizAge, .quizStudentType, .quizScreenTime,
             .quizScrollTimes, .quizSymptoms, .quizTestimonial,
             .quizExamDate, .quizPreparedness, .realityCheck,
             .calculating, .examVerdict:
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
        case .quizName: return 0.06
        case .quizAge: return 0.12
        case .quizStudentType: return 0.18
        case .quizScreenTime: return 0.24
        case .quizScrollTimes: return 0.30
        case .quizSymptoms: return 0.36
        case .quizExamDate: return 0.42
        case .quizPreparedness: return 0.48
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
    @Published var firstName: String = ""
    @Published var selectedAge: String = ""
    @Published var studentType: String = ""
    @Published var screenTime: String = ""
    @Published var peakScrollTime: String = ""
    @Published var symptoms: Set<String> = []
    /// Exact exam date. Nil = "No exams, just deadlines" (or unanswered):
    /// the diagnosis falls back to an 8-week "deadline season".
    @Published var examDate: Date?
    @Published var hasExams = true
    @Published var preparedness: String = ""
    /// The unlock rule chosen on the commitment screen (cards per unlock).
    @Published var commitCardCount: Int = 10
    /// Whether the reality-check screen got Screen Time authorization —
    /// the verdict shows the real-usage report row only when true.
    @Published var authorizedInQuiz = false

    @Published var newDeckName: String = "My First Deck"

    /// Tracks when each step was first shown so we can compute time-on-step
    /// when the user advances. Keyed by step name.
    private var stepStartTimes: [String: Date] = [:]

    private var hapticEngine: CHHapticEngine?

    init() {
        prepareHaptics()
        // Fire for the initial step (didSet doesn't run during init).
        trackStepViewed()
        #if DEBUG
        applyPreviewStepArgIfRequested()
        #endif
    }

    #if DEBUG
    /// Screenshot harness: `-sg-onb-<step>` (e.g. -sg-onb-examVerdict,
    /// -sg-onb-planReveal) jumps straight to that step with the quiz
    /// answers seeded, so every personalized screen renders with real
    /// numbers. Same idiom as the -sg-preview-quizv2 drivers.
    private func applyPreviewStepArgIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let arg = args.first(where: { $0.hasPrefix("-sg-onb-") }) else { return }

        firstName = "Jason"
        selectedAge = "18–22"
        studentType = "College"
        screenTime = "6–8 hours"
        peakScrollTime = "Late at night"
        symptoms = ["I cram at 2am the night before", "I can't focus for 10 minutes"]
        examDate = Calendar.current.date(byAdding: .day, value: 47, to: Date())
        hasExams = true
        preparedness = "A bit behind"

        let name = String(arg.dropFirst("-sg-onb-".count))
        if let step = OnboardingStep.allCases.first(where: { "\($0)" == name }) {
            currentStep = step
        }
    }
    #endif

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

    /// Calendar days until the picked exam date (min 1). Nil when the user
    /// has no exam date ("just deadlines" or unanswered).
    var daysToExam: Int? {
        guard hasExams, let examDate else { return nil }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: examDate)
        ).day ?? 0
        return max(1, days)
    }

    /// The diagnosis window: their real countdown, or an 8-week "deadline
    /// season" for the no-exams path.
    var effectiveDaysToExam: Int { daysToExam ?? 56 }

    /// Weeks until the next big exam — powers the paywall's honest-urgency
    /// countdown. Nil = no exam date: use the per-week fallback copy.
    var weeksToExam: Int? {
        daysToExam.map { max(1, Int((Double($0) / 7).rounded())) }
    }

    // Exam-scale receipt (the verdict + imagine screens): same math as the
    // semester numbers, but over THEIR countdown window.

    /// Full 24-hour days of the countdown spent on the phone.
    var phoneDaysToExam: Int {
        let raw = dailyHours * Double(effectiveDaysToExam) / 24.0
        return min(max(1, Int(raw.rounded())), effectiveDaysToExam)
    }

    var phonePctOfCountdown: Int {
        Int((Double(phoneDaysToExam) / Double(effectiveDaysToExam) * 100).rounded())
    }

    /// "Imagine if just half went to studying" — over the countdown.
    var reclaimDaysToExam: Int {
        max(1, Int((Double(phoneDaysToExam) / 2).rounded()))
    }

    /// Study hours gained before the exam if half the phone time flips.
    var studyHoursToExam: Int {
        Int((dailyHours / 2 * Double(effectiveDaysToExam)).rounded())
    }

    /// The exam date the way screens speak it ("Nov 4").
    var examDateLabel: String? {
        guard hasExams, let examDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: examDate)
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
            "flow_version": "sg_v4",
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

        // Persist quiz answers + person properties at the plan reveal —
        // the last screen before the paywall, when every answer is final.
        if currentStep == .planReveal {
            saveUserData()
        }

        let all = OnboardingStep.allCases
        guard let index = all.firstIndex(of: currentStep), index + 1 < all.count else { return }
        var next = all[index + 1]

        // Screen Time was usually authorized at the reality check; when it
        // was, the post-purchase explainer + permission pair is redundant.
        if next == .screenTimeExplainer,
           AuthorizationCenter.shared.authorizationStatus == .approved {
            next = .guardedApps
        }
        currentStep = next
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
        case .quizName:
            Analytics.capture("onboarding_name_entered", properties: [
                "provided": !firstName.isEmpty
            ])
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
        case .quizSymptoms:
            if !symptoms.isEmpty {
                Analytics.capture("onboarding_symptoms_selected", properties: [
                    "symptoms": symptoms.sorted().joined(separator: ", "),
                    "symptom_count": symptoms.count,
                ])
            }
        case .quizExamDate:
            Analytics.capture("onboarding_exam_date_selected", properties: [
                "has_exams": hasExams,
                "days_to_exam": daysToExam as Any,
                "weeks_to_exam": weeksToExam as Any,
            ])
        case .quizPreparedness:
            if !preparedness.isEmpty {
                Analytics.capture("onboarding_preparedness_selected", properties: [
                    "preparedness": preparedness
                ])
            }
        case .commitment:
            Analytics.capture("onboarding_commitment_selected", properties: [
                "card_count": commitCardCount,
            ])
        // .realityCheck fires screen_time_auth_result itself;
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
            "flow_version": "sg_v4",
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
            "flow_version": "sg_v4"
        ])
        currentStep = AuthorizationCenter.shared.authorizationStatus == .approved
            ? .guardedApps
            : .screenTimeExplainer
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
        UserDefaults.standard.set(firstName, forKey: "firstName")
        UserDefaults.standard.set(selectedAge, forKey: "selectedAge")
        UserDefaults.standard.set(screenTime, forKey: "screenTime")
        UserDefaults.standard.set(studentType, forKey: "studentType")
        UserDefaults.standard.set(peakScrollTime, forKey: "peakScrollTime")
        UserDefaults.standard.set(Array(symptoms), forKey: "symptoms")
        UserDefaults.standard.set(preparedness, forKey: "preparedness")
        if let examDate {
            UserDefaults.standard.set(examDate.timeIntervalSince1970, forKey: "examDate")
        }
        UserDefaults.standard.set(true, forKey: "hasSeenPaywall")

        // Push the quiz answers as person properties so every future event
        // auto-segments by them in PostHog (no joins needed).
        var personProps: [String: Any] = [
            "onboarding_flow_version": "sg_v4",
            "flashcard_count": commitCardCount,
        ]
        if !firstName.isEmpty { personProps["first_name"] = firstName }
        if !selectedAge.isEmpty { personProps["age_range"] = selectedAge }
        if !screenTime.isEmpty { personProps["screen_time"] = screenTime }
        if !studentType.isEmpty { personProps["student_type"] = studentType }
        if !peakScrollTime.isEmpty { personProps["peak_scroll_time"] = peakScrollTime }
        if !preparedness.isEmpty { personProps["preparedness"] = preparedness }
        if let daysToExam { personProps["days_to_exam"] = daysToExam }
        Analytics.setPersonProperties(personProps)
    }
}
