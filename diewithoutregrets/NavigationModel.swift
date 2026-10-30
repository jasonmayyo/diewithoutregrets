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
    /// Captured from the shield tap for this flow only. Cleared on every exit.
    @Published var unlockReturnDestination: ShieldReturnDestination?
    /// ContentView owns the overlay so it survives the swap into chat.
    @Published public var isLockStampPlaying: Bool = false
    @Published private(set) var monsterLockAnimationID: UUID?
    private var automaticallyOpenedMonsterGrant: Double?
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
            unlockReturnDestination = nil
        } else {
            DispatchQueue.main.async {
                self.currentDestination = nil
                self.unlockMethodOverride = nil
                self.unlockReturnDestination = nil
            }
        }
    }

    /// Called before the first frame on cold launch and immediately on a warm
    /// shield return. Bypass the locked-home reveal and any pending scene wipe.
    func openMonsterFromShield(returnDestination: ShieldReturnDestination?, grantStamp: Double? = nil) {
        activeWipe = nil
        wipeMidAction = nil
        monsterLockAnimationID = nil
        isLockStampPlaying = false
        automaticallyOpenedMonsterGrant = grantStamp ?? SGContract.sharedDefaults?.double(forKey: SGContract.Keys.budgetGrantedAt)
        unlockReturnDestination = returnDestination
        unlockMethodOverride = "monster"
        setDestination(.regretView)
    }

    /// Manual home entry shares the guarded chat route without requiring a
    /// shield tap or carrying a stale return-to-app destination into this chat.
    func openMonsterFromHome() {
        openMonsterFromShield(returnDestination: nil)
    }

    /// Enter once per allowance. Closing chat keeps Home usable instead of
    /// immediately reopening it; a new allowance arms the next automatic entry.
    @discardableResult
    func beginMonsterLockEntry(grantStamp: Double, animated: Bool) -> Bool {
        guard currentDestination == nil, activeWipe == nil, !isLockStampPlaying,
              automaticallyOpenedMonsterGrant != grantStamp else { return false }
        automaticallyOpenedMonsterGrant = grantStamp
        if animated {
            monsterLockAnimationID = UUID()
            isLockStampPlaying = true
        } else {
            openMonsterFromShield(returnDestination: nil, grantStamp: grantStamp)
        }
        return true
    }

    func revealMonsterAfterLock(animationID: UUID) {
        guard monsterLockAnimationID == animationID, isLockStampPlaying else { return }
        unlockReturnDestination = nil
        unlockMethodOverride = "monster"
        setDestination(.regretView)
    }

    func finishMonsterLockAnimation(animationID: UUID) {
        guard monsterLockAnimationID == animationID else { return }
        monsterLockAnimationID = nil
        isLockStampPlaying = false
    }

    /// Debug replay or a guard reset can explicitly arm the same allowance.
    func resetAutomaticMonsterEntry() {
        automaticallyOpenedMonsterGrant = nil
        monsterLockAnimationID = nil
        isLockStampPlaying = false
    }
    
    init() {
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
