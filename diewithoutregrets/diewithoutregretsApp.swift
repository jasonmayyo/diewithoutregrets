import SwiftUI
import RevenueCatUI
import BranchSDK
import UIKit

@main
struct diewithoutregretsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var navigationModel = NavigationModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var regretStore = RegretStore()
    @StateObject private var deckStore = DeckStore.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
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
            .fullScreenCover(isPresented: $navigationModel.showBuyBackOffer) {
                BuyBackOfferView()
            }
            .onOpenURL { url in
                print("[App] onOpenURL: \(url)")
                _ = Branch.getInstance().application(UIApplication.shared, open: url, options: [:])
                if url.scheme == "diewithoutregrets" && url.host == "buyback" {
                    navigationModel.presentBuyBackOffer()
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
                }
                
                // When app moves to background, schedule notification if applicable
                if newPhase == .background {
                    print("[App] 📱 App moved to background")
                    
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
}
