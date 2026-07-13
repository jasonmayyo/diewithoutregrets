import Foundation
import SwiftUI

// Define the destination enum
public enum NavigationDestination {
    case regretView
}

public final class NavigationModel: ObservableObject {
    public static let shared = NavigationModel()

    @Published public var currentDestination: NavigationDestination?
    @Published public var showBuyBackOffer: Bool = false
    @Published public var hasPendingBuyBackOffer: Bool = false
    @Published public var shouldDismissPaywall: Bool = false
    /// Set when the buyback offer is purchased while onboarding is still in
    /// progress. HardPaywallView observes this, advances the flow into
    /// post-purchase setup, and resets it back to false once handled.
    @Published public var buyBackPurchasedDuringOnboarding: Bool = false
    /// Transient override for the unlock method — lets a locked user switch
    /// to the other method ("Answer flashcards instead" / "Use True Focus
    /// instead") without changing their saved preference. Cleared when the
    /// unlock flow dismisses.
    @Published public var unlockMethodOverride: String?

    public func returnHome() {
        if Thread.isMainThread {
            currentDestination = nil
            unlockMethodOverride = nil
        } else {
            DispatchQueue.main.async {
                self.currentDestination = nil
                self.unlockMethodOverride = nil
            }
        }
    }
    
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

    public func signalBuyBackPurchaseDuringOnboarding() {
        print("[NavigationModel] signalBuyBackPurchaseDuringOnboarding called")
        if Thread.isMainThread {
            self.buyBackPurchasedDuringOnboarding = true
        } else {
            DispatchQueue.main.async {
                self.buyBackPurchasedDuringOnboarding = true
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
