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

// MARK: - Cold-start splash

/// The in-app continuation of the system launch screen: the same teal + the
/// same centered splash face, so the handoff from the static launch image is
/// invisible. Held on screen until the corner wipe swaps the app in.
struct ColdStartSplashView: View {
    /// The splash artwork's exact background teal (token in SGTheme).
    static let splashTeal = SGTheme.splashTeal

    var body: some View {
        ZStack {
            Self.splashTeal.ignoresSafeArea()
            // Unresized: 3x asset renders at the same point size and position
            // as the UILaunchScreen image — pixel-for-pixel continuity.
            Image("splash")
        }
    }
}

/// THE corner wipe: color sheets sweep in from the bottom-right corner, the
/// last band covers the screen, the caller swaps content while covered
/// (`onCovered`), then the wipe retracts to reveal it (`onFinished`).
///
/// One component, one timing, three band presets. The bands are always the
/// destination's ramp, so the transition previews where you are going and
/// every landing is color-matched.
struct SGCornerWipe: View {
    enum Preset {
        /// Splash → home canvas.
        case coldStart
        /// Day → the locked night scene.
        case lock
        /// Locked night → the quiz (back toward daylight).
        case unlock

        /// Outermost → innermost: index 0 is the leading edge (the first
        /// colour a pixel sees); the last settles at peak coverage.
        var bands: [Color] {
            switch self {
            case .coldStart: return [.white, SGTheme.splashTeal, SGTheme.ink]
            case .lock: return [.white, SGLockScene.accent, SGTheme.night]
            case .unlock: return [SGTheme.night, SGTheme.mint, SGTheme.ink]
            }
        }
    }

    var bands: [Color]
    var onCovered: () -> Void
    var onFinished: () -> Void

    // The one timing (the slower lock cadence, applied everywhere).
    private let coverDuration: Double = 0.6
    private let stagger: Double = 0.2
    private let revealDuration: Double = 0.5

    init(preset: Preset, onCovered: @escaping () -> Void = {}, onFinished: @escaping () -> Void = {}) {
        self.bands = preset.bands
        self.onCovered = onCovered
        self.onFinished = onFinished
    }

    init(bands: [Color], onCovered: @escaping () -> Void = {}, onFinished: @escaping () -> Void = {}) {
        self.bands = bands
        self.onCovered = onCovered
        self.onFinished = onFinished
    }

    /// Per-band cover scale (0 = point at corner, 1 = covers the screen).
    @State private var coverScale: [CGFloat] = [0.001, 0.001]
    /// Group retract scale for the reveal (1 = covering, 0 = shrunk away).
    @State private var retract: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            // 2.3× the diagonal so a corner-anchored circle fully clears the
            // opposite corner at scale 1.
            let diameter = 2.3 * hypot(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color)
                        .frame(width: diameter, height: diameter)
                        .scaleEffect(
                            index < coverScale.count ? coverScale[index] : 0.001,
                            anchor: .center
                        )
                        .position(x: geo.size.width, y: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(retract, anchor: .bottomTrailing)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle()) // absorb taps for the whole play
        .onAppear(perform: play)
    }

    private func play() {
        guard !reduceMotion else {
            // No sweep theatrics — swap under a brief full cover.
            coverScale = Array(repeating: 1, count: bands.count)
            onCovered()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) { retract = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onFinished() }
            return
        }

        if coverScale.count != bands.count {
            // Resize without animation, then start the grow on the next
            // runloop so the 0.001 baseline commits first (else the extra
            // bands would pop in fully grown).
            coverScale = Array(repeating: 0.001, count: bands.count)
            DispatchQueue.main.async { growBands() }
        } else {
            growBands()
        }
        let coverEnd = coverDuration + Double(bands.count - 1) * stagger

        // Screen covered: let the caller drop the splash, then retract the
        // wipe back into the corner to reveal the app.
        DispatchQueue.main.asyncAfter(deadline: .now() + coverEnd) {
            onCovered()
            withAnimation(.easeInOut(duration: revealDuration)) {
                retract = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + coverEnd + revealDuration) {
            onFinished()
        }
    }

    /// Cover: each band grows from the corner, staggered so they read as
    /// separate rings sweeping in.
    private func growBands() {
        for i in bands.indices {
            withAnimation(.easeIn(duration: coverDuration).delay(Double(i) * stagger)) {
                coverScale[i] = 1
            }
        }
    }
}

/// Shown when entering the unlock flow — the monster caught you.
/// The lock scene's shared stage values. The stamp overlay AND the locked
/// home both read these, so the crossfade between them is pixel-continuous
/// (rings and bloom land in exactly the same place at the same strength).
enum SGLockScene {
    /// The lock scene's red. Alarm (true red), not ember — the lock-out is
    /// the app's red-alert world; every lock-scene surface (wipe band,
    /// stamp bloom/rings, locked-home ripple) reads this one token.
    static let accent = SGTheme.alarm
    static let ringInnerOpacity = 0.22
    static let ringOuterOpacity = 0.10
    static let ringInnerSize: CGFloat = 264
    static let ringOuterSize: CGFloat = 356
    static let bloomOpacity = 0.20
    static let bloomCenter = UnitPoint(x: 0.5, y: 0.40)
    static let bloomStartRadius: CGFloat = 30
    static let bloomEndRadius: CGFloat = 360
}

struct MascotLockOverlay: View {
    /// Optional quiet third line, e.g. "Earn it back with your flashcards."
    var subtitle: String? = nil
    /// Canvas behind the stamp. The quiz flow keeps the warm white; the
    /// locked-home reveal passes LockedHomeView.night so the wipe, the
    /// stamp, and the dark home all share one background.
    var background: Color = SGTheme.ink
    /// Set alongside a dark `background`: flips the text to white.
    var onDark: Bool = false
    /// Delay before the stamp starts — lets a covering transition (the lock
    /// wipe) finish retracting before the monster drops.
    var startDelay: Double = 0
    /// When false, `onFinished` fires after the hold WITHOUT the red→white
    /// exit mask — the parent crossfades this overlay out instead. The quiz
    /// flow keeps the mask; the locked-home reveal fades to its dark scene.
    var usesExitMask: Bool = true
    /// When set, the overlay ends with a red→white mask that swallows the
    /// screen from the center, then calls back so the parent can fade this
    /// overlay out and reveal the quiz underneath.
    var onFinished: (() -> Void)? = nil

    /// The drop-in (oversized → settled).
    @State private var appeared = false
    /// The landing: thud haptic, shockwave, glow.
    @State private var slammed = false
    @State private var showLabel = false
    /// The exit mask: red swallows the screen, white right behind it.
    @State private var maskRed = false
    @State private var maskWhite = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            // Red-alert bloom rises with the landing (SGLockScene: shared
            // with LockedHomeView so the handoff is seamless).
            RadialGradient(colors: [SGLockScene.accent.opacity(SGLockScene.bloomOpacity), .clear],
                           center: SGLockScene.bloomCenter,
                           startRadius: SGLockScene.bloomStartRadius,
                           endRadius: SGLockScene.bloomEndRadius)
                .ignoresSafeArea()
                .opacity(slammed ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: slammed)

            // Static hairline rings give the mascot a stage without haze.
            ZStack {
                Circle()
                    .stroke(SGLockScene.accent.opacity(SGLockScene.ringInnerOpacity), lineWidth: 1)
                    .frame(width: SGLockScene.ringInnerSize, height: SGLockScene.ringInnerSize)
                Circle()
                    .stroke(SGLockScene.accent.opacity(SGLockScene.ringOuterOpacity), lineWidth: 1)
                    .frame(width: SGLockScene.ringOuterSize, height: SGLockScene.ringOuterSize)
            }
            .offset(y: ringOffset)
            .opacity(slammed ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: slammed)

            ShockwaveRings(color: SGLockScene.accent, fired: slammed)
                .offset(y: ringOffset)

            VStack(spacing: 30) {
                AngryMascotImage()
                    .frame(width: 180, height: 180)
                    .scaleEffect(appeared ? 1.0 : 1.45)
                    .rotationEffect(.degrees(appeared ? 0 : -5))
                    .opacity(appeared ? 1 : 0)
                    .shadow(color: SGLockScene.accent.opacity(slammed ? 0.30 : 0), radius: 28, y: 10)

                VStack(spacing: 12) {
                    SGMicroLabel(text: "Caught you scrolling",
                                 color: onDark ? SGLockScene.accent : SGTheme.alarmDeep)
                    Text("Locked.")
                        .font(SGTheme.display(40))
                        .foregroundColor(onDark ? .white : SGTheme.paper)
                    if let subtitle {
                        Text(subtitle)
                            .font(SGTheme.body)
                            .foregroundColor(onDark ? .white.opacity(0.65) : SGTheme.paperSecondary)
                            .padding(.top, 2)
                    }
                }
                .opacity(showLabel ? 1 : 0)
                .offset(y: showLabel ? 0 : 14)
            }

            // Exit mask: a red disc erupts from the center and swallows the
            // screen, white chases it, then the parent fades the whole
            // overlay so the quiz emerges from white.
            Circle()
                .fill(SGLockScene.accent)
                .frame(width: 30, height: 30)
                .scaleEffect(maskRed ? 70 : 0.001)
                .opacity(maskRed ? 1 : 0)
            Circle()
                .fill(SGTheme.ink)
                .frame(width: 30, height: 30)
                .scaleEffect(maskWhite ? 70 : 0.001)
                .opacity(maskWhite ? 1 : 0)
        }
        .onAppear(perform: play)
    }

    /// Rings center on the mascot, not the screen — the text block below
    /// pushes the mascot's visual center up from the VStack's midpoint.
    private var ringOffset: CGFloat { subtitle == nil ? -66 : -78 }

    private func play() {
        if startDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) { run() }
        } else {
            run()
        }
    }

    private func run() {
        guard !reduceMotion else {
            appeared = true
            slammed = true
            showLabel = true
            SGTheme.errorHaptic()
            if onFinished != nil {
                // No mask theatrics — hold the moment, then hand off.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onFinished?() }
            }
            return
        }

        // The stamp: he drops toward the glass and lands hard.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) { appeared = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            SGTheme.lockSlam()
            slammed = true
        }
        withAnimation(SGTheme.spring.delay(0.4)) { showLabel = true }

        guard onFinished != nil else { return }

        guard usesExitMask else {
            // Hold the stamp, then hand off — the parent crossfades us out.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { onFinished?() }
            return
        }

        // The mask: red erupts from center, white chases, quiz fades in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            SGTheme.beat()
            withAnimation(.easeIn(duration: 0.38)) { maskRed = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.38)) { maskWhite = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            onFinished?()
        }
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
                    .stroke(color.opacity(0.5 - Double(index) * 0.2), lineWidth: 1.5)
                    .frame(width: 230, height: 230)
                    .scaleEffect(fired ? 2.0 + CGFloat(index) * 0.45 : 0.8)
                    .opacity(fired ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.9).delay(Double(index) * 0.12), value: fired)
            }
        }
    }
}

// MascotUnlockOverlay and PulseRings were removed in the Phase 1 design
// migration: there is ONE unlock celebration (UnlockCelebrationView in
// QuizKit), used by both the flashcard and True Focus flows.
