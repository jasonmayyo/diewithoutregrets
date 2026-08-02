//
//  MonsterActivityManager.swift
//  diewithoutregrets
//
//  Keeps the monster mascot Live Activity alive in the Dynamic Island and
//  picks which mascot frame it shows.
//
//  The frame is the monster's MOOD: it tracks how much of the screen-time
//  budget has been burned, escalating happy → note-taking → unimpressed →
//  angry → furious as the session runs out (and furious while locked). The
//  budget is read fresh from the app-group defaults on every tick, so the
//  mood keeps escalating during the short background window while the
//  monitor extension counts usage in other apps.
//
//  Why still frames and not Lottie: the Dynamic Island is rendered by
//  WidgetKit, which draws static snapshots and cannot run an animation loop.
//  The mascot feels alive because we push a new frame via Activity.update().
//

import ActivityKit
import Foundation
import UIKit

@MainActor
final class MonsterActivityManager: ObservableObject {
    static let shared = MonsterActivityManager()

    /// All mascot frames. Names match imagesets present in the MonsterWidget
    /// asset catalog (copied from the app catalog).
    static let allMonsters = ["1", "2", "3", "4", "5"]

    /// The mood ladder, calm → furious. Asset numbers are NOT anger-ordered:
    /// 1 = happy, 5 = clipboard (keeping notes on you), 2 = unimpressed
    /// (watching you scroll), 4 = angry, 3 = the furious red guy.
    static let moodLadder = ["1", "5", "2", "4", "3"]

    /// How often the mood is re-read while the app is active (and during the
    /// short background window right after leaving the app, where the monitor
    /// extension's usage writes land between our ticks).
    private let switchInterval: TimeInterval = 4.0

    private static let lastMonsterKey = "lastMonsterImageName"

    @Published private(set) var currentMonster: String

    private var currentActivity: Activity<MonsterLiveActivityAttributes>?
    private var switchTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {
        // Resume from the last shown frame (validated against the current set),
        // defaulting to the first image. The first tick corrects it to the
        // real mood immediately.
        let saved = UserDefaults.standard.string(forKey: Self.lastMonsterKey)
        self.currentMonster = saved.flatMap { Self.allMonsters.contains($0) ? $0 : nil }
            ?? Self.allMonsters[0]
    }

    // MARK: - Mood

    /// The frame the island should show right now, derived from the guard
    /// state + budget in the app-group defaults (read fresh so background
    /// ticks see the monitor extension's latest usage writes).
    private func moodFrame() -> String {
        guard let d = SGContract.sharedDefaults else { return Self.moodLadder[0] }

        switch GuardState.derive(from: d) {
        case .notSetUp, .disabled:
            return Self.moodLadder[0]
        case .locked:
            // Out of time — maximum fury until a new budget is earned.
            return Self.moodLadder[Self.moodLadder.count - 1]
        case .metering:
            let total = d.double(forKey: SGContract.Keys.budgetTotalSeconds)
            guard total > 0 else { return Self.moodLadder[0] }
            // Stale-grant guard, same rule as StudyGuardManager.refresh().
            let grantedAt = Date(timeIntervalSince1970: d.double(forKey: SGContract.Keys.budgetGrantedAt))
            guard Calendar.current.isDateInToday(grantedAt) else { return Self.moodLadder[0] }
            let used = d.double(forKey: SGContract.Keys.budgetUsedSeconds)
            let fraction = min(max(used / total, 0), 1)
            // Even 20% bands across the ladder; the top band starts at 80%.
            let step = min(Int(fraction * Double(Self.moodLadder.count)), Self.moodLadder.count - 1)
            return Self.moodLadder[step]
        }
    }

    // MARK: - Lifecycle

    /// Ensure the monster Live Activity is running and (re)start the frame
    /// rotation. Safe to call on every app foreground.
    func ensureMonsterRunning() {
        endBackgroundTask() // back in the foreground — no longer need the bg window

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("👹 Live Activities are disabled — cannot show monster")
            return
        }

        // Derive the mood up front so a fresh activity starts on the right
        // frame instead of flashing the last persisted one.
        currentMonster = moodFrame()

        // Re-attach to an existing activity that survived a relaunch.
        if currentActivity == nil {
            currentActivity = Activity<MonsterLiveActivityAttributes>.activities
                .first { $0.activityState == .active }
        }

        if currentActivity == nil {
            startMonsterActivity()
        } else {
            updateRunningActivity()
        }

        startSwitchTimer()
    }

    /// Called when the app moves to the background. iOS hides an app's own Live
    /// Activity in the Dynamic Island while the app is in the foreground, so the
    /// rotation only becomes *visible* once we leave the app. We request a short
    /// background window (~30s) and keep cycling during it so the user sees the
    /// mascot change right after leaving. Once the window expires iOS suspends
    /// us and the mascot holds its last frame until the app is next opened.
    /// (Truly continuous background switching would require ActivityKit push
    /// updates from a server.)
    func continueSwitchingInBackground() {
        guard switchTimer != nil else { return }
        beginBackgroundTask()
    }

    /// Stop rotating immediately. The last frame stays visible in the island.
    func pauseSwitching() {
        switchTimer?.invalidate()
        switchTimer = nil
        endBackgroundTask()
    }

    /// Fully tear down the monster (e.g. for a debug toggle or sign-out).
    func stopMonster() {
        pauseSwitching()
        let activities = Activity<MonsterLiveActivityAttributes>.activities
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }

    // MARK: - Private

    private func makeState() -> MonsterLiveActivityAttributes.ContentState {
        MonsterLiveActivityAttributes.ContentState(imageName: currentMonster)
    }

    private func startMonsterActivity() {
        let attributes = MonsterLiveActivityAttributes()
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: makeState(), staleDate: nil),
                pushType: nil
            )
            print("👹 Monster Live Activity started with image \(currentMonster)")
        } catch {
            print("👹 Failed to start Monster Live Activity: \(error.localizedDescription)")
        }
    }

    private func beginBackgroundTask() {
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MonsterSwitch") { [weak self] in
            // Expiration handler: iOS is about to suspend us — stop cleanly.
            Task { @MainActor in self?.pauseSwitching() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func startSwitchTimer() {
        switchTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: switchInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshMood() }
        }
        timer.tolerance = switchInterval * 0.3
        switchTimer = timer
        // Land on the right mood immediately — don't wait out the first tick.
        refreshMood()
    }

    /// Timer tick: re-derive the mood and push it only when it changed
    /// (Activity.update is rate-limited; identical frames would waste it).
    private func refreshMood() {
        let mood = moodFrame()
        guard mood != currentMonster else { return }
        currentMonster = mood
        UserDefaults.standard.set(currentMonster, forKey: Self.lastMonsterKey)
        updateRunningActivity()
    }

    private func updateRunningActivity() {
        guard let activity = currentActivity, activity.activityState == .active else {
            // Activity was dismissed/ended — restart it so the monster is always present.
            currentActivity = nil
            startMonsterActivity()
            return
        }
        let content = ActivityContent(state: makeState(), staleDate: nil)
        Task {
            await activity.update(content)
        }
    }
}
