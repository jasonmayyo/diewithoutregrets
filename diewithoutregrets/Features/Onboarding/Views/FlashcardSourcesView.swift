//
//  FlashcardSourcesView.swift
//  diewithoutregrets
//
//  Onboarding v2 — FounderStoryView: the sincere beat before the reviews.
//  Two founder headshots (with monogram fallbacks until the assets land),
//  a quote about losing study years to a screen, and the indie mission card.
//

import SwiftUI

struct FounderStoryView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false
    @State private var ctaShown = false
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 20) {
                FounderHeadshot(imageName: "jason1", monogram: "J")
                FounderHeadshot(imageName: "jude", monogram: "J")
            }
            .fadeRise(shown, delay: 0.3)

            Text("\u{201C}We built Study Guard because we were tired of losing our best study years to a screen. We hope it helps you as much as it helped us.\u{201D}")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .fadeRise(shown, delay: 0.8)

            VStack(spacing: 4) {
                Text("Jason and Jude")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SGTheme.paper)
                Text("The two people who made this")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .padding(.top, 20)
            .fadeRise(shown, delay: 1.3)

            HStack(spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SGTheme.mint)

                Text("No investors. No growth team. Just two people trying to help students scroll less and learn more.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SGTheme.paperSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SGTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
            )
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 28)
            .fadeRise(shown, delay: 1.8)

            Spacer()

            OnbCTA(title: "Continue", visible: ctaShown) {
                viewModel.screenAction("founder_continue")
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            guard !started else { return }
            started = true

            if UIAccessibility.isReduceMotionEnabled {
                shown = true
                ctaShown = true
                return
            }

            shown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                ctaShown = true
            }
        }
    }
}

/// 120pt circular headshot that degrades gracefully: if the named asset is
/// missing from the catalog, it renders a monogram circle instead.
private struct FounderHeadshot: View {
    let imageName: String
    let monogram: String

    var body: some View {
        Group {
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    SGTheme.inkRaised
                    Text(monogram)
                        .font(SGTheme.display(42))
                        .foregroundColor(SGTheme.paperTertiary)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(SGTheme.hairline, lineWidth: 1))
        .shadow(color: SGTheme.cardShadow, radius: 10, y: 4)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        FounderStoryView()
            .environmentObject(OnboardingViewModel())
    }
}
