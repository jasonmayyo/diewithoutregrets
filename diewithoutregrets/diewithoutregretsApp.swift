import SwiftUI
import RevenueCatUI
import BranchSDK
import UIKit
import UserNotifications

@main
struct diewithoutregretsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        #if DEBUG
        SGPreviewHarness.applyLaunchArguments()
        #endif

        // Cold-launched straight from the shield's "Study to unlock" button? The
        // user tapped to get INTO the app right now, so drop the cold-start
        // splash. The system shield already told the blocked story; the app
        // should open directly on the first flashcard.
        if Self.launchedFromFreshShieldTap {
            _showSplash = State(initialValue: false)
        }
    }

    /// True when the shield "Study to unlock" button stamped sg_shieldTapAt within
    /// the freshness window. Peeked (not consumed) here to choose the launch
    /// presentation; consumeShieldTapIfFresh consumes the stamp on foreground.
    private static var launchedFromFreshShieldTap: Bool {
        guard let d = SGContract.sharedDefaults else { return false }
        let tapAt = d.double(forKey: SGContract.Keys.shieldTapAt)
        guard tapAt > 0 else { return false }
        return Date().timeIntervalSince1970 - tapAt < 120
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
                }
                #endif

                if showSplash {
                    ColdStartSplashView()
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .task {
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
                _ = Branch.getInstance().application(UIApplication.shared, open: url, options: [:])

                if url.scheme == "diewithoutregrets" && url.host == "buyback" {
                    navigationModel.presentBuyBackOffer()
                }

                if url.scheme == "diewithoutregrets" && url.host == "unlock" {
                    StudyGuardManager.shared.reconcileOnForeground()
                    if StudyGuardManager.shared.state == .locked {
                        navigationModel.unlockMethodOverride = "flashcards"
                        navigationModel.navigate(to: .regretView)
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
                    print("[App] ✅ App became active - clearing badge")
                    NotificationManager.shared.clearBadge()

                    // Study Guard third reliability layer: reconcile state with
                    // the extension + Screen Time system on every foreground.
                    StudyGuardManager.shared.reconcileOnForeground()
                    consumeShieldTapIfFresh()
                    Analytics.flushStudyGuardExtensionEvents()

                    // Keep the always-on monster mascot alive in the Dynamic
                    // Island and resume the frame rotation.
                    MonsterActivityManager.shared.ensureMonsterRunning()
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

    /// The shield action extension stamps sg_shieldTapAt when the user taps
    /// "Study to unlock" on the shield. If the app foregrounds shortly after
    /// (direct open via openParentalControlsApp on iOS 26.5+, a notification
    /// tap, or the user opening the app by hand), go straight to the first
    /// flashcard. The system shield already supplied the blocked beat. The
    /// stamp is consumed on first read.
    private func consumeShieldTapIfFresh() {
        guard let defaults = SGContract.sharedDefaults else { return }
        let tapAt = defaults.double(forKey: SGContract.Keys.shieldTapAt)
        guard tapAt > 0 else { return }
        defaults.removeObject(forKey: SGContract.Keys.shieldTapAt)
        let returnDestination = ShieldReturnContext.consumePending(in: defaults)

        // We're open now, so the shield tap's safety-net notification is
        // redundant — cancel it whether it's still pending (the delayed net
        // armed behind a direct open) or already delivered. Doing this the
        // moment we foreground is what keeps a successful direct open from ever
        // showing a notification.
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [SGContract.lockNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [SGContract.lockNotificationID])

        guard Date().timeIntervalSince1970 - tapAt < 120,
              StudyGuardManager.shared.state == .locked else { return }
        navigationModel.unlockReturnDestination = returnDestination
        navigationModel.unlockMethodOverride = "flashcards"
        navigationModel.navigate(to: .regretView)
    }
}
