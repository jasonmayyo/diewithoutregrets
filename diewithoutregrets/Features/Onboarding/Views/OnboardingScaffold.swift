//
//  OnboardingScaffold.swift
//  diewithoutregrets
//
//  Teal Ink onboarding step container. Reproduces the template every
//  onboarding step shares — headline block up top, flexible content in
//  the middle, primary CTA pinned at the bottom — on the ink canvas,
//  with the staged opacity+offset entrance driven internally.
//
//  Slots (top to bottom):
//    hero      — optional full-width visual above the header
//    mascot    — optional MascotView above the header (after hero);
//                bump mascotReplayKey to make it re-play, e.g. the
//                clipboard pose "taking a note" whenever an answer is picked
//    eyebrow   — optional SGMicroLabel
//    headline  — stepTitle (rounded 30 bold), paper
//    subtitle  — body, paperSecondary
//    content   — free-form middle (add Spacers inside to center things)
//    ctaTitle  — SGButton (.mint chunky capsule, white label)
//    secondary — optional SGButton .text under the CTA
//

import SwiftUI

struct OnboardingScaffold<Hero: View, Content: View>: View {
    var mascot: MascotPose?
    var mascotReplayKey: Int
    var mascotHeight: CGFloat
    var eyebrow: String?
    var headline: String?
    var subtitle: String?
    /// Pass true for atmosphere steps; plain ink otherwise.
    var aurora: Bool
    /// Centers the eyebrow/headline/subtitle block.
    var centerHeader: Bool
    var ctaTitle: String?
    var ctaEnabled: Bool
    var ctaAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var hero: Hero
    var content: Content

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        mascot: MascotPose? = nil,
        mascotReplayKey: Int = 0,
        mascotHeight: CGFloat = 120,
        eyebrow: String? = nil,
        headline: String? = nil,
        subtitle: String? = nil,
        aurora: Bool = false,
        centerHeader: Bool = false,
        ctaTitle: String? = nil,
        ctaEnabled: Bool = true,
        ctaAction: @escaping () -> Void = {},
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content
    ) {
        self.mascot = mascot
        self.mascotReplayKey = mascotReplayKey
        self.mascotHeight = mascotHeight
        self.eyebrow = eyebrow
        self.headline = headline
        self.subtitle = subtitle
        self.aurora = aurora
        self.centerHeader = centerHeader
        self.ctaTitle = ctaTitle
        self.ctaEnabled = ctaEnabled
        self.ctaAction = ctaAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.hero = hero()
        self.content = content()
    }

    var body: some View {
        ZStack {
            if aurora {
                SGAuroraBackground(intensity: 0.5)
            } else {
                SGTheme.ink.ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 0) {
                staged(index: 0) {
                    hero
                        .frame(maxWidth: .infinity)
                }

                if let mascot {
                    staged(index: 0) {
                        MascotView(pose: mascot, replayKey: mascotReplayKey)
                            .frame(height: mascotHeight)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 16)
                    }
                }

                if eyebrow != nil || headline != nil || subtitle != nil {
                    staged(index: 1) { header }
                }

                staged(index: 2) {
                    content
                        .frame(maxWidth: .infinity)
                }

                if ctaTitle != nil || secondaryTitle != nil {
                    staged(index: 3) { footer }
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .onAppear { revealed = true }
    }

    // MARK: - Slots

    private var header: some View {
        VStack(alignment: centerHeader ? .center : .leading, spacing: 8) {
            if let eyebrow {
                SGMicroLabel(text: eyebrow)
            }
            if let headline {
                Text(headline)
                    .font(SGTheme.stepTitle)
                    .foregroundColor(SGTheme.paper)
                    .lineSpacing(3)
                    .multilineTextAlignment(centerHeader ? .center : .leading)
            }
            if let subtitle {
                Text(subtitle)
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(centerHeader ? .center : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: centerHeader ? .center : .leading)
        .padding(.bottom, 16)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if let ctaTitle {
                SGButton(title: ctaTitle, enabled: ctaEnabled, action: ctaAction)
            }
            if let secondaryTitle, let secondaryAction {
                SGButton(title: secondaryTitle, variant: .text, action: secondaryAction)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Staged entrance

    /// The template's entrance: opacity + 20pt rise, 0.2s-increment delays.
    /// Reduce Motion renders everything immediately, no offset.
    @ViewBuilder
    private func staged<V: View>(index: Int, @ViewBuilder _ view: () -> V) -> some View {
        if reduceMotion {
            view()
        } else {
            view()
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.2 + Double(index) * 0.2), value: revealed)
        }
    }
}

extension OnboardingScaffold where Hero == EmptyView {
    init(
        mascot: MascotPose? = nil,
        mascotReplayKey: Int = 0,
        mascotHeight: CGFloat = 120,
        eyebrow: String? = nil,
        headline: String? = nil,
        subtitle: String? = nil,
        aurora: Bool = false,
        centerHeader: Bool = false,
        ctaTitle: String? = nil,
        ctaEnabled: Bool = true,
        ctaAction: @escaping () -> Void = {},
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            mascot: mascot,
            mascotReplayKey: mascotReplayKey,
            mascotHeight: mascotHeight,
            eyebrow: eyebrow,
            headline: headline,
            subtitle: subtitle,
            aurora: aurora,
            centerHeader: centerHeader,
            ctaTitle: ctaTitle,
            ctaEnabled: ctaEnabled,
            ctaAction: ctaAction,
            secondaryTitle: secondaryTitle,
            secondaryAction: secondaryAction,
            hero: { EmptyView() },
            content: content
        )
    }
}

/// Ink card backing for light-designed art (Lottie files, photos, charts)
/// so it stays legible on the ink canvas.
struct OnboardingIllustrationCard<Media: View>: View {
    /// Use SGTheme.paper for art with dark/black linework baked in.
    var fill: Color = SGTheme.inkRaised
    var padding: CGFloat = 12
    @ViewBuilder var media: Media

    var body: some View {
        media
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
            )
    }
}

#Preview {
    OnboardingScaffold(
        eyebrow: "The research is clear.",
        headline: "A headline that spans a couple of lines.",
        subtitle: "Supporting subtitle text sits here.",
        ctaTitle: "Continue",
        ctaAction: {},
        secondaryTitle: "Skip for now",
        secondaryAction: {}
    ) {
        Spacer()
        OnboardingIllustrationCard {
            Text("Content")
                .foregroundColor(SGTheme.paper)
                .frame(height: 160)
        }
        Spacer()
    }
}
