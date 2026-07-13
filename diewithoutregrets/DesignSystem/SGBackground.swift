//
//  SGBackground.swift
//  diewithoutregrets
//
//  "Morning Mist" aurora — the Meadow ambient background. Three soft
//  pastel radial-gradient blobs drift on slow sine paths over the white
//  canvas.
//  Deliberately NOT a particle/dot field. Radial gradients are already
//  soft, so there is no live blur; the TimelineView runs at 20fps and
//  pauses when the scene is inactive; Reduce Motion gets a static frame.
//

import SwiftUI

struct SGAuroraBackground: View {
    /// 0...1 — how present the blobs are.
    var intensity: Double = 1.0
    /// Locked state warms the field toward ember.
    var emberTint: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()
            if reduceMotion {
                blobs(t: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: scenePhase != .active)) { timeline in
                    blobs(t: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .animation(.easeInOut(duration: 1.2), value: emberTint)
    }

    private func blobs(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                blob(color: emberTint ? SGTheme.ember : SGTheme.teal,
                     diameter: w * 1.5, opacity: 0.11 * intensity)
                    .position(x: w * 0.18 + sin(t / 19) * 40,
                              y: h * 0.12 + cos(t / 23) * 30)

                blob(color: SGTheme.mint,
                     diameter: w * 1.3, opacity: 0.07 * intensity)
                    .position(x: w * 0.88 + cos(t / 17) * 35,
                              y: h * 0.42 + sin(t / 21) * 40)

                blob(color: emberTint ? SGTheme.ember : SGTheme.mint,
                     diameter: w * 1.6, opacity: 0.06 * intensity)
                    .position(x: w * 0.35 + sin(t / 29) * 50,
                              y: h * 0.95 + cos(t / 25) * 30)
            }
        }
        .ignoresSafeArea()
    }

    private func blob(color: Color, diameter: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }
}
