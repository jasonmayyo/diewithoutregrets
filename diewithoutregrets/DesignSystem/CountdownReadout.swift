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

@MainActor
final class CountdownReplayModel: ObservableObject {
    @Published var displayMinutes: Int = 0
    /// Floating "+N min"/"−N min" label; new identity per event.
    @Published var delta: DeltaEvent?
    /// True while a roll is playing — readouts swell slightly for drama.
    @Published var isRolling = false

    struct DeltaEvent: Identifiable, Equatable {
        let id: Double
        let amount: Int
    }

    private var pendingTicks: [DispatchWorkItem] = []
    private let lastShownKey = "sg_lastShownRemainingMin"
    private let lastStampKey = "sg_lastShownGrantStamp"

    /// The Guard home drives this: replays only play while the readout is
    /// actually on screen. While hidden, sync() is a no-op — the truth keys
    /// stay unconsumed, so the story plays when the user next lands on Home
    /// (the home view re-syncs on every appear).
    private var isVisible = false

    func setVisible(_ visible: Bool) {
        isVisible = visible
        if !visible { cancelTicks() }
    }

    /// Feed the current truth (from StudyGuardManager) and let the model
    /// decide what story to play.
    func sync(remainingMinutes: Int, grantStamp: Double) {
        guard isVisible else { return }
        cancelTicks()

        let defaults = UserDefaults.standard
        let lastShown = defaults.integer(forKey: lastShownKey)
        let lastStamp = defaults.double(forKey: lastStampKey)

        // Truth first — the show is optional.
        defaults.set(remainingMinutes, forKey: lastShownKey)
        defaults.set(grantStamp, forKey: lastStampKey)

        guard !UIAccessibility.isReduceMotionEnabled else {
            displayMinutes = remainingMinutes
            return
        }

        if grantStamp != lastStamp {
            // Fresh budget (grant or day rollover): count up from zero.
            if remainingMinutes > 0 {
                delta = DeltaEvent(id: grantStamp, amount: remainingMinutes)
                playRoll(from: 0, to: remainingMinutes, gain: true)
            } else {
                displayMinutes = remainingMinutes
            }
        } else if remainingMinutes < lastShown {
            // Same budget, usage arrived: roll down (≤10 visual ticks).
            delta = DeltaEvent(id: Date.timeIntervalSinceReferenceDate + Double(remainingMinutes),
                               amount: remainingMinutes - lastShown)
            playRoll(from: min(lastShown, remainingMinutes + 10), to: remainingMinutes, gain: false)
        } else if remainingMinutes > lastShown {
            playRoll(from: lastShown, to: remainingMinutes, gain: true)
        } else {
            displayMinutes = remainingMinutes
        }
    }

    /// Manual per-minute roll: each tick is its own numericText morph +
    /// haptic; the per-step DELAY carries the easing.
    private func playRoll(from start: Int, to end: Int, gain: Bool) {
        displayMinutes = start
        let steps = abs(end - start)
        guard steps > 0 else { return }

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
                guard let self else { return }
                withAnimation(.easeInOut(duration: min(stepDelay, 0.45))) {
                    self.displayMinutes = value
                }
                if gain { SGTheme.tickUpHaptic() } else { SGTheme.tickDownHaptic() }
            }
            pendingTicks.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + accumulated, execute: work)
        }

        // Settle the swell shortly after the last tick lands.
        let settle = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(SGTheme.spring) { self.isRolling = false }
        }
        pendingTicks.append(settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + accumulated + 0.4, execute: settle)
    }

    private func cancelTicks() {
        pendingTicks.forEach { $0.cancel() }
        pendingTicks.removeAll()
        if isRolling { withAnimation(SGTheme.spring) { isRolling = false } }
    }
}

struct CountdownReadout: View {
    @ObservedObject var model: CountdownReplayModel
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
            .foregroundColor(isGain ? SGTheme.mint : SGTheme.ember)
            .shadow(color: (isGain ? SGTheme.mint : SGTheme.ember).opacity(0.6), radius: 14)
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
