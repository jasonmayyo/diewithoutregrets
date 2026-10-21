import XCTest
@testable import diewithoutregrets

final class UnlockAppReturnTests: XCTestCase {
    func testSettlesBeforeOpeningAndIgnoresDoubleTap() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.start()
            XCTAssertTrue(f.subject.isOpening)
            XCTAssertEqual(f.urls.count, 0)
            XCTAssertEqual(f.delays, [0.35])
            f.runNext()
            XCTAssertEqual(f.urls, [f.destination.url])
            f.subject.cancel()
        }
    }

    func testImmediateFailureRetriesOnceThenWaitsForBackground() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext(); f.reply(false)
            XCTAssertFalse(f.subject.showFallback)
            XCTAssertEqual(f.delays, [0.35, 0.65])
            f.runNext(); f.reply(true)
            XCTAssertEqual(f.urls.count, 2)
            XCTAssertEqual(f.returned, 0)
            XCTAssertTrue(f.subject.isOpening)
            f.background = true
            f.subject.didEnterBackground()
            XCTAssertEqual(f.returned, 1)
            XCTAssertFalse(f.subject.isOpening)
            f.runNext() // stale watchdog cannot show a fallback after success
            XCTAssertFalse(f.subject.showFallback)
            XCTAssertEqual(f.returned, 1)
        }
    }

    func testTwoFailuresShowFallbackWithoutNavigatingHome() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext(); f.reply(false)
            f.runNext(); f.reply(false)
            XCTAssertEqual(f.urls.count, 2)
            XCTAssertTrue(f.subject.showFallback)
            XCTAssertFalse(f.subject.isOpening)
            XCTAssertEqual(f.returned, 0)
            XCTAssertTrue(f.scheduled.isEmpty)
        }
    }

    func testSlowRefusalDoesNotAutomaticallyRepeatPossibleCancelledPrompt() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext()
            f.time += 1
            f.reply(false)
            XCTAssertEqual(f.urls.count, 1)
            XCTAssertTrue(f.scheduled.isEmpty)
            XCTAssertTrue(f.subject.showFallback)
        }
    }

    func testBackgroundBeforeOpenCompletionStillCompletesOnce() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext()
            f.background = true
            f.subject.didEnterBackground()
            XCTAssertEqual(f.returned, 0)
            f.reply(true)
            f.subject.didEnterBackground()
            XCTAssertEqual(f.returned, 1)
            XCTAssertFalse(f.subject.showFallback)
        }
    }

    func testAlreadyBackgroundedStateCoversMissedNotification() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext()
            f.background = true
            f.reply(true)
            XCTAssertEqual(f.returned, 1)
            XCTAssertFalse(f.subject.isOpening)
        }
    }

    func testLeavingDuringSettlingOrRetryCancelsDelayedLaunch() async {
        await MainActor.run {
            for duringRetry in [false, true] {
                let f = Fixture()
                f.start()
                if duringRetry { f.runNext(); f.reply(false) }
                let previousCount = f.urls.count
                f.background = true
                f.subject.didEnterBackground()
                f.runNext()
                XCTAssertEqual(f.urls.count, previousCount)
                XCTAssertFalse(f.subject.isOpening)
                XCTAssertFalse(f.subject.showFallback)
                XCTAssertEqual(f.returned, 0)
            }
        }
    }

    func testInactiveAppDoesNotLaunchOrPresentAnAlert() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.active = false; f.runNext()
            XCTAssertTrue(f.urls.isEmpty)
            XCTAssertFalse(f.subject.isOpening)
            XCTAssertFalse(f.subject.showFallback)
        }
    }

    func testDisappearingFlowIgnoresLateCompletion() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext(); f.subject.cancel()
            f.background = true; f.reply(true)
            XCTAssertEqual(f.returned, 0)
            XCTAssertFalse(f.subject.showFallback)
            XCTAssertFalse(f.subject.isOpening)
        }
    }

    func testAcceptedRequestWithoutAppSwitchReleasesButton() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext(); f.reply(true); f.runNext()
            XCTAssertFalse(f.subject.isOpening)
            XCTAssertTrue(f.subject.showFallback)
            XCTAssertEqual(f.returned, 0)
        }
    }

    func testPreviousAttemptWatchdogCannotInterruptNewAttempt() async {
        await MainActor.run {
            let f = Fixture()
            f.start(); f.runNext(); f.reply(true)
            f.subject.cancel(); f.start()
            f.runNext() // watchdog belongs to the cancelled request
            XCTAssertTrue(f.subject.isOpening)
            XCTAssertFalse(f.subject.showFallback)
            f.runNext(); f.background = true; f.reply(true)
            XCTAssertEqual(f.returned, 1)
        }
    }

    func testUnknownDestinationDoesNotGuessAnAppOrNavigateHome() async {
        await MainActor.run {
            let f = Fixture()
            f.subject.open(nil) { f.returned += 1 }
            XCTAssertTrue(f.subject.showFallback)
            XCTAssertFalse(f.subject.isOpening)
            XCTAssertTrue(f.urls.isEmpty)
            XCTAssertTrue(f.scheduled.isEmpty)
            XCTAssertEqual(f.returned, 0)
        }
    }
}

@MainActor
private final class Fixture {
    let destination = ShieldReturnDestination.app(bundleIdentifier: "com.burbn.instagram")!
    var active = true
    var background = false
    var time: TimeInterval = 100
    var returned = 0
    var urls: [URL] = []
    var delays: [TimeInterval] = []
    var scheduled: [@MainActor () -> Void] = []
    var replies: [(Bool) -> Void] = []
    lazy var subject = UnlockAppReturn(
        openURL: { [unowned self] url, reply in urls.append(url); replies.append(reply) },
        isActive: { [unowned self] in active && !background },
        isBackground: { [unowned self] in background },
        schedule: { [unowned self] delay, action in delays.append(delay); scheduled.append(action) },
        now: { [unowned self] in Date(timeIntervalSince1970: time) }
    )

    func start() { subject.open(destination) { [weak self] in self?.returned += 1 } }
    func runNext() {
        guard !scheduled.isEmpty else { XCTFail("No scheduled action"); return }
        scheduled.removeFirst()()
    }
    func reply(_ opened: Bool) {
        guard !replies.isEmpty else { XCTFail("No open request"); return }
        replies.removeFirst()(opened)
    }
}
