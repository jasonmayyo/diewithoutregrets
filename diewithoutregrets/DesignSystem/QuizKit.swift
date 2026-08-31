//
//  QuizKit.swift
//  diewithoutregrets
//
//  The unlock quiz's feedback layer: haptic moments, the segmented progress
//  bar, answer tiles with a mask-sweep correct reveal, the praise capsule,
//  the wrong-answer panel, and the full-screen grant-stamp celebration.
//  Display-only — no engine calls in here.
//
//  Signature moves:
//  - Correct answers SWEEP: a solid-mint copy of the tile is revealed by a
//    leading-edge mask, so the color washes across the text instead of
//    snapping. Wrong answers shake. Each tile plays its reveal exactly once
//    per state change — the `played` latch makes replays impossible.
//  - Progress segments fill with the same mask sweep, then pop with a
//    spring + brief glow. Only the CURRENT segment breathes.
//  - The celebration is one decisive beat: circle-mask reveal, the mint
//    grant stamp + full "+N m" numeral landing together on ONE haptic,
//    a single ring pulse, done. The count-up lives on the home hero, so
//    the earned minutes are counted exactly once.
//

import SwiftUI

// MARK: - Haptics

/// Quiz haptic moments — thin delegates into the SGTheme haptic grammar
/// (the compositions live there, next to lockSlam). Kept as a named enum so
/// quiz call sites read as moments, not hardware.
enum QuizHaptics {
    static func selectTick() { SGTheme.tick() }
    static func correctBurst() { SGTheme.correctBurst() }
    static func wrongBuzz() { SGTheme.wrongBuzz() }
    static func celebrationTick() { SGTheme.celebrationTick() }
    static func celebrationLanding() { SGTheme.celebrationLanding() }
    static func coinLand(progress: Double) { SGTheme.collectTick(progress: progress) }
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
        .accessibilityElement()
        .accessibilityValue("Question \(min(currentIndex + 1, max(results.count, 1))) of \(results.count)")
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
    @State private var popTask: Task<Void, Never>?
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
            .opacity(breathing ? 0.55 : 1)
            .modifier(SegmentPop(popped: popped, glow: fillColor))
            .onChange(of: result != nil) { _, answered in
                if answered {
                    playFill()
                } else {
                    // Early retry keeps the bar in-tree and reverts results
                    // to nil — the segment must visibly reset with it.
                    popTask?.cancel()
                    fill = 0
                    popped = false
                }
            }
            .onChange(of: isCurrent) { _, current in
                updateBreathing(current)
            }
            .onAppear {
                // Already-answered segments (re-entry) show filled, no show.
                if result != nil { fill = 1 }
                updateBreathing(isCurrent)
            }
            .onDisappear {
                popTask?.cancel()
            }
    }

    private func playFill() {
        if reduceMotion {
            fill = 1
            return
        }
        withAnimation(.easeOut(duration: SGTheme.quizSegmentFill)) { fill = 1 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.2)) { popped = true }
        popTask?.cancel()
        popTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { popped = false }
        }
    }

    /// Only the current segment runs the breathe loop — N perpetual
    /// repeatForever animations on a progress bar is exactly the kind of
    /// noise this kit exists to prevent.
    private func updateBreathing(_ active: Bool) {
        if active && !reduceMotion {
            withAnimation(.easeInOut(duration: SGTheme.breatheCycle / 2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { breathing = false }
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
///
/// The reveal plays EXACTLY once per state change (the `played` latch), no
/// matter how the parent re-renders — parents mutate `state` in place on
/// one stable tile identity; never swap tiles through an if/else branch,
/// which would crossfade a ghost copy of the tile under the reveal.
struct QuizAnswerTile: View {
    let text: String
    let state: QuizTileState
    /// Shows the tap-again-to-confirm hint while selected (the quiz turns
    /// this on for the first arm of a session).
    var confirmHint: Bool = false
    var action: () -> Void = {}

    @State private var sweep: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var swell = false
    @State private var stamped = false
    /// One-shot latch: the reveal show runs once per reveal, full stop.
    @State private var played = false
    @State private var swellTask: Task<Void, Never>?
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
                        .shadow(color: SGTheme.mint.opacity(0.45), radius: 10 * sweep, y: 3)
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
                swellTask?.cancel()
                sweep = 0
                swell = false
                stamped = false
                played = false
            default: break
            }
        }
        .onAppear {
            // A tile that MOUNTS already revealed (re-entry into a shown
            // reveal) starts its show here; the latch keeps this and
            // onChange from ever double-playing.
            switch state {
            case .revealedCorrect: playCorrect()
            case .revealedWrong: playWrong()
            default: break
            }
        }
        .onDisappear {
            swellTask?.cancel()
        }
    }

    private func playCorrect() {
        guard !played else { return }
        played = true
        if reduceMotion {
            sweep = 1
            stamped = true
            return
        }
        withAnimation(.easeOut(duration: SGTheme.quizSweep)) { sweep = 1 }
        withAnimation(SGTheme.springPop.delay(0.12)) {
            stamped = true
            swell = true
        }
        swellTask?.cancel()
        swellTask = Task {
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(SGTheme.spring) { swell = false }
        }
    }

    private func playWrong() {
        guard !played else { return }
        played = true
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.4)) { shake += 1 }
    }

    private func tileContent(foreground: Color, badge: String?, badgeTint: Color) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(SGTheme.tileLabel)
                .foregroundColor(foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if state == .selected && confirmHint {
                SGMicroLabel(text: "Tap to confirm", color: SGTheme.mintDeep)
                    .transition(.opacity)
            }

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
        case .selected: return SGTheme.mintTint
        case .revealedWrong: return SGTheme.emberTint
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

// MARK: - Praise capsule

/// The correct-answer moment: a quiet capsule that drops in over the tiles
/// while the next card auto-advances. Tapping it (the quiz handles the tap)
/// pauses the advance and opens the explanation — praise for the fast lane,
/// learning one tap away.
struct QuizPraiseCapsule: View {
    let text: String
    /// Shows the "why?" affordance when the card has an explanation.
    var showsWhy: Bool = false

    private static let praise = ["Nice one!", "Nailed it!", "Correct!", "You know this."]

    /// Rotates the praise line so consecutive corrects don't repeat.
    static func line(for index: Int) -> String {
        praise[index % praise.count]
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SGTheme.mintDeep)
            Text(text)
                .font(SGTheme.buttonSmall)
                .foregroundColor(SGTheme.mintDeep)
            if showsWhy {
                Text("·")
                    .font(SGTheme.buttonSmall)
                    .foregroundColor(SGTheme.mintDeep.opacity(0.5))
                Text("Why?")
                    .font(SGTheme.buttonSmall)
                    .foregroundColor(SGTheme.mintDeep.opacity(0.7))
                    .underline()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
        .background(
            Capsule(style: .continuous)
                .fill(SGTheme.mintTint)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(SGTheme.mint.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Feedback panel

/// The verdict panel. On a wrong answer it rises over the bottom control:
/// the mascot reacts, the verdict lands, and the explanation rides along —
/// clamped to three lines with a More affordance instead of an invisible
/// scroll trap. The correct path only shows this panel when the user asks
/// (tapping the praise capsule), already expanded.
///
/// No answer restatement in here: the tiles above already tell that story
/// (the correct tile is sweeping mint as this panel rises).
struct QuizFeedbackPanel: View {
    let correct: Bool
    let title: String
    let explanation: String
    var initiallyExpanded: Bool = false

    @State private var expanded: Bool

    init(correct: Bool, title: String, explanation: String, initiallyExpanded: Bool = false) {
        self.correct = correct
        self.title = title
        self.explanation = explanation
        self.initiallyExpanded = initiallyExpanded
        _expanded = State(initialValue: initiallyExpanded)
    }

    private var tint: Color { correct ? SGTheme.mintDeep : SGTheme.emberDeep }
    private var wash: Color { correct ? SGTheme.mintTint : SGTheme.emberTint }
    private var stroke: Color { (correct ? SGTheme.mint : SGTheme.ember).opacity(0.35) }

    /// Long explanations get the More affordance; short ones just show.
    private var expandable: Bool { !expanded && explanation.count > 120 }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MascotView(pose: correct ? .teaching : .lookingDown, loops: 1)
                .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SGTheme.display(18))
                    .foregroundColor(tint)

                if !explanation.isEmpty {
                    Text(explanation)
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .lineSpacing(3)
                        .lineLimit(expanded ? nil : 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if expandable {
                    Button {
                        SGTheme.tick()
                        withAnimation(SGTheme.springFast) { expanded = true }
                    } label: {
                        HStack(spacing: 4) {
                            Text("More")
                                .font(SGTheme.caption.weight(.semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(tint)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SGPressStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(wash)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .strokeBorder(stroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - Celebration

/// The full-screen "time unlocked" moment, staged like the Meadow home it
/// hands off to: the mint grant stamp and the full "+N m" numeral land
/// together on ONE landing haptic, a single ring pulse blooms, and the CTA
/// is live almost immediately. No count-up here — the home hero rolls the
/// new minutes in after the handoff, so the earned time is counted exactly
/// once. Any tap after the opening beat snaps the whole show settled.
struct UnlockCelebrationView: View {
    let minutes: Int
    let ctaTitle: String
    /// The proud one-liner under the numeral; the flashcard flow keeps the
    /// default, the focus flow passes its own.
    var subtitle: String = "Every card correct. He's impressed."
    let onStart: () -> Void

    @State private var revealed = false
    @State private var stamped = false
    @State private var ringsFired = false
    @State private var showCTA = false
    @State private var mascotReplay = 0
    @State private var canSkip = false
    @State private var hapticPlayed = false
    @State private var seq: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // The air: stamp + readout, styled exactly like the home hero so
            // returning home feels like the same number settling in.
            VStack(spacing: 18) {
                Spacer(minLength: 24)

                ZStack {
                    CelebrationRings(fired: ringsFired)

                    Circle()
                        .fill(SGTheme.mint)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .sgShadow(SGTheme.glow(SGTheme.mint))
                        .scaleEffect(stamped ? 1.0 : 0.2)
                        .opacity(stamped ? 1 : 0)
                }
                .frame(height: 84)

                VStack(spacing: 14) {
                    numeral
                        .scaleEffect(stamped ? 1.0 : 0.85)
                        .opacity(stamped ? 1 : 0)

                    SGMicroLabel(text: "Time unlocked", color: SGTheme.mintDeep)
                        .opacity(stamped ? 1 : 0)

                    Text(subtitle)
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .padding(.top, 2)
                        .opacity(stamped ? 1 : 0)
                }

                Spacer(minLength: 0)
                    .frame(maxHeight: 56)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The meadow: mascot on the crest, CTA on the grass.
            VStack(spacing: 0) {
                SGButton(title: ctaTitle, variant: .white, action: onStart)
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
                MascotView(pose: .teaching, loops: 2, replayKey: mascotReplay)
                    .frame(width: 150, height: 150)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SGTheme.ink.ignoresSafeArea())
        // The circle-mask reveal: the whole screen blooms out of the center.
        .mask(
            Circle()
                .scale(revealed ? 4 : 0.02)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: revealed)
        )
        .contentShape(Rectangle())
        .onTapGesture { skipToSettled() }
        .onAppear(perform: play)
        .onDisappear { seq?.cancel() }
    }

    /// "+15 m" — the home hero's exact type treatment (SGTheme.heroDigit +
    /// heroUnit, thin space between digits and unit), shown at full value:
    /// this screen is the receipt, the home hero does the counting.
    private var numeral: some View {
        (Text("+\(minutes)")
            .font(SGTheme.heroDigit)
         + Text("\u{2009}m")
            .font(SGTheme.heroUnit)
            .foregroundColor(SGTheme.paperSecondary))
            .foregroundColor(SGTheme.paper)
    }

    private func play() {
        guard !reduceMotion else {
            revealed = true
            stamped = true
            showCTA = true
            if !hapticPlayed {
                hapticPlayed = true
                SGTheme.successHaptic()
            }
            return
        }

        revealed = true
        seq = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            landStamp()

            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.7)) { ringsFired = true }
            mascotReplay += 1
            canSkip = true

            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(SGTheme.spring) { showCTA = true }
        }
    }

    private func landStamp() {
        if !hapticPlayed {
            hapticPlayed = true
            QuizHaptics.celebrationLanding()
        }
        withAnimation(SGTheme.springPop) { stamped = true }
    }

    /// A tap after the opening beat snaps every stage to settled — the user
    /// is never held hostage by choreography.
    private func skipToSettled() {
        guard canSkip, !showCTA else { return }
        seq?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            stamped = true
            ringsFired = true
            showCTA = true
        }
    }
}

/// One-shot mint ring pulse behind the grant stamp — expands and dies.
private struct CelebrationRings: View {
    let fired: Bool

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(SGTheme.mint.opacity(0.5 - Double(index) * 0.2), lineWidth: 1)
                    .frame(width: 84, height: 84)
                    .scaleEffect(fired ? 2.6 + CGFloat(index) * 0.5 : 0.8)
                    .opacity(fired ? 0 : 0.9)
                    .animation(.easeOut(duration: 0.7).delay(Double(index) * 0.12), value: fired)
            }
        }
    }
}

// MARK: - Failure

/// Full-screen "still locked" takeover: ember bloom, the disappointed
/// monster, the score with the run's evidence bar, and the ways out.
/// Display-only; the caller owns every action.
struct QuizFailureView: View {
    let correctCount: Int
    let totalCount: Int
    /// The run's per-question outcomes — rendered as a thin evidence bar
    /// under the score line.
    var results: [Bool?] = []
    /// nil hides the emergency option (legacy flow).
    let emergencyUnlocksRemaining: Int?
    var giveUpTitle: String = "Give up for now"
    let onRetry: () -> Void
    let onEmergency: () -> Void
    let onGiveUp: () -> Void

    @State private var appeared = false
    @State private var breathing = false
    @State private var hapticPlayed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Emergency escape only renders while there are unlocks left to spend
    /// (parity with LockedHomeView).
    private var showsEmergency: Bool {
        (emergencyUnlocksRemaining ?? 0) > 0
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [SGTheme.ember.opacity(0.14), .clear],
                           center: .init(x: 0.5, y: 0.26),
                           startRadius: 30, endRadius: 360)
                .ignoresSafeArea()
                .opacity(breathing ? 0.7 : 1)

            VStack(spacing: 0) {
                Spacer()

                MascotView(pose: .lookingDown)
                    .frame(height: 150)
                    .padding(.bottom, 18)

                SGMicroLabel(text: "Still locked", color: SGTheme.emberDeep)
                    .padding(.bottom, 12)

                Text("Not quite.")
                    .font(SGTheme.stepTitle)
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

                if !results.isEmpty {
                    // The run as evidence: one 5pt segment per question.
                    HStack(spacing: 4) {
                        ForEach(results.indices, id: \.self) { index in
                            Capsule(style: .continuous)
                                .fill(segmentColor(results[index]))
                                .frame(height: 5)
                        }
                    }
                    .frame(maxWidth: 200)
                    .padding(.top, 16)
                    .accessibilityHidden(true)
                }

                Spacer()

                VStack(spacing: 12) {
                    SGButton(title: "Retry questions", action: onRetry)

                    if showsEmergency, let remaining = emergencyUnlocksRemaining {
                        SGButton(title: "Emergency unlock (\(remaining) left this week)",
                                 variant: .ghost,
                                 action: onEmergency)
                    }

                    // Destructive tertiary: bare text in the verdict ember.
                    Button(action: onGiveUp) {
                        Text(giveUpTitle)
                            .font(SGTheme.buttonSmall)
                            .foregroundColor(SGTheme.emberDeep)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SGPressStyle())
                }
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.bottom, 24)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(reduceMotion ? nil : SGTheme.springFast) { appeared = true }
            if !hapticPlayed {
                // wrongBuzz already played at the last check — the mount
                // gets one settling lock, not another verdict.
                hapticPlayed = true
                SGTheme.lock()
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: SGTheme.breatheCycle / 2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }

    private func segmentColor(_ result: Bool?) -> Color {
        switch result {
        case .some(true): return SGTheme.mint
        case .some(false): return SGTheme.emberDeep
        case .none: return SGTheme.glaze(0.08)
        }
    }
}

#Preview("Failure") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        QuizFailureView(correctCount: 2, totalCount: 3,
                        results: [true, false, true],
                        emergencyUnlocksRemaining: 2,
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
            QuizPraiseCapsule(text: "Nice one!", showsWhy: true)
                .padding(.bottom, 6)
            QuizAnswerTile(text: "Mitochondria", state: .revealedCorrect)
            QuizAnswerTile(text: "Nucleus", state: .revealedWrong)
            QuizAnswerTile(text: "Ribosome", state: .dimmed)
            QuizAnswerTile(text: "Golgi body", state: .selected, confirmHint: true)
        }
        .padding(24)
    }
}
