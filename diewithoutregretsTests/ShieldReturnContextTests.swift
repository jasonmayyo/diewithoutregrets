import XCTest
@testable import diewithoutregrets

final class ShieldReturnContextTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let instagramToken = Data("opaque-instagram-token".utf8)
    private let youtubeToken = Data("opaque-youtube-token".utf8)
    private let socialCategoryToken = Data("opaque-social-category".utf8)

    func testCategoryBlockedInstagramReturnsToInstagram() {
        ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                     categoryTokenData: socialCategoryToken, in: defaults, now: now)
        ShieldReturnContext.prepareCategoryReturn(for: socialCategoryToken, in: defaults, now: now.addingTimeInterval(2))
        let destination = ShieldReturnContext.consumePending(in: defaults, now: now.addingTimeInterval(3))
        XCTAssertEqual(destination?.name, "Instagram")
        XCTAssertEqual(destination?.url.absoluteString, "instagram://")
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now.addingTimeInterval(4)))
    }

    func testCategoryDoesNotRequireAnApplicationToken() {
        ShieldReturnContext.remember(tokenData: nil, bundleIdentifier: "com.burbn.instagram",
                                     categoryTokenData: socialCategoryToken, in: defaults, now: now)
        ShieldReturnContext.prepareCategoryReturn(for: socialCategoryToken, in: defaults, now: now)
        XCTAssertEqual(ShieldReturnContext.consumePending(in: defaults, now: now)?.name, "Instagram")
    }

    func testCategoryUsesTheCurrentShieldAndNotAnEarlierAppInTheCategory() {
        ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                     categoryTokenData: socialCategoryToken, in: defaults, now: now)
        ShieldReturnContext.remember(tokenData: youtubeToken, bundleIdentifier: "com.google.ios.youtube",
                                     categoryTokenData: socialCategoryToken, in: defaults, now: now.addingTimeInterval(1))
        ShieldReturnContext.prepareCategoryReturn(for: socialCategoryToken, in: defaults, now: now.addingTimeInterval(2))
        XCTAssertEqual(ShieldReturnContext.consumePending(in: defaults, now: now.addingTimeInterval(3))?.name, "YouTube")
    }

    func testUnmatchedOrExpiredCategoryCannotReuseAnApp() {
        for (token, age) in [(socialCategoryToken, -1.0), (socialCategoryToken, 120.0), (Data("another-category".utf8), 1.0)] {
            ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                         categoryTokenData: socialCategoryToken, in: defaults, now: now)
            ShieldReturnContext.prepareCategoryReturn(for: token, in: defaults, now: now.addingTimeInterval(age))
            XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        }
    }

    func testWebsiteOrUnsupportedAppRenderClearsCategoryReturn() {
        for bundleID: String? in [nil, "com.example.unsupported"] {
            ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                         categoryTokenData: socialCategoryToken, in: defaults, now: now)
            ShieldReturnContext.remember(tokenData: nil, bundleIdentifier: bundleID,
                                         categoryTokenData: socialCategoryToken, in: defaults, now: now)
            ShieldReturnContext.prepareCategoryReturn(for: socialCategoryToken, in: defaults, now: now)
            XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        }
    }

    func testTokenJSONOrderDoesNotBreakCrossExtensionLookup() {
        let rendered = Data(#"{"data":"opaque","version":1}"#.utf8)
        let tapped = Data(#"{"version":1,"data":"opaque"}"#.utf8)
        ShieldReturnContext.remember(tokenData: rendered, bundleIdentifier: "com.burbn.instagram",
                                     categoryTokenData: rendered, in: defaults, now: now)
        ShieldReturnContext.prepareReturn(for: tapped, in: defaults, now: now)
        XCTAssertEqual(ShieldReturnContext.consumePending(in: defaults, now: now)?.name, "Instagram")
        ShieldReturnContext.prepareCategoryReturn(for: tapped, in: defaults, now: now)
        XCTAssertEqual(ShieldReturnContext.consumePending(in: defaults, now: now)?.name, "Instagram")
    }

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
        ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                     categoryTokenData: socialCategoryToken, in: defaults, now: now)
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
        ShieldReturnContext.clear(in: defaults)
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        ShieldReturnContext.prepareReturn(for: instagramToken, in: defaults, now: now)
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
        ShieldReturnContext.prepareCategoryReturn(for: socialCategoryToken, in: defaults, now: now)
        XCTAssertNil(ShieldReturnContext.consumePending(in: defaults, now: now))
    }

    private func rememberInstagram() {
        ShieldReturnContext.remember(tokenData: instagramToken, bundleIdentifier: "com.burbn.instagram",
                                     in: defaults, now: now)
    }
}
