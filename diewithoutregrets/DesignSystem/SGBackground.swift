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

// MARK: - Dot-grid ripple (the lock-out scene backdrop)

/// Full-screen grid of dots that stretch into radially-oriented dashes as
/// waves ripple outward from a centre point — ported from One Thing's
/// DotGridRippleView (its home-screen signature), recolored for the alarm
/// world of the locked home. Pure SwiftUI Canvas + TimelineView, no assets.
/// The centre hole stays calm (static dark dots) so the mascot sits in a
/// quiet eye while the storm radiates around him.
struct SGDotGridRipple: View {
    /// Origin of the ripple in unit coordinates (default = screen centre).
    var center: UnitPoint = .center
    /// Absolute origin (in this view's own coordinate space). Overrides
    /// `center` when set — used to lock the ripple to the mascot wherever
    /// he sits.
    var centerPoint: CGPoint? = nil
    /// 0…1 extra energy.
    var intensity: Double = 0.14

    // Tunables — One Thing's home-screen values, kept verbatim.
    var spacing: CGFloat = 17
    var dotSize: CGFloat = 2.65
    var maxStretch: CGFloat = 5.5
    var wavelength: CGFloat = 253      // px between radial wave crests
    var speed: Double = 1.73           // radial wave drift
    var ringSpeed: CGFloat = 122       // px/sec a crest sweeps outward
    var ringPeriod: CGFloat = 413      // px between successive crests
    var ringSpread: CGFloat = 34       // crest width (px)
    var dotColor: Color = SGTheme.alarm
    var holeRadius: CGFloat = 88       // clear circle around the mascot
    var holeFeather: CGFloat = 151     // soft fade-in band beyond the hole

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                draw(context, size: size, t: 0)
            }
        } else {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    draw(context, size: size, t: t)
                }
            }
        }
    }

    private func draw(_ context: GraphicsContext, size: CGSize, t: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }

        let cx = centerPoint?.x ?? (size.width * center.x)
        let cy = centerPoint?.y ?? (size.height * center.y)
        let cols = Int(size.width / spacing) + 2
        let rows = Int(size.height / spacing) + 2

        let stretchScale = maxStretch * (1.0 + intensity * 1.3)
        let peakBoost = 1.0 + intensity * 0.9
        let ringPos = CGFloat(t) * ringSpeed

        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * spacing
                let y = CGFloat(row) * spacing
                let dx = x - cx
                let dy = y - cy
                let dist = sqrt(dx * dx + dy * dy)
                let angle = atan2(dy, dx)

                let phase = Double(dist / wavelength) - t * speed
                let base = sin(phase)

                var m = (dist - ringPos).truncatingRemainder(dividingBy: ringPeriod)
                if m < 0 { m += ringPeriod }
                let dRing = min(m, ringPeriod - m)
                let ring = exp(-(dRing * dRing) / (2 * ringSpread * ringSpread))

                var amp = base * 0.35 + Double(ring)
                amp = max(0, min(1, amp))

                // Soft circle around the centre. `hole` ≈ 0 in the middle,
                // 1 outside.
                let edge = max(0, min(1, (dist - holeRadius) / holeFeather))
                let hole = Double(edge * edge * (3 - 2 * edge)) // smoothstep
                amp *= hole

                // The middle is filled with STATIC, dim, non-animated dots
                // (no stretch) that fade out as the animated outer dots
                // take over.
                let centreFactor = 1 - hole
                if centreFactor > 0.02 {
                    let r = dotSize / 2
                    let dotRect = CGRect(x: x - r, y: y - r, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: dotRect),
                                 with: .color(Color(white: 0.13).opacity(centreFactor)))
                }

                if hole < 0.01 { continue }

                // Every dot stays visible at rest; the wave only ADDS
                // brightness and stretches it into a dash — dots never
                // disappear.
                let restingOpacity = 0.16 * hole
                let waveOpacity = amp * 0.55 * peakBoost
                let opacity = min(0.95, restingOpacity + waveOpacity)

                let length = dotSize + CGFloat(amp) * stretchScale
                let rect = CGRect(x: -dotSize / 2, y: -length / 2, width: dotSize, height: length)
                let path = Capsule().path(in: rect)

                var cellContext = context
                cellContext.translateBy(x: x, y: y)
                cellContext.rotate(by: .radians(angle - .pi / 2)) // long axis points radially
                cellContext.fill(path, with: .color(dotColor.opacity(opacity)))
            }
        }
    }
}
