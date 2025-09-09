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
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(navigationModel)
                .environmentObject(regretStore)
                .environmentObject(deckStore)
                .onOpenURL { url in
                    print("[App] onOpenURL: \(url)")
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        if url.scheme == "diewithoutregrets" && url.host == "buyback" {
            print("[App] Handling buyback URL")
            navigationModel.presentBuyBackOffer()
        }
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var isAppReady = false
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .sheet(isPresented: $navigationModel.showBuyBackOffer) {
            BuyBackOfferView()
        }
        .onAppear {
            print("[RootView] onAppear")
            isAppReady = true
            
            // Check for pending shortcut action
            if let pendingAction = ShortcutAction.pending {
                print("[RootView] Found pending action: \(pendingAction)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    handleShortcutAction(pendingAction)
                    ShortcutAction.pending = nil
                }
            }
        }
    }
    
    private func handleShortcutAction(_ action: ShortcutAction) {
        switch action {
        case .buyBackOffer:
            print("[RootView] Presenting BuyBackOffer from shortcut")
            navigationModel.showBuyBackOffer = true
        }
    }
}

enum ShortcutAction {
    case buyBackOffer
    
    static var pending: ShortcutAction? {
        get {
            if UserDefaults.standard.bool(forKey: "pendingBuyBackOffer") {
                return .buyBackOffer
            }
            return nil
        }
        set {
            UserDefaults.standard.set(newValue == .buyBackOffer, forKey: "pendingBuyBackOffer")
        }
    }
}
