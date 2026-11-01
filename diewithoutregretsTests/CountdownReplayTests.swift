import XCTest
import Observation
@testable import diewithoutregrets

final class CountdownReplayTests: XCTestCase {
    @MainActor func testDuplicateUpdateKeepsTheCurrentRollAndSettlesOnce() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runNext(); f.runNext()
        XCTAssertEqual(f.model.displayMinutes, 2)
        let pending = f.scheduled.count
        let delta = f.model.delta

        f.model.sync(remainingMinutes: 15, grantStamp: 1)

        XCTAssertEqual(f.model.displayMinutes, 2)
        XCTAssertTrue(f.model.isRolling)
        XCTAssertEqual(f.model.delta, delta)
        XCTAssertEqual(f.scheduled.count, pending)
        XCTAssertTrue(f.settled.isEmpty)
        f.runAll()
        XCTAssertEqual(f.model.displayMinutes, 15)
        XCTAssertFalse(f.model.isRolling)
        XCTAssertEqual(f.settled, [15])
    }

    @MainActor func testNewCheckpointContinuesFromVisibleValueDuringCountUp() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runNext(); f.runNext()

        f.model.sync(remainingMinutes: 14, grantStamp: 1)

        XCTAssertEqual(f.model.displayMinutes, 2, "Must not jump to the persisted target of 15")
        f.runAll() // Includes cancelled callbacks from the superseded roll.
        XCTAssertEqual(f.model.displayMinutes, 14)
        XCTAssertEqual(f.settled, [14])
    }

    @MainActor func testNewCheckpointContinuesFromVisibleValueDuringCountDown() {
        let f = Fixture(lastShown: 15, stamp: 1)
        f.model.sync(remainingMinutes: 10, grantStamp: 1)
        f.runNext(); f.runNext()
        XCTAssertEqual(f.model.displayMinutes, 13)

        f.model.sync(remainingMinutes: 9, grantStamp: 1)

        XCTAssertEqual(f.model.displayMinutes, 13, "Must not jump to the previous target of 10")
        f.runAll()
        XCTAssertEqual(f.model.displayMinutes, 9)
        XCTAssertEqual(f.settled, [9])
    }

    @MainActor func testNewGrantWithSameMinutesStartsItsOwnRoll() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runNext(); f.runNext()
        f.model.sync(remainingMinutes: 15, grantStamp: 2)
        XCTAssertEqual(f.model.displayMinutes, 0)
        XCTAssertEqual(f.model.delta?.id, 2)
        f.runAll()
        XCTAssertEqual(f.settled, [15])
        XCTAssertEqual(f.defaults.double(forKey: CountdownReplayModel.lastStampKey), 2)
    }

    @MainActor func testHiddenViewCancelsCallbacksAndDoesNotConsumeNewCheckpoints() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runNext()
        f.model.setVisible(false)
        f.model.sync(remainingMinutes: 0, grantStamp: 1)
        f.runAll()
        XCTAssertEqual(f.model.displayMinutes, 1)
        XCTAssertFalse(f.model.isRolling)
        XCTAssertTrue(f.settled.isEmpty)
        XCTAssertEqual(f.defaults.integer(forKey: CountdownReplayModel.lastShownKey), 15)

        f.model.setVisible(true)
        f.model.sync(remainingMinutes: 0, grantStamp: 1)
        f.runAll()
        XCTAssertEqual(f.model.displayMinutes, 0)
        XCTAssertEqual(f.settled, [0], "The lock handoff must still fire on return")
    }

    @MainActor func testReturningToSameTargetSettlesWithoutReplayingCancelledRoll() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runNext()
        f.model.setVisible(false)
        f.model.setVisible(true)
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runAll()
        XCTAssertEqual(f.model.displayMinutes, 15)
        XCTAssertFalse(f.model.isRolling)
        XCTAssertEqual(f.settled, [15])
    }

    @MainActor func testReduceMotionCanInterruptAnIdenticalActiveTarget() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runNext()
        f.reduceMotion = true
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        f.runAll()
        XCTAssertEqual(f.model.displayMinutes, 15)
        XCTAssertFalse(f.model.isRolling)
        XCTAssertEqual(f.settled, [15])
    }

    @MainActor func testZeroCanSettleAgainWhenGuardStateBecomesLocked() {
        let f = Fixture(lastShown: 0, stamp: 1)
        f.model.sync(remainingMinutes: 0, grantStamp: 1)
        f.model.sync(remainingMinutes: 0, grantStamp: 1)
        XCTAssertEqual(f.settled, [0, 0], "Only in-flight duplicates are ignored; a later lock still needs its callback")
        XCTAssertTrue(f.scheduled.isEmpty)
    }

    @MainActor func testTargetPersistsBeforeAnimationAndLargeDropsStayCapped() {
        let f = Fixture(lastShown: 60, stamp: 1)
        f.model.sync(remainingMinutes: 0, grantStamp: 1)
        XCTAssertEqual(f.defaults.integer(forKey: CountdownReplayModel.lastShownKey), 0)
        XCTAssertEqual(f.model.displayMinutes, 10)
        XCTAssertEqual(f.scheduled.count, 11, "Ten visual ticks plus the existing settle callback")
        XCTAssertTrue(f.settled.isEmpty)
        f.runAll()
        XCTAssertEqual(f.settled, [0])
    }

    @MainActor func testCountUpRetainsPerMinuteTicksAndTiming() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        XCTAssertEqual(f.scheduled.count, 16)
        XCTAssertEqual(f.delays.last!, 3.094, accuracy: 0.001)
        for minute in 1...15 {
            f.runNext()
            XCTAssertEqual(f.model.displayMinutes, minute)
            XCTAssertTrue(f.model.isRolling)
        }
        f.runNext()
        XCTAssertFalse(f.model.isRolling)
        XCTAssertEqual(f.settled, [15])
    }

    @MainActor func testMinuteTicksOnlyInvalidatePropertiesReadByAView() {
        let f = Fixture()
        f.model.sync(remainingMinutes: 15, grantStamp: 1)
        let number = ChangeCounter()
        let swell = ChangeCounter()
        withObservationTracking { _ = f.model.displayMinutes } onChange: { number.increment() }
        withObservationTracking { _ = f.model.isRolling } onChange: { swell.increment() }
        f.runNext()
        XCTAssertEqual(number.value, 1)
        XCTAssertEqual(swell.value, 0)
    }
}

private final class ChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
}

@MainActor
private final class Fixture {
    let suite = "CountdownReplayTests.\(UUID())"
    let defaults: UserDefaults
    var scheduled: [DispatchWorkItem] = []
    var delays: [TimeInterval] = []
    var settled: [Int] = []
    var reduceMotion = false
    var model: CountdownReplayModel!

    init(lastShown: Int = 0, stamp: Double = 0) {
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(lastShown, forKey: CountdownReplayModel.lastShownKey)
        defaults.set(stamp, forKey: CountdownReplayModel.lastStampKey)
        model = CountdownReplayModel(defaults: defaults, reduceMotion: { [weak self] in
            self?.reduceMotion ?? false
        }, schedule: { [weak self] delay, work in
            self?.scheduled.append(work)
            self?.delays.append(delay)
        })
        model.onSettled = { [weak self] in self?.settled.append($0) }
        model.setVisible(true)
    }

    deinit { defaults.removePersistentDomain(forName: suite) }
    func runNext() { scheduled.removeFirst().perform() }
    func runAll() { while !scheduled.isEmpty { runNext() } }
}
