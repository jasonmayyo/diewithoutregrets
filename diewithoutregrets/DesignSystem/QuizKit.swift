//
//  QuizKit.swift
//  diewithoutregrets
//
//  The unlock quiz's feedback layer: haptic bursts, the segmented progress
//  bar, answer tiles with a mask-sweep correct reveal, and the full-screen
//  time-unlocked celebration. Display-only — no engine calls in here.
//
//  Signature moves:
//  - Correct answers SWEEP: a solid-mint copy of the tile is revealed by a
//    leading-edge mask, so the color washes across the text instead of
//    snapping. Wrong answers shake.
//  - Progress segments fill with the same mask sweep, then pop with a
//    spring + brief glow.
//  - The celebration opens with an expanding circle mask, counts the earned
//    minutes up with per-tick haptics, draws the ring, then lands with a
//    success chime + confetti.
//

import SwiftUI

// MARK: - Haptics

/// Timed haptic sequences for the quiz. Each moment is a little composition,
/// not a single tap — that layering is what reads as "satisfying".
enum QuizHaptics {
    static func selectTick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
    }

    /// Correct: soft tap, rigid snap, then the success chime.
    static func correctBurst() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Wrong: error buzz with a heavy afterthud.
    static func wrongBuzz() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.6)
        }
    }

    static func celebrationTick() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
    }

    static func celebrationLanding() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
    }
}

// MARK: - Shake

/// Horizontal shake for wrong answers. Drive `animatableData` 0 → 1 inside
/// withAnimation to play one full shake.
struct QuizShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: travel * sin(animatableData * .pi * shakes * 2),
            y: 0
        ))
    }
}

// MARK: - Progress bar

/// Segmented quiz progress: one capsule per question. Answered segments
/// fill with a leading-edge sweep and pop; the current segment breathes.
struct QuizProgressBar: View {
    let results: [Bool?]
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(results.indices, id: \.self) { index in
                QuizProgressSegment(
                    result: results[index],
                    isCurrent: index == currentIndex && results[index] == nil
                )
            }
        }
        .frame(height: 8)
    }
}

private struct QuizProgressSegment: View {
    let result: Bool?
    let isCurrent: Bool

    /// 0 → 1 fill sweep once answered.
    @State private var fill: CGFloat = 0
    /// Spring pop as the fill lands.
    @State private var popped = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fillColor: Color {
        (result ?? true) ? SGTheme.mint : SGTheme.emberDeep
    }

    var body: some View {
        Capsule(style: .continuous)
            .fill(SGTheme.glaze(0.08))
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule(style: .continuous)
                        .fill(fillColor)
                        .frame(width: geo.size.width * fill)
                }
            }
            .opacity(isCurrent && breathing ? 0.55 : 1)
            .modifier(SegmentPop(popped: popped, glow: fillColor))
            .onChange(of: result != nil) { _, answered in
                guard answered else { return }
                if reduceMotion {
                    fill = 1
                    return
                }
                withAnimation(.easeOut(duration: 0.35)) { fill = 1 }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.2)) { popped = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.5)) { popped = false }
                }
            }
            .onAppear {
                // Already-answered segments (retry re-entry) show filled, no show.
                if result != nil { fill = 1 }
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}

/// Scale + glow pop for a just-filled segment.
private struct SegmentPop: ViewModifier {
    let popped: Bool
    let glow: Color

    func body(content: Content) -> some View {
        content
            .scaleEffect(popped ? 1.25 : 1.0)
            .shadow(color: popped ? glow.opacity(0.55) : .clear, radius: popped ? 6 : 0)
    }
}

// MARK: - Answer tiles

enum QuizTileState: Equatable {
    case idle
    case selected
    case revealedCorrect
    case revealedWrong
    /// Another tile was the story — fade back.
    case dimmed
}

/// One answer option. The correct reveal is a true masking animation: a
/// solid-mint copy of the tile sits on top and a leading-edge mask sweeps
/// it across, washing the color through the text.
struct QuizAnswerTile: View {
    let text: String
    let state: QuizTileState
    var action: () -> Void = {}

    @State private var sweep: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var swell = false
    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                // Base layer: normal tile (also carries the wrong styling).
                tileContent(
                    foreground: baseForeground,
                    badge: state == .revealedWrong ? "xmark.circle.fill" : nil,
                    badgeTint: SGTheme.emberDeep
                )
                .background(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                        .fill(baseFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                                .strokeBorder(baseBorder, lineWidth: borderWidth)
                        )
                )

                // Sweep layer: the mint tile, revealed left → right by mask.
                tileContent(
                    foreground: .white,
                    badge: stamped ? "checkmark.circle.fill" : nil,
                    badgeTint: .white
                )
                .background(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                        .fill(SGTheme.mint)
                        .shadow(color: SGTheme.mint.opacity(0.45), radius: sweep > 0 ? 10 : 0, y: 3)
                )
                .mask(
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .frame(width: geo.size.width * sweep)
                    }
                )
                .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(swell ? 1.035 : 1.0)
        .opacity(state == .dimmed ? 0.45 : 1)
        .modifier(QuizShakeEffect(animatableData: shake))
        .animation(SGTheme.springFast, value: state)
        .onChange(of: state) { _, newState in
            switch newState {
            case .revealedCorrect: playCorrect()
            case .revealedWrong: playWrong()
            case .idle:
                // Retry / next question: reset the show.
                sweep = 0
                swell = false
                stamped = false
            default: break
            }
        }
        .onAppear {
            // The reveal step builds fresh tiles, so the show starts here
            // (onChange covers parents that mutate state in place instead).
            switch state {
            case .revealedCorrect: playCorrect()
            case .revealedWrong: playWrong()
            default: break
            }
        }
    }

    private func playCorrect() {
        if reduceMotion {
            sweep = 1
            stamped = true
            return
        }
        withAnimation(.easeOut(duration: 0.38)) { sweep = 1 }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.18)) {
            stamped = true
            swell = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(SGTheme.spring) { swell = false }
        }
    }

    private func playWrong() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.4)) { shake += 1 }
    }

    private func tileContent(foreground: Color, badge: String?, badgeTint: Color) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let badge {
                Image(systemName: badge)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(badgeTint)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    private var baseForeground: Color {
        state == .revealedWrong ? SGTheme.emberDeep : SGTheme.paper
    }

    private var baseFill: Color {
        switch state {
        case .selected: return SGTheme.mint.opacity(0.12)
        case .revealedWrong: return SGTheme.ember.opacity(0.14)
        default: return SGTheme.inkRaised
        }
    }

    private var baseBorder: Color {
        switch state {
        case .selected: return SGTheme.mint
        case .revealedWrong: return SGTheme.ember.opacity(0.6)
        default: return SGTheme.hairline
        }
    }

    private var borderWidth: CGFloat {
        state == .selected ? 2 : 1
    }
}

// MARK: - Celebration

/// The full-screen "time unlocked" moment, staged like the Meadow home it
/// hands off to: the giant earned-minutes numeral owns the white air (same
/// type treatment as the home hero), the whiteboard mascot celebrates on
/// the green hill, and the start button sits on the grass. Opens with an
/// expanding circle mask; the count-up ticks with haptics and lands with a
/// chime + confetti.
struct UnlockCelebrationView: View {
    let minutes: Int
    let ctaTitle: String
    let onStart: () -> Void

    @State private var revealed = false
    @State private var shownMinutes = 0
    @State private var landed = false
    @State private var showConfetti = false
    @State private var showCTA = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // The air: the readout, styled exactly like the home hero so
            // returning home feels like the same number settling in.
            VStack(spacing: 14) {
                Spacer(minLength: 24)

                numeral
                    .scaleEffect(landed ? 1.07 : 1.0)

                SGMicroLabel(text: "Time unlocked", color: SGTheme.mintDeep)

                Text("Every card correct. He's impressed.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 2)

                Spacer(minLength: 0)
                    .frame(maxHeight: 56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The meadow: whiteboard mascot on the crest, CTA on the grass.
            VStack(spacing: 0) {
                SGPrimaryButton(title: ctaTitle,
                                tint: .white.opacity(0.96),
                                labelColor: SGTheme.mintDeep,
                                action: onStart)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, y: 5)
                    .opacity(showCTA ? 1 : 0)
                    .offset(y: showCTA ? 0 : 16)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 150)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(
                MeadowHill()
                    .fill(SGTheme.meadowGradient)
                    .shadow(color: SGTheme.mint.opacity(0.28), radius: 24, y: -8)
                    .padding(.top, 92)
                    .ignoresSafeArea(edges: .bottom)
            )
            .overlay(alignment: .top) {
                MascotView(pose: .teaching, loops: nil)
                    .frame(width: 150, height: 150)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGTheme.ink.ignoresSafeArea())
        // The circle-mask reveal: the whole screen blooms out of the center.
        .mask(
            Circle()
                .scale(revealed ? 4 : 0.02)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: revealed)
        )
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onAppear(perform: play)
    }

    /// "+15 m" — the home hero's exact type treatment (plain SF semibold
    /// digits, thin space, muted medium unit).
    private var numeral: some View {
        (Text("+\(shownMinutes)")
            .font(.system(size: 88, weight: .semibold))
         + Text("\u{2009}m")
            .font(.system(size: 40, weight: .medium))
            .foregroundColor(SGTheme.paperSecondary))
            .foregroundColor(SGTheme.paper)
            .contentTransition(.numericText())
    }

    private func play() {
        guard !reduceMotion else {
            revealed = true
            shownMinutes = minutes
            showCTA = true
            return
        }

        revealed = true

        runCountUp(startingAt: 0.5, over: 1.35)

        let landingTime = 0.5 + 1.35 + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + landingTime) {
            QuizHaptics.celebrationLanding()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { landed = true }
            withAnimation(.easeOut(duration: 0.4)) { showConfetti = true }
            withAnimation(SGTheme.spring.delay(0.35)) { showCTA = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(SGTheme.spring) { landed = false }
            }
        }
    }

    /// Ease-out count-up: ticks bunch at the start, land gently, one soft
    /// haptic per tick (capped so long grants don't buzz forever).
    private func runCountUp(startingAt lead: Double, over duration: Double) {
        guard minutes > 0 else { return }
        let ticks = min(minutes, 22)
        for i in 1...ticks {
            let t = Double(i) / Double(ticks)
            let eased = 1 - pow(1 - t, 2.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + lead + duration * eased) {
                withAnimation(.easeOut(duration: 0.12)) {
                    shownMinutes = Int((Double(minutes) * t).rounded())
                }
                QuizHaptics.celebrationTick()
            }
        }
    }
}

// MARK: - Failure

/// Full-screen "still locked" takeover: ember bloom, the disappointed
/// monster, the score, and the ways out. Display-only; the caller owns
/// every action.
struct QuizFailureView: View {
    let correctCount: Int
    let totalCount: Int
    /// nil hides the emergency option (legacy flow).
    let emergencyUnlocksRemaining: Int?
    var giveUpTitle: String = "Give up for now"
    let onRetry: () -> Void
    let onEmergency: () -> Void
    let onGiveUp: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RadialGradient(colors: [SGTheme.ember.opacity(0.14), .clear],
                           center: .init(x: 0.5, y: 0.26),
                           startRadius: 30, endRadius: 360)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                MascotView(pose: .lookingDown)
                    .frame(height: 150)
                    .padding(.bottom, 18)

                SGMicroLabel(text: "Still locked", color: SGTheme.emberDeep)
                    .padding(.bottom, 12)

                Text("Not quite.")
                    .font(SGTheme.display(32))
                    .foregroundColor(SGTheme.paper)
                    .padding(.bottom, 8)

                Text(totalCount > 0
                     ? "You got \(correctCount) of \(totalCount). Your apps stay locked until every card is right."
                     : "Your apps stay locked until every card is right.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 44)

                Spacer()

                VStack(spacing: 12) {
                    SGPrimaryButton(title: "Retry questions", action: onRetry)

                    if let remaining = emergencyUnlocksRemaining {
                        SGGhostButton(title: "Emergency unlock (\(remaining) left this week)",
                                      action: onEmergency)
                    }

                    Button(action: onGiveUp) {
                        Text(giveUpTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(SGTheme.emberDeep)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SGPressStyle())
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : SGTheme.spring) { appeared = true }
        }
    }
}

#Preview("Failure") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        QuizFailureView(correctCount: 2, totalCount: 3, emergencyUnlocksRemaining: 2,
                        onRetry: {}, onEmergency: {}, onGiveUp: {})
    }
}

#Preview("Celebration") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        UnlockCelebrationView(minutes: 15, ctaTitle: "Start my 15 minutes", onStart: {})
    }
}

#Preview("Tiles") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        VStack(spacing: 14) {
            QuizProgressBar(results: [true, true, false, nil, nil], currentIndex: 3)
                .padding(.bottom, 20)
            QuizAnswerTile(text: "Mitochondria", state: .revealedCorrect)
            QuizAnswerTile(text: "Nucleus", state: .revealedWrong)
            QuizAnswerTile(text: "Ribosome", state: .dimmed)
            QuizAnswerTile(text: "Golgi body", state: .selected)
        }
        .padding(24)
    }
}
