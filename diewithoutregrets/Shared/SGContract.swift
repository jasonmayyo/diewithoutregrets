//
//  SGContract.swift
//  Study Guard v2 — Screen Time engine contract
//
//  Single source of truth for every app-group key, activity/event name, and
//  the event-building rule shared between the main app and the Screen Time
//  extensions. This file is a member of ALL FIVE targets (app, StudyGuardMonitor,
//  StudyGuardShield, RegretGuardIntent, OpenGuardIntent) so the cross-process
//  contract can never drift. Full written spec: Docs/StudyGuardAppGroupContract.md
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

    /// Allowed usage intervals (minutes) and the default.
    static let allowedIntervals = [10, 15, 20, 30, 45, 60]
    static let defaultIntervalMinutes = 15

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
        /// JSON [Double] — rolling 7-day emergency-unlock ledger.
        static let emergencyUnlockTimestamps = "sg_emergencyUnlockTimestamps"
        static let needsReauth = "sg_needsReauth"
        /// Start-of-day (timeIntervalSince1970) of the last processed rollover.
        static let lastRolloverDay = "sg_lastRolloverDay"
        static let lockNotifThrottleAt = "sg_lockNotifThrottleAt"
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

    /// Round an arbitrary minute count to the nearest allowed interval
    /// (used to seed sg_intervalMinutes from the legacy BreakDurationMinutes;
    /// legacy default 5 rounds up to 10).
    static func nearestAllowedInterval(to minutes: Int) -> Int {
        allowedIntervals.min {
            (abs($0 - minutes), $0) < (abs($1 - minutes), $1)
        } ?? defaultIntervalMinutes
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
    /// Always concrete tokens (empty-token events never fire) and
    /// includesPastActivity:false (a restart must count usage from zero).
    static func buildEvents(intervalMinutes n: Int, selection: FamilyActivitySelection) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
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
            DeviceActivityEvent.Name(limitEventName): event(thresholdMinutes: n)
        ]
        let step = max(1, Int((Double(n) / 20.0).rounded(.up)))
        var m = step
        while m < n {
            events[DeviceActivityEvent.Name("\(progressEventPrefix)\(m)")] = event(thresholdMinutes: m)
            m += step
        }
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
