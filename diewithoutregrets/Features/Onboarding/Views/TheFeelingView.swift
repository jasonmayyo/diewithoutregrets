//
//  TheFeelingView.swift
//  diewithoutregrets
//
//  Onboarding v2 screen 2 (night): absolution + villain reveal. Phase A
//  reveals "It's not your fault." word by word, then three taps stack the
//  evidence cards. Phase B crossfades to the stats cascade and the ember
//  kicker: you. can't. stop. scrolling.
//

import SwiftUI

struct NotYourFaultView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private enum Phase {
        case words
        case stats
    }

    private let headlineWords = ["It's", "not", "your", "fault."]

    /// Real headline screenshots (shared with OneThing): each tap stacks
    /// another piece of published evidence.
    private let cardImages = ["law1", "law2", "law3"]
    private let cardRotations: [Double] = [-3, 2, -0.5]
    private let cardRestOffsets: [CGFloat] = [10, -2, -12]

    private let stats: [(number: String, label: String)] = [
        ("10,000+", "ENGINEERS"),
        ("$100B+", "IN FUNDING"),
        ("PhDs", "IN BEHAVIORAL PSYCHOLOGY"),
    ]
    private let kickerWords = ["you.", "can't.", "stop.", "scrolling."]

    @State private var started = false
    @State private var phase: Phase = .words
    @State private var wordCount = 0
    @State private var readyForTaps = false
    @State private var cardsShown = 0
    @State private var statCount = 0
    @State private var showLeadIn = false
    @State private var kickerCount = 0
    @State private var showCTA = false
    @State private var hintPulse = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.clear

            switch phase {
            case .words:
                wordsPhase
                    .transition(.opacity)
            case .stats:
                statsPhase
                    .transition(.opacity)
            }

            VStack {
                Spacer()
                OnbCTA(title: "So what do I do?", night: true, visible: showCTA) {
                    viewModel.nextStep()
                }
                .padding(.bottom, 12)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
        .onAppear(perform: start)
    }

    // MARK: - Phase A: words + evidence cards

    private var wordsPhase: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 9) {
                ForEach(headlineWords.indices, id: \.self) { index in
                    Text(headlineWords[index])
                        .font(SGTheme.stepTitle)
                        .foregroundColor(OnbNight.textPrimary)
                        .opacity(index < wordCount ? 1 : 0)
                        .offset(y: index < wordCount ? 0 : 14)
                        .animation(.easeOut(duration: 0.4), value: wordCount)
                }
            }
            .padding(.horizontal, 24)

            // The evidence pile, one headline screenshot per tap.
            ZStack {
                ForEach(0..<cardsShown, id: \.self) { index in
                    evidenceCard(index)
                        .rotationEffect(.degrees(cardRotations[index]))
                        .offset(y: cardRestOffsets[index])
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: cardsShown)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .frame(height: cardsShown > 0 ? 400 : 40, alignment: .center)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cardsShown > 0)

            Spacer()

            if readyForTaps && cardsShown < 3 {
                Text("Tap to continue")
                    .font(SGTheme.caption)
                    .foregroundColor(OnbNight.textMuted)
                    .opacity(hintPulse ? 1 : 0.35)
                    .padding(.bottom, 90)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            hintPulse = true
                        }
                    }
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue")
        .accessibilityHint("Reveals the next card")
        .accessibilityAddTraits(.isButton)
    }

    private func evidenceCard(_ index: Int) -> some View {
        Image(cardImages[index])
            .resizable()
            .scaledToFit()
            .frame(height: 380)
            .clipShape(RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
    }

    // MARK: - Phase B: stats cascade

    private var statsPhase: some View {
        VStack(spacing: 30) {
            Spacer()

            ForEach(stats.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    Text(stats[index].number)
                        .font(SGTheme.display(28, weight: .heavy))
                        .foregroundColor(OnbNight.textPrimary)
                    Text(stats[index].label)
                        .font(SGTheme.micro)
                        .tracking(2.5)
                        .foregroundColor(OnbNight.textSecondary)
                }
                .opacity(statCount > index ? 1 : 0)
                .offset(y: statCount > index ? 0 : 16)
                .animation(.easeOut(duration: 0.5), value: statCount)
            }

            Text("All working to make sure")
                .font(SGTheme.body)
                .foregroundColor(OnbNight.textSecondary)
                .opacity(showLeadIn ? 1 : 0)
                .offset(y: showLeadIn ? 0 : 12)
                .animation(.easeOut(duration: 0.5), value: showLeadIn)
                .padding(.top, 6)

            HStack(spacing: 10) {
                ForEach(kickerWords.indices, id: \.self) { index in
                    Text(kickerWords[index])
                        .font(SGTheme.display(26, weight: .heavy))
                        .foregroundColor(SGTheme.ember)
                        .opacity(kickerCount > index ? 1 : 0)
                        .scaleEffect(kickerCount > index ? 1 : 1.6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: kickerCount)
                }
            }

            Spacer()
            Spacer().frame(height: 76)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Choreography

    private func start() {
        guard !started else { return }
        started = true

        if reduceMotion {
            // Collapse the whole timeline: land on the final state.
            viewModel.screenAction("word_reveal_started")
            viewModel.screenAction("stats_cascade_started")
            wordCount = headlineWords.count
            cardsShown = 3
            phase = .stats
            statCount = stats.count
            showLeadIn = true
            kickerCount = kickerWords.count
            showCTA = true
            viewModel.screenAction("continue_shown")
            return
        }

        viewModel.screenAction("word_reveal_started")
        for index in headlineWords.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(index) * 0.35) {
                wordCount = index + 1
                SGTheme.gain()
            }
        }

        let wordsDone = 0.4 + Double(headlineWords.count) * 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + wordsDone + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                readyForTaps = true
            }
            viewModel.screenAction("ready_for_taps")
        }
    }

    private func handleTap() {
        guard readyForTaps, cardsShown < 3 else { return }
        cardsShown += 1
        SGTheme.beat()
        viewModel.screenAction("card_tapped", properties: ["card_number": cardsShown])

        if cardsShown == 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                phase = .stats
                startStatsCascade()
            }
        }
    }

    private func startStatsCascade() {
        viewModel.screenAction("stats_cascade_started")

        for index in stats.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.8) {
                statCount = index + 1
                SGTheme.beat()
            }
        }

        let statsDone = 0.5 + Double(stats.count) * 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + statsDone + 0.3) {
            showLeadIn = true
            SGTheme.gain()
        }

        for index in kickerWords.indices {
            let isLast = index == kickerWords.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + statsDone + 0.9 + Double(index) * 0.5) {
                kickerCount = index + 1
                if isLast { SGTheme.climax() } else { SGTheme.beat() }
            }
        }

        let kickerDone = statsDone + 0.9 + Double(kickerWords.count) * 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + kickerDone + 0.4) {
            showCTA = true
            viewModel.screenAction("continue_shown")
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        NotYourFaultView()
            .environmentObject(OnboardingViewModel())
    }
}
