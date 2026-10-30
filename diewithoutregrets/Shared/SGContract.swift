//
//  SGContract.swift
//  Study Guard v2 — Screen Time engine contract
//
//  Single source of truth for every app-group key, activity/event name, and
//  the event-building rule shared between the main app and the Screen Time
//  extensions. This file is a member of ALL SIX targets (app, StudyGuardMonitor,
//  StudyGuardShield, StudyGuardShieldAction, RegretGuardIntent, OpenGuardIntent)
//  so the cross-process contract can never drift. Full written spec:
//  Docs/StudyGuardAppGroupContract.md
//

import Foundation
#if canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity
import FamilyControls
#endif

enum SGContract {

    static let appGroupID = "group.com.jasonmayo.diewithoutregrets"

    /// The named ManagedSettingsStore that holds Study Guard's shields.
    /// Study Guard never touches the default (unnamed) store, so it coexists
    /// with the user's own Screen Time limits/Downtime.
    static let storeName = "studyGuardLock"

    /// The single DeviceActivity activity. Daily repeating 00:01–23:59:59
    /// (00:01 because schedules starting exactly at 00:00 misbehave).
    static let activityName = "sg_daily"

    /// The lock-trigger event: N minutes of cumulative usage on the selection.
    static let limitEventName = "sg_limit"

    /// Progress events "sg_used_p<minutes>" — approximate usage telemetry,
    /// since the Screen Time API provides no live usage feed.
    static let progressEventPrefix = "sg_used_p"

    // Notifications posted by the monitor extension.
    static let lockNotificationID = "sg_lock_notification"
    static let warningNotificationID = "sg_warning_notification"
    static let unlockDeepLink = "diewithoutregrets://unlock"

    /// The host app's bundle identifier — used by the shield-action extension's
    /// direct-open path to foreground the app.
    static let hostBundleID = "com.jasonmayo.diewithoutregrets"

    /// Allowed usage intervals (minutes) and the default.
    static let allowedIntervals = [10, 15, 20, 30, 45, 60]
    static let defaultIntervalMinutes = 15

    /// Earned-time economy: each correct flashcard in the unlock quiz earns
    /// this many seconds of screen time. Completed quizzes grant time for
    /// correct answers only, rounded UP to whole minutes to match our metering
    /// and capped at maxEarnedMinutes. This rounding is an app policy, not an
    /// Apple minimum: the monitoring schedule and usage threshold are separate.
    static let defaultPerCardSeconds = 30
    static let maxEarnedMinutes = 60

    /// Emergency unlocks allowed per rolling 7-day window.
    static let emergencyUnlocksPerWeek = 3
    static let emergencyWindowSeconds: Double = 7 * 86_400

    /// Shield caps at 50 tokens total; the picker enforces this with revert.
    static let maxSelectionTokens = 50

    // MARK: - App-group keys

    enum Keys {
        /// THE migration kill switch. Written only after monitoring verifiably
        /// started. Never un-set except full reset. When true, both legacy
        /// intents (RegretGuardIntent/OpenGuardIntent) become silent no-ops.
        static let setupComplete = "sg_setupComplete"
        static let guardEnabled = "sg_guardEnabled"
        /// JSON-encoded FamilyActivitySelection — the only token hand-off to extensions.
        static let selection = "sg_selection"
        /// Single source of truth for N (no @AppStorage mirror).
        static let intervalMinutes = "sg_intervalMinutes"
        /// Seconds of screen time one correct flashcard earns. Unset means
        /// defaultPerCardSeconds; the onboarding plan builder will write it.
        static let perCardSeconds = "sg_perCardSeconds"
        /// Exam date (timeIntervalSince1970) written by onboarding's
        /// reality-check step so the report extension can render the
        /// real-usage verdict ("your phone will eat X of your Y days").
        /// Usage numbers can never leave the report sandbox — the exam date
        /// crossing INTO it is the only data hand-off.
        static let onboardingExamDate = "sg_onbExamDate"
        /// "metering" | "locked" (StateValue).
        static let state = "sg_state"
        static let lockedAt = "sg_lockedAt"
        static let budgetGrantedAt = "sg_budgetGrantedAt"
        static let budgetTotalSeconds = "sg_budgetTotalSeconds"
        /// Written by the extension at progress events; reset to 0 by the app on grant.
        static let budgetUsedSeconds = "sg_budgetUsedSeconds"
        static let warnedThisBudget = "sg_warnedThisBudget"
        /// Threshold minutes actually armed at the last startMonitoring —
        /// diverges from intervalMinutes after a re-baseline; the extension
        /// normalizes it back at day rollover.
        static let armedThresholdMinutes = "sg_armedThresholdMinutes"
        /// Identity of the current event registration, carried in every event
        /// name so late callbacks cannot consume a subsequent earned budget.
        static let monitoringGeneration = "sg_monitoringGeneration"
        /// JSON [Double] — rolling 7-day emergency-unlock ledger.
        static let emergencyUnlockTimestamps = "sg_emergencyUnlockTimestamps"
        static let needsReauth = "sg_needsReauth"
        /// Start-of-day (timeIntervalSince1970) of the last processed rollover.
        static let lastRolloverDay = "sg_lastRolloverDay"
        static let lockNotifThrottleAt = "sg_lockNotifThrottleAt"
        /// Stamped by the shield action extension when the user taps
        /// "Open Study Guard" on the shield; consumed by the app on
        /// foreground to land directly on the unlock flow.
        static let shieldTapAt = "sg_shieldTapAt"
        /// Mirrored by PersonaStore for the shield configuration extension.
        static let selectedPersonaID = "sg_selectedPersonaID"
        static let shieldReturnCandidates = "sg_shieldReturnCandidates"
        static let pendingShieldReturn = "sg_pendingShieldReturn"
        /// [String] ring buffer (≤200) — extension debug log, viewable in the app's Debug tab.
        static let extLog = "sg_extLog"
        /// JSON [[String: Any]] — analytics queued by the extension, drained by the app.
        static let pendingEvents = "sg_pendingEvents"
        /// Drain-side twin of pendingEvents (swap-to-drain avoids the
        /// extension-append vs app-drain read-modify-write race).
        static let pendingEventsDraining = "sg_pendingEventsDraining"
        /// Count of legacy-intent fires after migration (analytics tail).
        static let legacyIntentFireCount = "LegacyIntentFireCount"

        // Legacy v1 keys — still written while !sg_setupComplete, frozen after.
        static let legacyLastBreakTime = "LastBreakTime"
        static let legacyBreakDurationMinutes = "BreakDurationMinutes"
        static let legacyUserAllowedBreak = "UserAllowedBreak"
        static let legacyLastGuardedApp = "LastGuardedApp"
    }

    enum StateValue {
        static let metering = "metering"
        static let locked = "locked"
    }

    // MARK: - Shared helpers

    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    @discardableResult
    static func beginMonitoringGeneration(_ defaults: UserDefaults) -> String {
        let generation = UUID().uuidString
        defaults.set(generation, forKey: Keys.monitoringGeneration)
        return generation
    }

    static func monitoringEventName(_ base: String, generation: String?) -> String {
        generation.map { "\(base):\($0)" } ?? base
    }

    enum UsageEvent: Equatable {
        case limit
        case progress(Int)
    }

    /// Reject old registrations by identity, even hours after the next grant.
    /// Generationless names remain valid only until an upgrade first re-arms.
    static func usageEvent(named name: String, defaults: UserDefaults) -> UsageEvent? {
        let parts = name.split(separator: ":", omittingEmptySubsequences: false)
        if let generation = defaults.string(forKey: Keys.monitoringGeneration) {
            guard parts.count == 2, parts[1] == generation else { return nil }
        } else {
            guard parts.count == 1 else { return nil }
        }
        let base = String(parts[0])
        if base == limitEventName { return .limit }
        guard base.hasPrefix(progressEventPrefix),
              let minutes = Int(base.dropFirst(progressEventPrefix.count)), minutes > 0,
              minutes <= defaults.integer(forKey: Keys.armedThresholdMinutes) + 1 else { return nil }
        return .progress(minutes)
    }

    /// Round an arbitrary minute count to the nearest allowed interval
    /// (used to seed sg_intervalMinutes from the legacy BreakDurationMinutes;
    /// legacy default 5 rounds up to 10).
    static func nearestAllowedInterval(to minutes: Int) -> Int {
        allowedIntervals.min {
            (abs($0 - minutes), $0) < (abs($1 - minutes), $1)
        } ?? defaultIntervalMinutes
    }

    /// The per-card earn rate, falling back to the default when unset (or when
    /// the app group is unavailable).
    static func perCardSeconds(_ defaults: UserDefaults?) -> Int {
        let n = defaults?.integer(forKey: Keys.perCardSeconds) ?? 0
        return n > 0 ? n : defaultPerCardSeconds
    }

    /// Minutes earned by `cardCount` correct answers. No correct answers means
    /// no grant; a positive reward is rounded up, never discarded by a minimum.
    static func earnedMinutes(cardCount: Int, perCardSeconds rate: Int) -> Int {
        guard cardCount > 0, rate > 0 else { return 0 }
        let raw = (Double(cardCount) * Double(rate) / 60).rounded(.up)
        return Int(min(Double(maxEarnedMinutes), raw))
    }

    /// The completion rule shared by both Screen Time quiz routes. A wrong
    /// final answer must not cancel earlier earnings; incomplete/empty quizzes
    /// must not unlock apps.
    static func completedQuizMinutes(results: [Bool?], perCardSeconds rate: Int) -> Int {
        guard !results.isEmpty, results.allSatisfy({ $0 != nil }) else { return 0 }
        return earnedMinutes(cardCount: results.filter { $0 == true }.count, perCardSeconds: rate)
    }

    // MARK: - Gate-encounter counters (tutor-monster pressure signal)
    //
    // iOS gives the app process no live usage feed, so "how hard is the user
    // hammering the lock" is something WE count: the shield-action extension bumps
    // a per-day counter on every "Study to unlock" tap, and the app reads it to
    // drive the monster's mood. Pure UserDefaults — safe on the extension hot path.

    private static let gateEncounterPrefix = "sg_gateEnc_"

    /// yyyyMMdd in the given calendar, for day-keyed counters.
    static func dayStamp(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func gateEncounterKey(day: String) -> String { gateEncounterPrefix + day }

    /// Increment today's gate-encounter count. Minimal work for the shield hot path.
    static func recordGateEncounter(_ defaults: UserDefaults?, now: Date = Date()) {
        guard let defaults else { return }
        let key = gateEncounterKey(day: dayStamp(now))
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    /// Today's gate-encounter count (unlock attempts on the shield).
    static func gateEncountersToday(_ defaults: UserDefaults?, now: Date = Date()) -> Int {
        defaults?.integer(forKey: gateEncounterKey(day: dayStamp(now))) ?? 0
    }

    /// Remove stale day-counters (anything but today). App-side cleanup, kept off
    /// the extension hot path.
    static func pruneOldGateEncounters(_ defaults: UserDefaults?, now: Date = Date()) {
        guard let defaults else { return }
        let keep = gateEncounterKey(day: dayStamp(now))
        for k in defaults.dictionaryRepresentation().keys
        where k.hasPrefix(gateEncounterPrefix) && k != keep {
            defaults.removeObject(forKey: k)
        }
    }

    // MARK: - Tutor-monster mood (pressure → escalation dials)
    //
    // Pure and testable. Starting numbers from Docs/TutorMonsterPlan.md Appendix A.
    // Primitives only (no app-model deps) so this compiles into every target and
    // the shield can derive the monster's mood for its copy later.

    enum MonsterMood: Int, Comparable, CaseIterable {
        case chill = 0, nudgy, annoyed, fedUp, feral
        static func < (lhs: MonsterMood, rhs: MonsterMood) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    struct PressureInputs: Equatable {
        var gateEncountersToday: Int = 0
        var daysSinceStudy: Int = 0       // 0 = studied today
        var nearestExamDays: Int? = nil   // nil = no upcoming exam
        var weakCardLoad: Int = 0         // count of weak/overdue cards
        var fastBurn: Bool = false        // last grant spent unusually fast
    }

    struct MoodDials: Equatable {
        var mood: MonsterMood
        var questions: Int      // toll size
        var minutesBack: Int    // screen-time reward on a pass
    }

    /// 0...~12 pressure score from app-observable signals.
    static func pressureScore(_ p: PressureInputs) -> Int {
        var score = 0
        switch p.gateEncountersToday {
        case ..<3: break
        case 3...5: score += 1
        case 6...15: score += 2
        case 16...30: score += 3
        default: score += 4
        }
        switch p.daysSinceStudy {
        case ..<1: break
        case 1: score += 1
        case 2...3: score += 2
        default: score += 3
        }
        if let d = p.nearestExamDays, d >= 0 {
            switch d {
            case 0: score += 4
            case 1...2: score += 3
            case 3...6: score += 2
            case 7...14: score += 1
            default: break
            }
        }
        switch p.weakCardLoad {
        case ..<5: break
        case 5...15: score += 1
        default: score += 2
        }
        if p.fastBurn { score += 1 }
        return score
    }

    static func mood(forScore score: Int) -> MonsterMood {
        switch score {
        case ..<3: return .chill
        case 3...4: return .nudgy
        case 5...6: return .annoyed
        case 7...9: return .fedUp
        default: return .feral
        }
    }

    static func dials(for mood: MonsterMood) -> MoodDials {
        switch mood {
        case .chill:   return MoodDials(mood: .chill,   questions: 3,  minutesBack: 6)
        case .nudgy:   return MoodDials(mood: .nudgy,   questions: 4,  minutesBack: 5)
        case .annoyed: return MoodDials(mood: .annoyed, questions: 6,  minutesBack: 4)
        case .fedUp:   return MoodDials(mood: .fedUp,   questions: 8,  minutesBack: 3)
        case .feral:   return MoodDials(mood: .feral,   questions: 10, minutesBack: 2)
        }
    }

    static func dials(for inputs: PressureInputs) -> MoodDials {
        dials(for: mood(forScore: pressureScore(inputs)))
    }

    /// Per-card seconds that realizes a mood's `minutesBack` across `questions`
    /// correct answers, so the existing earn economy pays the intended reward.
    static func perCardSeconds(for dials: MoodDials) -> Int {
        guard dials.questions > 0 else { return defaultPerCardSeconds }
        return max(1, Int((Double(dials.minutesBack) * 60 / Double(dials.questions)).rounded()))
    }

    /// Append a timestamped line to the extension debug ring buffer (≤200 entries).
    static func appendExtLog(_ defaults: UserDefaults, _ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        var log = defaults.stringArray(forKey: Keys.extLog) ?? []
        log.append("[\(stamp)] \(message)")
        if log.count > 200 { log = Array(log.suffix(200)) }
        defaults.set(log, forKey: Keys.extLog)
    }

    /// Queue an analytics event from an extension (PostHog can't run there).
    /// The app drains the queue on foreground with original timestamps.
    static func enqueueAnalyticsEvent(_ defaults: UserDefaults, name: String, properties: [String: String] = [:]) {
        var payload: [String: Any] = [
            "event": name,
            "timestamp": Date().timeIntervalSince1970,
        ]
        properties.forEach { payload[$0.key] = $0.value }
        var queue: [[String: Any]] = []
        if let data = defaults.data(forKey: Keys.pendingEvents),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            queue = existing
        }
        queue.append(payload)
        if queue.count > 100 { queue = Array(queue.suffix(100)) }
        if let data = try? JSONSerialization.data(withJSONObject: queue) {
            defaults.set(data, forKey: Keys.pendingEvents)
        }
    }

    #if canImport(DeviceActivity) && canImport(FamilyControls)

    static var activity: DeviceActivityName { DeviceActivityName(activityName) }

    /// Daily repeating schedule. repeats:true gives the free daily accumulator
    /// reset at the interval boundary.
    static var dailySchedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 1),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
    }

    /// Build the full event set for one budget: the sg_limit lock trigger at
    /// N minutes plus progress events every step = max(1, ceil(N/20)) minutes.
    /// Terminal progress at N and recovery at N+1 let the missed-lock fallback
    /// reach the total even if the primary limit callback never arrives.
    /// Always concrete tokens (empty-token events never fire) and
    /// includesPastActivity:false (a restart must count usage from zero).
    static func buildEvents(intervalMinutes n: Int, selection: FamilyActivitySelection, generation: String? = nil) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        func name(_ base: String) -> DeviceActivityEvent.Name {
            DeviceActivityEvent.Name(monitoringEventName(base, generation: generation))
        }
        func event(thresholdMinutes: Int) -> DeviceActivityEvent {
            DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: thresholdMinutes),
                includesPastActivity: false
            )
        }
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            name(limitEventName): event(thresholdMinutes: n)
        ]
        let step = max(1, Int((Double(n) / 20.0).rounded(.up)))
        var m = step
        while m < n {
            events[name("\(progressEventPrefix)\(m)")] = event(thresholdMinutes: m)
            m += step
        }
        events[name("\(progressEventPrefix)\(n)")] = event(thresholdMinutes: n)
        events[name("\(progressEventPrefix)\(n + 1)")] = event(thresholdMinutes: n + 1)
        return events
    }

    static func decodeSelection(_ defaults: UserDefaults) -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: Keys.selection) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func isSelectionEmpty(_ selection: FamilyActivitySelection) -> Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }

    static func tokenCount(_ selection: FamilyActivitySelection) -> Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    #endif
}
