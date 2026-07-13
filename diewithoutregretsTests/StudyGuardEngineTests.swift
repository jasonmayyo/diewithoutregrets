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

    func testBuildEventsContainsLimitEvent() {
        let events = SGContract.buildEvents(intervalMinutes: 15, selection: FamilyActivitySelection())
        XCTAssertNotNil(events[DeviceActivityEvent.Name(SGContract.limitEventName)])
    }

    func testBuildEventsProgressStepMath() {
        // step = max(1, ceil(N/20)): N=15 → 1-min steps → events at 1..14 (14) + limit.
        let n15 = SGContract.buildEvents(intervalMinutes: 15, selection: FamilyActivitySelection())
        XCTAssertEqual(n15.count, 15) // 14 progress + 1 limit

        // N=30 → step 2 → 2,4,…,28 (14 progress) + limit.
        let n30 = SGContract.buildEvents(intervalMinutes: 30, selection: FamilyActivitySelection())
        XCTAssertEqual(n30.count, 15)
        XCTAssertNotNil(n30[DeviceActivityEvent.Name("\(SGContract.progressEventPrefix)28")])
        XCTAssertNil(n30[DeviceActivityEvent.Name("\(SGContract.progressEventPrefix)30")]) // < N, never == N

        // N=60 → step 3 → 3,6,…,57 (19 progress) + limit = 20 total (≤ 20 progress cap holds).
        let n60 = SGContract.buildEvents(intervalMinutes: 60, selection: FamilyActivitySelection())
        XCTAssertEqual(n60.count, 20)
    }

    func testBuildEventsProgressNeverReachesLimit() {
        for n in SGContract.allowedIntervals {
            let events = SGContract.buildEvents(intervalMinutes: n, selection: FamilyActivitySelection())
            let progressMinutes = events.keys
                .map(\.rawValue)
                .filter { $0.hasPrefix(SGContract.progressEventPrefix) }
                .compactMap { Int($0.dropFirst(SGContract.progressEventPrefix.count)) }
            XCTAssertFalse(progressMinutes.isEmpty, "N=\(n) should have progress events")
            XCTAssertLessThan(progressMinutes.max() ?? 0, n)
            // Progress cap: at most 20 progress events.
            XCTAssertLessThanOrEqual(progressMinutes.count, 20)
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
