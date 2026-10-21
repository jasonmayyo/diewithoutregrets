// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4FightingBackView.swift
//  OneThing
//
//  Screen 110 (V4): Value proposition — visual pivot from villain reveal to quiz.
//  Rotating "[X] More." + "Scroll Less." with infinite-scroll habit icon rows.
//

import SwiftUI

struct SGV5V4FightingBackView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sequenceTask: Task<Void, Never>?

    /// When true, swaps the lower habit-icon marquee for a looping wall of user
    /// reviews (used by the V5 "More life" step for added social proof).
    var showsReviews: Bool = false

    private let phrases = ["Study More.", "Learn More.", "Remember More."]
    private let habitIcons = [
        "book.closed.fill", "brain.head.profile", "graduationcap.fill",
        "rectangle.stack.fill", "doc.text.fill", "atom", "scalemass.fill",
    ]
    private let reviews = SGV5AppStoreReview.featured

    @State private var showGlow = false
    @State private var showRows = false
    @State private var phraseIndex = 0
    @State private var showTagline = false
    @State private var showSubtext = false
    @State private var showReviews = false
    @State private var showTrust = false
    @State private var showButton = false
    @State private var rotationTimer: Timer?

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .onAppear { startSequence() }
        .onDisappear { sequenceTask?.cancel(); rotationTimer?.invalidate() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { rotationTimer?.invalidate() }
            else if !reduceMotion { startPhraseRotation() }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            SGTheme.ink
                .ignoresSafeArea()
            RadialGradient(
                colors: [
                    SGTheme.mint.opacity(showGlow ? 0.08 : 0),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
            .ignoresSafeArea()
            .animation(.easeIn(duration: 1.2), value: showGlow)
        }
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(spacing: 0) {
            Spacer()

            SGV5HabitIconMarquee(icons: habitIcons, scrollRight: false)
                .opacity(showRows ? 0.35 : 0)
                .animation(.easeIn(duration: 1.0), value: showRows)
                .padding(.bottom, 32)

            taglineSection
                .padding(.bottom, 20)

            subtitleSection
                .padding(.bottom, showsReviews ? 24 : 32)

            if showsReviews {
                Text("STUDY GUARD · APP STORE REVIEWS")
                    .font(.system(size: 10, weight: .semibold)).tracking(1)
                    .foregroundStyle(SGTheme.paperSecondary).padding(.bottom, 12)
                reviewsStrip
                    .padding(.bottom, 20)
            } else {
                SGV5HabitIconMarquee(icons: habitIcons.reversed(), scrollRight: true)
                    .opacity(showRows ? 0.35 : 0)
                    .animation(.easeIn(duration: 1.0), value: showRows)
                    .padding(.bottom, 16)
            }

            trustBanners

            Spacer()

            ctaSection
        }
    }

    // MARK: - Reviews (shown when showsReviews is true)

    private var reviewsStrip: some View {
        SGV5V4ReviewMarqueeLoop(
            stripId: "morelife",
            reviews: reviews,
            pixelsPerSecond: 24,
            timePhaseSeconds: 0
        )
        .opacity(showReviews ? 1 : 0)
        .offset(y: showReviews ? 0 : 14)
        .animation(.easeOut(duration: 0.6), value: showReviews)
    }

    // MARK: - Rotating Tagline

    private var taglineSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Text(phrases[phraseIndex])
                    .id("phrase-\(phraseIndex)")
                    .transition(.asymmetric(
                        insertion: .offset(y: 40).combined(with: .opacity),
                        removal: .offset(y: -40).combined(with: .opacity)
                    ))
            }
            .font(.system(size: 40, weight: .heavy))
            .foregroundColor(SGTheme.mintDeep)
            .frame(height: 50)
            .clipped()

            Text("Scroll Less.")
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(SGTheme.paper.opacity(0.9))
        }
        .multilineTextAlignment(.center)
        .opacity(showTagline ? 1 : 0)
        .offset(y: showTagline ? 0 : 25)
        .animation(.easeOut(duration: 0.8), value: showTagline)
    }

    // MARK: - Subtitle

    private var subtitleSection: some View {
        Text("Turn your next scroll\ninto a quick study session.")
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(SGTheme.paperSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .opacity(showSubtext ? 1 : 0)
            .offset(y: showSubtext ? 0 : 10)
            .animation(.easeOut(duration: 0.6), value: showSubtext)
    }

    // MARK: - Trust Banners

    private var trustBanners: some View {
        Link(destination: URL(string: "https://apps.apple.com/gb/app/study-guard-study-focus/id6744607430")!) {
            Label("Read Study Guard reviews", systemImage: "arrow.up.right.square")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SGTheme.mintDeep)
        }
        .opacity(showTrust ? 1 : 0)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        SGV5QuizContinueButton(text: "I’m ready") {
            viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "lets_go_tapped")
            viewModel.nextPage()
        }
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
        .animation(.easeOut(duration: 0.5), value: showButton)
        .sgV5FloatingCTA()
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        sequenceTask?.cancel()
        showButton = true
        if reduceMotion {
            showRows = true; showGlow = true; showTagline = true
            showSubtext = true; showReviews = true; showTrust = true
            return
        }
        sequenceTask = Task { @MainActor in
            showRows = true; showGlow = true; showTagline = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            showSubtext = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            showReviews = true; showTrust = true
            startPhraseRotation()
        }
    }

    private func startPhraseRotation() {
        rotationTimer?.invalidate()
        guard !reduceMotion, scenePhase == .active else { return }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                phraseIndex = (phraseIndex + 1) % phrases.count
            }
        }
    }
}

// MARK: - Infinite Scrolling Icon Row

private struct SGV5HabitIconMarquee: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let icons: [String]
    let scrollRight: Bool

    private let iconSize: CGFloat = 44
    private let iconPadding: CGFloat = 14
    private let spacing: CGFloat = 16

    private var itemWidth: CGFloat { iconSize + iconPadding * 2 + spacing }
    private var setWidth: CGFloat { CGFloat(icons.count) * itemWidth }

    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { _ in
                    ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
                        iconCircle(icon)
                    }
                }
            }
            .offset(x: offset)
            .frame(width: geo.size.width, alignment: .leading)
            .onAppear { startScroll() }
        }
        .frame(height: iconSize + iconPadding * 2)
        .clipped()
        .mask(edgeFadeMask)
    }

    private func iconCircle(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .foregroundStyle(SGTheme.mintDeep)
            .frame(width: iconSize, height: iconSize)
            .padding(iconPadding)
            .background(
                Circle()
                    .fill(SGTheme.paper.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(SGTheme.paper.opacity(0.08), lineWidth: 0.5)
                    )
            )
    }

    private var edgeFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, SGTheme.paper], startPoint: .leading, endPoint: .trailing)
                .frame(width: 50)
            SGTheme.paper
            LinearGradient(colors: [SGTheme.paper, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 50)
        }
    }

    private func startScroll() {
        guard !reduceMotion else { return }
        let duration = setWidth / 30
        offset = scrollRight ? -setWidth : 0

        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = scrollRight ? 0 : -setWidth
        }
    }
}


