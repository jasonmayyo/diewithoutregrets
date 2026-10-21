// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4EarnScreenTimeView.swift
//  OneThing
//
//  The "how it works" explainer, rebuilt around the ghost animations and the
//  home-screen budget orb. One auto-playing story:
//
//    1. Lock   — at the start of every day your apps lock (app icons lock).
//    2. Biology — ten correct flashcards earn time, the orb counts UP.
//    3. Criminal Law — twenty correct flashcards earn more, the orb counts UP again.
//    4. Scroll — the phone ghost drains it, the orb counts DOWN (red).
//
//  Reuses the same orb primitives as HomeView (SGV5DotGridRippleView, SGV5BudgetDropLabel,
//  SGV5BudgetNumberAnim, sgV5FormatBudgetMinutes, sgV5BlendWhite, the reaction colours) so the
//  teaching montage matches what the user sees on the real home screen.
//

import SwiftUI
import Lottie
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct SGV5V4EarnScreenTimeView: View {
    @ObservedObject var viewModel: SGV5FlowModel

    /// When true the Continue button dismisses via `onClose` instead of advancing
    /// the onboarding flow, and a close (✕) button is shown. Set from the debug view.
    var isDebugPreview: Bool = false
    /// Debug-only dismiss / live-flow override. When nil in the live flow, Continue
    /// calls `viewModel.nextPage()`.
    var onClose: (() -> Void)? = nil

    var showcaseOnly = false
    var includesShowcase = true

    // Ghost Lottie animation file names (note the space in the lifting filename).
    private static let biologyMascot = "4_teaching"
    private static let criminalLawMascot = "4_teaching"
    private static let phoneGhost = "2_Looking down"

    private let appIconNames = [
        "Facebook-onboarding",
        "Instagram-onboarding",
        "Tiktok-onboarding",
        "Youtube-onboarding",
    ]
    private let biologyReward = SGContract.earnedMinutes(cardCount: 10, perCardSeconds: SGContract.defaultPerCardSeconds)
    private let criminalLawReward = SGContract.earnedMinutes(cardCount: 20, perCardSeconds: SGContract.defaultPerCardSeconds)
    private var totalReward: Int { biologyReward + criminalLawReward }
    private let iconSide: CGFloat = 64
    private let iconCorner: CGFloat = 15

    private enum Beat { case lock, biology, criminalLaw, scroll, done }

    // MARK: - State
    @State private var beat: Beat = .lock

    // Beat 1 (lock) icon animation.
    @State private var revealedIconCount = 0
    @State private var lockedIconCount = 0

    // Orb + ghost.
    @State private var showIcons = false
    @State private var showOrb = false
    @State private var showGhost = false
    @State private var ghostAnim: String? = nil
    @State private var orbMinutes: Int = 0
    @State private var lockGlyphShown = false

    // Floating "earned" chips above the ghost (gym on the left, reading on the right).
    @State private var showBiologyChip = false
    @State private var showCriminalLawChip = false

    // Final "ways to earn" showcase (auto-scrolling strips of activities + integrations).
    @State private var showShowcase = false

    // Orb reaction (shared with the home orb visuals).
    @State private var alertStart: TimeInterval? = nil
    @State private var reactionIsGain = true
    @State private var deltaText = ""
    @State private var showDelta = false

    // Copy.
    @State private var title = "At the start of every day,\nyour apps lock."
    @State private var subtitle = "No more mindless morning scrolling."
    @State private var showCopy = true

    @State private var showContinue = false

    // Scheduled work, so we can cancel on replay / disappear.
    @State private var work: [DispatchWorkItem] = []

    private var reactionColor: Color { reactionIsGain ? sgV5BudgetGainGreen : sgV5BudgetAlarmRed }
    private var labelColor: Color { reactionIsGain ? sgV5BudgetLabelGreen : sgV5BudgetLabelRed }

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            SGV5DotGridRippleView(
                intensity: 0.18,
                holeRadius: 104,
                holeFeather: 80,
                alertStart: alertStart,
                alertColor: reactionColor,
                alertDuration: 4.5
            )
            .ignoresSafeArea()

            // Readability scrim: fade the dot grid to near-solid black under the
            // copy + CTA so the text reads clearly. Drawn UNDER the centre stage so
            // it only darkens the background, never the showcase cards on top of it.
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [
                        SGTheme.ink.opacity(0),
                        SGTheme.ink.opacity(0.7),
                        SGTheme.ink.opacity(0.95),
                        SGTheme.ink,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 440)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Centre stage: locking icons (beat 1) crossfading to ghost + orb.
            VStack {
                Spacer()
                stage
                Spacer()
            }

            // Bottom copy + CTA.
            VStack(spacing: 0) {
                Spacer()
                copyBlock
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)

                SGV5QuizContinueButton(action: advance)
                .opacity(showContinue ? 1 : 0)
                .offset(y: showContinue ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: showContinue)
                .sgV5FloatingCTA()
            }

            if isDebugPreview {
                debugControls
            }
        }
        .onAppear {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-sg-v5-demo-earned") || arguments.contains("-sg-v5-demo-spent") {
                showOrb = true
                showGhost = true
                ghostAnim = Self.criminalLawMascot
                showBiologyChip = true
                orbMinutes = biologyReward
                play(arguments.contains("-sg-v5-demo-earned") ? .criminalLaw : .scroll)
                return
            }
            #endif
            play(showcaseOnly ? .done : .lock)
        }
        .onDisappear(perform: cancelAll)
    }

    // MARK: - Stage

    private var stage: some View {
        ZStack {
            // App icons — shown while they lock (beat 1) and unlock (gym intro),
            // and again when the balance hits 0 and they relock.
            iconRow
                .opacity(showIcons ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: showIcons)

            // Beats 2-4 — floating chips, ghost, then the orb just beneath it.
            VStack(spacing: 2) {
                chipsZone

                ZStack {
                    if let ghostAnim, showGhost {
                        LottieView(animation: .named(ghostAnim))
                            .playing(loopMode: .loop)
                            .frame(width: 160, height: 160)
                            .id(ghostAnim)
                            .transition(.opacity)
                    }
                }
                .frame(width: 160, height: 160)

                orb

                // Small app row under the orb that locks/unlocks in step with the
                // balance — no separate full-screen sequence to wait on.
                miniIconRow
                    .padding(.top, 14)
            }
            .opacity(showOrb ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: showOrb)
            .offset(y: -104) // lift the cluster so the orb lands near screen centre

            // Final beat — "ways to earn" showcase strips.
            showcase
                .opacity(showShowcase ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: showShowcase)
                .offset(y: -84)
        }
    }

    private var showcase: some View { SGV5V4ActivityWall() }

    /// Floating "earned" chips that stack above the ghost like notifications,
    /// growing upward from the bottom — Biology appears first, then Criminal Law slides in
    /// beneath it (closest to the ghost) and pushes the stack up.
    private var chipsZone: some View {
        VStack(spacing: 8) {
            if showBiologyChip {
                earnChip(emoji: "🧬", name: "Biology", cards: 10, minutes: biologyReward)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if showCriminalLawChip {
                earnChip(emoji: "⚖️", name: "Criminal Law", cards: 20, minutes: criminalLawReward)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 108, alignment: .bottom)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showBiologyChip)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showCriminalLawChip)
    }

    private func earnChip(emoji: String, name: String, cards: Int, minutes: Int) -> some View {
        HStack(spacing: 11) {
            Text(emoji).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) · \(cards) flashcards")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(SGTheme.paper)
                Text("Answered correctly · +\(minutes) min")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(sgV5BudgetLabelGreen)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(width: 280)
        .background(
            Capsule()
                .fill(SGTheme.ink)
                .overlay(Capsule().stroke(SGTheme.paper.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: SGTheme.ink.opacity(0.5), radius: 12, y: 5)
    }

    private var orb: some View {
        Text(sgV5FormatBudgetMinutes(orbMinutes))
            .font(.system(size: 68, weight: .semibold))
            .monospacedDigit()
            .foregroundColor(SGTheme.paper)
            .contentTransition(.numericText(countsDown: !reactionIsGain))
            .keyframeAnimator(initialValue: SGV5BudgetNumberAnim(), trigger: alertStart) { content, value in
                content
                    .scaleEffect(value.scale)
                    .foregroundStyle(sgV5BlendWhite(to: reactionColor, amount: value.redness))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.3, duration: 1.1, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 3.6, spring: .smooth)
                }
                KeyframeTrack(\.redness) {
                    CubicKeyframe(1.0, duration: 1.0)
                    LinearKeyframe(1.0, duration: 2.2)
                    CubicKeyframe(0.0, duration: 1.6)
                }
            }
            .opacity(lockGlyphShown ? 0 : 1)
            .overlay {
                if lockGlyphShown {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(sgV5BudgetAlarmRed)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topTrailing) {
                if showDelta {
                    SGV5BudgetDropLabel(text: deltaText, color: labelColor)
                        .id(alertStart)
                        .offset(x: 30, y: -6)
                }
            }
    }

    private var iconRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(appIconNames.enumerated()), id: \.offset) { index, _ in
                appIconCell(index: index)
            }
        }
        .padding(.horizontal, 20)
    }

    private func appIconCell(index: Int) -> some View {
        let name = appIconNames[index]
        let isRevealed = index < revealedIconCount
        let isLocked = index < lockedIconCount

        return ZStack {
            Image(SGV5Assets.name(name))
                .resizable()
                .scaledToFill()
                .frame(width: iconSide, height: iconSide)
                .grayscale(isLocked ? 1 : 0)
                .brightness(isLocked ? -0.14 : 0)
                .contrast(isLocked ? 0.88 : 1)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: iconCorner, style: .continuous))

            if isLocked {
                RoundedRectangle(cornerRadius: iconCorner, style: .continuous)
                    .fill(SGTheme.paperSecondary.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: iconCorner, style: .continuous)
                            .strokeBorder(SGTheme.paper.opacity(0.18), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(SGTheme.paper)
                            .shadow(color: SGTheme.ink.opacity(0.4), radius: 2, x: 0, y: 1)
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: iconSide, height: iconSide)
        .opacity(isRevealed ? 1 : 0)
        .scaleEffect(isRevealed ? 1 : 0.88)
        .animation(.easeOut(duration: 0.48), value: isRevealed)
        .animation(.easeInOut(duration: 0.42), value: isLocked)
    }

    // Compact app row that sits under the orb during the earn/drain beats. Always
    // visible (when the orb is); only the lock state animates, quickly.
    private var miniIconRow: some View {
        HStack(spacing: 9) {
            ForEach(Array(appIconNames.enumerated()), id: \.offset) { index, name in
                miniAppIcon(index: index, name: name)
            }
        }
    }

    private func miniAppIcon(index: Int, name: String) -> some View {
        let isLocked = index < lockedIconCount
        let side: CGFloat = 36
        let corner: CGFloat = 9
        return ZStack {
            Image(SGV5Assets.name(name))
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .grayscale(isLocked ? 1 : 0)
                .brightness(isLocked ? -0.12 : 0)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

            if isLocked {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(SGTheme.paperSecondary.opacity(0.4))
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(SGTheme.paper)
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: side, height: side)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isLocked)
    }

    private var copyBlock: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SGTheme.paper.opacity(0.45))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(showCopy ? 1 : 0)
        .offset(y: showCopy ? 0 : 14)
        .animation(.easeOut(duration: 0.45), value: showCopy)
        .animation(.easeInOut(duration: 0.3), value: title)
    }

    private var debugControls: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(SGTheme.paper.opacity(0.5))
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
            Spacer()
        }
    }

    // MARK: - Choreography

    private func continueTapped() {
        if isDebugPreview {
            onClose?()
        } else {
            viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "earn_screen_time_continue")
            viewModel.nextPage()
        }
    }

    /// Continue button: advance to the next stage, or finish on the last one.
    private func advance() {
        switch beat {
        case .lock: play(.biology)
        case .biology: play(.criminalLaw)
        case .criminalLaw: play(.scroll)
        case .scroll: includesShowcase ? play(.done) : continueTapped()
        case .done: continueTapped()
        }
    }

    private func revealContinue(after delay: Double) {
        after(delay) { withAnimation(.easeOut(duration: 0.5)) { showContinue = true } }
    }

    /// Schedule the app-icons reveal-then-lock animation, the first icon appearing
    /// `base` seconds from now. Returns the time (relative to now) all icons are
    /// locked. Used by the opening lock beat and again when the balance hits 0.
    @discardableResult
    private func scheduleLockApps(base: Double) -> Double {
        let reveal = 0.25, revealStagger = 0.28
        for i in 0..<appIconNames.count {
            after(base + reveal + Double(i) * revealStagger) {
                withAnimation(.easeOut(duration: 0.45)) { revealedIconCount = i + 1 }
            }
        }
        let lockBase = base + reveal + Double(appIconNames.count) * revealStagger + 0.35
        let lockStagger = 0.26
        for i in 0..<appIconNames.count {
            after(lockBase + Double(i) * lockStagger) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { lockedIconCount = i + 1 }
            }
        }
        return lockBase + Double(appIconNames.count) * lockStagger
    }

    /// Set up + auto-play a single stage, then reveal Continue once it settles.
    /// Each stage waits for the user to tap Continue before the next one runs.
    private func play(_ stage: Beat) {
        cancelAll()
        withAnimation(.easeOut(duration: 0.2)) { showContinue = false }

        switch stage {
        case .lock:
            var tx = Transaction(); tx.disablesAnimations = true
            withTransaction(tx) {
                beat = .lock
                revealedIconCount = 0
                lockedIconCount = 0
                showIcons = true
                showOrb = false
                showGhost = false
                ghostAnim = nil
                orbMinutes = 0
                lockGlyphShown = false
                showDelta = false
                showBiologyChip = false
                showCriminalLawChip = false
                showShowcase = false
                title = "At the start of every day,\nyour apps lock."
                subtitle = "No more mindless morning scrolling."
                showCopy = true
            }
            let lockedAt = scheduleLockApps(base: 0)
            revealContinue(after: lockedAt + 0.5)

        case .biology:
            // Gym example: the mini app row (locked, under the orb) unlocks QUICKLY
            // and concurrently as the orb earns +30. Then auto-cycle into reading.
            beat = .biology
            setCopy("Answer flashcards.\nEarn screen time.", "Correct answers unlock your apps.")
            var tx = Transaction(); tx.disablesAnimations = true
            withTransaction(tx) {
                orbMinutes = 0; lockGlyphShown = false
                showBiologyChip = false; showCriminalLawChip = false
                lockedIconCount = appIconNames.count // mini row starts locked
            }

            // Crossfade from the big lock icons to the orb cluster (mini row beneath).
            withAnimation(.easeInOut(duration: 0.5)) { showIcons = false; showOrb = true }
            ghostAnim = Self.biologyMascot
            after(0.15) { withAnimation(.easeInOut(duration: 0.5)) { showGhost = true } }

            // Earn the time, unlocking the mini apps in parallel (quick stagger).
            after(0.8) {
                showBiologyChip = true
                runCount(from: 0, to: biologyReward, duration: 2.6, isGain: true)
                for i in 0..<appIconNames.count {
                    after(Double(i) * 0.1) {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
                        lockedIconCount = appIconNames.count - 1 - i
                    }
                }
            }
            after(0.8 + 2.6 + 1.3) { play(.criminalLaw) }

        case .criminalLaw:
            // Reading example: keep the same headline, swap the ghost, float the
            // reading chip in from the right, orb earns +15, then offer Continue.
            beat = .criminalLaw
            setCopy("Answer flashcards.\nEarn screen time.", "Correct answers unlock your apps.")
            withAnimation(.easeInOut(duration: 0.45)) { ghostAnim = Self.criminalLawMascot }
            after(0.6) {
                showCriminalLawChip = true
                runCount(from: biologyReward, to: totalReward, duration: 2.0, isGain: true)
            }
            revealContinue(after: 0.6 + 2.0 + 1.0)

        case .scroll:
            // Drain all the way to 0 while the mini app row LOCKS in parallel near
            // the end — the cycle restarts, no separate full-screen lock sequence.
            beat = .scroll
            showBiologyChip = false
            showCriminalLawChip = false
            setCopy("Time on distracting apps\nspends your balance.", "The only screen time you get is what you earn.")
            withAnimation(.easeInOut(duration: 0.45)) { ghostAnim = Self.phoneGhost }
            let countdownDelay = 0.2
            let countdownDuration = 1.5
            after(countdownDelay) {
                runCount(from: totalReward, to: 0, duration: countdownDuration, isGain: false)
            }

            // Relock the apps during the final moments of the faster countdown.
            let lockStart = countdownDelay + countdownDuration - 0.6
            for i in 0..<appIconNames.count {
                after(lockStart + Double(i) * 0.15) {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
                    lockedIconCount = i + 1
                }
            }
            revealContinue(after: countdownDelay + countdownDuration)

        case .done:
            // Swap the orb out for the "ways to earn" showcase strips.
            beat = .done
            withAnimation(.easeInOut(duration: 0.5)) {
                showIcons = false
                showOrb = false
                showShowcase = true
            }
            setCopy("Real life unlocks\nyour screen time.", "No discipline needed. No workarounds.")
            revealContinue(after: 0.9)
        }
    }

    /// Schedule `block` `delay` seconds from now and remember it for cancellation.
    private func after(_ delay: Double, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        work.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelAll() {
        work.forEach { $0.cancel() }
        work.removeAll()
    }

    private func setCopy(_ newTitle: String, _ newSubtitle: String) {
        withAnimation(.easeOut(duration: 0.25)) { showCopy = false }
        after(0.28) {
            title = newTitle
            subtitle = newSubtitle
            withAnimation(.easeOut(duration: 0.4)) { showCopy = true }
        }
    }

    /// Roll the orb number from `from` to `to` over roughly `duration` seconds,
    /// firing the orb punch/flash, the floating +/- label, the ripple pulse, and a
    /// per-minute haptic — mirroring the home-screen reaction.
    private func runCount(from: Int, to: Int, duration: Double, isGain: Bool) {
        let steps = abs(to - from)
        guard steps > 0 else { return }

        var tx = Transaction(); tx.disablesAnimations = true
        withTransaction(tx) { orbMinutes = from }

        reactionIsGain = isGain
        deltaText = "\(isGain ? "+" : "-")\(steps)m"
        alertStart = Date().timeIntervalSinceReferenceDate
        withAnimation(.easeOut(duration: 0.25)) { showDelta = true }

        // Per-step weights: gain eases slow→fast→slow, drop eases fast→slow.
        var weights: [Double] = []
        for k in 0..<steps {
            let c = Double(k) / Double(steps)
            let w = isGain ? (0.5 + 0.5 * sin(.pi * c)) : (0.35 + 0.65 * pow(1 - c, 1.6))
            weights.append(w)
        }
        let wsum = weights.reduce(0, +)

        var elapsed = 0.0
        for k in 0..<steps {
            let stepDur = duration * weights[k] / wsum
            after(elapsed) {
                withAnimation(.easeInOut(duration: max(0.05, stepDur))) {
                    orbMinutes += isGain ? 1 : -1
                }
                let g = UIImpactFeedbackGenerator(style: isGain ? .soft : .rigid)
                g.impactOccurred(intensity: isGain ? 0.7 : 0.9)
            }
            elapsed += stepDur
        }

        after(elapsed + 1.4) {
            withAnimation(.easeOut(duration: 0.4)) { showDelta = false }
        }
    }
}

// MARK: - Auto-scrolling marquee strip

/// A seamless, infinitely auto-scrolling horizontal strip. Renders the items
/// three times back-to-back and drifts by exactly one set width, so the loop is
/// invisible. `reversed` scrolls right-to-left vs left-to-right.
private struct SGV5AutoScrollStrip<Content: View>: View {
    let itemCount: Int
    let itemWidth: CGFloat
    let spacing: CGFloat
    var reversed: Bool = false
    var pointsPerSecond: CGFloat = 26
    @ViewBuilder let content: (Int) -> Content

    @State private var offset: CGFloat = 0
    private var setWidth: CGFloat { CGFloat(itemCount) * (itemWidth + spacing) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: spacing) {
                ForEach(0..<(itemCount * 3), id: \.self) { i in
                    content(i % itemCount)
                        .frame(width: itemWidth)
                }
            }
            .offset(x: offset)
            .frame(width: geo.size.width, alignment: .leading)
            .onAppear {
                let duration = Double(setWidth / pointsPerSecond)
                if reversed {
                    offset = -setWidth
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        offset = 0
                    }
                } else {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        offset = -setWidth
                    }
                }
            }
        }
        .clipped()
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, SGTheme.paper], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 36)
                SGTheme.paper
                LinearGradient(colors: [SGTheme.paper, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 36)
            }
        )
    }
}

/// Like `SGV5AutoScrollStrip` but the items keep their natural (intrinsic) width and
/// only `spacing` separates them — no fixed-width gaps. It renders the items 3×,
/// measures the run, and drifts by exactly one set so the loop stays seamless.
private struct SGV5TightMarquee<Content: View>: View {
    let count: Int
    let spacing: CGFloat
    var reversed: Bool = false
    var pointsPerSecond: CGFloat = 26
    @ViewBuilder let content: (Int) -> Content

    @State private var offset: CGFloat = 0
    @State private var started = false

    var body: some View {
        // Outer GeometryReader keeps this view's reported width at the available
        // width (NOT the huge fixedSize content width), so it can't blow out the
        // layout of sibling views like the Continue button.
        GeometryReader { outer in
            HStack(spacing: spacing) {
                ForEach(0..<(count * 3), id: \.self) { i in
                    content(i % count)
                }
            }
            .fixedSize()
            .background(
                GeometryReader { inner in
                    Color.clear.onAppear {
                        guard !started else { return }
                        started = true
                        // width of 3 sets → one set's repeating period.
                        let period = (inner.size.width + spacing) / 3
                        offset = reversed ? -period : 0
                        withAnimation(.linear(duration: Double(period / pointsPerSecond))
                            .repeatForever(autoreverses: false)) {
                            offset = reversed ? 0 : -period
                        }
                    }
                }
            )
            .offset(x: offset)
            .frame(width: outer.size.width, alignment: .leading)
        }
        .clipped()
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, SGTheme.paper], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 36)
                SGTheme.paper
                LinearGradient(colors: [SGTheme.paper, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 36)
            }
        )
    }
}

// MARK: - Looping video (from a Data asset)

/// Plays a muted, seamlessly looping clip stored as a Data asset in the catalog,
/// aspect-filling its frame. Used by the activity cards in the earn showcase.
private struct SGV5LoopingVideoView: UIViewRepresentable {
    let assetName: String

    func makeUIView(context: Context) -> SGV5LoopingPlayerView {
        let view = SGV5LoopingPlayerView()
        view.play(assetName: assetName)
        return view
    }

    func updateUIView(_ uiView: SGV5LoopingPlayerView, context: Context) {}
}

private final class SGV5LoopingPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func play(assetName: String) {
        guard queuePlayer == nil,
              let dataAsset = NSDataAsset(name: SGV5Assets.name(assetName)) else { return }

        // AVPlayer needs a URL, so spill the asset bytes to a temp file once. Use
        // the asset's real type (mp4 / mov) for the extension so AVFoundation
        // parses it correctly.
        let ext = UTType(dataAsset.typeIdentifier)?.preferredFilenameExtension ?? "mp4"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("onething-earn-\(assetName).\(ext)")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? dataAsset.data.write(to: url)
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: player, templateItem: item)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        queuePlayer = player
        player.play()
    }
}



/// Shared by the original teaching montage and the V5 activity showcase.
struct SGV5V4ActivityWall: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    // MARK: - "Ways to earn" showcase
    //
    // Only methods that actually ship: Photo verification, on-device Move (Vision
    // rep counting), and Apple Health connections. (Strava is a placeholder enum
    // case with no connection, so it is intentionally left out.)

    private static let motionBlue = Color(red: 0.36, green: 0.70, blue: 1.0)

    // Photo + Vision activities (the ones you capture in the real world). `video`
    // is a looping Data-asset clip, `image` is a still asset; a card with neither
    // falls back to a grey placeholder.
    private let earnActivities: [(title: String, symbol: String, badge: String, badgeColor: Color, video: String?, image: String?)] = [
        ("Push-ups", "figure.strengthtraining.traditional", "Motion verified", motionBlue, "pushups", nil),
        ("Gym", "dumbbell.fill", "Photo verified", sgV5BudgetLabelGreen, nil, "gym-habit-scan"),
        ("Squats", "figure.cross.training", "Motion verified", motionBlue, "squats", nil),
        ("Reading", "book.fill", "Photo verified", sgV5BudgetLabelGreen, nil, "reading-habit-scan"),
        ("Star jumps", "figure.mixed.cardio", "Motion verified", motionBlue, "starjumps", nil),
        ("Deep Work", "laptopcomputer", "Photo verified", sgV5BudgetLabelGreen, nil, "deep-work-habit-scan"),
    ]

    // Apple Health metrics that auto-earn (the implemented connection metrics).
    private let earnIntegrations: [(title: String, symbol: String, color: Color)] = [
        ("Run / walk", "figure.run", sgV5BudgetGainGreen),
        ("Exercise", "figure.highintensity.intervaltraining", .orange),
        ("Mindfulness", "brain.head.profile", Color(red: 0.55, green: 0.82, blue: 0.9)),
        ("Steps", "shoeprints.fill", Color(red: 1.0, green: 0.6, blue: 0.2)),
        ("Calories", "flame.fill", Color(red: 1.0, green: 0.35, blue: 0.25)),
    ]

    // The three implemented ways a habit gets verified — tightly packed chips up top.
    private let verifyMethods: [(title: String, symbol: String, color: Color)] = [
        ("Photo scan", "camera.viewfinder", sgV5BudgetGainGreen),
        ("Rep counter", "figure.strengthtraining.traditional", motionBlue),
        ("Apple Health", "heart.fill", Color(red: 1.0, green: 0.27, blue: 0.33)),
    ]

    var body: some View {
        if reduceMotion || voiceOver {
            VStack(spacing: 16) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(verifyMethods.indices, id: \.self) { verifyChip(verifyMethods[$0]) }
                    }.padding(.horizontal, 24)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(earnActivities.indices, id: \.self) { activityCard(earnActivities[$0]) }
                    }.padding(.horizontal, 24)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(earnIntegrations.indices, id: \.self) { integrationCard(earnIntegrations[$0]) }
                    }.padding(.horizontal, 24)
                }
            }.scrollIndicators(.hidden)
        } else {
        VStack(spacing: 16) {
            SGV5TightMarquee(count: verifyMethods.count, spacing: 8,
                         reversed: true, pointsPerSecond: 26) { i in
                verifyChip(verifyMethods[i])
            }
            .frame(height: 40)

            SGV5AutoScrollStrip(itemCount: earnActivities.count, itemWidth: 178, spacing: 12,
                            reversed: false, pointsPerSecond: 26) { i in
                activityCard(earnActivities[i])
            }
            .frame(height: 240)

            SGV5AutoScrollStrip(itemCount: earnIntegrations.count, itemWidth: 184, spacing: 12,
                            reversed: true, pointsPerSecond: 22) { i in
                integrationCard(earnIntegrations[i])
            }
            .frame(height: 62)
        }
        }
    }

    private func verifyChip(_ item: (title: String, symbol: String, color: Color)) -> some View {
        HStack(spacing: 7) {
            Image(systemName: item.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(item.color)
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SGTheme.paper)
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(SGTheme.inkRaised)
                .overlay(Capsule().stroke(SGTheme.paper.opacity(0.1), lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
    }

    private func activityCard(_ item: (title: String, symbol: String, badge: String, badgeColor: Color, video: String?, image: String?)) -> some View {
        ZStack {
            if let video = item.video, !reduceMotion {
                SGV5LoopingVideoView(assetName: video)
            } else if let image = item.image {
                Image(SGV5Assets.name(image))
                    .resizable()
                    .scaledToFill()
            } else {
                SGTheme.inkRaised
                Image(systemName: item.symbol)
                    .font(.system(size: 42, weight: .regular))
                    .foregroundColor(SGTheme.paper.opacity(0.22))
            }

            // Bottom scrim so the title reads over the footage.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, SGTheme.ink.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 110)
            }
        }
        .frame(width: 178, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topLeading) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 11, weight: .bold))
                Text(item.badge).font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(SGTheme.paper)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(item.badgeColor))
            .padding(11)
        }
        .overlay(alignment: .bottomLeading) {
            Text(item.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SGTheme.paper)
                .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SGTheme.paper.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.badge)")
    }

    private func integrationCard(_ item: (title: String, symbol: String, color: Color)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(item.color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(item.color.opacity(0.16)))
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(SGTheme.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Apple Health")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SGTheme.paper.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 184, height: 62)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(SGTheme.paper.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), Apple Health")
    }

}
