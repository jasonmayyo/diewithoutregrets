//
//  StudyGuardMonitorExtension.swift
//  StudyGuardMonitor
//
//  DeviceActivityMonitor extension: applies the Study Guard lock when the
//  usage threshold fires, keeps usage telemetry fresh via progress events,
//  and handles day rollover. It never grants an unlock — only the main app
//  does that (quiz / True Focus / emergency unlock).
//
//  Reliability notes (learned from production reference apps):
//  - eventDidReachThreshold is unreliable → checkForMissedLock() runs on
//    every callback, and the app runs the same check on foreground.
//  - intervalDidEnd and all warning callbacks are LOG-ONLY, so app-side
//    stopMonitoring (which fires intervalDidEnd) is always safe.
//  - The only extension-side monitoring restart is the day-rollover
//    normalization (re-arming the full interval after a re-baseline).
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import UserNotifications
import Foundation

final class StudyGuardMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(named: .init(SGContract.storeName))

    // MARK: - Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == SGContract.activityName,
              let d = SGContract.sharedDefaults else { return }
        sgLog(d, "intervalDidStart")
        guard d.bool(forKey: SGContract.Keys.guardEnabled),
              d.bool(forKey: SGContract.Keys.setupComplete) else { return }

        // A lock always survives midnight — only a grant exits it.
        if d.string(forKey: SGContract.Keys.state) == SGContract.StateValue.locked {
            applyShields(d)
            sgLog(d, "rollover: still locked, shields re-applied")
            return
        }

        let startOfToday = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        if d.double(forKey: SGContract.Keys.lastRolloverDay) != startOfToday {
            performDayRollover(d, startOfToday: startOfToday)
        }
        checkForMissedLock(d)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity.rawValue == SGContract.activityName,
              let d = SGContract.sharedDefaults,
              d.bool(forKey: SGContract.Keys.guardEnabled),
              d.bool(forKey: SGContract.Keys.setupComplete) else { return }

        if event.rawValue == SGContract.limitEventName {
            guard d.string(forKey: SGContract.Keys.state) != SGContract.StateValue.locked else { return }
            // Grant-epsilon guard: a stale sg_limit from the pre-grant monitoring
            // generation can be delivered late. A legitimate lock always arrives
            // ≥ N minutes after the grant, so ignore deliveries in the first
            // seconds of a fresh, unused budget.
            let grantedAt = d.double(forKey: SGContract.Keys.budgetGrantedAt)
            let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
            if Date().timeIntervalSince1970 - grantedAt < 90, used < 60 {
                sgLog(d, "sg_limit ignored (grant-epsilon guard)")
                return
            }
            lock(d, detectedBy: "extension")
        } else if event.rawValue.hasPrefix(SGContract.progressEventPrefix),
                  let m = Int(event.rawValue.dropFirst(SGContract.progressEventPrefix.count)) {
            // Progress telemetry only makes sense while metering (shield-overlay
            // foreground time can still tick events after a lock).
            guard d.string(forKey: SGContract.Keys.state) == SGContract.StateValue.metering else { return }
            let used = max(d.double(forKey: SGContract.Keys.budgetUsedSeconds), Double(m * 60))
            d.set(used, forKey: SGContract.Keys.budgetUsedSeconds)

            let totalMinutes = Int(d.double(forKey: SGContract.Keys.budgetTotalSeconds) / 60)
            if totalMinutes > 0,
               Double(m) >= (0.8 * Double(totalMinutes)).rounded(.up),
               !d.bool(forKey: SGContract.Keys.warnedThisBudget) {
                d.set(true, forKey: SGContract.Keys.warnedThisBudget)
                sendWarningNotification(remainingMinutes: max(1, totalMinutes - m))
            }
            d.synchronize()
            sgLog(d, "progress: ~\(m) min used of \(totalMinutes)")
            checkForMissedLock(d)
        }
    }

    // Log-only by design — no logic may ever live here (stopMonitoring fires
    // intervalDidEnd, and the warning callbacks are unreliable).
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if let d = SGContract.sharedDefaults { sgLog(d, "intervalDidEnd (log-only)") }
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    // MARK: - Day rollover

    private func performDayRollover(_ d: UserDefaults, startOfToday: Double) {
        d.set(0.0, forKey: SGContract.Keys.budgetUsedSeconds)
        d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
        d.set(false, forKey: SGContract.Keys.warnedThisBudget)
        d.set(startOfToday, forKey: SGContract.Keys.lastRolloverDay)

        // Normalization restart — the ONE sanctioned extension-side restart:
        // after a re-baseline (or an interval change) the armed threshold
        // diverges from sg_intervalMinutes; without this, a re-baselined user
        // wakes up to a tiny budget every day and interval edits never apply.
        let interval = d.integer(forKey: SGContract.Keys.intervalMinutes)
        var armed = d.integer(forKey: SGContract.Keys.armedThresholdMinutes)
        if armed == 0 { armed = interval }
        var effectiveMinutes = armed
        if armed != interval, interval > 0,
           let selection = SGContract.decodeSelection(d),
           !SGContract.isSelectionEmpty(selection) {
            let center = DeviceActivityCenter()
            center.stopMonitoring([SGContract.activity])
            do {
                try center.startMonitoring(
                    SGContract.activity,
                    during: SGContract.dailySchedule,
                    events: SGContract.buildEvents(intervalMinutes: interval, selection: selection)
                )
                d.set(interval, forKey: SGContract.Keys.armedThresholdMinutes)
                effectiveMinutes = interval
                sgLog(d, "rollover: normalized threshold \(armed) → \(interval) min")
            } catch {
                sgLog(d, "rollover: normalization restart FAILED: \(error.localizedDescription)")
            }
        }
        d.set(Double(effectiveMinutes * 60), forKey: SGContract.Keys.budgetTotalSeconds)
        d.synchronize()
        sgLog(d, "rollover: fresh day budget (\(effectiveMinutes) min)")
    }

    // MARK: - Locking

    /// Fallback for the documented unreliability of eventDidReachThreshold:
    /// if the used-seconds estimate has reached the total but we're still
    /// metering, the main event was missed — lock now.
    private func checkForMissedLock(_ d: UserDefaults) {
        guard d.string(forKey: SGContract.Keys.state) == SGContract.StateValue.metering else { return }
        let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
        let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
        if total > 0, used >= total {
            sgLog(d, "missed sg_limit detected (used \(Int(used))s ≥ \(Int(total))s), locking")
            lock(d, detectedBy: "extension_fallback")
        }
    }

    private func lock(_ d: UserDefaults, detectedBy: String) {
        applyShields(d)
        d.set(SGContract.StateValue.locked, forKey: SGContract.Keys.state)
        d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.lockedAt)
        let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
        d.set(total, forKey: SGContract.Keys.budgetUsedSeconds)
        d.synchronize()
        SGContract.enqueueAnalyticsEvent(d, name: "budget_lock_fired", properties: [
            "detected_by": detectedBy,
            "interval_minutes": String(d.integer(forKey: SGContract.Keys.armedThresholdMinutes)),
        ])
        sendLockNotification(d)
        sgLog(d, "LOCKED (\(detectedBy))")
    }

    /// Shield exactly what the user picked — never .all() fallbacks
    /// (over-blocking Safari/every domain is a known trap).
    private func applyShields(_ d: UserDefaults) {
        guard let selection = SGContract.decodeSelection(d),
              !SGContract.isSelectionEmpty(selection) else {
            sgLog(d, "applyShields: no selection found, nothing shielded")
            return
        }
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
        sgLog(d, "shielded apps=\(selection.applicationTokens.count) cats=\(selection.categoryTokens.count) webs=\(selection.webDomainTokens.count)")
    }

    // MARK: - Notifications

    private func sendLockNotification(_ d: UserDefaults) {
        // 30s throttle with a fixed identifier so re-fires replace, not stack.
        let now = Date().timeIntervalSince1970
        let lastSent = d.double(forKey: SGContract.Keys.lockNotifThrottleAt)
        guard now - lastSent >= 30 else {
            sgLog(d, "lock notification throttled")
            return
        }
        d.set(now, forKey: SGContract.Keys.lockNotifThrottleAt)

        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [SGContract.lockNotificationID])

        let content = UNMutableNotificationContent()
        content.title = "Time's up! The monster's got your apps"
        content.body = "Answer your flashcards in Study Guard to win them back."
        content.sound = .default
        content.userInfo = ["deeplink": SGContract.unlockDeepLink]

        let request = UNNotificationRequest(identifier: SGContract.lockNotificationID, content: content, trigger: nil)
        center.add(request) { error in
            if let error {
                SGContract.sharedDefaults.map { SGContract.appendExtLog($0, "lock notification failed: \(error.localizedDescription)") }
            }
        }
        SGContract.enqueueAnalyticsEvent(d, name: "lock_notification_sent")
    }

    private func sendWarningNotification(remainingMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Almost out of time"
        content.body = "About \(remainingMinutes) min left before your apps lock. He's watching."
        content.sound = .default
        content.userInfo = ["deeplink": SGContract.unlockDeepLink]
        let request = UNNotificationRequest(identifier: SGContract.warningNotificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Logging

    private func sgLog(_ d: UserDefaults, _ message: String) {
        SGContract.appendExtLog(d, message)
    }
}
