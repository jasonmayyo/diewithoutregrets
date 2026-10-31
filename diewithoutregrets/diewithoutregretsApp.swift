import SwiftUI
import RevenueCatUI
import SuperwallKit
import BranchSDK
import UIKit
import UserNotifications

@main
struct diewithoutregretsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        // Tutor Monster unlock is ON by default. register(defaults:) makes BOTH
        // @AppStorage and raw UserDefaults.bool(forKey:) read true until the user
        // flips the Profile toggle; the DEBUG -sg-monster-off arg still overrides.
        UserDefaults.standard.register(defaults: ["sg_monsterUnlock": true])
        _ = PersonaStore.shared // Publish an existing selection to the shield app group.

        #if DEBUG
        SGPreviewHarness.applyLaunchArguments()
        // Device-safe enabler for the Tutor Monster unlock flow: flips the flag
        // WITHOUT seeding/freezing guard state (unlike -sg-preview-monster, which
        // is simulator-only). Add -sg-monster-on to the Run scheme to test the real
        // shield -> monster flow; remove -sg-monster-off to turn it back off.
        if ProcessInfo.processInfo.arguments.contains("-sg-monster-on") {
            UserDefaults.standard.set(true, forKey: "sg_monsterUnlock")
        }
        if ProcessInfo.processInfo.arguments.contains("-sg-monster-off") {
            UserDefaults.standard.set(false, forKey: "sg_monsterUnlock")
        }
        // Override the chosen persona for testing (the onboarding picker sets it normally). Persists.
        let monsterArgs = ProcessInfo.processInfo.arguments
        if monsterArgs.contains("-sg-monster-diva") { PersonaStore.shared.select(.diva) }
        else if monsterArgs.contains("-sg-monster-coach") { PersonaStore.shared.select(.coach) }
        else if monsterArgs.contains("-sg-monster-gremlin") { PersonaStore.shared.select(.gremlin) }
        else if monsterArgs.contains("-sg-monster-willow") { PersonaStore.shared.select(.willow) }
        #endif

        // Select chat before ContentView is constructed, so the first frame is
        // the conversation rather than the red locked-home scene.
        if Self.launchedFromFreshShieldTap {
            NavigationModel.shared.openMonsterFromShield(returnDestination: nil)
            _showSplash = State(initialValue: false)
        }
    }

    private static var launchedFromFreshShieldTap: Bool {
        ShieldChatHandoff.shouldOpenChat(in: SGContract.sharedDefaults)
    }
    @StateObject private var navigationModel = NavigationModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var regretStore = RegretStore()
    @StateObject private var deckStore = DeckStore.shared
    @Environment(\.scenePhase) private var scenePhase

    /// Cold-start splash: holds the launch-screen artwork for a beat, then
    /// crossfades straight into the app's real first frame. A crossfade
    /// can't mismatch the destination — the old corner wipe revealed a
    /// white canvas that matched neither the locked night scene nor the
    /// meadow home.
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if hasCompletedOnboarding {
                        ContentView()
                            .environmentObject(navigationModel)
                            .environmentObject(regretStore)
                            .environmentObject(deckStore)
                    } else {
                        OnboardingView()
                            .environmentObject(navigationModel)
                            .environmentObject(regretStore)
                            .environmentObject(deckStore)
                    }
                }
                #if DEBUG
                // Simulator review hook for the blocking-flow redesign:
                // presents the live quiz over a seeded locked state.
                .overlay {
                    if SGPreviewHarness.wantsQuizV2Preview {
                        QuizV2View()
                            .environmentObject(DeckStore.shared)
                            .environmentObject(RegretStore.shared)
                    }
                    if SGPreviewHarness.wantsMonsterPreview {
                        MonsterChatView(session: MonsterSession())
                    }
                }
                #endif

                if showSplash {
                    ColdStartSplashView()
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .task {
                consumeShieldTapIfFresh()
                guard showSplash else { return }
                // Hold the splash artwork for a beat, then dissolve into
                // whatever the first scene really is (onboarding, meadow
                // home, or the locked night scene).
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
            }
            .fullScreenCover(isPresented: $navigationModel.showBuyBackOffer) {
                BuyBackOfferView()
            }
            .onOpenURL { url in
                print("[App] onOpenURL: \(url)")
                // Enables Superwall's on-device preview links for phase 2.
                if Superwall.handleDeepLink(url) { return }
                _ = Branch.getInstance().application(UIApplication.shared, open: url, options: [:])

                if url.scheme == "diewithoutregrets" && url.host == "buyback" {
                    navigationModel.presentBuyBackOffer()
                }

                if url.scheme == "diewithoutregrets" && url.host == "unlock" {
                    StudyGuardManager.shared.reconcileOnForeground()
                    if StudyGuardManager.shared.state == .locked {
                        navigationModel.openMonsterFromShield(returnDestination: nil)
                    }
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                _ = Branch.getInstance().continue(userActivity)
            }
            .onReceive(NotificationCenter.default.publisher(for: .showBuyBackOffer)) { _ in
                print("[App] ⚡️ Received showBuyBackOffer notification")
                navigationModel.presentBuyBackOffer()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("[App] 🔄 Scene phase changed from \(oldPhase) to \(newPhase)")
                
                // When app becomes active, clear any badge
                if newPhase == .active {
                    // Handle the user's entry intent before reconciliation and SDK work.
                    consumeShieldTapIfFresh()
                    Task { await SGSuperwallBilling.shared.refreshSubscriptionStatus() }
                    print("[App] ✅ App became active - clearing badge")
                    NotificationManager.shared.clearBadge()

                    // Study Guard third reliability layer: reconcile state with
                    // the extension + Screen Time system on every foreground.
                    StudyGuardManager.shared.reconcileOnForeground()
                    Analytics.flushStudyGuardExtensionEvents()

                    // Keep the always-on monster mascot alive in the Dynamic
                    // Island and resume the frame rotation.
                    MonsterActivityManager.shared.ensureMonsterRunning()

                    // Tutor Monster: ensure a persona-voiced study nudge is queued
                    // (only when the monster flow is on and notifications are allowed).
                    if UserDefaults.standard.bool(forKey: "sg_monsterUnlock") {
                        MonsterNudges.ensureScheduled(persona: PersonaStore.shared.persona)
                    }
                }
                
                // When app moves to background, schedule notification if applicable
                if newPhase == .background {
                    print("[App] 📱 App moved to background")

                    // Keep cycling the monster during the short background
                    // window so the user sees it switch in the Dynamic Island
                    // right after leaving the app.
                    MonsterActivityManager.shared.continueSwitchingInBackground()

                    // Check if we should schedule the buyback notification
                    if NotificationManager.shared.didViewPaywallWithoutPurchasing() &&
                       !NotificationManager.shared.hasSeenBuybackNotification() {
                        print("[App] 🔔 Scheduling buyback notification")
                        NotificationManager.shared.scheduleBuybackNotification()
                    } else {
                        print("[App] ⏭️ Not scheduling notification - conditions not met")
                        print("  - didViewPaywall: \(NotificationManager.shared.didViewPaywallWithoutPurchasing())")
                        print("  - hasSeenNotification: \(NotificationManager.shared.hasSeenBuybackNotification())")
                    }
                }
            }
        }
    }

    /// Consume the cross-process request once. Warm launches route immediately;
    /// cold launches already selected chat before the first frame.
    private func consumeShieldTapIfFresh() {
        guard let defaults = SGContract.sharedDefaults,
              defaults.double(forKey: SGContract.Keys.shieldTapAt) > 0 else { return }
        let opensChat = ShieldChatHandoff.consume(in: defaults)
        let returnDestination = ShieldReturnContext.consumePending(in: defaults)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [SGContract.lockNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [SGContract.lockNotificationID])
        guard opensChat else { return }
        showSplash = false
        navigationModel.openMonsterFromShield(returnDestination: returnDestination)
    }
}
