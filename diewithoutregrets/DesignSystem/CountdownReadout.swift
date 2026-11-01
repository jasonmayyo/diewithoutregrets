//
//  CountdownReadout.swift
//  diewithoutregrets
//
//  The big rounded minutes readout under the Guard Ring. Screen Time gives
//  no live usage feed — usage arrives as checkpoints — so the number is
//  CHECKPOINT-REPLAYED: on every refresh we diff the new remaining minutes
//  against the last value we SHOWED (persisted with its grant stamp) and
//  replay the delta as per-minute numericText ticks with haptics.
//
//  Correctness rules (learned from the reference implementation):
//  - Two keys, not one: a new grant stamp means "fresh budget — count up
//    from zero", never "diff against the old grant" (which would show a
//    phantom drop after an interval change).
//  - Write the settled value + stamp BEFORE animating: an interrupted
//    animation can only lose the show, never the truth.
//  - All ticks run on cancelable work items: overlapping refreshes
//    (onAppear + reconcile + grant land within a second) never double-play.
//  - Drops are capped at 10 visual ticks; gains compress to ≤6s.
//  - Display-only: this file never touches the engine.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class CountdownReplayModel {
    private(set) var displayMinutes: Int = 0
    /// Floating "+N min"/"−N min" label; new identity per event.
    private(set) var delta: DeltaEvent?
    /// True while a roll is playing — readouts swell slightly for drama.
    private(set) var isRolling = false

    struct DeltaEvent: Identifiable, Equatable {
        let id: Double
        let amount: Int
    }

    /// Fired when the readout settles on its final value —
    /// immediately when nothing rolls, or after the last tick of a roll.
    /// The Guard home uses this to chain the lock stamp after a roll to 0.
    /// Never fired for syncs that are skipped while the readout is hidden.
    /// An identical sync during a roll leaves its existing completion intact.
    @ObservationIgnored var onSettled: ((Int) -> Void)?

    @ObservationIgnored private var pendingTicks: [DispatchWorkItem] = []
    @ObservationIgnored private var activeRollID: UUID?
    @ObservationIgnored private var activeTarget: Target?
    private let defaults: UserDefaults
    private let reduceMotion: () -> Bool
    private let schedule: (TimeInterval, DispatchWorkItem) -> Void

    private struct Target: Equatable {
        let minutes: Int
        let grantStamp: Double
    }

    init(defaults: UserDefaults = .standard,
         reduceMotion: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled },
         schedule: @escaping (TimeInterval, DispatchWorkItem) -> Void = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.defaults = defaults
        self.reduceMotion = reduceMotion
        self.schedule = schedule
    }
    /// Persisted "last value we SHOWED" pair. Static so the Creator Toolkit
    /// can pre-settle the story (an instant staged lock writes 0 + the
    /// grant stamp here so no roll plays on the next home visit).
    static let lastShownKey = "sg_lastShownRemainingMin"
    static let lastStampKey = "sg_lastShownGrantStamp"

    /// The Guard home drives this: replays only play while the readout is
    /// actually on screen. While hidden, sync() is a no-op — the truth keys
    /// stay unconsumed, so the story plays when the user next lands on Home
    /// (the home view re-syncs on every appear).
    @ObservationIgnored private var isVisible = false

    func setVisible(_ visible: Bool) {
        isVisible = visible
        if !visible { cancelTicks() }
    }

    /// Feed the current truth (from StudyGuardManager) and let the model
    /// decide what story to play.
    func sync(remainingMinutes: Int, grantStamp: Double) {
        guard isVisible else { return }
        let target = Target(minutes: remainingMinutes, grantStamp: grantStamp)
        let shouldReduceMotion = reduceMotion()
        // onAppear and the guard's separate state/budget callbacks can deliver
        // the same target together. Do not cancel a roll that already owns it.
        if isRolling, activeTarget == target, !shouldReduceMotion { return }
        let interruptedDisplay = isRolling && activeTarget?.grantStamp == grantStamp
            ? displayMinutes : nil
        cancelTicks()

        let lastShown = defaults.integer(forKey: Self.lastShownKey)
        let lastStamp = defaults.double(forKey: Self.lastStampKey)

        // Truth first — the show is optional.
        defaults.set(remainingMinutes, forKey: Self.lastShownKey)
        defaults.set(grantStamp, forKey: Self.lastStampKey)

        guard !shouldReduceMotion else {
            displayMinutes = remainingMinutes
            onSettled?(remainingMinutes)
            return
        }

        activeTarget = target
        if grantStamp != lastStamp {
            // Fresh budget (grant or day rollover): count up from zero.
            if remainingMinutes > 0 {
                delta = DeltaEvent(id: grantStamp, amount: remainingMinutes)
                playRoll(from: 0, to: remainingMinutes, gain: true)
            } else {
                displayMinutes = remainingMinutes
                onSettled?(remainingMinutes)
            }
        } else {
            if remainingMinutes < lastShown {
                delta = DeltaEvent(id: Date.timeIntervalSinceReferenceDate + Double(remainingMinutes),
                                   amount: remainingMinutes - lastShown)
            }
            // The persisted value is the target, not necessarily the current
            // frame. A newer checkpoint continues from the visible number.
            let start = interruptedDisplay ?? lastShown
            if remainingMinutes < start {
                playRoll(from: min(start, remainingMinutes + 10), to: remainingMinutes, gain: false)
            } else if remainingMinutes > start {
                playRoll(from: start, to: remainingMinutes, gain: true)
            } else {
                displayMinutes = remainingMinutes
                onSettled?(remainingMinutes)
            }
        }
    }

    /// Manual per-minute roll: each tick is its own numericText morph +
    /// haptic; the per-step DELAY carries the easing.
    private func playRoll(from start: Int, to end: Int, gain: Bool) {
        displayMinutes = start
        let steps = abs(end - start)
        guard steps > 0 else { return }
        let rollID = UUID()
        activeRollID = rollID

        withAnimation(SGTheme.spring) { isRolling = true }

        var accumulated: Double = 0.15
        for i in 1...steps {
            let completed = Double(i) / Double(steps)
            let stepDelay: Double
            if gain {
                // Sine ease-in-out, compressed so any gain fits ≤6s.
                let s = sin(.pi * completed)
                stepDelay = min(0.30 - (0.30 - 0.06) * pow(s, 1.6), 6.0 / Double(steps))
            } else {
                // Ease-out: fast start, gentle landing.
                stepDelay = 0.14 + 0.65 * pow(completed, 2.5)
            }
            accumulated += stepDelay

            let value = gain ? start + i : start - i
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.activeRollID == rollID else { return }
                withAnimation(.easeInOut(duration: min(stepDelay, 0.45))) {
                    self.displayMinutes = value
                }
                if gain { SGTheme.tickUpHaptic() } else { SGTheme.tickDownHaptic(progress: completed) }
            }
            pendingTicks.append(work)
            schedule(accumulated, work)
        }

        // Settle the swell shortly after the last tick lands.
        let settle = DispatchWorkItem { [weak self] in
            guard let self, self.activeRollID == rollID else { return }
            self.activeRollID = nil
            self.activeTarget = nil
            self.pendingTicks.removeAll()
            withAnimation(SGTheme.spring) { self.isRolling = false }
            self.onSettled?(end)
        }
        pendingTicks.append(settle)
        schedule(accumulated + 0.4, settle)
    }

    private func cancelTicks() {
        activeRollID = nil
        activeTarget = nil
        pendingTicks.forEach { $0.cancel() }
        pendingTicks.removeAll()
        if isRolling { withAnimation(SGTheme.spring) { isRolling = false } }
    }
}

struct CountdownReadout: View {
    let model: CountdownReplayModel
    var caption: String = "of scroll time left"

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Text("\(model.displayMinutes) min")
                    .font(SGTheme.display(42))
                    .monospacedDigit()
                    .foregroundColor(SGTheme.paper)
                    .contentTransition(.numericText(countsDown: true))
                    .scaleEffect(model.isRolling ? 1.08 : 1)

                if let delta = model.delta {
                    CountdownDeltaLabel(event: delta)
                        .offset(x: 64, y: -14)
                        .id(delta.id)
                }
            }
            Text(caption)
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperSecondary)
        }
    }
}

/// "+15 min" / "−3 min" — drifts up and fades after each budget event.
/// Internal so the home hero readout can reuse it.
struct CountdownDeltaLabel: View {
    let event: CountdownReplayModel.DeltaEvent
    @State private var drifted = false

    private var isGain: Bool { event.amount >= 0 }

    var body: some View {
        Text("\(isGain ? "+" : "−")\(abs(event.amount))")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundColor(isGain ? SGTheme.mintDeep : SGTheme.emberDeep)
            // Sticker-style white rim (stacked tight shadows) so the label
            // reads over the meadow greens.
            .shadow(color: .white, radius: 0.7)
            .shadow(color: .white, radius: 0.7)
            .shadow(color: .white, radius: 0.7)
            .shadow(color: .white, radius: 0.7)
            .shadow(color: .white, radius: 0.7)
            .shadow(color: .white, radius: 0.7)
            .opacity(drifted ? 0 : 1)
            .scaleEffect(drifted ? 1.25 : 1)
            .offset(y: drifted ? -90 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 4.5)) {
                    drifted = true
                }
            }
            .accessibilityHidden(true)
    }
}
