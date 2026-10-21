import Foundation
import Combine
import RevenueCat
import StoreKit
import SuperwallKit

/// Superwall supplies paywall UI; RevenueCat remains responsible for billing
/// and access, including purchases initiated by the onboarding paywall.
@MainActor
final class SGSuperwallBilling: PurchaseController {
    static let shared = SGSuperwallBilling()

    // Public SDK key for Study Guard, safe to include in the app binary.
    private static let apiKey = "pk_58wkThEIDpQtj6WjGCItj"
    // Superwall identifiers cannot contain spaces. Keep RevenueCat's existing
    // entitlement unchanged and translate it to the dashboard's `pro` ID.
    nonisolated static let revenueCatEntitlementID = "Pro Acess"
    nonisolated static let superwallEntitlementID = "pro"
    nonisolated static let onboardingPlacement = "onboarding_paywall"
    private var customerInfoTask: Task<Void, Never>?
    private var isConfigured = false

    private init() {}

    func configure() {
        guard !isConfigured else { return }
        precondition(Purchases.isConfigured, "Configure RevenueCat before Superwall.")

        let options = SuperwallOptions()
        options.storeKitVersion = .storeKit2
        options.paywalls.shouldPreload = true
        Superwall.configure(apiKey: Self.apiKey, purchaseController: self, options: options) {
            #if DEBUG
            print("[Superwall] Configuration: \(Superwall.shared.configurationStatus)")
            #endif
        }
        Superwall.shared.identify(userId: Purchases.shared.appUserID)
        isConfigured = true

        customerInfoTask = Task { [weak self] in
            // The stream replays cached data but doesn't initiate a fetch.
            // Fetch first so a new installation resolves its unknown status.
            await self?.refreshSubscriptionStatus()
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                self?.apply(customerInfo)
            }
        }
    }

    /// Also called on foreground to pick up renewals, expiry and refunds.
    /// Network failures preserve the last known status instead of revoking access.
    func refreshSubscriptionStatus() async {
        guard isConfigured else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            #if DEBUG
            print("[Superwall] RevenueCat subscription refresh failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func apply(_ customerInfo: RevenueCat.CustomerInfo) {
        Superwall.shared.subscriptionStatus = Self.subscriptionStatus(
            activeEntitlementIDs: Set(customerInfo.entitlements.activeInCurrentEnvironment.keys)
        )
        #if DEBUG
        print("[Superwall] RevenueCat access synced: \(Superwall.shared.subscriptionStatus)")
        #endif
    }

    /// The app's hard gate always checks RevenueCat, even when a dashboard
    /// campaign skips a paywall or is accidentally configured as non-gated.
    func hasActiveAccess() async throws -> Bool {
        let info = try await Purchases.shared.customerInfo()
        apply(info)
        return Self.hasActiveAccess(info)
    }

    nonisolated static func hasActiveAccess(_ info: RevenueCat.CustomerInfo) -> Bool {
        info.entitlements.activeInCurrentEnvironment[revenueCatEntitlementID] != nil
    }

    func restoreAccess() async throws -> Bool {
        Analytics.restorePurchasesAttempted(surface: "onboarding_superwall")
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            let hasAccess = Self.hasActiveAccess(info)
            Analytics.restorePurchasesSucceeded(surface: "onboarding_superwall", hasActiveEntitlements: hasAccess)
            return hasAccess
        } catch {
            Analytics.restorePurchasesFailed(surface: "onboarding_superwall", error: error.localizedDescription)
            throw error
        }
    }

    nonisolated static func subscriptionStatus(activeEntitlementIDs: Set<String>) -> SuperwallKit.SubscriptionStatus {
        activeEntitlementIDs.contains(revenueCatEntitlementID)
            ? .active([SuperwallKit.Entitlement(id: Self.superwallEntitlementID)])
            : .inactive
    }

    func purchase(product: SuperwallKit.StoreProduct) async -> SuperwallKit.PurchaseResult {
        guard let storeKitProduct = product.sk2Product else {
            return .failed(BillingError.storeKitProductUnavailable)
        }

        do {
            let result = try await Purchases.shared.purchase(
                product: RevenueCat.StoreProduct(sk2Product: storeKitProduct)
            )
            apply(result.customerInfo)
            if !result.userCancelled, Self.hasActiveAccess(result.customerInfo) {
                trackPurchase(storeKitProduct, info: result.customerInfo)
            }
            return result.userCancelled ? .cancelled : .purchased
        } catch {
            return Self.purchaseFailure(error)
        }
    }

    nonisolated static func purchaseFailure(_ error: Error) -> SuperwallKit.PurchaseResult {
        switch error as? RevenueCat.ErrorCode {
        case .purchaseCancelledError: return .cancelled
        case .paymentPendingError: return .pending
        default: return .failed(error)
        }
    }

    func restorePurchases() async -> SuperwallKit.RestorationResult {
        do {
            // Update access before returning so Superwall can distinguish a
            // successful restore request from one with no active entitlement.
            _ = try await restoreAccess()
            return .restored
        } catch {
            return .failed(error)
        }
    }

    private func trackPurchase(_ product: StoreKit.Product, info: RevenueCat.CustomerInfo) {
        let price = NSDecimalNumber(decimal: product.price).doubleValue
        let currency = product.priceFormatStyle.currencyCode
        let isTrial = info.entitlements.activeInCurrentEnvironment[Self.revenueCatEntitlementID]?.periodType == .trial
        if isTrial {
            AdsTracker.trackStartTrial(productId: product.id, productName: product.displayName, price: price, currency: currency)
        } else {
            AdsTracker.trackSubscribe(productId: product.id, productName: product.displayName, price: price, currency: currency)
            AdsTracker.trackPurchase(productId: product.id, productName: product.displayName, price: price, currency: currency)
        }
        Analytics.subscriptionStarted(surface: "onboarding_superwall", productId: product.id,
                                      price: price, currency: currency, isTrial: isTrial,
                                      offeringId: nil, entitlements: Array(info.entitlements.activeInCurrentEnvironment.keys))
        Analytics.capture("onboarding_purchase_completed", properties: ["provider": "superwall", "product_id": product.id])
    }

    private enum BillingError: LocalizedError {
        case storeKitProductUnavailable

        var errorDescription: String? {
            "This product is unavailable. Please try again later."
        }
    }
}

/// Owns presentation and access verification independently of SwiftUI's view
/// lifetime. A purchase/restore/skip callback alone never unlocks onboarding.
@MainActor
final class SGOnboardingPaywallCoordinator: ObservableObject {
    enum State: Equatable {
        case idle, loading, presented, ready, completed
        case failed(String)
    }

    enum Event {
        case presented, declined, verifyAccess, failed(Error)
    }

    struct Dependencies {
        var checkAccess: () async throws -> Bool
        var restoreAccess: () async throws -> Bool
        var present: (_ placement: String, _ event: @escaping @MainActor (Event) async -> Void) -> Void
        var dismiss: () async -> Void
        var refreshConfiguration: () async -> Void

        static var live: Self {
            Self(checkAccess: { try await SGSuperwallBilling.shared.hasActiveAccess() },
                 restoreAccess: { try await SGSuperwallBilling.shared.restoreAccess() },
                 present: { placement, event in
                let handler = PaywallPresentationHandler()
                handler.onPresent { info in
                    Analytics.paywallViewed(surface: "onboarding_superwall", properties: [
                        "placement": placement, "paywall_id": info.identifier
                    ])
                    NotificationManager.shared.markPaywallViewedWithoutPurchase()
                    Task { @MainActor in await event(.presented) }
                }
                handler.onDismiss { info, result in
                    if info.closeReason == .forNextPaywall { return }
                    if info.closeReason == .webViewFailedToLoad {
                        Task { @MainActor in
                            await event(.failed(URLError(.cannotLoadFromNetwork)))
                        }
                        return
                    }
                    let declined = result == .declined
                    Analytics.paywallDismissed(surface: "onboarding_superwall", didPurchase: !declined)
                    Task { @MainActor in await event(declined ? .declined : .verifyAccess) }
                }
                handler.onSkip { reason in
                    Analytics.capture("onboarding_paywall_skipped", properties: ["reason": reason.description])
                    Task { @MainActor in await event(.verifyAccess) }
                }
                handler.onError { error in
                    Telemetry.capture(error, tags: ["feature": "paywall", "surface": "onboarding_superwall"])
                    Task { @MainActor in await event(.failed(error)) }
                }
                Superwall.shared.register(placement: placement, handler: handler) {
                    // Includes already-subscribed users. Re-check RevenueCat;
                    // a non-gated or missing campaign can also call this block.
                    Task { @MainActor in await event(.verifyAccess) }
                }
            }, dismiss: { await Superwall.shared.dismiss() },
                 refreshConfiguration: { await Superwall.shared.refreshConfiguration() })
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var declineCount = 0
    @Published private(set) var isRestoring = false
    private let dependencies: Dependencies
    private var attempt: UUID?
    private var resolvingAttempt: UUID?

    init(dependencies: Dependencies = .live) { self.dependencies = dependencies }

    var isBusy: Bool { state == .loading || state == .presented || isRestoring }

    func present() async {
        guard !isBusy, state != .completed else { return }
        let retry: Bool
        if case .failed = state { retry = true } else { retry = false }
        let id = UUID()
        attempt = id
        state = .loading
        do {
            let hasAccess = try await dependencies.checkAccess()
            guard attempt == id else { return }
            if hasAccess { complete(); return }
            if retry { await dependencies.refreshConfiguration() }
            guard attempt == id else { return }
            dependencies.present(SGSuperwallBilling.onboardingPlacement) { [weak self] event in
                await self?.receive(event, attempt: id)
            }
        } catch {
            guard attempt == id else { return }
            fail("Couldn't load your plan. Check your connection and try again.")
        }
    }

    private func receive(_ event: Event, attempt id: UUID) async {
        guard attempt == id else {
            // A queued presentation can finish after a buyback deep link
            // superseded it. Do not leave that stale paywall over the offer.
            if case .presented = event { await dependencies.dismiss() }
            return
        }
        switch event {
        case .presented:
            state = .presented
        case .declined:
            attempt = nil
            state = .ready
            declineCount += 1
        case .verifyAccess:
            guard resolvingAttempt != id else { return }
            resolvingAttempt = id
            await verifyAccess(attempt: id)
        case .failed:
            fail("Couldn't load your plan. Check your connection and try again.")
        }
    }

    private func verifyAccess(attempt id: UUID) async {
        state = .loading
        do {
            let hasAccess = try await dependencies.checkAccess()
            guard attempt == id else { return }
            if hasAccess { complete() }
            else { fail("We couldn't confirm an active subscription. Try again or restore your purchases.") }
        } catch {
            guard attempt == id else { return }
            fail("Couldn't verify your subscription. Check your connection and try again.")
        }
    }

    func restore() async {
        guard !isBusy, state != .completed else { return }
        let id = UUID()
        attempt = id
        isRestoring = true
        state = .loading
        defer { isRestoring = false }
        do {
            let hasAccess = try await dependencies.restoreAccess()
            guard attempt == id else { return }
            if hasAccess { complete() }
            else { fail("No active Study Guard subscription was found to restore.") }
        } catch {
            guard attempt == id else { return }
            fail("Couldn't restore purchases. Check your connection and try again.")
        }
    }

    /// External buyback presentation is not a decline of this paywall.
    func dismissForExternalOffer() async {
        guard state != .completed else { return }
        let id = UUID()
        attempt = id
        resolvingAttempt = nil
        await dependencies.dismiss()
        guard attempt == id else { return }
        attempt = nil
        state = .ready
    }

    func verifyExternalPurchase() async {
        guard state != .completed else { return }
        let id = UUID()
        attempt = id
        resolvingAttempt = id
        state = .loading
        await dependencies.dismiss()
        guard attempt == id else { return }
        await verifyAccess(attempt: id)
    }

    private func complete() {
        attempt = nil
        resolvingAttempt = nil
        state = .completed
    }

    private func fail(_ message: String) {
        attempt = nil
        resolvingAttempt = nil
        state = .failed(message)
    }
}
