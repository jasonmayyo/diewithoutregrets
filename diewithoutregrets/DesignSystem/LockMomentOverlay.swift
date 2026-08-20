//
//  LockMomentOverlay.swift
//  diewithoutregrets
//
//  The lock moment — replaces the old corner-wipe + monster-stamp reveal.
//  A night scrim fades up over the dead 0m readout, Lock.lottie clicks
//  shut in the centre, and on the final click a single dot-ripple burst
//  (the locked home's dot language, fired once) disperses outward. Then
//  the whole overlay slowly fades away and the locked home, already set
//  underneath while the screen was covered, fades up.
//
//  Choreography:
//    fade in (0.3s) → onCovered (caller swaps the locked scene in)
//    → Lock.lottie plays once → click: haptic slam + one-shot burst
//    → burst disperses (~1s) → fade out (0.7s) → onFinished
//

import SwiftUI
import Lottie

struct LockMomentOverlay: View {
    /// Called once the scrim is opaque — safe to swap the scene underneath.
    var onCovered: () -> Void = {}
    /// Called after the fade-out completes — remove the overlay.
    var onFinished: () -> Void = {}

    /// >1 tightens the source's drop-and-click (frames 0-52) into a quick
    /// beat: 52 / 30fps / 1.3 ≈ 1.3s.
    var lottieSpeed: CGFloat = 1.3

    @State private var covered = false
    @State private var burstStartedAt: Date?
    @State private var fadingOut = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SGTheme.night.ignoresSafeArea()

            // The one-shot burst rides behind the lock so the dots read as
            // dispersing FROM it.
            if let start = burstStartedAt {
                LockRippleBurst(startedAt: start)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            LockClickLottie(speed: lottieSpeed, onClick: fireBurst)
                .frame(width: 330, height: 250)
        }
        .opacity(covered && !fadingOut ? 1 : 0)
        .contentShape(Rectangle()) // absorb taps for the whole play
        .onAppear(perform: play)
    }

    private func play() {
        guard !covered else { return }

        if reduceMotion {
            // No theatrics: cover, swap, reveal.
            covered = true
            onCovered()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.4)) { fadingOut = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: onFinished)
            }
            return
        }

        withAnimation(.easeIn(duration: 0.3)) { covered = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            onCovered()
        }
        // The lottie starts on its own once loaded; onClick drives the rest.
    }

    /// The lock just clicked shut: slam haptic, one burst, then the slow
    /// fade to the locked home.
    private func fireBurst() {
        guard burstStartedAt == nil else { return }
        SGTheme.lockSlam()
        burstStartedAt = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.7)) { fadingOut = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72, execute: onFinished)
        }
    }
}

// MARK: - Lock.lottie (one-shot, click callback)

/// Plays Lock.lottie once and reports completion — the "click" the burst
/// keys off. Falls back to an immediate click if the file fails to load,
/// so the reveal can never strand.
private struct LockClickLottie: UIViewRepresentable {
    let speed: CGFloat
    let onClick: () -> Void

    func makeUIView(context: Context) -> some UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        Task { @MainActor in
            guard let file = try? await DotLottieFile.named("Lock") else {
                onClick()
                return
            }
            let view = LottieAnimationView(dotLottie: file)
            view.loopMode = .playOnce
            view.animationSpeed = speed
            view.contentMode = .scaleAspectFit
            view.backgroundColor = .clear
            view.translatesAutoresizingMaskIntoConstraints = false

            // The source art is near-black — recolor every fill and stroke
            // white so the lock reads against the night scrim.
            view.setValueProvider(
                ColorValueProvider(LottieColor(r: 1, g: 1, b: 1, a: 1)),
                keypath: AnimationKeypath(keypath: "**.Color")
            )

            container.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])

            // The source loops: shackle drops in and clicks shut at frame
            // 50, holds, then pops back open at 105 to loop seamlessly.
            // Stop just past the click so the lock stays SHUT — the click
            // is the story beat the burst fires on.
            view.play(fromFrame: 0, toFrame: 52, loopMode: .playOnce) { _ in
                onClick()
            }
        }

        return container
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

// MARK: - One-shot dot ripple burst

/// A single crest of the locked home's dot ripple, fired once from the
/// centre: the same grid, dash stretch and alarm colour as SGDotGridRipple,
/// but one expanding ring that decays as it travels instead of an endless
/// storm.
struct LockRippleBurst: View {
    let startedAt: Date

    /// How long the crest takes to cross the screen and die out.
    var duration: Double = 1.4

    // Grid language shared with SGDotGridRipple.
    var spacing: CGFloat = 17
    var dotSize: CGFloat = 2.65
    var maxStretch: CGFloat = 5.5
    var ringSpread: CGFloat = 44
    var dotColor: Color = SGTheme.alarm

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startedAt)
            Canvas { context, size in
                draw(context, size: size, t: t)
            }
        }
    }

    private func draw(_ context: GraphicsContext, size: CGSize, t: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }
        let progress = t / duration
        guard progress >= 0, progress <= 1 else { return }

        let cx = size.width / 2
        let cy = size.height / 2
        let maxDist = hypot(cx, cy) + ringSpread * 2
        // Ease-out travel: fast off the lock, coasting at the edges.
        let eased = 1 - pow(1 - progress, 2)
        let ringPos = CGFloat(eased) * maxDist
        // The crest dims as it disperses.
        let energy = pow(1 - progress, 1.5)

        let cols = Int(size.width / spacing) + 2
        let rows = Int(size.height / spacing) + 2

        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * spacing
                let y = CGFloat(row) * spacing
                let dx = x - cx
                let dy = y - cy
                let dist = sqrt(dx * dx + dy * dy)

                let dRing = dist - ringPos
                let ring = exp(-(dRing * dRing) / (2 * ringSpread * ringSpread))
                let amp = Double(ring) * energy
                if amp < 0.02 { continue }

                let opacity = min(0.95, amp * 0.85)
                let length = dotSize + CGFloat(amp) * maxStretch
                let rect = CGRect(x: -dotSize / 2, y: -length / 2,
                                  width: dotSize, height: length)
                let path = Capsule().path(in: rect)

                var cell = context
                cell.translateBy(x: x, y: y)
                cell.rotate(by: .radians(atan2(dy, dx) - .pi / 2))
                cell.fill(path, with: .color(dotColor.opacity(opacity)))
            }
        }
    }
}

#Preview("Lock moment") {
    ZStack {
        Color.white.ignoresSafeArea()
        LockMomentOverlay()
    }
}
