//
//  AIFlashcardDemo.swift
//  diewithoutregrets
//
//  Onboarding v2 — MoreFeaturesView: the auto-advancing feature reel.
//  Zero interaction, no CTA: "That's not all." then the True Focus card,
//  then the AI flashcards card, then it advances itself (~12s). Under
//  Reduce Motion it collapses to a static summary with a Continue button.
//

import SwiftUI

struct MoreFeaturesView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// 0 = blank, 1 = intro line, 2 = True Focus, 3 = AI flashcards,
    /// 4 = fading out before the auto-advance.
    @State private var phase = 0
    @State private var started = false
    @State private var advanced = false
    @State private var pendingAdvance = false

    /// Captured once in onAppear so a mid-screen settings flip can't strand
    /// the reel or double-advance.
    @State private var reduceMotion = false

    var body: some View {
        Group {
            if reduceMotion {
                staticSummary
            } else {
                reel
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            reduceMotion = UIAccessibility.isReduceMotionEnabled
            guard !reduceMotion else { return }
            runReel()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && pendingAdvance {
                pendingAdvance = false
                advance()
            }
        }
    }

    // MARK: - The reel

    private var reel: some View {
        ZStack {
            switch phase {
            case 1:
                VStack(spacing: 12) {
                    Text("That's not all.")
                        .font(SGTheme.display(32))
                        .foregroundColor(SGTheme.paper)
                    Text("Study Guard verifies you're actually studying.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 36)
                .transition(.opacity)

            case 2:
                featureSlide(title: "True Focus",
                             sub: "Camera-verified study sessions. No faking it.") {
                    trueFocusCard
                }
                .transition(.opacity)

            case 3:
                featureSlide(title: "AI flashcards",
                             sub: "Paste notes, a YouTube link, or a Quizlet set. He makes the cards.") {
                    aiCardsCard
                }
                .transition(.opacity)

            default:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureSlide<Card: View>(title: String, sub: String,
                                          @ViewBuilder card: () -> Card) -> some View {
        VStack(spacing: 24) {
            card()

            VStack(spacing: 8) {
                Text(title)
                    .font(SGTheme.display(26))
                    .foregroundColor(SGTheme.paper)
                Text(sub)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 36)
        }
        .padding(.horizontal, SGTheme.screenPadding)
    }

    // The art has black typography baked in, so it gets a paper backing —
    // inkRaised would swallow it.
    private var trueFocusCard: some View {
        OnboardingIllustrationCard(fill: SGTheme.paper) {
            Image("verified-focus-image")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
    }

    private var aiCardsCard: some View {
        OnboardingIllustrationCard {
            VStack(spacing: 16) {
                DotLottieView(fileName: "scan-document", speed: 0.8)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    sourceChip("youtube-icon")
                    sourceChip("quizlet")
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func sourceChip(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SGTheme.ink)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
            )
    }

    // MARK: - Choreography

    private func runReel() {
        withAnimation(.easeInOut(duration: 0.5)) { phase = 1 }
        viewModel.screenAction("intro_shown")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) { phase = 2 }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            viewModel.screenAction("true_focus_shown")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            withAnimation(.easeInOut(duration: 0.5)) { phase = 3 }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            viewModel.screenAction("ai_cards_shown")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
            withAnimation(.easeInOut(duration: 0.6)) { phase = 4 }
            viewModel.screenAction("showcase_complete")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 11.2) {
            advance()
        }
    }

    private func advance() {
        guard !advanced else { return }
        guard scenePhase == .active else {
            pendingAdvance = true
            return
        }
        advanced = true
        viewModel.nextStep()
    }

    // MARK: - Reduce Motion fallback

    private var staticSummary: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("That's not all.")
                .font(SGTheme.display(30))
                .foregroundColor(SGTheme.paper)

            trueFocusCard
                .padding(.horizontal, SGTheme.screenPadding)

            VStack(spacing: 4) {
                Text("True Focus")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Text("Camera-verified study sessions. No faking it.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }

            VStack(spacing: 4) {
                Text("AI flashcards")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Text("Paste notes, a YouTube link, or a Quizlet set. He makes the cards.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()

            OnbCTA(title: "Continue") {
                viewModel.screenAction("showcase_complete", properties: ["reduced_motion": true])
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        MoreFeaturesView()
            .environmentObject(OnboardingViewModel())
    }
}
