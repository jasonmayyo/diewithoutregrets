// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
import SwiftUI
struct SGV5AppStoreReview {
    let name: String
    let title: String
    let body: String
    let storefront: String
    let sourceURL: URL

    // Short verbatim excerpts, checked against the linked App Store listings
    // on 21 October 2026. Do not substitute invented names, stars or outcomes.
    static let featured: [Self] = [
        .init(name: "zara prakash", title: "the BEST app for studying", body: "…helped me ace my tests…",
              storefront: "India", sourceURL: URL(string: "https://apps.apple.com/in/app/study-guard-study-focus/id6744607430?platform=iphone&see-all=reviews")!),
        .init(name: "Nickname24567444", title: "Good", body: "I loved this, it helped my grades improve!",
              storefront: "UK", sourceURL: URL(string: "https://apps.apple.com/gb/app/study-guard-study-focus/id6744607430")!),
        .init(name: "Finé Taylor", title: "Review", body: "…it helps me a lot with studying…",
              storefront: "Germany", sourceURL: URL(string: "https://apps.apple.com/de/app/study-guard-study-focus/id6744607430")!),
    ]
}

struct SGV5AppStoreReviewCard: View {
    let review: SGV5AppStoreReview
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(review.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SGTheme.paper.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "apple.logo")
                    .font(.system(size: 13)).foregroundStyle(SGTheme.paperSecondary)

            }

            Text(review.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(SGTheme.paper)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("“\(review.body)”")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(SGTheme.paper.opacity(0.5))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: review.sourceURL) {
                Text("App Store · \(review.storefront) ↗")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SGTheme.mintDeep)
            }
            .accessibilityLabel("Read \(review.name)'s original App Store review")
        }
        .padding(14)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SGTheme.paper.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SGTheme.paper.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Infinite horizontal marquee (seamless loop)

/// Two instances must use different `stripId` values so SwiftUI never merges their identity.
struct SGV5V4ReviewMarqueeLoop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()
    let stripId: String
    let reviews: [SGV5AppStoreReview]
    var pixelsPerSecond: CGFloat = 26
    /// Shifts the animation phase so stacked rows are not identical.
    var timePhaseSeconds: Double = 0

    private let cardWidth: CGFloat = 268
    private let spacing: CGFloat = 12

    private var itemStride: CGFloat { cardWidth + spacing }
    private var cycleWidth: CGFloat {
        guard !reviews.isEmpty else { return 1 }
        return CGFloat(reviews.count) * itemStride
    }

    private var rowHeight: CGFloat { 176 }

    var body: some View {
        Group {
            if reduceMotion {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(reviews.enumerated()), id: \.offset) { _, review in
                            SGV5AppStoreReviewCard(review: review, width: cardWidth)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                animatedReviews
            }
        }
        .frame(height: rowHeight)
    }

    private var animatedReviews: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion || scenePhase != .active)) { context in
                let elapsed = reduceMotion ? 0 : max(0, context.date.timeIntervalSince(startedAt)) + timePhaseSeconds
                let distance = CGFloat(elapsed) * pixelsPerSecond
                let remainder = distance.truncatingRemainder(dividingBy: cycleWidth)
                let offset = -remainder

                HStack(spacing: spacing) {
                    ForEach(0..<2, id: \.self) { copyIndex in
                        ForEach(Array(reviews.enumerated()), id: \.offset) { index, review in
                            SGV5AppStoreReviewCard(review: review, width: cardWidth)
                                .id("\(stripId)-\(copyIndex)-\(index)")
                                .accessibilityHidden(copyIndex > 0)
                        }
                    }
                }
                .offset(x: offset)
                .frame(width: geo.size.width, alignment: .leading)
            }
        }
        .frame(height: rowHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: SGTheme.paper, location: 0.07),
                    .init(color: SGTheme.paper, location: 0.93),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

