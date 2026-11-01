#if DEBUG && targetEnvironment(simulator)
import SwiftUI

/// Read-only native UI fixtures for the local onboarding screenshot walkthrough.
/// This never verifies access, purchases, selects guarded apps, or awards time.
struct BuddyOnboardingCaptureView: View {
    static var requestedPhase: BuddyOnboardingPhase? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-sg-buddy-capture"),
              arguments.indices.contains(index + 1) else { return nil }
        return BuddyOnboardingPhase.allCases.first { String(describing: $0) == arguments[index + 1] }
    }

    @StateObject private var model: SGV5FlowModel

    static func makeModel() -> SGV5FlowModel {
        let suite = "com.studyguard.onboarding-screenshot-preview"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        model.saveBuddyIdentity(.init(name: "Alex", pronouns: "Just my name"))
        model.v5Profile.gender = .nonBinary
        model.v5Profile.studyLevel = .university
        model.v5Profile.subject = "Cell Biology"
        model.v5Profile.noExamYet = true
        model.v5Profile.ageBracket = .age18to24
        model.v5Profile.studyRule = .five
        model.v5Profile.baseline = .twoToFour
        return model
    }

    init(phase: BuddyOnboardingPhase) {
        let model = Self.makeModel()
        // Render only the chat view. Never enter the verified post-purchase route.
        model.currentPageIndex = 823
        model.buddy.phase = phase
        model.buddy.personaID = model.buddyPersona.id
        model.buddy.practiceCard = SGV5FlowModel.buddySampleCards.first
        model.buddy.practicePassed = phase.rawValue >= BuddyOnboardingPhase.practiceReview.rawValue
        // The target question is genuinely unanswered; earlier normal screens
        // retain their sample answers so the real resume logic can run.
        switch phase {
        case .name: model.saveBuddyIdentity(.init())
        case .pronouns: model.v5Profile.gender = nil
        case .level: model.v5Profile.studyLevel = nil
        case .subject: model.v5Profile.subject = nil
        case .exam: model.v5Profile.noExamYet = nil
        case .age: model.v5Profile.ageBracket = nil
        default: break
        }

        func prompt(_ phase: BuddyOnboardingPhase) {
            model.buddySay(BuddyOnboardingCopy.prompt(phase, name: model.buddyName,
                subject: model.v5Profile.subjectLabel, persona: model.buddyPersona,
                card: model.buddy.practiceCard))
        }
        func reply(_ text: String) { model.buddySay(text, isUser: true) }

        switch phase {
        case .name:
            model.buddySay(BuddyOnboardingCopy.greeting(model.buddyPersona), reaction: .awkwardWave)
        case .pronouns:
            reply("Alex")
            model.buddySay(BuddyOnboardingCopy.welcome(name: "Alex", persona: model.buddyPersona))
        case .level:
            reply("Alex")
            model.buddySay(BuddyOnboardingCopy.welcome(name: "Alex", persona: model.buddyPersona))
        case .subject:
            // Retired question, retained for old drafts: notes now supply the subject.
            prompt(.level); reply(SGV5V5OnboardingProfile.StudyLevel.university.title)
        case .materials:
            // Notes come right after study level in the current flow.
            prompt(.level); reply(SGV5V5OnboardingProfile.StudyLevel.university.title)
        case .exam, .age:
            // The exam date is asked after the notes upload, which supplies the subject.
            prompt(.materials); reply("Here are my notes")
            model.buddySay("Your \(model.v5Profile.subjectLabel) cards are ready. One quick thing before we practice.")
        case .practice:
            prompt(.materials); reply("Here are my notes")
            model.buddySay("Your \(model.v5Profile.subjectLabel) cards are ready. One quick thing before we practice.")
            prompt(.exam); reply("No date yet")
            model.buddySay("Let’s try one card together. This is just practice, so no app time is earned yet.")
        case .practiceReview:
            prompt(.practice)
            model.buddy.phase = .practice
            model.buddySubmitText(model.buddy.practiceCard!.correctAnswer)
        case .rule:
            prompt(.practiceReview)
        case .offer:
            prompt(.practiceReview)
        case .permission, .apps, .firstRound, .notifications:
            // These are presentation fixtures only, with all interactions disabled.
            break
        }
        if phase != .practiceReview { prompt(phase) }
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        BuddyOnboardingChatView(viewModel: model)
            .allowsHitTesting(false)
            .preferredColorScheme(.light)
    }
}

/// Uses the same isolated preferences for the introductory screens and paywall.
struct BuddyOnboardingScreenCaptureView: View {
    static var requestedScreen: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-sg-onboarding-screen-capture"),
              args.indices.contains(index + 1), let screen = Int(args[index + 1]),
              SGV5V5OnboardingStep.prePaywallSteps.map(\.rawValue).contains(screen) || screen == 506
        else { return nil }
        return screen
    }

    @StateObject private var model: SGV5FlowModel
    @StateObject private var purchaseModel = OnboardingViewModel()

    init(screen: Int) {
        let model = BuddyOnboardingCaptureView.makeModel()
        model.currentPageIndex = screen
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()
            if let step = SGV5V5OnboardingStep(rawValue: model.currentPageIndex) {
                SGV5V5OnboardingView(viewModel: model, step: step)
            } else {
                HardPaywallView().environmentObject(purchaseModel)
            }
        }
        .allowsHitTesting(false)
        .preferredColorScheme(.light)
    }
}
#endif
