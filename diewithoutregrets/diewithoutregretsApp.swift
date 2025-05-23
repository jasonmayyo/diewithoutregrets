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
                ContentView()
                    .environmentObject(navigationModel)
                    .environmentObject(regretStore)
                    .environmentObject(deckStore)
    }
}
