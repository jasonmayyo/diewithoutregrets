//
//  LongTermResults.swift
//  diewithoutregrets
//
//  Onboarding v2 — ReviewsView: the social proof wall before the paywall.
//  Trust badges over two opposing review marquees; the CTA fires the system
//  rating request and advances after it lands.
//

import SwiftUI
import StoreKit

struct ReviewsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @Environment(\.requestReview) private var requestReview

    @State private var shown = false
    @State private var ctaShown = false
    @State private var started = false
    @State private var requested = false

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    private let reviews: [OnbReview] = [
        OnbReview(name: "Ella P.", title: "Saved my finals week",
                  text: "My apps locked and suddenly I had three free hours a night. Passed every single exam."),
        OnbReview(name: "Marcus T.", title: "The monster guilt-trips me",
                  text: "He just stares at me until I answer my flashcards. Somehow it actually works."),
        OnbReview(name: "Priya S.", title: "Finally works with my ADHD",
                  text: "Blocking apps never stuck. Earning time back does. My focus is completely different now."),
        OnbReview(name: "Jake L.", title: "I sleep before 1am now",
                  text: "No more 2am TikTok spirals. My phone locks and I just go to bed. Wild concept."),
        OnbReview(name: "Sofia R.", title: "From C's to A's",
                  text: "Two months of flashcards made from my own notes. My GPA finally moved."),
        OnbReview(name: "Daniel K.", title: "Screen time cut in half",
                  text: "Six hours a day down to three. And the three I get now, I actually earned."),
        OnbReview(name: "Amara J.", title: "Better than deleting apps",
                  text: "I always reinstalled them by Friday. Now they stay locked until I study. No willpower needed."),
        OnbReview(name: "Leo M.", title: "Carried my MCAT prep",
                  text: "Every scroll break turned into a review session. Genuinely the reason I stayed on schedule."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TrustBadges(night: false)
                .padding(.top, 24)
                .fadeRise(shown, delay: 0.2)

            Text("45,000 students stopped fighting themselves")
                .font(SGTheme.stepTitle)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 18)
                .fadeRise(shown, delay: 0.4)

            Spacer()

            VStack(spacing: 14) {
                reviewStrip(Array(reviews.prefix(4)), speed: 26, reverse: false)
                reviewStrip(Array(reviews.suffix(4)), speed: 21, reverse: true)
            }
            .fadeRise(shown, delay: 0.7)

            Spacer()

            OnbCTA(title: "Continue", visible: ctaShown) {
                guard !requested else { return }
                requested = true
                viewModel.screenAction("rating_request_triggered")
                requestReview()
                // Give the system rating sheet time to land before the step
                // changes underneath it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    viewModel.nextStep()
                }
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            guard !started else { return }
            started = true

            if reduceMotion {
                shown = true
                ctaShown = true
                return
            }

            shown = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                ctaShown = true
            }
        }
    }

    /// One marquee strip; under Reduce Motion it renders a static row
    /// instead of drifting forever.
    ///
    /// The strip content is thousands of points wide, so it lives in an
    /// `overlay` on a fixed-height spacer: overlays contribute NOTHING to
    /// layout, which guarantees the row can never push the screen's width
    /// past the device edges no matter what the marquee reports.
    private func reviewStrip(_ items: [OnbReview], speed: Double, reverse: Bool) -> some View {
        Color.clear
            .frame(height: OnbReviewCard.height)
            .frame(maxWidth: .infinity)
            .overlay {
                if reduceMotion {
                    HStack(spacing: 12) {
                        ForEach(items) { review in
                            OnbReviewCard(review: review)
                        }
                    }
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: reverse ? .trailing : .leading)
                } else {
                    MarqueeRow(speed: speed, reverse: reverse) {
                        HStack(spacing: 12) {
                            ForEach(items) { review in
                                OnbReviewCard(review: review)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }
            .clipped()
    }
}

// MARK: - Review card

private struct OnbReview: Identifiable {
    let id = UUID()
    let name: String
    let title: String
    let text: String
}

private struct OnbReviewCard: View {
    let review: OnbReview

    /// Fixed card height (14pt padding × 2 + name/title/2-line-text rows)
    /// so the strips can reserve exact layout space and render the moving
    /// row purely as an overlay.
    static let height: CGFloat = 118

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(review.name)
                    .font(SGTheme.rowLabel)
                    .foregroundColor(SGTheme.paperSecondary)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(SGTheme.micro)
                            .foregroundColor(SGTheme.sun)
                    }
                }
            }

            Text(review.title)
                .font(SGTheme.cardTitle)
                .foregroundColor(SGTheme.paper)
                .lineLimit(1)

            Text(review.text)
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperSecondary)
                .lineSpacing(2)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(14)
        .frame(width: 268, height: Self.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        ReviewsView()
            .environmentObject(OnboardingViewModel())
    }
}
