import SwiftUI
import RevenueCatUI
import BranchSDK

@main
struct diewithoutregretsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var navigationModel = NavigationModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var regretStore = RegretStore()
    @StateObject private var deckStore = DeckStore.shared
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(navigationModel)
                    .environmentObject(regretStore)
                    .environmentObject(deckStore)
                    .onContinueUserActivity("NSUserActivityTypeBrowsingWeb") { userActivity in
                        // Handle Universal Links - Using standard method
                        Branch.getInstance().continue(userActivity)
                    }
                    .onOpenURL { url in
                        // Handle URL schemes - Using app method since handleDeepLink might not exist
                        Branch.getInstance().application(UIApplication.shared, open: url, options: [:])
                    }
            } else {
                OnboardingView()
                    .environmentObject(regretStore) 
            }
        }
    }
}