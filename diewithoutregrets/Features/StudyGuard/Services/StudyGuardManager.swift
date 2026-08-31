//
//  StudyGuardManager.swift
//  diewithoutregrets
//
//  The Study Guard v2 engine — the ONLY app-side code that touches
//  DeviceActivityCenter or ManagedSettingsStore. Views observe the published
//  surface and call the API; the monitor extension is the other half of the
//  contract (see Docs/StudyGuardAppGroupContract.md).
//
//  Reliability model: Apple's eventDidReachThreshold is unreliable, so every
//  transition has three layers — extension callbacks, the foreground
//  reconcile in this file, and read guards on state derivation.
//

import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class StudyGuardManager: ObservableObject {

    static let shared = StudyGuardManager()

    // MARK: - Published surface

    @Published private(set) var state: GuardState = .notSetUp
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selection = FamilyActivitySelection()
    @Published private(set) var intervalMinutes: Int = SGContract.defaultIntervalMinutes
    /// Approximate — updated by extension progress events; correct-on-return.
    @Published private(set) var usedMinutes: Int = 0
    @Published private(set) var totalMinutes: Int = SGContract.defaultIntervalMinutes
    @Published private(set) var emergencyUnlocksRemaining: Int = SGContract.emergencyUnlocksPerWeek
    @Published private(set) var nextEmergencyUnlockDate: Date?
    @Published private(set) var needsReauth: Bool = false

    var isSetupComplete: Bool { state != .notSetUp }

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore(named: .init(SGContract.storeName))
    private var defaults: UserDefaults? { SGContract.sharedDefaults }

    #if DEBUG
    /// Set by SGPreviewHarness: freezes reconcile so simulator screenshot
    /// states aren't reverted (no real Screen Time auth exists there).
    var previewFrozen = false
    #endif

    private init() {
        refresh()
    }

    // MARK: - Refresh (app-group → published)

    func refresh() {
        guard let d = defaults else { return }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        state = GuardState.derive(from: d)
        if let stored = SGContract.decodeSelection(d) {
            selection = stored
        }
        let interval = d.integer(forKey: SGContract.Keys.intervalMinutes)
        intervalMinutes = interval > 0 ? interval : SGContract.defaultIntervalMinutes
        let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
        totalMinutes = total > 0 ? Int(total / 60) : intervalMinutes
        // Read guard: used minutes only meaningful for a budget granted today.
        let grantedAt = Date(timeIntervalSince1970: d.double(forKey: SGContract.Keys.budgetGrantedAt))
        usedMinutes = Calendar.current.isDateInToday(grantedAt)
            ? min(totalMinutes, Int(d.double(forKey: SGContract.Keys.budgetUsedSeconds) / 60))
            : 0
        let ledger = EmergencyLedger.load(from: d)
        emergencyUnlocksRemaining = EmergencyLedger.remaining(ledger)
        nextEmergencyUnlockDate = EmergencyLedger.nextAvailableDate(ledger)
        needsReauth = d.bool(forKey: SGContract.Keys.needsReauth)
    }

    // MARK: - Authorization

    /// FamilyActivityPicker shows an empty list without prior approval —
    /// always call this before presenting the picker, and re-check at tap time.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            Telemetry.capture(error, context: [:], tags: ["feature": "study_guard", "operation": "request_authorization"])
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        if authorizationStatus == .approved, let d = defaults {
            d.set(false, forKey: SGContract.Keys.needsReauth)
            needsReauth = false
        }
        return authorizationStatus == .approved
    }

    // MARK: - Setup

    enum SetupError: Error {
        case notAuthorized
        case emptySelection
        case monitoringFailed
    }

    /// Completes Screen Time setup. Flips the legacy-Shortcuts kill switch
    /// (`sg_setupComplete`) ONLY after monitoring verifiably started — if it
    /// fails, the legacy path stays alive and the caller shows an error.
    func completeSetup() -> Result<Void, SetupError> {
        guard let d = defaults else { return .failure(.monitoringFailed) }
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { return .failure(.notAuthorized) }
        guard !SGContract.isSelectionEmpty(selection) else { return .failure(.emptySelection) }

        persistSelection()

        // Seed the interval from the legacy break duration on first setup
        // (legacy default 5 min rounds to 10).
        if d.integer(forKey: SGContract.Keys.intervalMinutes) == 0 {
            let legacy = d.integer(forKey: SGContract.Keys.legacyBreakDurationMinutes)
            let seeded = legacy > 0 ? SGContract.nearestAllowedInterval(to: legacy) : SGContract.defaultIntervalMinutes
            d.set(seeded, forKey: SGContract.Keys.intervalMinutes)
        }

        writeFreshBudgetKeys(d, minutes: effectiveInterval(d))
        guard restartMonitoring(thresholdMinutes: effectiveInterval(d)) else {
            return .failure(.monitoringFailed)
        }

        // Verified live — now (and only now) flip the kill switch.
        d.set(true, forKey: SGContract.Keys.guardEnabled)
        d.set(true, forKey: SGContract.Keys.setupComplete)
        d.synchronize()
        refresh()
        return .success(())
    }

    // MARK: - Grants (the unlock primitive)

    /// Clears the shield and starts a fresh budget. The ONLY exit from
    /// `.locked`. Must be called synchronously the moment the unlock is
    /// earned — never inside an animation delay.
    ///
    /// `minutes` nil means the user's interval setting — the duration for
    /// every non-quiz grant (focus, emergency, re-enable, setup, debug).
    /// Quiz unlocks go through `grantEarnedBudget`, which computes the
    /// per-card earned amount and passes it here.
    func grantFreshBudget(reason: GrantReason, minutes: Int? = nil, analyticsContext: [String: String] = [:]) {
        guard let d = defaults else { return }
        let granted = minutes ?? effectiveInterval(d)
        store.clearAllSettings()
        writeFreshBudgetKeys(d, minutes: granted)
        _ = restartMonitoring(thresholdMinutes: granted)
        var properties = [
            "source": reason.rawValue,
            "interval_minutes": String(effectiveInterval(d)),
            "granted_minutes": String(granted),
        ]
        analyticsContext.forEach { properties[$0.key] = $0.value }
        SGContract.enqueueAnalyticsEvent(d, name: "budget_granted", properties: properties)
        d.synchronize()
        refresh()
    }

    /// The quiz grant: earned time scales with the draw (perCardSeconds per
    /// card, rounded up to whole minutes, floored at minEarnedMinutes).
    /// Returns the granted minutes so callers can show the real number.
    @discardableResult
    func grantEarnedBudget(cardCount: Int) -> Int {
        let rate = SGContract.perCardSeconds(defaults)
        let minutes = SGContract.earnedMinutes(cardCount: cardCount, perCardSeconds: rate)
        grantFreshBudget(reason: .quiz, minutes: minutes, analyticsContext: [
            "card_count": String(cardCount),
            "per_card_seconds": String(rate),
        ])
        return minutes
    }

    /// Per-card earn rate for display (the quiz chip, settings copy).
    var perCardSeconds: Int { SGContract.perCardSeconds(defaults) }

    /// Minutes a quiz of `cardCount` cards would earn right now.
    func earnedMinutes(forCardCount cardCount: Int) -> Int {
        SGContract.earnedMinutes(cardCount: cardCount, perCardSeconds: perCardSeconds)
    }

    /// 3 per rolling week. Returns false (and refuses) when exhausted.
    @discardableResult
    func useEmergencyUnlock() -> Bool {
        guard let d = defaults else { return false }
        var ledger = EmergencyLedger.prune(EmergencyLedger.load(from: d))
        guard ledger.count < SGContract.emergencyUnlocksPerWeek else {
            SGContract.enqueueAnalyticsEvent(d, name: "emergency_unlock_blocked", properties: ["reason": "exhausted"])
            refresh()
            return false
        }
        ledger.append(Date().timeIntervalSince1970)
        EmergencyLedger.save(ledger, to: d)
        SGContract.enqueueAnalyticsEvent(d, name: "emergency_unlock_used", properties: [
            "used_this_week": String(ledger.count),
            "remaining_after": String(SGContract.emergencyUnlocksPerWeek - ledger.count),
        ])
        grantFreshBudget(reason: .emergency)
        return true
    }

    // MARK: - Settings

    /// Refused while locked (a two-tap disable would be an unlimited bypass —
    /// pass the quiz or spend an emergency unlock first).
    @discardableResult
    func setGuardEnabled(_ enabled: Bool) -> Bool {
        guard let d = defaults else { return false }
        if !enabled {
            guard state != .locked else { return false }
            center.stopMonitoring([SGContract.activity])
            store.clearAllSettings()
            d.set(false, forKey: SGContract.Keys.guardEnabled)
            d.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
            d.removeObject(forKey: SGContract.Keys.lockedAt)
            d.synchronize()
            refresh()
            return true
        } else {
            d.set(true, forKey: SGContract.Keys.guardEnabled)
            grantFreshBudget(reason: .enabled)
            return true
        }
    }

    enum SelectionUpdateResult {
        case saved
        case rebaselined(remainingMinutes: Int)
        case refusedLocked
        case refusedTooMany
        case refusedEmpty
    }

    /// Selection edits: refused while locked (anti-escape); re-baselined while
    /// metering (restarting monitoring resets the accumulator — the new
    /// threshold is the REMAINING minutes so nothing is gifted back).
    func updateSelection(_ newSelection: FamilyActivitySelection) -> SelectionUpdateResult {
        guard let d = defaults else { return .refusedLocked }
        guard state != .locked else {
            refresh() // rollback published selection to stored truth
            return .refusedLocked
        }
        guard SGContract.tokenCount(newSelection) <= SGContract.maxSelectionTokens else {
            refresh()
            return .refusedTooMany
        }
        guard !SGContract.isSelectionEmpty(newSelection) else {
            // Emptying the selection turns monitoring off but keeps setup state.
            selection = newSelection
            persistSelection()
            center.stopMonitoring([SGContract.activity])
            store.clearAllSettings()
            d.synchronize()
            refresh()
            return .refusedEmpty
        }

        selection = newSelection
        persistSelection()

        if state == .metering {
            let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
            let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
            let remaining = max(1, Int(((total - used) / 60).rounded(.up)))
            d.set(Double(remaining * 60), forKey: SGContract.Keys.budgetTotalSeconds)
            d.set(0.0, forKey: SGContract.Keys.budgetUsedSeconds)
            _ = restartMonitoring(thresholdMinutes: remaining)
            d.synchronize()
            refresh()
            return .rebaselined(remainingMinutes: remaining)
        }

        refresh()
        return .saved
    }

    /// Persist only — takes effect at the next grant or day rollover
    /// (restarting mid-budget would reset the accumulator for zero benefit).
    func updateInterval(_ minutes: Int) {
        guard SGContract.allowedIntervals.contains(minutes), let d = defaults else { return }
        let previous = d.integer(forKey: SGContract.Keys.intervalMinutes)
        d.set(minutes, forKey: SGContract.Keys.intervalMinutes)
        if previous != minutes {
            SGContract.enqueueAnalyticsEvent(d, name: "setting_changed", properties: [
                "setting": "usage_interval_minutes",
                "from": String(previous),
                "to": String(minutes),
            ])
        }
        d.synchronize()
        refresh()
    }

    // MARK: - Foreground reconcile (third reliability layer)

    /// Run on every scenePhase == .active and at launch.
    func reconcileOnForeground() {
        #if DEBUG
        if previewFrozen { refresh(); return }
        #endif
        guard let d = defaults else { return }
        d.synchronize()

        // (a) Authorization revoked → drop everything, never quiz-blackmail.
        if d.bool(forKey: SGContract.Keys.setupComplete) {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            if authorizationStatus != .approved {
                store.clearAllSettings()
                center.stopMonitoring([SGContract.activity])
                d.set(true, forKey: SGContract.Keys.needsReauth)
                d.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
                d.removeObject(forKey: SGContract.Keys.lockedAt)
                d.synchronize()
                refresh()
                return
            }
        }

        let guardActive = d.bool(forKey: SGContract.Keys.setupComplete) && d.bool(forKey: SGContract.Keys.guardEnabled)
        guard guardActive else {
            refresh()
            return
        }

        // (b) Stale-day purge (phone off at midnight — extension rollover missed).
        let startOfToday = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        if d.string(forKey: SGContract.Keys.state) != SGContract.StateValue.locked,
           d.double(forKey: SGContract.Keys.lastRolloverDay) != startOfToday {
            d.set(0.0, forKey: SGContract.Keys.budgetUsedSeconds)
            d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
            d.set(false, forKey: SGContract.Keys.warnedThisBudget)
            d.set(startOfToday, forKey: SGContract.Keys.lastRolloverDay)
            let interval = effectiveInterval(d)
            if d.integer(forKey: SGContract.Keys.armedThresholdMinutes) != interval {
                _ = restartMonitoring(thresholdMinutes: interval)
            } else {
                d.set(Double(interval * 60), forKey: SGContract.Keys.budgetTotalSeconds)
            }
            d.synchronize()
        }

        // (c) Missed-lock fallback (the extension's sg_limit never arrived).
        if d.string(forKey: SGContract.Keys.state) == SGContract.StateValue.metering {
            let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
            let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
            if total > 0, used >= total {
                applyShieldsFromStoredSelection()
                d.set(SGContract.StateValue.locked, forKey: SGContract.Keys.state)
                d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.lockedAt)
                d.synchronize()
                SGContract.enqueueAnalyticsEvent(d, name: "budget_lock_fired", properties: [
                    "detected_by": "reconcile",
                    "interval_minutes": String(d.integer(forKey: SGContract.Keys.armedThresholdMinutes)),
                ])
            }
        }

        // (d) Shield/state consistency. Re-read state right before touching the
        // store so a foreground reconcile racing an extension lock can't strip
        // fresh shields.
        d.synchronize()
        let currentState = d.string(forKey: SGContract.Keys.state)
        let storeIsShielding = store.shield.applications != nil
            || store.shield.applicationCategories != nil
            || store.shield.webDomains != nil
        if currentState == SGContract.StateValue.locked, !storeIsShielding {
            applyShieldsFromStoredSelection()
        } else if currentState != SGContract.StateValue.locked, storeIsShielding {
            let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
            let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
            if !(total > 0 && used >= total) { // never clear when a lock is due
                store.clearAllSettings()
            }
        }

        // (e) Monitoring health: iOS silently dropped our schedule → re-baseline restart.
        if currentState == SGContract.StateValue.metering,
           let stored = SGContract.decodeSelection(d), !SGContract.isSelectionEmpty(stored),
           !isMonitoringActive {
            let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
            let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
            let remaining = max(1, Int(((max(total, 60) - used) / 60).rounded(.up)))
            d.set(Double(remaining * 60), forKey: SGContract.Keys.budgetTotalSeconds)
            d.set(0.0, forKey: SGContract.Keys.budgetUsedSeconds)
            _ = restartMonitoring(thresholdMinutes: remaining)
            d.synchronize()
        }

        refresh()
    }

    var isMonitoringActive: Bool {
        center.activities.contains(SGContract.activity)
    }

    // MARK: - Internals

    private func effectiveInterval(_ d: UserDefaults) -> Int {
        let n = d.integer(forKey: SGContract.Keys.intervalMinutes)
        return n > 0 ? n : SGContract.defaultIntervalMinutes
    }

    private func writeFreshBudgetKeys(_ d: UserDefaults, minutes n: Int) {
        d.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
        d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
        d.set(Double(n * 60), forKey: SGContract.Keys.budgetTotalSeconds)
        d.set(0.0, forKey: SGContract.Keys.budgetUsedSeconds)
        d.set(false, forKey: SGContract.Keys.warnedThisBudget)
        d.removeObject(forKey: SGContract.Keys.lockedAt)
    }

    /// Stop + start with fresh events (the only reliable threshold reset).
    /// Pre-writes the rollover marker BEFORE startMonitoring so the immediate
    /// intervalDidStart a mid-interval registration fires is a no-op.
    @discardableResult
    private func restartMonitoring(thresholdMinutes: Int) -> Bool {
        guard let d = defaults,
              let stored = SGContract.decodeSelection(d) ?? optionalCurrentSelection(),
              !SGContract.isSelectionEmpty(stored) else { return false }

        d.set(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970, forKey: SGContract.Keys.lastRolloverDay)
        d.set(thresholdMinutes, forKey: SGContract.Keys.armedThresholdMinutes)
        d.synchronize()

        center.stopMonitoring([SGContract.activity])
        do {
            try center.startMonitoring(
                SGContract.activity,
                during: SGContract.dailySchedule,
                events: SGContract.buildEvents(intervalMinutes: thresholdMinutes, selection: stored)
            )
            return true
        } catch {
            Telemetry.capture(error, context: ["threshold_minutes": thresholdMinutes],
                              tags: ["feature": "study_guard", "operation": "start_monitoring"])
            return false
        }
    }

    private func optionalCurrentSelection() -> FamilyActivitySelection? {
        SGContract.isSelectionEmpty(selection) ? nil : selection
    }

    private func persistSelection() {
        guard let d = defaults, let data = try? JSONEncoder().encode(selection) else { return }
        d.set(data, forKey: SGContract.Keys.selection)
        d.synchronize()
    }

    private func applyShieldsFromStoredSelection() {
        guard let d = defaults, let stored = SGContract.decodeSelection(d),
              !SGContract.isSelectionEmpty(stored) else { return }
        if !stored.applicationTokens.isEmpty { store.shield.applications = stored.applicationTokens }
        if !stored.categoryTokens.isEmpty { store.shield.applicationCategories = .specific(stored.categoryTokens) }
        if !stored.webDomainTokens.isEmpty { store.shield.webDomains = stored.webDomainTokens }
    }

    // MARK: - Debug & creator support
    //
    // Compiled into Release too: the Creator Toolkit (Profile tab) ships to
    // TestFlight so creators can force states while filming. App Store
    // installs never reach these — the toolkit UI is gated by
    // AppEnvironment, and nothing else calls them.

    /// Creator toolkit: pin the remaining screen time to an exact value so
    /// the countdown, progress bar and mascot pose can be staged without
    /// waiting out real usage. Keeps the TOTAL untouched (the mascot's
    /// doomscrolling pose keys off remaining/total), floors at one minute
    /// (zero-while-metering is a state the real engine never shows), and
    /// leaves monitoring alone: real usage keeps accruing on top.
    func creatorSetRemaining(minutes: Int) {
        guard let d = defaults, state == .metering else { return }
        let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
        guard total > 0 else { return }
        let remaining = min(max(60, Double(minutes) * 60), total)
        d.set(total - remaining, forKey: SGContract.Keys.budgetUsedSeconds)
        d.synchronize()
        refresh()
    }

    func debugForceLock() {
        guard let d = defaults else { return }
        applyShieldsFromStoredSelection()
        d.set(SGContract.StateValue.locked, forKey: SGContract.Keys.state)
        d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.lockedAt)
        let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
        d.set(total, forKey: SGContract.Keys.budgetUsedSeconds)
        d.synchronize()
        refresh()
    }

    func debugResetAll() {
        guard let d = defaults else { return }
        center.stopMonitoring([SGContract.activity])
        store.clearAllSettings()
        [SGContract.Keys.setupComplete, SGContract.Keys.guardEnabled, SGContract.Keys.selection,
         SGContract.Keys.intervalMinutes, SGContract.Keys.state, SGContract.Keys.lockedAt,
         SGContract.Keys.budgetGrantedAt, SGContract.Keys.budgetTotalSeconds, SGContract.Keys.budgetUsedSeconds,
         SGContract.Keys.warnedThisBudget, SGContract.Keys.armedThresholdMinutes,
         SGContract.Keys.emergencyUnlockTimestamps, SGContract.Keys.needsReauth,
         SGContract.Keys.lastRolloverDay, SGContract.Keys.lockNotifThrottleAt,
         SGContract.Keys.extLog, SGContract.Keys.pendingEvents].forEach { d.removeObject(forKey: $0) }
        d.synchronize()
        selection = FamilyActivitySelection()
        refresh()
    }

    func debugStateDump() -> [(String, String)] {
        guard let d = defaults else { return [] }
        func ts(_ key: String) -> String {
            let v = d.double(forKey: key)
            return v > 0 ? Date(timeIntervalSince1970: v).formatted(date: .abbreviated, time: .standard) : "-"
        }
        return [
            ("state", d.string(forKey: SGContract.Keys.state) ?? "-"),
            ("setupComplete", String(d.bool(forKey: SGContract.Keys.setupComplete))),
            ("guardEnabled", String(d.bool(forKey: SGContract.Keys.guardEnabled))),
            ("intervalMinutes", String(d.integer(forKey: SGContract.Keys.intervalMinutes))),
            ("armedThreshold", String(d.integer(forKey: SGContract.Keys.armedThresholdMinutes))),
            ("budgetGrantedAt", ts(SGContract.Keys.budgetGrantedAt)),
            ("budgetTotal", "\(Int(d.double(forKey: SGContract.Keys.budgetTotalSeconds)))s"),
            ("budgetUsed", "\(Int(d.double(forKey: SGContract.Keys.budgetUsedSeconds)))s"),
            ("lockedAt", ts(SGContract.Keys.lockedAt)),
            ("lastRolloverDay", ts(SGContract.Keys.lastRolloverDay)),
            ("monitoringActive", String(isMonitoringActive)),
            ("storeShielding", String(store.shield.applications != nil || store.shield.applicationCategories != nil)),
            ("emergencyRemaining", String(emergencyUnlocksRemaining)),
            ("needsReauth", String(d.bool(forKey: SGContract.Keys.needsReauth))),
            ("legacyIntentFires", String(d.integer(forKey: SGContract.Keys.legacyIntentFireCount))),
            ("tokens", "\(SGContract.tokenCount(selection))"),
        ]
    }

    func debugExtensionLog() -> [String] {
        defaults?.stringArray(forKey: SGContract.Keys.extLog)?.reversed() ?? []
    }
}
