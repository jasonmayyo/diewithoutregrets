// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4NotYourFaultView.swift
//  OneThing
//
//  Screen 108 (V4): Tap-driven empathy hook + villain reveal.
//  Word-by-word "It's not your fault." → tap to reveal 3 headlines → stats cascade → kicker.
//

import SwiftUI

struct SGV5V4NotYourFaultView: View {
    @ObservedObject var viewModel: SGV5FlowModel

    private let words = ["It's", "not", "your", "fault."]

    @State private var wordsRevealed = 0
    @State private var readyForTaps = false
    @State private var showTapHint = false
    @State private var headlinesRevealed = 0
    @State private var inStatsPhase = false
    @State private var statsRevealed = 0
    @State private var showKickerLeadIn = false
    @State private var kickerWordsRevealed = 0
    @State private var showButton = false

    var body: some View {
        ZStack {
            backgroundLayer

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
                .allowsHitTesting(readyForTaps && headlinesRevealed < 3)

            VStack(spacing: 0) {
                Spacer()
                centerContent
                Spacer()
                bottomArea
            }
        }
        .onAppear { startWordReveal() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            SGTheme.ink
                .ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 0.4, green: 0.05, blue: 0.05)
                        .opacity(inStatsPhase ? 0.15 : 0),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 350
            )
            .ignoresSafeArea()
            .animation(.easeIn(duration: 1.5), value: inStatsPhase)
        }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        ZStack {
            headlinePhaseContent
                .opacity(inStatsPhase ? 0 : 1)
                .scaleEffect(inStatsPhase ? 0.85 : 1)

            statsPhaseContent
                .opacity(inStatsPhase ? 1 : 0)
                .offset(y: inStatsPhase ? 0 : 30)
        }
        .animation(.easeInOut(duration: 0.7), value: inStatsPhase)
    }

    // MARK: - Headline Phase

    private var headlinePhaseContent: some View {
        VStack(spacing: 0) {
            wordByWordText
            headlineCardStack
                .frame(height: headlinesRevealed > 0 ? 480 : 0)
                .padding(.top, headlinesRevealed > 0 ? 28 : 0)
        }
    }

    private var wordByWordText: some View {
        HStack(spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(SGTheme.paper)
                    .opacity(wordsRevealed > index ? 1 : 0)
                    .offset(y: wordsRevealed > index ? 0 : 15)
                    .animation(.easeOut(duration: 0.5), value: wordsRevealed)
            }
        }
    }

    private var headlineCardStack: some View {
        ZStack {
            headlineCard("law1", rotation: -3, restY: 10, visible: headlinesRevealed >= 1)
            headlineCard("law2", rotation: 2, restY: -2, visible: headlinesRevealed >= 2)
            headlineCard("law3", rotation: -0.5, restY: -12, visible: headlinesRevealed >= 3)
        }
        .padding(.horizontal, 28)
    }

    private func headlineCard(
        _ imageName: String,
        rotation: Double,
        restY: CGFloat,
        visible: Bool
    ) -> some View {
        Image(SGV5Assets.name(imageName))
            .resizable()
            .scaledToFit()
            .frame(height: 450)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SGTheme.paper.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: SGTheme.ink.opacity(0.5), radius: 12, x: 0, y: 6)
            .rotationEffect(.degrees(rotation))
            .offset(y: visible ? restY : restY + 80)
            .opacity(visible ? 1 : 0)
    }

    // MARK: - Stats Phase

    private var statsPhaseContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                statRow("10,000+", label: "engineers", visible: statsRevealed >= 1)
                statRow("$100B+", label: "in funding", visible: statsRevealed >= 2)
                statRow("PhDs", label: "in behavioral psychology", visible: statsRevealed >= 3)
            }

            VStack(spacing: 10) {
                Text("All working to make sure")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SGTheme.paper.opacity(0.4))
                    .opacity(showKickerLeadIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: showKickerLeadIn)

                HStack(spacing: 8) {
                    kickerWord("you.", visibleAt: 1)
                    kickerWord("can't.", visibleAt: 2)
                    kickerWord("stop.", visibleAt: 3)
                    kickerWord("scrolling.", visibleAt: 4)
                }
            }
        }
    }

    private func statRow(_ number: String, label: String, visible: Bool) -> some View {
        VStack(spacing: 3) {
            Text(number)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(SGTheme.paper)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SGTheme.paper.opacity(0.4))
                .tracking(1.5)
                .textCase(.uppercase)
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 20)
        .animation(.easeOut(duration: 0.6), value: visible)
    }

    private func kickerWord(_ word: String, visibleAt: Int) -> some View {
        Text(word)
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
            .opacity(kickerWordsRevealed >= visibleAt ? 1 : 0)
            .scaleEffect(kickerWordsRevealed >= visibleAt ? 1 : 1.4)
            .animation(.easeOut(duration: 0.3), value: kickerWordsRevealed)
    }

    // MARK: - Bottom Area

    @ViewBuilder
    private var bottomArea: some View {
        Group {
            if showButton {
                ctaButton
                    .transition(.opacity.combined(with: .offset(y: 20)))
            } else if showTapHint {
                Button(action: handleTap) { SGV5V4TapHintLabel() }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reveal next headline")
                    .padding(.bottom, 50)
                    .transition(.opacity)
            } else {
                Color.clear.frame(height: 96)
            }
        }
        .animation(.easeOut(duration: 0.4), value: showButton)
        .animation(.easeOut(duration: 0.3), value: showTapHint)
    }

    private var ctaButton: some View {
        SGV5QuizContinueButton { viewModel.nextPage() }
        .sgV5FloatingCTA()
    }

    // MARK: - Tap Handling

    private func handleTap() {
        guard readyForTaps, headlinesRevealed < 3 else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            headlinesRevealed += 1
        }
        viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "headline_tapped", properties: ["headline_number": headlinesRevealed])

        if headlinesRevealed >= 3 {
            withAnimation(.easeOut(duration: 0.3)) { showTapHint = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                beginStatsPhase()
            }
        }
    }

    // MARK: - Animation Sequences

    private func startWordReveal() {
        viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "word_reveal_started")
        for i in 1...words.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.35) {
                withAnimation { wordsRevealed = i }
            }
        }

        let readyTime = 0.5 + Double(words.count) * 0.35 + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + readyTime) {
            readyForTaps = true
            withAnimation { showTapHint = true }
            viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "ready_for_taps")
        }
    }

    private func beginStatsPhase() {
        viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "stats_cascade_started")
        withAnimation { inStatsPhase = true }

        let statDelays: [Double] = [0.5, 1.2, 1.9]
        for (i, delay) in statDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { statsRevealed = i + 1 }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showKickerLeadIn = true }
        }

        let wordDelays: [Double] = [3.8, 4.3, 4.8, 5.3]
        for (i, delay) in wordDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { kickerWordsRevealed = i + 1 }
                let style: UIImpactFeedbackGenerator.FeedbackStyle = (i == 3) ? .heavy : .medium
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.2) {
            withAnimation { showButton = true }
            viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "continue_button_shown")
        }
    }
}

// MARK: - Tap Hint

private struct SGV5V4TapHintLabel: View {
    @State private var pulsing = false

    var body: some View {
        Text("Tap to continue")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(SGTheme.paper.opacity(pulsing ? 0.4 : 0.15))
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}


