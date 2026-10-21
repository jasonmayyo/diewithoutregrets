import XCTest
import RevenueCat
import SuperwallKit
@testable import diewithoutregrets

final class SuperwallBillingTests: XCTestCase {
    func testExistingRevenueCatSubscriberReceivesSuperwallProAccess() {
        XCTAssertEqual(
            SGSuperwallBilling.subscriptionStatus(activeEntitlementIDs: ["Pro Acess"]),
            .active([SuperwallKit.Entitlement(id: "pro")])
        )
    }

    func testExpiredOrMissingEntitlementDoesNotGrantAccess() {
        XCTAssertEqual(SGSuperwallBilling.subscriptionStatus(activeEntitlementIDs: []), .inactive)
        // The legacy identifier must be preserved exactly, not "corrected".
        XCTAssertEqual(SGSuperwallBilling.subscriptionStatus(activeEntitlementIDs: ["Pro Access"]), .inactive)
    }

    func testCancellationIsNotReportedAsPurchaseFailure() {
        let error = RevenueCat.ErrorCode.purchaseCancelledError as NSError
        guard case .cancelled = SGSuperwallBilling.purchaseFailure(error) else {
            return XCTFail("A cancelled RevenueCat purchase must remain cancelled in Superwall.")
        }
    }

    func testPendingApprovalIsNotReportedAsSuccess() {
        let error = RevenueCat.ErrorCode.paymentPendingError as NSError
        guard case .pending = SGSuperwallBilling.purchaseFailure(error) else {
            return XCTFail("A purchase awaiting approval must remain pending.")
        }
    }

    func testNetworkFailureRetainsOriginalError() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        guard case .failed(let returnedError) = SGSuperwallBilling.purchaseFailure(error) else {
            return XCTFail("Network failures must not grant access or be reported as cancellation.")
        }
        XCTAssertEqual(returnedError as NSError, error)
    }
}

@MainActor
final class OnboardingSuperwallFlowTests: XCTestCase {
    @MainActor
    private final class Harness {
        var hasAccess = false
        var restoredAccess = false
        var accessError: Error?
        var placements: [String] = []
        var handlers: [@MainActor (SGOnboardingPaywallCoordinator.Event) async -> Void] = []
        var dismissals = 0
        var refreshes = 0
        var accessCheck: (() async throws -> Bool)?

        lazy var model = SGOnboardingPaywallCoordinator(dependencies: .init(
            checkAccess: {
                if let check = self.accessCheck { return try await check() }
                if let error = self.accessError { throw error }
                return self.hasAccess
            },
            restoreAccess: { self.restoredAccess },
            present: { placement, handler in
                self.placements.append(placement)
                self.handlers.append(handler)
            },
            dismiss: { self.dismissals += 1 },
            refreshConfiguration: { self.refreshes += 1 }
        ))

        func send(_ event: SGOnboardingPaywallCoordinator.Event) async {
            await handlers.last?(event)
        }
    }

    func testExistingRevenueCatSubscriberContinuesWithoutShowingPaywall() async {
        let h = Harness()
        h.hasAccess = true
        await h.model.present()
        XCTAssertEqual(h.model.state, .completed)
        XCTAssertTrue(h.placements.isEmpty)
    }

    func testUnsubscribedUserRegistersOnboardingPlacementOnlyOnce() async {
        let h = Harness()
        await h.model.present()
        await h.model.present()
        XCTAssertEqual(h.placements, ["onboarding_paywall"])
        await h.send(.presented)
        XCTAssertEqual(h.model.state, .presented)
        await h.model.present()
        XCTAssertEqual(h.placements.count, 1)
    }

    func testPurchaseCallbackRequiresRevenueCatAccessBeforeContinuing() async {
        let h = Harness()
        await h.model.present()
        await h.send(.presented)
        h.hasAccess = true
        await h.send(.verifyAccess)
        XCTAssertEqual(h.model.state, .completed)
        // Superwall also invokes its feature closure after onDismiss.
        await h.send(.verifyAccess)
        await h.send(.declined)
        XCTAssertEqual(h.model.state, .completed)
        XCTAssertEqual(h.model.declineCount, 0)
    }

    func testSkippedOrNonGatedCampaignCannotUnlockWithoutRevenueCatAccess() async {
        let h = Harness()
        await h.model.present()
        await h.send(.verifyAccess)
        guard case .failed = h.model.state else { return XCTFail("A skipped campaign must not unlock onboarding.") }
        XCTAssertEqual(h.model.declineCount, 0)
    }

    func testFailedEntitlementVerificationDoesNotAdvance() async {
        let h = Harness()
        await h.model.present()
        h.accessError = URLError(.notConnectedToInternet)
        await h.send(.verifyAccess)
        guard case .failed = h.model.state else { return XCTFail("Verification failure must remain gated.") }
    }

    func testDeclineKeepsGateAndCountsOneDismissal() async {
        let h = Harness()
        await h.model.present()
        await h.send(.presented)
        await h.send(.declined)
        // A non-gated dashboard variant may then run the feature closure.
        await h.send(.verifyAccess)
        await h.send(.declined)
        XCTAssertEqual(h.model.state, .ready)
        XCTAssertEqual(h.model.declineCount, 1)
        await h.model.present()
        XCTAssertEqual(h.placements.count, 2)
    }

    func testPresentationFailureAllowsRetryAndRefreshesDashboardConfiguration() async {
        let h = Harness()
        await h.model.present()
        await h.send(.failed(URLError(.cannotLoadFromNetwork)))
        guard case .failed = h.model.state else { return XCTFail("A load error must show a retry state.") }
        XCTAssertEqual(h.model.declineCount, 0)
        await h.model.present()
        XCTAssertEqual(h.refreshes, 1)
        XCTAssertEqual(h.placements.count, 2)
    }

    func testRestoreWithoutSubscriptionStaysGated() async {
        let h = Harness()
        await h.model.restore()
        guard case .failed = h.model.state else { return XCTFail("An empty restore must not unlock onboarding.") }
        XCTAssertFalse(h.model.isRestoring)
    }

    func testRestoreWithRevenueCatAccessContinues() async {
        let h = Harness()
        h.restoredAccess = true
        await h.model.restore()
        XCTAssertEqual(h.model.state, .completed)
        XCTAssertTrue(h.placements.isEmpty)
    }

    func testExternalOfferDismissalIsNotCountedAsUserDecline() async {
        let h = Harness()
        await h.model.present()
        await h.send(.presented)
        await h.model.dismissForExternalOffer()
        await h.send(.declined)
        XCTAssertEqual(h.model.state, .ready)
        XCTAssertEqual(h.model.declineCount, 0)
        XCTAssertEqual(h.dismissals, 1)
    }

    func testLateQueuedPaywallIsDismissedAfterExternalOfferTakesOver() async {
        let h = Harness()
        await h.model.present()
        await h.model.dismissForExternalOffer()
        await h.send(.presented)
        XCTAssertEqual(h.dismissals, 2)
        XCTAssertEqual(h.model.state, .ready)
    }

    func testBuybackSignalStillRequiresRevenueCatVerification() async {
        let h = Harness()
        await h.model.verifyExternalPurchase()
        guard case .failed = h.model.state else { return XCTFail("A signal alone is not an entitlement.") }
        h.hasAccess = true
        await h.model.verifyExternalPurchase()
        XCTAssertEqual(h.model.state, .completed)
    }

    func testSupersededAccessCheckCannotPresentOverExternalOffer() async {
        let h = Harness()
        var continuation: CheckedContinuation<Bool, Never>?
        h.accessCheck = { await withCheckedContinuation { continuation = $0 } }
        let task = Task { await h.model.present() }
        while continuation == nil { await Task.yield() }
        await h.model.dismissForExternalOffer()
        continuation?.resume(returning: false)
        await task.value
        XCTAssertTrue(h.placements.isEmpty)
        XCTAssertEqual(h.model.state, .ready)
    }
}
