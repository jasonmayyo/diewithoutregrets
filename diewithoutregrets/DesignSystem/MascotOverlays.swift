//
//  MascotOverlays.swift
//  diewithoutregrets
//
//  Fullscreen transition moments. Lock-in: the angry monster STAMPS onto
//  the screen — drops in oversized, lands with a heavy haptic thud, fires a
//  one-shot shockwave, then the "caught you" label settles in. Unlock: the
//  happy monster + mint pulse (still used by the focus-session flow; the
//  flashcard flow celebrates with UnlockCelebrationView instead).
//

import SwiftUI

/// Shown when entering the unlock flow — the monster caught you.
struct MascotLockOverlay: View {
    /// The drop-in (oversized → settled).
    @State private var appeared = false
    /// The landing: thud haptic, shockwave, glow.
    @State private var slammed = false
    @State private var showLabel = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            // Ember bloom rises with the landing.
            RadialGradient(colors: [SGTheme.ember.opacity(0.16), .clear],
                           center: .init(x: 0.5, y: 0.42),
                           startRadius: 30, endRadius: 360)
                .ignoresSafeArea()
                .opacity(slammed ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: slammed)

            ShockwaveRings(color: SGTheme.ember, fired: slammed)

            VStack(spacing: 22) {
                AngryMascotImage()
                    .frame(width: 200, height: 200)
                    .scaleEffect(appeared ? 1.0 : 1.45)
                    .rotationEffect(.degrees(appeared ? 0 : -5))
                    .opacity(appeared ? 1 : 0)
                    .shadow(color: SGTheme.ember.opacity(slammed ? 0.35 : 0), radius: 24)

                VStack(spacing: 8) {
                    SGMicroLabel(text: "Caught you scrolling", color: SGTheme.emberDeep)
                    Text("Locked.")
                        .font(SGTheme.display(30))
                        .foregroundColor(SGTheme.paper)
                }
                .opacity(showLabel ? 1 : 0)
                .offset(y: showLabel ? 0 : 12)
            }
        }
        .onAppear(perform: play)
    }

    private func play() {
        guard !reduceMotion else {
            appeared = true
            slammed = true
            showLabel = true
            SGTheme.errorHaptic()
            return
        }

        // The stamp: he drops toward the glass and lands hard.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) { appeared = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
            slammed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        withAnimation(SGTheme.spring.delay(0.4)) { showLabel = true }
    }
}

/// One-shot shockwave fired at the stamp's landing — expands and dies, no
/// endless pulsing.
private struct ShockwaveRings: View {
    let color: Color
    let fired: Bool

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.32 - Double(index) * 0.12), lineWidth: 2.5)
                    .frame(width: 230, height: 230)
                    .scaleEffect(fired ? 2.0 + CGFloat(index) * 0.45 : 0.8)
                    .opacity(fired ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.9).delay(Double(index) * 0.12), value: fired)
            }
        }
    }
}

/// Shown the moment an unlock is earned — the monster is proud of you.
/// (Caller grants the budget BEFORE presenting this — display only.)
struct MascotUnlockOverlay: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            PulseRings(color: SGTheme.mint)

            VStack(spacing: 18) {
                MascotView(pose: .idle, loops: 1)
                    .frame(width: 190, height: 190)
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(SGTheme.mint)
            }
            .scaleEffect(appeared ? 1.0 : 0.6)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            SGTheme.successHaptic()
            withAnimation(reduceMotion ? .none : .spring(response: 0.45, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

/// Expanding concentric pulse rings — shared by both overlays.
private struct PulseRings: View {
    let color: Color
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.35 - Double(index) * 0.1), lineWidth: 2)
                    .frame(width: 220 + CGFloat(index) * 90,
                           height: 220 + CGFloat(index) * 90)
                    .scaleEffect(pulsing ? 1.25 : 0.85)
                    .opacity(pulsing ? 0 : 1)
                    .animation(
                        reduceMotion ? .none :
                            .easeOut(duration: 1.4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.35),
                        value: pulsing
                    )
            }
        }
        .onAppear { pulsing = true }
    }
}
