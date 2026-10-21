// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4GhostWitnessCommitmentView.swift
//  OneThing
//
//  Screen 236 (V4): Premium commitment screen.
//  Simple headline → ghost-oath card → fist-bump the ghost to commit:
//  a tap ping on the fist shows where to tap, then a heavy haptic, ghost punch
//  reaction, and an emoji burst erupt from the tap point before the screen fades on.
//

import SwiftUI
import UIKit

struct SGV5V4GhostWitnessCommitmentView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let goldAccent = SGTheme.mint

    // Celebratory emojis that fly out of the fist bump.
    private let burstEmojis: [String] = [
        "👊", "🔥", "✨", "💪", "⚡️", "🎉", "⭐️", "💥", "🙌", "😤", "🫡", "💫",
    ]

    private var usesV5Profile: Bool { viewModel.currentPageIndex == SGV5V5OnboardingStep.commitment.rawValue }

    private var oathText: String {
        if usesV5Profile {
            let profile = viewModel.v5Profile
            return "Before I scroll, I'll answer \(profile.studyCardCount) \(profile.subjectLabel) flashcards correctly to earn 5 minutes on my apps."
        }
        return "From this day forward, I am committed to living more and scrolling less."
    }

    private var headline: String {
        "Study first.\nScroll after."
    }

    // MARK: - State

    @State private var showHeadline = false
    @State private var showOathCard = false
    @State private var showGhost = false
    @State private var showHint = false
    @State private var oathComplete = false
    @State private var ghostFloating = false
    @State private var introTask: Task<Void, Never>?
    @State private var completionTask: Task<Void, Never>?
    @State private var fistLocation = CGPoint.zero
    @State private var tapPulse = false

    // Fist-bump interaction
    @State private var ghostPunch = false
    @State private var burstOrigin: CGPoint = .zero
    @State private var particles: [BurstParticle] = []
    @State private var isBursting = false
    @State private var particlesVisible = false

    // Whole-screen fade on completion.
    @State private var screenOpacity: CGFloat = 1

    private let coordSpace = "commitScreen"

    var body: some View {
        ZStack {
            backgroundLayers
            mainContent
            emojiBurstLayer
        }
        .opacity(screenOpacity)
        .coordinateSpace(name: coordSpace)
        .onAppear { runIntroSequence() }
        .onDisappear { introTask?.cancel(); completionTask?.cancel() }
    }

    // MARK: - Background

    private var backgroundLayers: some View {
        ZStack {
            SGTheme.ink
                .ignoresSafeArea()

            // Soft, steady warm glow for ambiance (no celebratory gold flash).
            RadialGradient(
                colors: [goldAccent.opacity(0.06), Color.clear],
                center: .init(x: 0.5, y: 0.5),
                startRadius: 20,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            // Ghost sits dead-center on the screen.
            if showGhost {
                ghostImage
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                headlineView
                    .padding(.horizontal, 32)

                // Oath card below the headline
                if showGhost {
                    oathCard
                        .padding(.top, 28)
                        .transition(.opacity)
                }

                Spacer()

                // Bottom hint
                if showGhost {
                    hintText
                        .transition(.opacity)
                }

                Spacer().frame(height: 28)
            }
        }
    }

    // MARK: - Headline

    private var headlineView: some View {
        Text(headline)
            .font(.system(size: 28, weight: .heavy))
            .foregroundColor(SGTheme.paper)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(showHeadline ? 1 : 0)
            .offset(y: showHeadline ? 0 : 12)
            .animation(.easeOut(duration: 0.7), value: showHeadline)
    }

    // MARK: - Ghost

    private var ghostImage: some View {
        GeometryReader { geometry in
            Button {
                guard !oathComplete else { return }
                fistBump(at: fistLocation)
            } label: {
                ZStack {
                    Image(SGV5Assets.name("ghost-fistpump"))
                        .resizable().scaledToFit()
                        .shadow(color: goldAccent.opacity(0.16), radius: 18, y: 8)
                    if !oathComplete {
                        Circle().stroke(SGTheme.mintDeep.opacity(tapPulse ? 0.12 : 0.45), lineWidth: 2)
                            .frame(width: 70, height: 70)
                            .scaleEffect(tapPulse && !reduceMotion ? 1.35 : 1)
                            .position(x: geometry.size.width * 0.25, y: geometry.size.height * 0.58)
                            .animation(reduceMotion ? nil : .easeOut(duration: 1.3).repeatForever(autoreverses: false), value: tapPulse)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(oathComplete)
            .accessibilityLabel("Fist bump the Study Guard mascot to commit")
            .accessibilityHint("Confirms your study rule and continues to your plan")
            .accessibilityIdentifier("onboarding.commitment.fistBump")
            .onAppear {
                let frame = geometry.frame(in: .named(coordSpace))
                fistLocation = CGPoint(x: frame.minX + frame.width * 0.25,
                                       y: frame.minY + frame.height * 0.58)
                tapPulse = !reduceMotion
            }
        }
        .frame(width: 280, height: 280)
        .offset(y: ghostFloating && !reduceMotion ? -5 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: ghostFloating)
        .scaleEffect(ghostPunch && !reduceMotion ? 1.12 : 1)
        .rotationEffect(.degrees(ghostPunch && !reduceMotion ? -5 : 0))
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: ghostPunch)
    }

    private var hintText: some View {
        Text(oathComplete ? "You've got this." : "Tap his fist to commit.")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(oathComplete ? SGTheme.mintDeep : SGTheme.paperSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 44)
            .opacity(showHint || oathComplete ? 1 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: showHint)
            .accessibilityIdentifier("onboarding.commitment.hint")
    }

    private var oathCard: some View {
        Text(oathText)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(SGTheme.paper.opacity(showOathCard ? 0.92 : 0))
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [SGTheme.paper.opacity(0.07), SGTheme.paper.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [goldAccent.opacity(0.12), SGTheme.paper.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 24)
            .opacity(showOathCard ? 1 : 0)
            .offset(y: showOathCard ? 0 : 10)
            .animation(.easeOut(duration: 0.6), value: showOathCard)
    }

    // MARK: - Emoji Burst Layer

    private var emojiBurstLayer: some View {
        ZStack {
            ForEach(particles) { p in
                Text(p.emoji)
                    .font(.system(size: p.size))
                    .scaleEffect(isBursting ? p.endScale : 0.1)
                    .rotationEffect(.degrees(isBursting ? p.rotation : 0))
                    .position(
                        x: burstOrigin.x + (isBursting ? p.dx : 0),
                        y: burstOrigin.y + (isBursting ? p.dy : 0)
                    )
                    .animation(.spring(response: p.duration, dampingFraction: 0.68).delay(p.delay), value: isBursting)
            }
        }
        .opacity(particlesVisible ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }

    // MARK: - Intro Sequence

    private func runIntroSequence() {
        introTask?.cancel()
        if reduceMotion {
            showHeadline = true; showOathCard = true; showGhost = true; showHint = true
            return
        }
        introTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }

            withAnimation { showHeadline = true }

            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.6)) { showGhost = true }
            ghostFloating = true

            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.5)) { showOathCard = true }

            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }

            // Reveal the bottom hint.
            withAnimation { showHint = true }
        }
    }

    // MARK: - Fist Bump

    private func fistBump(at location: CGPoint) {
        guard !oathComplete else { return }
        oathComplete = true
        burstOrigin = location
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        ghostPunch = !reduceMotion
        if !reduceMotion {
            spawnParticles()
            particlesVisible = true
            withAnimation { isBursting = true }
        }
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 300))
            guard !Task.isCancelled else { return }
            ghostPunch = false
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { screenOpacity = 0 }
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled,
                  viewModel.currentPageIndex == SGV5V5OnboardingStep.commitment.rawValue else { return }
            viewModel.trackScreenAction(screenId: 814, action: "fist_bump_committed")
            viewModel.advanceV5()
        }
    }

    private func spawnParticles() {
        let count = 26
        var made: [BurstParticle] = []
        for i in 0..<count {
            // Spread evenly around the circle with a little jitter so it reads organic.
            let base = (Double(i) / Double(count)) * 2 * Double.pi
            let angle = base + Double.random(in: -0.22...0.22)
            let distance = CGFloat.random(in: 170...460)
            var dx = cos(angle) * distance
            var dy = sin(angle) * distance
            // Bias slightly downward so emojis rain across the screen like Opal.
            dy += CGFloat.random(in: 20...90)
            dx += CGFloat.random(in: -24...24)

            made.append(
                BurstParticle(
                    emoji: burstEmojis.randomElement() ?? "✨",
                    dx: dx,
                    dy: dy,
                    endScale: CGFloat.random(in: 0.8...1.5),
                    size: CGFloat.random(in: 24...40),
                    rotation: Double.random(in: -220...220),
                    duration: Double.random(in: 0.55...0.85),
                    delay: Double.random(in: 0...0.08)
                )
            )
        }
        particles = made
    }
}

// MARK: - Burst Particle

private struct BurstParticle: Identifiable {
    let id = UUID()
    let emoji: String
    let dx: CGFloat
    let dy: CGFloat
    let endScale: CGFloat
    let size: CGFloat
    let rotation: Double
    let duration: Double
    let delay: Double
}


