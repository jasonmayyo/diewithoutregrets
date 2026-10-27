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

// MARK: - Tutor Monster foundation (Phase 0)

/// Unit tests for the invisible Phase 0 foundation: Leitner mastery on cards,
/// the pressure→mood escalation ladder, gate-encounter counters, weighted card
/// selection, the multi-exam model + onboarding migration, and persona storage.
final class TutorMonsterFoundationTests: XCTestCase {

    private func makeCard(topic: String? = nil, box: Int = 1) -> Regret {
        Regret(regretPrompt: "Q", regret: "A", choices: ["A", "B"],
               correctAnswerIndex: 0, backgroundExplanation: "",
               box: box, topic: topic)
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.tutormonster.\(UUID().uuidString)")!
    }

    // MARK: Leitner mastery

    func testNewCardIsWeakDueAndUnmastered() {
        let c = makeCard()
        XCTAssertEqual(c.box, 1)
        XCTAssertTrue(c.isWeak)
        XCTAssertTrue(c.isDue())
        XCTAssertEqual(c.masteryStrength, 0, accuracy: 0.0001)
        XCTAssertEqual(c.accuracy, 0, accuracy: 0.0001)
    }

    func testCorrectAnswerPromotesBoxAndSchedulesForward() {
        var c = makeCard()
        let now = Date()
        c.recordReview(correct: true, now: now)
        XCTAssertEqual(c.box, 2)
        XCTAssertEqual(c.timesSeen, 1)
        XCTAssertEqual(c.timesCorrect, 1)
        XCTAssertFalse(c.isDue(asOf: now))                               // box 2 is due in a day
        XCTAssertTrue(c.isDue(asOf: now.addingTimeInterval(2 * 86_400)))
    }

    func testBoxClimbsToMaxAndCaps() {
        var c = makeCard()
        for _ in 0..<10 { c.recordReview(correct: true) }
        XCTAssertEqual(c.box, Regret.maxBox)
        XCTAssertFalse(c.isWeak)
        XCTAssertEqual(c.masteryStrength, 1, accuracy: 0.0001)
    }

    func testWrongAnswerResetsToBoxOne() {
        var c = makeCard()
        c.recordReview(correct: true)
        c.recordReview(correct: true)     // box 3
        c.recordReview(correct: false)    // reset
        XCTAssertEqual(c.box, 1)
        XCTAssertTrue(c.isWeak)
        XCTAssertTrue(c.isDue())
        XCTAssertEqual(c.timesSeen, 3)
        XCTAssertEqual(c.timesCorrect, 2)
        XCTAssertEqual(c.accuracy, 2.0 / 3.0, accuracy: 0.0001)
    }

    // MARK: Pressure → mood ladder

    func testCalmContextIsChill() {
        XCTAssertEqual(SGContract.dials(for: SGContract.PressureInputs()).mood, .chill)
    }

    func testNearbyExamAndScrollingClimbsToAnnoyed() {
        let p = SGContract.PressureInputs(gateEncountersToday: 10, daysSinceStudy: 2, nearestExamDays: 5)
        XCTAssertEqual(SGContract.pressureScore(p), 6)   // 2 + 2 + 2
        XCTAssertEqual(SGContract.mood(forScore: 6), .annoyed)
    }

    func testRelentlessContextIsFeral() {
        let p = SGContract.PressureInputs(gateEncountersToday: 40, daysSinceStudy: 5,
                                          nearestExamDays: 0, weakCardLoad: 20, fastBurn: true)
        XCTAssertEqual(SGContract.pressureScore(p), 14) // 4 + 3 + 4 + 2 + 1
        XCTAssertEqual(SGContract.dials(for: p).mood, .feral)
    }

    func testPastExamAddsNoPressure() {
        XCTAssertEqual(SGContract.pressureScore(SGContract.PressureInputs(nearestExamDays: -3)), 0)
    }

    func testEscalationTurnsAllThreeDials() {
        let chill = SGContract.dials(for: .chill)
        let feral = SGContract.dials(for: .feral)
        XCTAssertEqual(chill.questions, 3);  XCTAssertEqual(chill.minutesBack, 6)
        XCTAssertEqual(feral.questions, 10); XCTAssertEqual(feral.minutesBack, 2)
        XCTAssertGreaterThan(feral.questions, chill.questions)   // more work
        XCTAssertLessThan(feral.minutesBack, chill.minutesBack)  // less reward
    }

    func testPerCardSecondsRealizesMoodReward() {
        XCTAssertEqual(SGContract.perCardSeconds(for: SGContract.dials(for: .chill)), 120) // 6m / 3
        XCTAssertEqual(SGContract.perCardSeconds(for: SGContract.dials(for: .feral)), 12)  // 2m / 10
    }

    // MARK: Gate-encounter counters

    func testGateEncounterIncrementsForToday() {
        let d = freshDefaults()
        XCTAssertEqual(SGContract.gateEncountersToday(d), 0)
        SGContract.recordGateEncounter(d)
        SGContract.recordGateEncounter(d)
        XCTAssertEqual(SGContract.gateEncountersToday(d), 2)
    }

    func testGateEncounterPruneDropsOldDays() {
        let d = freshDefaults()
        let oldKey = SGContract.gateEncounterKey(day: SGContract.dayStamp(Date().addingTimeInterval(-86_400)))
        d.set(5, forKey: oldKey)
        SGContract.recordGateEncounter(d)
        SGContract.pruneOldGateEncounters(d)
        XCTAssertEqual(d.integer(forKey: oldKey), 0)
        XCTAssertEqual(SGContract.gateEncountersToday(d), 1)
    }

    // MARK: Deck aggregation + weighted selection

    func testDeckTopicsAndWeakness() {
        var cards = [makeCard(topic: "A"), makeCard(topic: "A"), makeCard(topic: "B")]
        cards[0].recordReview(correct: true)
        cards[0].recordReview(correct: true)   // one A card now stronger
        let deck = Deck(name: "D", cards: cards)
        XCTAssertEqual(Set(deck.topics), ["A", "B"])
        let tw = deck.topicWeakness()
        XCTAssertEqual(tw["B"] ?? 0, 1, accuracy: 0.0001)      // all of B is weak
        XCTAssertLessThan(tw["A"] ?? 1, 1)                     // A partially mastered
        XCTAssertGreaterThan(deck.masteryFraction, 0)
    }

    func testSelectionFavorsWeakExamTopicCards() {
        var strongs: [Regret] = []
        for _ in 0..<5 {
            var s = makeCard(topic: "easy")
            for _ in 0..<5 { s.recordReview(correct: true) }
            strongs.append(s)
        }
        let examWeak = (0..<8).map { _ in makeCard(topic: "exam") }
        let cards = strongs + examWeak

        var rng = SystemRandomNumberGenerator()
        let trials = 200
        var examHits = 0
        for _ in 0..<trials {
            let pick = CardSelection.pick(from: cards, count: 3, examTopics: ["exam"], using: &rng)
            XCTAssertEqual(pick.count, 3)
            examHits += pick.filter { $0.topic == "exam" }.count
        }
        // Weakness + exam weighting pushes well past the unweighted 8/13 ≈ 0.62.
        XCTAssertGreaterThan(Double(examHits) / Double(trials * 3), 0.8)
    }

    func testSelectionReturnsWholeDeckWhenCountExceedsIt() {
        let cards = [makeCard(), makeCard()]
        XCTAssertEqual(CardSelection.pick(from: cards, count: 5).count, 2)
    }

    // MARK: Exams + migration

    func testStudyExamDaysUntilAndUpcoming() {
        let cal = Calendar.current
        let exam = StudyExam(subject: "Bio", date: cal.date(byAdding: .day, value: 3, to: Date())!)
        XCTAssertEqual(exam.daysUntil(), 3)
        XCTAssertTrue(exam.isUpcoming)
        let past = StudyExam(subject: "Old", date: cal.date(byAdding: .day, value: -2, to: Date())!)
        XCTAssertFalse(past.isUpcoming)
    }

    func testExamStoreMigratesOnboardingExamAndMirrorsNearest() {
        let d = freshDefaults()
        let shared = freshDefaults()
        let ts = Date().addingTimeInterval(5 * 86_400).timeIntervalSince1970
        d.set(ts, forKey: "examDate")
        d.set("Chemistry", forKey: "studySubject")

        let store = ExamStore(defaults: d, sharedDefaults: shared)
        XCTAssertEqual(store.exams.count, 1)
        XCTAssertEqual(store.exams.first?.subject, "Chemistry")
        XCTAssertEqual(store.nextExam?.subject, "Chemistry")
        XCTAssertEqual(shared.double(forKey: SGContract.Keys.onboardingExamDate), ts, accuracy: 1)
    }

    func testExamStoreEmptyWithoutOnboardingExam() {
        XCTAssertTrue(ExamStore(defaults: freshDefaults(), sharedDefaults: nil).exams.isEmpty)
    }

    // MARK: Personas

    func testPersonaStoreDefaultsToFallbackAndPersists() {
        let d = freshDefaults()
        let store = PersonaStore(defaults: d)
        XCTAssertEqual(store.persona.id, MonsterPersona.fallback.id)
        store.select(.diva)
        XCTAssertEqual(PersonaStore(defaults: d).persona.name, "Zaza")
    }

    func testPersonaLookupFallsBack() {
        XCTAssertEqual(MonsterPersona.with(id: "nope").id, MonsterPersona.fallback.id)
        XCTAssertEqual(MonsterPersona.with(id: nil).id, MonsterPersona.fallback.id)
        XCTAssertEqual(MonsterPersona.all.count, 4)
    }
}
