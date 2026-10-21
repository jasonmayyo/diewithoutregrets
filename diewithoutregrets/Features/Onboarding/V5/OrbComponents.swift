// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
import SwiftUI
struct SGV5BudgetNumberAnim {
    var scale: Double = 1.0
    var redness: Double = 0.0
}

struct SGV5BudgetDropLabel: View {
    let text: String
    var color: Color = sgV5BudgetLabelRed
    var rise: Double = 70
    var duration: Double = 4.5
    @State private var gone = false

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 8)
            .offset(y: gone ? -rise : 0)
            .opacity(gone ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { gone = true }
            }
            .allowsHitTesting(false)
    }
}

struct SGV5DotGridRippleView: View {
    /// Origin of the ripple in unit coordinates (default = screen centre / orb).
    var center: UnitPoint = .center
    /// Absolute origin (in this view's own coordinate space). Overrides `center`
    /// when set — used to lock the ripple to the centrepiece wherever it sits.
    var centerPoint: CGPoint? = nil
    /// 0…1 extra energy. HomeView raises this while an unlock window is active.
    var intensity: Double = 0.14

    // Tunables — tweak freely to taste.
    // Tuned via the Debug → Ripple Tuner.
    var spacing: CGFloat = 17
    var dotSize: CGFloat = 2.65
    var maxStretch: CGFloat = 5.5
    var wavelength: CGFloat = 253      // px between radial wave crests
    var speed: Double = 1.73           // radial wave drift
    var ringSpeed: CGFloat = SGV5RippleSync.ringSpeed   // shared cadence (see RippleSync)
    var ringPeriod: CGFloat = SGV5RippleSync.ringPeriod
    var ringSpread: CGFloat = SGV5RippleSync.ringSpread
    var dotColor: Color = SGTheme.paper
    var holeRadius: CGFloat = 58       // clear circle around the centrepiece
    var holeFeather: CGFloat = 151     // soft fade-in band beyond the hole

    /// Reference-date seconds of the last "budget dropped" event. While set and
    /// recent, the dots blend toward `alertColor` then ease back to `dotColor`
    /// over `alertDuration`, and the wave gets a little extra energy.
    var alertStart: TimeInterval? = nil
    var alertColor: Color = .red
    var alertDuration: Double = 1.8

    /// Freeze the ripple in place (the focus session is paused). The timeline stops
    /// advancing so the wave holds, then continues when unpaused.
    var paused: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Canvas { context, size in
                draw(context, size: size, t: 0)
            }
        } else {
            TimelineView(.animation(paused: paused)) { timeline in
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

        // Budget-drop alert: ease from full strength at the event down to 0 over
        // alertDuration, using the same clock as the animation (t > 0). The static
        // reduce-motion branch passes t == 0 and skips the tint.
        var alertF: Double = 0
        if let alertStart = alertStart, t > 0 {
            alertF = max(0, min(1, 1 - (t - alertStart) / alertDuration))
        }
        let drawColor = blend(from: dotColor, to: alertColor, amount: alertF)
        let effectiveIntensity = intensity + alertF * 0.5

        let stretchScale = maxStretch * (1.0 + effectiveIntensity * 1.3)
        let peakBoost = 1.0 + effectiveIntensity * 0.9
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

                // Soft circle around the centre. `hole` ≈ 0 in the middle, 1 outside.
                let edge = max(0, min(1, (dist - holeRadius) / holeFeather))
                let hole = Double(edge * edge * (3 - 2 * edge)) // smoothstep
                amp *= hole

                // The middle is filled with STATIC, dark, non-animated dots (no
                // stretch) that fade out as the animated outer dots take over.
                let centreFactor = 1 - hole
                if centreFactor > 0.02 {
                    let r = dotSize / 2
                    let dotRect = CGRect(x: x - r, y: y - r, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: dotRect),
                                 with: .color(SGTheme.inkRaised.opacity(centreFactor)))
                }

                if hole < 0.01 { continue }

                // Every dot stays visible at rest; the wave only ADDS brightness
                // and stretches it into a dash — dots never disappear.
                let restingOpacity = 0.16 * hole
                let waveOpacity = amp * 0.55 * peakBoost
                let opacity = min(0.95, restingOpacity + waveOpacity)

                let length = dotSize + CGFloat(amp) * stretchScale
                let rect = CGRect(x: -dotSize / 2, y: -length / 2, width: dotSize, height: length)
                let path = Capsule().path(in: rect)

                var cellContext = context
                cellContext.translateBy(x: x, y: y)
                cellContext.rotate(by: .radians(angle - .pi / 2)) // long axis points radially
                cellContext.fill(path, with: .color(drawColor.opacity(opacity)))
            }
        }
    }

    /// Linear RGB blend between two colors (0 = `from`, 1 = `to`).
    private func blend(from: Color, to: Color, amount: Double) -> Color {
        guard amount > 0 else { return from }
        let a = amount
        let f = UIColor(from)
        let g = UIColor(to)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var gr: CGFloat = 0, gg: CGFloat = 0, gb: CGFloat = 0, ga: CGFloat = 0
        f.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        g.getRed(&gr, green: &gg, blue: &gb, alpha: &ga)
        return Color(
            red: Double(fr) * (1 - a) + Double(gr) * a,
            green: Double(fg) * (1 - a) + Double(gg) * a,
            blue: Double(fb) * (1 - a) + Double(gb) * a
        )
    }
}

func sgV5FormatBudgetMinutes(_ totalMinutes: Int) -> String {
    let m = max(0, totalMinutes)
    let h = m / 60
    let mm = m % 60
    if h > 0 && mm > 0 { return "\(h)h \(String(format: "%02d", mm))m" }
    if h > 0 { return "\(h)h" }
    return "\(String(format: "%02d", mm))m"
}

func sgV5BlendWhite(to color: Color, amount: Double) -> Color {
    let u = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    u.getRed(&r, green: &g, blue: &b, alpha: &a)
    let f = max(0, min(1, amount))
    let base = UIColor(SGTheme.paper)
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return Color(red: Double(br) + (Double(r) - Double(br)) * f,
                 green: Double(bg) + (Double(g) - Double(bg)) * f,
                 blue: Double(bb) + (Double(b) - Double(bb)) * f)
}
let sgV5BudgetAlarmRed = SGTheme.ember
let sgV5BudgetGainGreen = SGTheme.mint
let sgV5BudgetLabelRed = SGTheme.emberDeep
let sgV5BudgetLabelGreen = SGTheme.mintDeep

enum SGV5RippleSync {
    static let ringSpeed: CGFloat = 122   // px/sec a crest sweeps outward
    static let ringPeriod: CGFloat = 413  // px between successive crests
    static let ringSpread: CGFloat = 34   // crest width (px)
    /// Seconds between crests launching from the centre.
    static var period: Double { Double(ringPeriod / ringSpeed) }
}
