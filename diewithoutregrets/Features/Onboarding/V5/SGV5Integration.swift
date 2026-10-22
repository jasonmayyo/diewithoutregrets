import SwiftUI
import FamilyControls
import RevenueCat
import UserNotifications

enum SGV5Theme {
    static let textPrimary = SGTheme.paper
    static let textSecondary = SGTheme.paperSecondary
    static let horizontalPadding: CGFloat = 24
    static let buttonHeight: CGFloat = 56
    static let floatingCTABackground = SGTheme.ink
}

enum SGV5Assets {
    static func name(_ source: String) -> String {
        if source == "ghost-fistpump" { return "sgv5-mascot-fistbump" }
        if source.contains("clipboard") { return "sgv5-mascot-clipboard" }
        if source.contains("science") && source != "sciencedirect" { return "sgv5-mascot-teaching" }
        if source == "priority-ghost-learning" || source == "priority-ghost-focus"
            || source == "plan-week-day-1" { return "sgv5-mascot-teaching" }
        if source == "plan-week-day-2" || source == "plan-week-day-7" { return "sgv5-mascot-clipboard" }
        if source.contains("ghost") || source.hasPrefix("plan-week-day-") || source == "post-orbit-onething" {
            return "sgv5-mascot-idle"
        }
        return "sgv5-" + source
    }
}

struct SGV5RootView: View {
    @StateObject private var model = SGV5FlowModel()
    // Retains Study Guard's purchase, restore and buyback integration.
    @StateObject private var purchaseModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()
            if SGV5PostPurchaseStyle.screenIDs.contains(model.currentPageIndex) {
                SGV5PostPurchaseBackdrop()
            }
            Group {
                if let step = SGV5V5OnboardingStep(rawValue: model.currentPageIndex) {
                    SGV5V5OnboardingView(viewModel: model, step: step)
                } else if model.currentPageIndex == 506 {
                    HardPaywallView()
                        .environmentObject(purchaseModel)
                } else {
                    SGV5SetupView(viewModel: model)
                }
            }
            .id(model.currentPageIndex)
            .transition(.opacity)
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.3), value: model.currentPageIndex)
        .onChange(of: model.currentPageIndex) { _, id in
            model.trackScreenAction(screenId: id, action: "viewed")
            if id == 506 {
                purchaseModel.currentStep = .paywall
                purchaseModel.studentType = model.v5Profile.studyLevel?.legacyValue ?? ""
                purchaseModel.hasExams = model.v5Profile.examDate != nil
                purchaseModel.examDate = model.v5Profile.examDate
                purchaseModel.selectedAge = model.v5Profile.ageBracket?.title ?? ""
                purchaseModel.screenTime = model.v5Profile.baseline?.title ?? ""
                purchaseModel.peakScrollTime = model.v5Profile.moment?.title ?? ""
            }
        }
        .onChange(of: purchaseModel.currentStep) { _, step in
            guard model.currentPageIndex == 506 else { return }
            if step == .screenTimeExplainer || step == .guardedApps {
                model.startSetupAfterPurchase()
            }
        }
        .onAppear {
            purchaseModel.currentStep = .paywall
            model.trackScreenAction(screenId: model.currentPageIndex, action: "viewed")
        }
        .alert("Verification failed", isPresented: Binding(
            get: { model.completionError != nil },
            set: { if !$0 { model.completionError = nil } }
        )) {
            Button("Retry") { Task { await model.finishSetup() } }
            Button("Not now", role: .cancel) { model.completionError = nil }
        } message: {
            Text(model.completionError ?? "")
        }
    }
}

struct SGV5WelcomeView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @State private var restoring = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            SGV5WelcomeDemoVideo()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .layoutPriority(-1)
            VStack(spacing: 12) {
                Text("Scroll Less. Study More.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(SGTheme.paper)
                    .multilineTextAlignment(.center)
                Text("Turn your study time into screen time.")
                    .font(.system(size: 18))
                    .foregroundStyle(SGTheme.paperSecondary)
            }
            .padding(.horizontal, 24)
            VStack(spacing: 12) {
                Button(restoring ? "Restoring..." : "I already have an account") { restore() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SGTheme.paperSecondary)
                    .frame(minHeight: 32)
                    .disabled(restoring)
                SGV5QuizContinueButton(text: "Get Started") { viewModel.nextPage() }
            }
            .sgV5FloatingCTA()
        }
        .alert("Restore purchases", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    private func restore() {
        guard !restoring else { return }
        SGV5Haptics.play(.tap)
        restoring = true
        Task { @MainActor in
            defer { restoring = false }
            do {
                let customer = try await Purchases.shared.restorePurchases()
                guard SGSuperwallBilling.hasActiveAccess(customer) else {
                    errorMessage = "We couldn't find an active subscription. Please continue to subscribe."
                    SGV5Haptics.play(.warning)
                    return
                }
                viewModel.startSetupAfterPurchase()
            } catch {
                errorMessage = "Could not restore purchases. Check your connection and try again."
                SGV5Haptics.play(.error)
            }
        }
    }
}

/// Kept only for a stable, retired source ID; absent from the active sequence.
struct SGV5RetiredView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    var body: some View { SGV5V4EarnScreenTimeView(viewModel: viewModel) }
}

struct SGV5SetupView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @ObservedObject private var manager = StudyGuardManager.shared
    @State private var busy = false
    @State private var showPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var previousSelection = FamilyActivitySelection()
    @State private var showLimit = false
    private var hasSelection: Bool { !SGContract.isSelectionEmpty(selection) }
    private var authorized: Bool { manager.authorizationStatus == .approved }

    var body: some View {
        Group {
            switch viewModel.currentPageIndex {
            case 601:
                SGV5PostPurchaseCard(viewModel: viewModel, screenID: 601,
                    title: "A little space\nfor your studies.",
                    subtitle: "Give your studying a head start.\nYour apps will be there when you're done.",
                    buttonTitle: "Let's set it up",
                    footnote: "A few small steps. A little more time for you.",
                    action: { viewModel.nextPage() }) {
                        SGV5PostPurchaseHabitIllustration()
                    }
            case 602:
                SGV5PostPurchaseCard(viewModel: viewModel, screenID: 602,
                    title: "Make room for\nwhat matters.",
                    subtitle: "Connect Screen Time so Study Guard can pause the apps you choose.",
                    buttonTitle: "Connect Screen Time", isBusy: busy,
                    footnote: "iOS will ask you to confirm access.",
                    action: requestAccess) {
                        VStack(spacing: 12) {
                            SGV5PostPurchasePermissionIllustration()
                            SGV5PostPurchaseFeatureRow(symbol: "hand.raised.fill", title: "You're in control",
                                detail: "Choose which apps to pause in the next step.")
                        }
                    }
            case 606:
                SGV5PostPurchaseCard(viewModel: viewModel, screenID: 606,
                    title: "Which apps\ncan wait?",
                    subtitle: "Pick the apps you'd like to earn time for. Your studying comes first.",
                    buttonTitle: hasSelection && authorized ? "Continue" : authorized ? "Choose apps" : "Connect Screen Time",
                    isBusy: busy, secondaryTitle: "Set up apps later",
                    secondaryAction: { viewModel.nextPage() }, action: selectApps) {
                        VStack(spacing: 16) {
                            SGV5PostPurchaseAppsIllustration()
                            if hasSelection {
                                Label("Your apps are selected", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline).foregroundStyle(SGTheme.mintDeep)
                                Button("Edit apps") {
                                    SGV5Haptics.play(.selection)
                                    showPicker = true
                                }
                            } else {
                                Text("Your choice. Your pace.").font(.system(size: 13))
                                    .foregroundStyle(SGTheme.paperSecondary)
                            }
                        }
                    }
            default:
                SGV5PostPurchaseCard(viewModel: viewModel, screenID: 604,
                    title: "A friendly nudge.\nA little momentum.",
                    subtitle: "A nudge to study.\nA heads-up when your apps are ready.",
                    buttonTitle: "Enable notifications", isBusy: busy || viewModel.isFinishing,
                    secondaryTitle: "Maybe later",
                    secondaryAction: { Task { await viewModel.finishSetup() } },
                    action: requestNotifications) {
                        SGV5PostPurchaseNotificationStack(compact: true)
                    }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onAppear { selection = manager.selection; previousSelection = selection }
        .onChange(of: selection) { _, newValue in
            if SGContract.tokenCount(newValue) > SGContract.maxSelectionTokens {
                selection = previousSelection
                showLimit = true
                SGV5Haptics.play(.warning)
            } else if newValue != previousSelection {
                previousSelection = newValue
                SGV5Haptics.play(.selection)
            }
        }
        .alert("That's the limit", isPresented: $showLimit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can guard up to \(SGContract.maxSelectionTokens) apps, categories, and websites. Remove one to add another.")
        }
    }

    private func requestAccess() {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            let granted = await manager.requestAuthorization()
            viewModel.trackScreenAction(screenId: 602, action: "permission_result", properties: ["granted": granted])
            busy = false
            viewModel.nextPage()
        }
    }

    private func selectApps() {
        guard !busy else { return }
        if authorized && hasSelection {
            if case .refusedTooMany = manager.updateSelection(selection) { showLimit = true; return }
            viewModel.nextPage()
        } else if authorized {
            showPicker = true
        } else {
            busy = true
            Task { @MainActor in
                let granted = await manager.requestAuthorization()
                busy = false
                if granted { showPicker = true }
            }
        }
    }

    private func requestNotifications() {
        guard !busy, !viewModel.isFinishing else { return }
        busy = true
        Task { @MainActor in
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            Analytics.onboardingNotificationPermission(granted: granted)
            busy = false
            await viewModel.finishSetup()
        }
    }
}
