import SwiftUI
import FamilyControls
import RevenueCat

/// The OneThing V5 sequence, with Study Guard persistence and purchase/setup boundaries.
@MainActor
final class SGV5FlowModel: ObservableObject {
    static let profileKey = "studyguard.onboarding.v5.profile"
    @Published var currentPageIndex = 800
    @Published var v5Profile: SGV5V5OnboardingProfile {
        didSet { persist() }
    }
    @Published var completionError: String?
    @Published var isFinishing = false
    let activeFlowOrder = SGV5V5OnboardingStep.flowOrder
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private var lastAdvance = Date.distantPast

    struct LegacyPresentationData {
        var occupation = ""
        var dailyScreenTimeHours = 0
        var realAverageScreenTimeMinutes: Int?
        var selectedOneThing = ""
    }
    var userData: LegacyPresentationData {
        LegacyPresentationData(dailyScreenTimeHours: v5Profile.estimatedDailyHours,
                               selectedOneThing: v5Profile.habit?.title ?? "")
    }

    init(defaults: UserDefaults = .standard, sharedDefaults: UserDefaults? = SGContract.sharedDefaults) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        if let data = defaults.data(forKey: Self.profileKey),
           var saved = try? JSONDecoder().decode(SGV5V5OnboardingProfile.self, from: data) {
            saved.clearRetiredPriority()
            v5Profile = saved
        } else {
            v5Profile = SGV5V5OnboardingProfile()
        }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let argument = arguments.first(where: { $0.hasPrefix("-sg-v5-") }),
           let id = Int(argument.dropFirst("-sg-v5-".count)), activeFlowOrder.contains(id) {
            v5Profile.studyLevel = .university
            v5Profile.subject = "Biology"
            let daysArgument = arguments.firstIndex(of: "-sg-v5-exam-days")
            let demoDays = daysArgument.flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil } ?? 30
            v5Profile.examDate = Calendar.current.date(byAdding: .day, value: max(0, min(3650, demoDays)), to: Date())
            v5Profile.goal = .focus
            v5Profile.pain = .time
            v5Profile.moment = .bedtime
            v5Profile.habit = .reading
            v5Profile.baseline = .twoToFour
            v5Profile.ageBracket = .age25to34
            let cardsArgument = arguments.firstIndex(of: "-sg-v5-rule-cards")
            let demoCards = cardsArgument.flatMap { arguments.indices.contains($0 + 1) ? Int(arguments[$0 + 1]) : nil } ?? 10
            v5Profile.studyRule = SGV5V5OnboardingProfile.StudyRule(rawValue: demoCards) ?? .ten
            currentPageIndex = id
        }
        #endif
    }

    var v5ExampleRewardMinutes: Int {
        SGContract.earnedMinutes(cardCount: v5Profile.studyCardCount, perCardSeconds: v5Profile.studyPerCardSeconds)
    }

    /// Commit the displayed default too, so an untouched slider still installs
    /// the same rule shown by the commitment and plan.
    func confirmStudyRule() {
        guard currentPageIndex == SGV5V5OnboardingStep.timeBack.rawValue else { return }
        v5Profile.studyRule = v5Profile.selectedStudyRule
        advanceV5()
    }

    func advanceV5() {
        guard let step = SGV5V5OnboardingStep(rawValue: currentPageIndex),
              v5Profile.canContinue(from: step) else { return }
        nextPage()
    }

    func nextPage() {
        guard Date().timeIntervalSince(lastAdvance) > 0.45 else { return }
        if let step = SGV5V5OnboardingStep(rawValue: currentPageIndex),
           !v5Profile.canContinue(from: step) { return }
        // The paywall can only be left by a verified purchase/restore callback.
        guard currentPageIndex != 506,
              let index = activeFlowOrder.firstIndex(of: currentPageIndex),
              index + 1 < activeFlowOrder.count else { return }
        lastAdvance = Date()
        syncV5Profile()
        trackScreenAction(screenId: currentPageIndex, action: "completed")
        currentPageIndex = activeFlowOrder[index + 1]
        SGTheme.beat()
    }

    func previousPage() {
        guard let index = activeFlowOrder.firstIndex(of: currentPageIndex), index > 0 else { return }
        // A purchased user stays inside setup when using its back control.
        guard currentPageIndex != 601 else { return }
        currentPageIndex = activeFlowOrder[index - 1]
        lastAdvance = .distantPast
    }

    func startSetupAfterPurchase() {
        syncV5Profile()
        currentPageIndex = 601
        lastAdvance = .distantPast
    }

    func syncV5Profile() {
        persist()
        if let level = v5Profile.studyLevel { defaults.set(level.legacyValue, forKey: "studentType") }
        defaults.set(v5Profile.studySubject, forKey: "studySubject")
        if let examDate = v5Profile.examDate {
            defaults.set(examDate.timeIntervalSince1970, forKey: "examDate")
            defaults.set(true, forKey: "hasExams")
            sharedDefaults?.set(examDate.timeIntervalSince1970, forKey: SGContract.Keys.onboardingExamDate)
        }
        if let rule = v5Profile.studyRule {
            sharedDefaults?.set(rule.secondsPerCard, forKey: SGContract.Keys.perCardSeconds)
            // Both unlock-quiz routes read these existing preferences. Small
            // decks still use all available cards and earn for correct answers.
            defaults.set(rule.rawValue, forKey: "flashcardCount")
            defaults.set(false, forKey: "useAllCards")
        }
        if let age = v5Profile.ageBracket { defaults.set(age.title, forKey: "selectedAge") }
        if let baseline = v5Profile.baseline { defaults.set(baseline.title, forKey: "screenTime") }
        if let moment = v5Profile.moment { defaults.set(moment.title, forKey: "peakScrollTime") }
    }

    func generateRecoveryPlan() { syncV5Profile() }

    func trackUserInput(screenId: Int, inputType: String, value: String) {
        trackScreenAction(screenId: screenId, action: "answer_selected",
                          properties: ["input_type": inputType, "value": value])
    }

    func trackScreenAction(screenId: Int, action: String, properties: [String: Any] = [:]) {
        var event = properties
        event["screen_id"] = screenId
        event["action"] = action
        event["flow_version"] = "sg_v5"
        Analytics.capture("onboarding_screen_action", properties: event)
    }

    /// Setup uses the selected flashcard rate and the existing guard services.
    func finishSetup() async {
        guard !isFinishing else { return }
        isFinishing = true
        defer { isFinishing = false }
        do {
            let customer = try await Purchases.shared.customerInfo()
            guard SGSuperwallBilling.hasActiveAccess(customer) else {
                currentPageIndex = 506
                return
            }
            syncV5Profile()
            let result = StudyGuardManager.shared.completeSetup()
            switch result {
            case .success:
                trackScreenAction(screenId: 604, action: "guard_setup_completed")
            case .failure(let reason):
                // The existing Guard checklist repairs denied access, no selection
                // or a failed monitor. Never mark shielding successful on failure.
                trackScreenAction(screenId: 604, action: "guard_setup_deferred",
                                  properties: ["reason": String(describing: reason)])
            }
            Analytics.capture("onboarding_completed", properties: [
                "flow_version": "sg_v5",
                "study_level": v5Profile.studyLevel?.rawValue ?? "",
                "days_to_exam": v5Profile.examDays,
                "age_range": v5Profile.ageBracket?.title ?? "",
                "flashcards_per_five_minutes": v5Profile.studyCardCount,
                "per_card_seconds": v5Profile.studyPerCardSeconds
            ])
            AdsTracker.trackCompleteRegistration()
            defaults.set(true, forKey: "hasCompletedOnboarding")
            SGTheme.successHaptic()
        } catch {
            completionError = "Couldn't verify your subscription. Check your connection and try again."
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(v5Profile) else { return }
        defaults.set(data, forKey: Self.profileKey)
    }
}
