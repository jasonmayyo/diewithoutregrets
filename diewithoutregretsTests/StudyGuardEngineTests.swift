//
//  StudyGuardEngineTests.swift
//  diewithoutregretsTests
//
//  Unit tests for the pure parts of the Study Guard v2 engine: interval
//  rounding, event-set construction, the emergency-unlock ledger, and
//  GuardState derivation. Runtime Screen Time behavior can only be tested
//  on a real device (see Docs/StudyGuardAppGroupContract.md).
//

import XCTest
import FamilyControls
import DeviceActivity
@testable import diewithoutregrets

final class StudyGuardEngineTests: XCTestCase {

    // MARK: - Earned quiz budget

    func testPartialQuizGrantsOnlyCorrectAnswersEvenWhenLastAnswerIsWrong() {
        // Two correct answers at 75 seconds = 2m 30s, rounded UP to 3m.
        let results: [Bool?] = [true, false, true, false, false]
        XCTAssertEqual(SGContract.completedQuizMinutes(results: results, perCardSeconds: 75), 3)
    }

    func testPartialQuizAlsoGrantsWhenLastAnswerIsCorrect() {
        XCTAssertEqual(SGContract.completedQuizMinutes(
            results: [false, true, false, false, true], perCardSeconds: 30), 1)
    }

    func testUnfinishedEmptyAndZeroCorrectQuizzesEarnNothing() {
        let runs: [[Bool?]] = [[], [nil], [true, nil], [true, false, nil], [false, false, false]]
        for results in runs {
            XCTAssertEqual(SGContract.completedQuizMinutes(results: results, perCardSeconds: 75), 0)
        }
        XCTAssertEqual(SGContract.earnedMinutes(cardCount: 0, perCardSeconds: 30), 0)
        XCTAssertEqual(SGContract.earnedMinutes(cardCount: -1, perCardSeconds: 30), 0)
        XCTAssertEqual(SGContract.earnedMinutes(cardCount: 1, perCardSeconds: 0), 0)
    }

    func testSmallAndPerfectRewardsRoundUpWithoutFiveMinuteFloor() {
        XCTAssertEqual(SGContract.completedQuizMinutes(results: [true], perCardSeconds: 30), 1)
        XCTAssertEqual(SGContract.completedQuizMinutes(
            results: Array(repeating: true, count: 5), perCardSeconds: 30), 3)
        XCTAssertEqual(SGContract.earnedMinutes(cardCount: 3, perCardSeconds: 60), 3)
    }

    func testEarnedBudgetCapAndLargeInputs() {
        XCTAssertEqual(SGContract.earnedMinutes(cardCount: 200, perCardSeconds: 30), 60)
        XCTAssertEqual(SGContract.earnedMinutes(cardCount: Int.max, perCardSeconds: Int.max), 60)
    }

    func testShortEarnedBudgetUsesShortUsageThresholdWithinDailySchedule() {
        for minutes in [1, 2, 3] {
            let events = SGContract.buildEvents(intervalMinutes: minutes, selection: FamilyActivitySelection())
            let limit = events[DeviceActivityEvent.Name(SGContract.limitEventName)]
            XCTAssertEqual(limit?.threshold, DateComponents(minute: minutes))
            XCTAssertEqual(limit?.includesPastActivity, false)
            XCTAssertEqual(events.count, minutes + 2) // primary + terminal + recovery
        }
        XCTAssertEqual(SGContract.dailySchedule.intervalStart, DateComponents(hour: 0, minute: 1))
        XCTAssertEqual(SGContract.dailySchedule.intervalEnd, DateComponents(hour: 23, minute: 59, second: 59))
    }

    // MARK: - Interval rounding (legacy BreakDurationMinutes seeding)

    func testNearestAllowedIntervalRoundsLegacyDefaultUp() {
        // Legacy default 5 min must seed to 10 (the minimum allowed).
        XCTAssertEqual(SGContract.nearestAllowedInterval(to: 5), 10)
    }

    func testNearestAllowedIntervalExactMatches() {
        for allowed in SGContract.allowedIntervals {
            XCTAssertEqual(SGContract.nearestAllowedInterval(to: allowed), allowed)
        }
    }

    func testNearestAllowedIntervalMidpoints() {
        XCTAssertEqual(SGContract.nearestAllowedInterval(to: 12), 10)   // closer to 10
        XCTAssertEqual(SGContract.nearestAllowedInterval(to: 13), 15)   // closer to 15
        XCTAssertEqual(SGContract.nearestAllowedInterval(to: 26), 30)   // closer to 30
        XCTAssertEqual(SGContract.nearestAllowedInterval(to: 999), 60)  // clamps to max
        XCTAssertEqual(SGContract.nearestAllowedInterval(to: 0), 10)    // clamps to min
    }

    // MARK: - Event construction

    func testPriorRegistrationCannotDebitOrLockNewBudget() throws {
        let suite = "StudyGuardGenerationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(15, forKey: SGContract.Keys.armedThresholdMinutes)
        let old = SGContract.beginMonitoringGeneration(defaults)
        let oldEvents = SGContract.buildEvents(intervalMinutes: 15, selection: FamilyActivitySelection(), generation: old)
        let current = SGContract.beginMonitoringGeneration(defaults)
        XCTAssertNotEqual(old, current)
        // A long wall-time gap must not make an old event valid again.
        defaults.set(Date().addingTimeInterval(-3_600).timeIntervalSince1970,
                     forKey: SGContract.Keys.budgetGrantedAt)
        for name in oldEvents.keys {
            XCTAssertNil(SGContract.usageEvent(named: name.rawValue, defaults: defaults))
        }
        let currentEvents = SGContract.buildEvents(intervalMinutes: 15, selection: FamilyActivitySelection(), generation: current)
        for name in currentEvents.keys {
            XCTAssertNotNil(SGContract.usageEvent(named: name.rawValue, defaults: defaults))
        }
        XCTAssertEqual(SGContract.usageEvent(named: "sg_limit:\(current)", defaults: defaults), .limit)
        XCTAssertEqual(SGContract.usageEvent(named: "sg_used_p14:\(current)", defaults: defaults), .progress(14))
        XCTAssertEqual(SGContract.usageEvent(named: "sg_used_p15:\(current)", defaults: defaults), .progress(15))
        XCTAssertEqual(SGContract.usageEvent(named: "sg_used_p16:\(current)", defaults: defaults), .progress(16))
    }

    func testLegacyRegistrationWorksOnlyUntilFirstGenerationIsArmed() throws {
        let suite = "StudyGuardLegacyEventsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(3, forKey: SGContract.Keys.armedThresholdMinutes)
        XCTAssertEqual(SGContract.usageEvent(named: "sg_limit", defaults: defaults), .limit)
        XCTAssertEqual(SGContract.usageEvent(named: "sg_used_p2", defaults: defaults), .progress(2))
        XCTAssertNil(SGContract.usageEvent(named: "sg_limit:unknown", defaults: defaults))
        let generation = SGContract.beginMonitoringGeneration(defaults)
        for name in ["sg_limit", "sg_used_p2", "", "sg_used_p0:\(generation)",
                     "sg_used_p5:\(generation)", "sg_limit:\(generation):extra"] {
            XCTAssertNil(SGContract.usageEvent(named: name, defaults: defaults))
        }
    }

    func testMissingLimitCallbackHasUsageBasedRecoveryEvents() {
        for minutes in [1, 2, 3, 15, 30, 60] {
            let events = SGContract.buildEvents(intervalMinutes: minutes, selection: FamilyActivitySelection())
            // Ignoring sg_limit entirely must still allow the recorded usage
            // to reach the budget, including a one-minute earned allowance.
            let terminal = events[DeviceActivityEvent.Name("\(SGContract.progressEventPrefix)\(minutes)")]
            let recovery = events[DeviceActivityEvent.Name("\(SGContract.progressEventPrefix)\(minutes + 1)")]
            XCTAssertEqual(terminal?.threshold, DateComponents(minute: minutes))
            XCTAssertEqual(recovery?.threshold, DateComponents(minute: minutes + 1))
            XCTAssertEqual(recovery?.includesPastActivity, false)
        }
    }

    func testBuildEventsContainsLimitEvent() {
        let events = SGContract.buildEvents(intervalMinutes: 15, selection: FamilyActivitySelection())
        XCTAssertNotNil(events[DeviceActivityEvent.Name(SGContract.limitEventName)])
    }

    func testBuildEventsProgressStepMath() {
        // Below-budget progress + primary limit + terminal/recovery progress.
        let n15 = SGContract.buildEvents(intervalMinutes: 15, selection: FamilyActivitySelection())
        XCTAssertEqual(n15.count, 17)

        // N=30 → step 2 → 2,4,…,28 + limit + terminal/recovery.
        let n30 = SGContract.buildEvents(intervalMinutes: 30, selection: FamilyActivitySelection())
        XCTAssertEqual(n30.count, 17)
        XCTAssertNotNil(n30[DeviceActivityEvent.Name("\(SGContract.progressEventPrefix)28")])
        XCTAssertNotNil(n30[DeviceActivityEvent.Name("\(SGContract.progressEventPrefix)30")])

        // N=60 → step 3 → 3,6,…,57 + limit + terminal/recovery = 22.
        let n60 = SGContract.buildEvents(intervalMinutes: 60, selection: FamilyActivitySelection())
        XCTAssertEqual(n60.count, 22)
    }

    func testBuildEventsProgressIncludesBoundedRecoveryBeyondLimit() {
        for n in SGContract.allowedIntervals {
            let events = SGContract.buildEvents(intervalMinutes: n, selection: FamilyActivitySelection())
            let progressMinutes = events.keys
                .map(\.rawValue)
                .filter { $0.hasPrefix(SGContract.progressEventPrefix) }
                .compactMap { Int($0.dropFirst(SGContract.progressEventPrefix.count)) }
            XCTAssertFalse(progressMinutes.isEmpty, "N=\(n) should have progress events")
            XCTAssertEqual(progressMinutes.max(), n + 1)
            XCTAssertTrue(progressMinutes.contains(n))
            // At most 19 below-budget samples plus two recovery samples.
            XCTAssertLessThanOrEqual(progressMinutes.count, 21)
        }
    }

    // MARK: - Emergency ledger

    func testEmergencyLedgerRemainingFreshUser() {
        XCTAssertEqual(EmergencyLedger.remaining([]), SGContract.emergencyUnlocksPerWeek)
    }

    func testEmergencyLedgerPrunesOldEntries() {
        let now: Double = 1_800_000_000
        let eightDaysAgo = now - 8 * 86_400
        let yesterday = now - 86_400
        let pruned = EmergencyLedger.prune([eightDaysAgo, yesterday], now: now)
        XCTAssertEqual(pruned, [yesterday])
        XCTAssertEqual(EmergencyLedger.remaining([eightDaysAgo, yesterday], now: now),
                       SGContract.emergencyUnlocksPerWeek - 1)
    }

    func testEmergencyLedgerExhaustionAndNextAvailable() {
        let now: Double = 1_800_000_000
        let stamps = [now - 3 * 86_400, now - 2 * 86_400, now - 86_400]
        XCTAssertEqual(EmergencyLedger.remaining(stamps, now: now), 0)
        let next = EmergencyLedger.nextAvailableDate(stamps, now: now)
        XCTAssertEqual(next?.timeIntervalSince1970, stamps.min()! + SGContract.emergencyWindowSeconds)
    }

    func testEmergencyLedgerNextAvailableNilWhenNotExhausted() {
        let now: Double = 1_800_000_000
        XCTAssertNil(EmergencyLedger.nextAvailableDate([now - 86_400], now: now))
    }

    // MARK: - GuardState derivation

    private func makeDefaults() -> UserDefaults {
        let suite = "test.studyguard.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    func testGuardStateNotSetUpByDefault() {
        XCTAssertEqual(GuardState.derive(from: makeDefaults()), .notSetUp)
    }

    func testGuardStateDisabledWhenToggledOff() {
        let d = makeDefaults()
        d.set(true, forKey: SGContract.Keys.setupComplete)
        d.set(false, forKey: SGContract.Keys.guardEnabled)
        XCTAssertEqual(GuardState.derive(from: d), .disabled)
    }

    func testGuardStateMeteringAndLocked() {
        let d = makeDefaults()
        d.set(true, forKey: SGContract.Keys.setupComplete)
        d.set(true, forKey: SGContract.Keys.guardEnabled)
        XCTAssertEqual(GuardState.derive(from: d), .metering)
        d.set(SGContract.StateValue.locked, forKey: SGContract.Keys.state)
        XCTAssertEqual(GuardState.derive(from: d), .locked)
        d.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
        XCTAssertEqual(GuardState.derive(from: d), .metering)
    }
}
