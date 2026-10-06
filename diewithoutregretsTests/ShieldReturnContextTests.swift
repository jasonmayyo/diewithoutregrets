import XCTest
@testable import diewithoutregrets

final class ShieldReturnContextTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let instagramToken = Data("opaque-instagram-token".utf8)
    private let youtubeToken = Data("opaque-youtube-token".utf8)

    override func setUp() {
        suite = "test.shield-return.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    func testReturnsTheTappedAppRatherThanTheMostRecentlyRenderedShield() {
        rememberInstagram()
        ShieldReturnContext.remember(tokenData: youtubeToken, bundleIdentifier: "com.google.ios.youtube",
                                     in: defaults, now: now.addingTimeInterval(1))
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now.addingTimeInterval(2))
        let destination = ShieldReturnContext.consumePending(in: defaults, now: now.addingTimeInterval(3))
        XCTAssertEqual(destination?.name, "Instagram")
        XCTAssertEqual(destination?.url.absoluteString, "instagram://")
    }

    func testRenderingAloneDoesNotCreateAReturnAndTapCanOnlyBeConsumedOnce() {
        rememberInstagram()
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
        XCTAssertNotNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
    }

    func testWebsiteCategoryAndUnknownTokenClearAnyPreviousDestination() {
        rememberInstagram()
        for token: Data? in [nil, Data("unknown-token".utf8)] {
            ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
            ShieldReturnContext.prepareReturn(for: token, in: defaults, now: now)
            XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        }
    }

    func testExpiredAndFutureDatedHandoffsAreDiscarded() {
        rememberInstagram()
        for age in [-1.0, 120.0, 300.0] {
            ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
            XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now.addingTimeInterval(age)))
            XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        }
    }

    func testUnknownAppsNeverFallBackToInstagram() {
        XCTAssertNil(ShieldReturnDestination.app(bundleIdentifier: "com.example.unknown"))
        rememberInstagram()
        // A token whose identity is no longer available must not retain old metadata.
        ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: nil, in: defaults, now: now)
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
    }

    func testResetClearsCachedAndPendingDestinations() {
        rememberInstagram()
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
        ShieldReturnContext.clear(in: defaults)
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
    }

    private func rememberInstagram() {
        ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                     in: defaults, now: now)
    }
}
