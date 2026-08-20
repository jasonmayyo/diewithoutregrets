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
    /// True while the Guard home's lock-stamp overlay is playing. ContentView
    /// hides the floating tab bar so the stamp owns the whole screen.
    @Published public var isLockStampPlaying: Bool = false
    /// True while the Guard home is showing the revealed lock-out scene.
    /// ContentView flips the floating tab bar to its night (smoked-glass)
    /// look so it reads against the dark ripple instead of glowing white.
    @Published public var isLockedHomeShowing: Bool = false
    /// One-shot tab-switch request (the Creator Toolkit uses it to land on
    /// the Guard tab so a staged lock or refill plays on camera).
    /// ContentView applies it to its tab selection and clears it.
    @Published public var requestedTab: Int?

    /// A corner wipe crossing a root swap (locked home → quiz, give-up →
    /// locked home). ContentView renders it above the root switch; the
    /// destination change happens in `wipeMidAction` while the screen is
    /// fully covered, so the swap is never visible as a jump cut.
    /// (A plain enum, not SGCornerWipe.Preset: this file is also compiled
    /// into the intent extensions, which don't carry the DesignSystem.)
    public enum WipeStyle {
        case lock
        case unlock
    }

    @Published public var activeWipe: WipeStyle?
    public var wipeMidAction: (() -> Void)?

    public func wipeTo(_ style: WipeStyle, midAction: @escaping () -> Void) {
        if Thread.isMainThread {
            startWipe(style, midAction: midAction)
        } else {
            DispatchQueue.main.async {
                self.startWipe(style, midAction: midAction)
            }
        }
    }

    /// Re-entry guard: a second wipeTo while a wipe is in flight (double-tap,
    /// notification racing a tap) would reassign midAction under a running
    /// wipe and could strand or double-run the root swap — refuse it.
    private func startWipe(_ style: WipeStyle, midAction: @escaping () -> Void) {
        guard activeWipe == nil else { return }
        wipeMidAction = midAction
        activeWipe = style
    }

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
            setDestination(destination)
        } else {
            DispatchQueue.main.async {
                self.setDestination(destination)
            }
        }
    }

    /// Same-destination guard: a notification tap while already on the quiz
    /// (or a deeplink racing a wipe) re-publishes the root and re-runs the
    /// whole entry choreography — make it a no-op instead.
    private func setDestination(_ destination: NavigationDestination) {
        guard currentDestination != destination else { return }
        currentDestination = destination
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
