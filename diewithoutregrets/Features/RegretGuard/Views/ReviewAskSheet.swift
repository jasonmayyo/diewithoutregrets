//
//  ReviewAskSheet.swift
//  diewithoutregrets
//
//  The rating funnel: shown after a winning quiz run (the user's happiest
//  moment). Step one asks whether they're enjoying Study Guard. Yes routes
//  to the system App Store rating prompt; no routes to the support page so
//  the frustration lands in our inbox instead of a one-star review.
//
//  Ask policy (SGReviewAsk): never after a yes or a no (both are terminal),
//  at most 3 asks total, at least 7 days between asks, and at least 3 days
//  after the onboarding system prompt so two rating requests never stack in
//  one week (Apple grants only 3 per year).
//

import SwiftUI

// MARK: - Ask ledger

enum SGReviewAsk {
    private static let doneKey = "sg_reviewAskDone"
    private static let lastShownKey = "sg_reviewAskLastShown"
    private static let shownCountKey = "sg_reviewAskShownCount"
    private static let systemPromptKey = "sg_reviewSystemPromptAt"

    static let supportURL = "https://studyguard.framer.website/support"

    private static let maxAsks = 3
    private static let daysBetweenAsks = 7.0
    private static let daysAfterSystemPrompt = 3.0

    static func shouldAsk(now: Date = Date()) -> Bool {
        let d = UserDefaults.standard
        guard !d.bool(forKey: doneKey) else { return false }
        guard d.integer(forKey: shownCountKey) < maxAsks else { return false }

        let sysAt = d.double(forKey: systemPromptKey)
        if sysAt > 0,
           now.timeIntervalSinceReferenceDate - sysAt < daysAfterSystemPrompt * 86_400 {
            return false
        }

        let lastAt = d.double(forKey: lastShownKey)
        if lastAt > 0,
           now.timeIntervalSinceReferenceDate - lastAt < daysBetweenAsks * 86_400 {
            return false
        }
        return true
    }

    static func recordShown(now: Date = Date()) {
        let d = UserDefaults.standard
        d.set(now.timeIntervalSinceReferenceDate, forKey: lastShownKey)
        d.set(d.integer(forKey: shownCountKey) + 1, forKey: shownCountKey)
    }

    /// Both answers are terminal: a yes already got the rating prompt, a no
    /// must never be asked to rate us again.
    static func recordAnswered() {
        UserDefaults.standard.set(true, forKey: doneKey)
    }

    /// Stamped wherever the system rating prompt fires outside this funnel
    /// (the onboarding social-proof wall), so the funnel keeps its distance.
    static func recordSystemPromptRequested(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSinceReferenceDate,
                                  forKey: systemPromptKey)
    }

    #if DEBUG
    /// Creator toolkit: wipe the ledger so the funnel can be replayed.
    static func creatorReset() {
        let d = UserDefaults.standard
        d.removeObject(forKey: doneKey)
        d.removeObject(forKey: lastShownKey)
        d.removeObject(forKey: shownCountKey)
        d.removeObject(forKey: systemPromptKey)
    }
    #endif
}

// MARK: - Sheet

struct ReviewAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// Fired AFTER the sheet dismisses on a yes, so the presenter can raise
    /// the system rating prompt from a stable presentation context.
    var onLoved: () -> Void

    private enum Step { case ask, feedback }
    @State private var step: Step = .ask

    var body: some View {
        SGFittedSheet(estimatedHeight: 380) {
            Group {
                switch step {
                case .ask: askStep
                case .feedback: feedbackStep
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .interactiveDismissDisabled(false)
    }

    private var askStep: some View {
        VStack(spacing: 20) {
            MascotView(pose: .idle)
                .frame(width: 110, height: 110)

            Text("Enjoying Study Guard?")
                .font(SGTheme.sheetTitle)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)

            Text("You just earned your screen time. Quick question: is Study Guard working for you?")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            VStack(spacing: 12) {
                SGButton(title: "Yes, loving it", variant: .mint) {
                    Analytics.capture("review_ask_answered", properties: [
                        "enjoying": true
                    ])
                    SGReviewAsk.recordAnswered()
                    dismiss()
                    onLoved()
                }

                SGButton(title: "Not really", variant: .ghost) {
                    Analytics.capture("review_ask_answered", properties: [
                        "enjoying": false
                    ])
                    withAnimation(SGTheme.springFast) { step = .feedback }
                }
            }
            .padding(.top, 8)
        }
    }

    private var feedbackStep: some View {
        VStack(spacing: 20) {
            MascotView(pose: .clipboard)
                .frame(width: 110, height: 110)

            Text("Help us make it right")
                .font(SGTheme.sheetTitle)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)

            Text("Sorry it's not clicking yet. Tell us what's not working and it goes straight to the team.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            VStack(spacing: 12) {
                SGButton(title: "Send us a message", variant: .mint) {
                    Analytics.capture("review_ask_feedback_opened", properties: [
                        "url": SGReviewAsk.supportURL
                    ])
                    SGReviewAsk.recordAnswered()
                    if let url = URL(string: SGReviewAsk.supportURL) {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                }

                SGButton(title: "Not now", variant: .ghost) {
                    // Their "not really" already sealed the ledger; we just
                    // don't force the trip to the support page.
                    Analytics.capture("review_ask_feedback_skipped")
                    SGReviewAsk.recordAnswered()
                    dismiss()
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Previews

#Preview("Ask") {
    Color.white.sheet(isPresented: .constant(true)) {
        ReviewAskSheet(onLoved: {})
    }
}
