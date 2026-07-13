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

    private let cards: [(eyebrow: String, text: String)] = [
        ("THE ATTENTION ECONOMY", "Apps are engineered to be un-putdownable"),
        ("THE ATTENTION ECONOMY", "Infinite feeds exploit the same loops as slot machines"),
        ("THE ATTENTION ECONOMY", "Your attention is the product being sold"),
    ]
    private let cardRotations: [Double] = [-3, 2, -0.5]

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
                OnbCTA(title: "Continue", night: true, visible: showCTA) {
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
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(OnbNight.textPrimary)
                        .opacity(index < wordCount ? 1 : 0)
                        .offset(y: index < wordCount ? 0 : 14)
                        .animation(.easeOut(duration: 0.4), value: wordCount)
                }
            }
            .padding(.horizontal, 24)

            // The evidence pile, one card per tap.
            ZStack {
                ForEach(0..<cardsShown, id: \.self) { index in
                    evidenceCard(index)
                        .rotationEffect(.degrees(cardRotations[index]))
                        .offset(y: CGFloat(index) * 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: cardsShown)
            .padding(.horizontal, 32)
            .padding(.top, 36)
            .frame(height: 220, alignment: .top)

            Spacer()

            if readyForTaps && cardsShown < 3 {
                Text("Tap to continue")
                    .font(.system(size: 14, weight: .medium))
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
        VStack(spacing: 10) {
            Text(cards[index].eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(OnbNight.textMuted)

            Text(cards[index].text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(OnbNight.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(OnbNight.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .strokeBorder(OnbNight.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Phase B: stats cascade

    private var statsPhase: some View {
        VStack(spacing: 30) {
            Spacer()

            ForEach(stats.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    Text(stats[index].number)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(OnbNight.textPrimary)
                    Text(stats[index].label)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2.5)
                        .foregroundColor(OnbNight.textSecondary)
                }
                .opacity(statCount > index ? 1 : 0)
                .offset(y: statCount > index ? 0 : 16)
                .animation(.easeOut(duration: 0.5), value: statCount)
            }

            Text("All working to make sure")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(OnbNight.textSecondary)
                .opacity(showLeadIn ? 1 : 0)
                .offset(y: showLeadIn ? 0 : 12)
                .animation(.easeOut(duration: 0.5), value: showLeadIn)
                .padding(.top, 6)

            HStack(spacing: 10) {
                ForEach(kickerWords.indices, id: \.self) { index in
                    Text(kickerWords[index])
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
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
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        let statsDone = 0.5 + Double(stats.count) * 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + statsDone + 0.3) {
            showLeadIn = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        for index in kickerWords.indices {
            let isLast = index == kickerWords.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + statsDone + 0.9 + Double(index) * 0.5) {
                kickerCount = index + 1
                UIImpactFeedbackGenerator(style: isLast ? .heavy : .medium).impactOccurred()
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
