//
//  StudyGuardState.swift
//  diewithoutregrets
//
//  Guard state derivation from the app-group contract, plus the small pure
//  functions (interval rounding, emergency ledger) kept free of side effects
//  so they are unit-testable.
//

import Foundation

/// The four Study Guard states. Derived in exactly one place
/// (`GuardState.derive`) from app-group keys — views never guess.
enum GuardState: String, Equatable {
    /// Screen Time setup never completed — the legacy Shortcuts flow is still live.
    case notSetUp
    /// Set up, but the user toggled the guard off.
    case disabled
    /// Apps usable; DeviceActivity is counting toward the limit.
    case metering
    /// Shields up; only a grant (quiz / True Focus / emergency) exits.
    case locked
}

extension GuardState {
    /// A manual route remains available if the last usage checkpoint reaches
    /// zero before the shield transition arrives. Setup/off states are excluded.
    func offersStudyUnlock(remainingMinutes: Int) -> Bool {
        self == .locked || (self == .metering && remainingMinutes <= 0)
    }

    static func derive(from defaults: UserDefaults) -> GuardState {
        guard defaults.bool(forKey: SGContract.Keys.setupComplete) else { return .notSetUp }
        guard defaults.bool(forKey: SGContract.Keys.guardEnabled) else { return .disabled }
        return defaults.string(forKey: SGContract.Keys.state) == SGContract.StateValue.locked ? .locked : .metering
    }
}

/// Displayed allowance follows the lock, even when yesterday's budget is
/// retained or a usage checkpoint is missing. Midnight never unlocks apps.
struct GuardBudgetSnapshot {
    let totalMinutes: Int
    let usedMinutes: Int
    var remainingMinutes: Int { max(0, totalMinutes - usedMinutes) }

    init(from defaults: UserDefaults, state: GuardState,
         now: Date = Date(), calendar: Calendar = .current) {
        let interval = defaults.integer(forKey: SGContract.Keys.intervalMinutes)
        let fallback = interval > 0 ? interval : SGContract.defaultIntervalMinutes
        let total = defaults.double(forKey: SGContract.Keys.budgetTotalSeconds)
        totalMinutes = total > 0 ? Int(total / 60) : fallback

        if state == .locked {
            usedMinutes = totalMinutes
        } else {
            let grantedAt = Date(timeIntervalSince1970: defaults.double(forKey: SGContract.Keys.budgetGrantedAt))
            usedMinutes = calendar.isDate(grantedAt, inSameDayAs: now)
                ? min(totalMinutes, max(0, Int(defaults.double(forKey: SGContract.Keys.budgetUsedSeconds) / 60)))
                : 0
        }
    }
}

/// Why a fresh budget was granted — becomes the analytics `source`.
enum GrantReason: String {
    case setup
    case quiz = "flashcards"
    case focusSession = "true_focus"
    case emergency
    case enabled = "guard_enabled"
    case debug
}

/// Rolling-week emergency-unlock ledger math (pure, unit-testable).
enum EmergencyLedger {

    /// Drop entries older than the rolling window.
    static func prune(_ timestamps: [Double], now: Double = Date().timeIntervalSince1970) -> [Double] {
        timestamps.filter { now - $0 < SGContract.emergencyWindowSeconds }
    }

    static func remaining(_ timestamps: [Double], now: Double = Date().timeIntervalSince1970) -> Int {
        max(0, SGContract.emergencyUnlocksPerWeek - prune(timestamps, now: now).count)
    }

    /// When the oldest in-window use expires — i.e. when the next unlock
    /// becomes available for a user who has exhausted the allowance.
    static func nextAvailableDate(_ timestamps: [Double], now: Double = Date().timeIntervalSince1970) -> Date? {
        let pruned = prune(timestamps, now: now)
        guard pruned.count >= SGContract.emergencyUnlocksPerWeek, let oldest = pruned.min() else { return nil }
        return Date(timeIntervalSince1970: oldest + SGContract.emergencyWindowSeconds)
    }

    static func load(from defaults: UserDefaults) -> [Double] {
        guard let data = defaults.data(forKey: SGContract.Keys.emergencyUnlockTimestamps),
              let stamps = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return stamps
    }

    static func save(_ timestamps: [Double], to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(timestamps) {
            defaults.set(data, forKey: SGContract.Keys.emergencyUnlockTimestamps)
        }
    }
}
