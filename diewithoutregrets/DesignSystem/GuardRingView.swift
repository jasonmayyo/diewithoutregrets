//
//  GuardRingView.swift
//  diewithoutregrets
//
//  The signature element: the mascot lives inside the minutes-remaining
//  ring — he IS the guard. Mint→teal gradient while metering, full ember
//  when locked, dimmed when the guard is off. The ring only moves on
//  checkpoint refreshes (spring to the new value) — never a live tick.
//

import SwiftUI

struct GuardRingView: View {
    /// Remaining fraction 0...1 (ignored when `locked`).
    let progress: Double
    let locked: Bool
    let pose: MascotPose
    var dimmed: Bool = false
    var size: CGFloat = 260

    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { locked ? SGTheme.ember : SGTheme.mint }
    private var trimTo: Double { locked ? 1.0 : max(0.001, progress) }

    var body: some View {
        ZStack {
            // Soft halo behind everything — breathes.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.16), .clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.78
                    )
                )
                .frame(width: size * 1.55, height: size * 1.55)
                .opacity(breathing ? 0.95 : 0.55)
                .scaleEffect(breathing ? 1.05 : 1.0)

            // Track.
            Circle()
                .stroke(SGTheme.glaze(0.1), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: size, height: size)

            // Progress — springs to new checkpoint values.
            progressRing
                .frame(width: size, height: size)

            // Glow copy of the progress ring.
            progressRing
                .frame(width: size, height: size)
                .blur(radius: 6)
                .opacity(breathing ? 0.5 : 0.2)

            // The guard himself.
            MascotView(pose: pose)
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(y: 2)
        }
        .opacity(dimmed ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.6), value: locked)
        .animation(.easeInOut(duration: 0.4), value: dimmed)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private var progressRing: some View {
        Circle()
            .trim(from: 0, to: trimTo)
            .stroke(
                locked
                    ? AnyShapeStyle(SGTheme.ember)
                    : AnyShapeStyle(SGTheme.ringGradient),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(SGTheme.spring, value: trimTo)
    }
}
