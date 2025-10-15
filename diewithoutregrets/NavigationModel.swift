import Foundation
import SwiftUI

// Define the destination enum
public enum NavigationDestination {
    case regretView
    case regretReport
}

public final class NavigationModel: ObservableObject {
    public static let shared = NavigationModel()
    
    @Published public var currentDestination: NavigationDestination?
    @Published public var showBuyBackOffer: Bool = false
    @Published public var hasPendingBuyBackOffer: Bool = false
    @Published public var shouldDismissPaywall: Bool = false
    
    private init() {
        print("[NavigationModel] Initialized")
    }
    
    public func navigate(to destination: NavigationDestination) {
        print("[NavigationModel] Navigate to: \(destination)")
        if Thread.isMainThread {
            currentDestination = destination
        } else {
            DispatchQueue.main.async {
                self.currentDestination = destination
            }
        }
    }

    public func presentBuyBackOffer() {
        print("[NavigationModel] presentBuyBackOffer called, current value: \(showBuyBackOffer)")
        if Thread.isMainThread {
            // First, dismiss any showing paywall
            print("[NavigationModel] Dismissing any showing paywall")
            self.shouldDismissPaywall = true
            
            // Then show buyback offer after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showBuyBackOffer = true
                print("[NavigationModel] showBuyBackOffer set to true")
                
                // Reset the dismiss flag
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shouldDismissPaywall = false
                }
            }
        } else {
            DispatchQueue.main.async {
                // First, dismiss any showing paywall
                print("[NavigationModel] Dismissing any showing paywall (async)")
                self.shouldDismissPaywall = true
                
                // Then show buyback offer after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showBuyBackOffer = true
                    print("[NavigationModel] showBuyBackOffer set to true (async)")
                    
                    // Reset the dismiss flag
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.shouldDismissPaywall = false
                    }
                }
            }
        }
    }

    public func dismissCurrentModal() {
        print("[NavigationModel] dismissCurrentModal called")
        if Thread.isMainThread {
            self.showBuyBackOffer = false
        } else {
            DispatchQueue.main.async {
                self.showBuyBackOffer = false
            }
        }
    }
}
