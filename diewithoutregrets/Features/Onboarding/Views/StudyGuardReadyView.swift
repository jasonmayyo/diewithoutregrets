//
//  StudyGuardReadyView.swift
//  diewithoutregrets
//
//  Onboarding hard gate. Superwall presents the hosted flow; RevenueCat
//  verifies access. Declines retain the existing survey and buyback ladder.
//

import SwiftUI

struct HardPaywallView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @ObservedObject private var navigationModel = NavigationModel.shared

    // Entrance
    @State private var shown = false
    @State private var appeared = false

    @StateObject private var paywall = SGOnboardingPaywallCoordinator()
    @State private var backdropRevealed = false
    @State private var didCompletePurchase = false

    // Decline ladder
    private var declineCount: Int { paywall.declineCount }
    @State private var showDeclineSurvey = false
    /// Idempotency latch: at most one buyback presentation per cover
    /// dismissal round. Reset at the start of each new dismissal.
    @State private var didTriggerBuyBackThisRound = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer()

            Group {
                if backdropRevealed {
                    hero
                } else {
                    loadingHero
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)

            Spacer()

            footer
                .padding(.bottom, 12)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showDeclineSurvey, onDismiss: presentBuyBack) {
            DeclineSurveySheet { reason in
                viewModel.screenAction("decline_survey_reason", properties: ["reason": reason])
            }
            .presentationDetents([.medium])
            .sgSheetChrome()
        }
        .onChange(of: paywall.state) { _, state in
            guard state == .completed, !didCompletePurchase else { return }
            didCompletePurchase = true
            NotificationManager.shared.resetPaywallTracking()
            showDeclineSurvey = false
            viewModel.nextStep()
        }
        .onChange(of: paywall.declineCount) { _, _ in handlePaywallDeclined() }
        .onChange(of: navigationModel.shouldDismissPaywall) { _, shouldDismiss in
            guard shouldDismiss else { return }
            backdropRevealed = true
            Task { await paywall.dismissForExternalOffer() }
        }
        .onChange(of: navigationModel.buyBackPurchasedDuringOnboarding) { _, purchased in
            guard purchased else { return }
            navigationModel.buyBackPurchasedDuringOnboarding = false
            showDeclineSurvey = false
            Task { await paywall.verifyExternalPurchase() }
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            shown = true

            Analytics.paywallViewed(surface: "onboarding_v5", properties: [
                "student_type": viewModel.studentType,
                "screen_time": viewModel.screenTime,
                "phone_days": viewModel.phoneDaysToExam,
                "days_to_exam": viewModel.daysToExam as Any,
                "weeks_to_exam": viewModel.weeksToExam as Any,
                "card_count": viewModel.commitCardCount
            ])
            Telemetry.breadcrumb("Paywall viewed", category: "paywall",
                                 data: ["surface": "onboarding_v5"])
            AdsTracker.trackViewContent(name: "onboarding_paywall")

            Task { await paywall.present() }
        }
    }

    // MARK: - Backdrop pieces

    private var header: some View {
        HStack {
            Spacer()

            SGButton(title: paywall.isRestoring ? "Restoring..." : "Restore",
                     variant: .text,
                     fullWidth: false,
                     enabled: !paywall.isBusy,
                     loading: paywall.isRestoring) {
                Task { await paywall.restore() }
            }
            .accessibilityLabel("Restore purchases")
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 10)
        .fadeRise(shown)
    }

    /// The named offer (Hormozi MAGIC): "Your College Comeback Plan" for
    /// the student types that read naturally in the slot; generic otherwise.
    private var offerName: String {
        switch viewModel.studentType {
        case "High school", "College", "Grad school":
            return "Your \(viewModel.studentType) Comeback Plan"
        default:
            return "Your Comeback Plan"
        }
    }

    /// Honest urgency: the exam date is real — no fake countdowns.
    private var urgencyLine: String {
        if let weeks = viewModel.weeksToExam, let hours = viewModel.scrollHoursToExam {
            return "Your exam is about \(weeks) weeks out. That's \(hours) hours of scrolling between now and then, or your prep time. Your call."
        }
        return "\(viewModel.scrollHoursPerWeek) hours of scrolling every week from here to finals, or your study time. Your call."
    }

    /// What shows while the Superwall paywall is being fetched and
    /// auto-presented: just the mascot and a quiet loader, nothing that
    /// reads as a second paywall.
    private var loadingHero: some View {
        VStack(spacing: 18) {
            MascotView(pose: .idle)
                .frame(width: 90, height: 90)
                .fadeRise(shown)
        }
    }

    private var hero: some View {
        VStack(spacing: 0) {
            MascotView(pose: .idle)
                .frame(width: 90, height: 90)
                .fadeRise(shown)

            SGMicroLabel(text: offerName.uppercased(), color: SGTheme.mintDeep)
                .padding(.top, 16)
                .fadeRise(shown, delay: 0.05)

            (Text("Win back ")
                + Text("\(viewModel.phoneDaysToExam) days")
                .foregroundColor(SGTheme.mintDeep)
                + Text(viewModel.examDateLabel.map { " before \($0)" } ?? " of this semester"))
                .font(SGTheme.stepTitle)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .fadeRise(shown, delay: 0.1)

            Text(urgencyLine)
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.horizontal, 12)
                .fadeRise(shown, delay: 0.15)

            // The value stack: outcome-first, one line each.
            VStack(alignment: .leading, spacing: 14) {
                PaywallFeatureRow(icon: "lock.fill",
                                  text: "Your apps lock themselves. No willpower required")
                PaywallFeatureRow(icon: "rectangle.stack.fill",
                                  text: "Every unlock is a real study session")
                PaywallFeatureRow(icon: "sparkles",
                                  text: "AI turns your notes into flashcards in seconds")
                PaywallFeatureRow(icon: "eye.fill",
                                  text: "True Focus: camera-verified deep work")
                PaywallFeatureRow(icon: "cross.circle.fill",
                                  text: "Emergency unlocks, because life happens")
            }
            .padding(.top, 24)
            .fadeRise(shown, delay: 0.25)

            // Risk reversal.
            VStack(spacing: 6) {
                HStack(spacing: 16) {
                    riskReversalItem("Try it free")
                    riskReversalItem("Cancel in two taps")
                }
                Text("The lock goes on your apps, never your wallet.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .padding(.top, 20)
            .fadeRise(shown, delay: 0.3)
        }
    }

    private func riskReversalItem(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(SGTheme.display(13, weight: .semibold))
                .foregroundColor(SGTheme.mintDeep)
            Text(text)
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperSecondary)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if paywall.isBusy {
            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: SGTheme.mintDeep))
                Text("Loading your plan...")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .frame(height: 76)
            .accessibilityLabel("Loading your plan")
        } else if case .failed(let message) = paywall.state {
            VStack(spacing: 12) {
                Text(message)
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                SGButton(title: "Retry") {
                    viewModel.screenAction("paywall_retry_tapped")
                    Task { await paywall.present() }
                }
                .accessibilityLabel("Retry loading plans")
            }
            .padding(.horizontal, SGTheme.screenPadding)
        } else if backdropRevealed {
            OnbCTA(title: "See plans", visible: shown) {
                viewModel.screenAction("see_plans_tapped", properties: [
                    "decline_count": declineCount
                ])
                Task { await paywall.present() }
            }
        }
    }

    // MARK: - Decline ladder

    private func handlePaywallDeclined() {
        guard !didCompletePurchase else { return }
        withAnimation(.easeInOut(duration: 0.3)) { backdropRevealed = true }
        didTriggerBuyBackThisRound = false
        viewModel.screenAction("paywall_declined", properties: [
            "decline_count": declineCount
        ])

        if declineCount == 1 {
            // Let the cover finish its dismissal transition before the sheet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Guard the race: skip if the Superwall paywall was re-presented in
                // the meantime or the survey is already up.
                guard !paywall.isBusy, !didCompletePurchase, !showDeclineSurvey else { return }
                showDeclineSurvey = true
            }
        } else {
            presentBuyBack()
        }
    }

    /// Presents the app-level BuyBackOfferView (mounted as a fullScreenCover
    /// on NavigationModel.showBuyBackOffer in diewithoutregretsApp).
    private func presentBuyBack() {
        guard !didCompletePurchase, !didTriggerBuyBackThisRound else { return }
        didTriggerBuyBackThisRound = true
        viewModel.screenAction("buyback_presented", properties: [
            "decline_count": declineCount
        ])
        NavigationModel.shared.presentBuyBackOffer()
    }

}

// MARK: - Feature row

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(SGTheme.buttonSmall)
                .foregroundColor(SGTheme.mintDeep)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SGTheme.inkRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(SGTheme.hairline, lineWidth: 1)
                        )
                )
                .accessibilityHidden(true)

            Text(text)
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paper)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Decline survey

/// Decline #1 sheet: one tap on a reason, then the buyback offer. The
/// reason fires through `onReason`; the presenting view triggers buyback in
/// the sheet's onDismiss (so a swipe-away still leads to the offer).
private struct DeclineSurveySheet: View {
    let onReason: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: String?

    private let reasons = [
        "Too expensive",
        "Not sure it'll work for me",
        "Just exploring",
        "Other",
    ]

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("What's holding you back?")
                    .font(SGTheme.sheetTitle)
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                Text("One tap. It helps us make Study Guard better.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                VStack(spacing: 10) {
                    ForEach(reasons, id: \.self) { reason in
                        reasonRow(reason)
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 24)

                Spacer(minLength: 0)
            }
        }
    }

    private func reasonRow(_ reason: String) -> some View {
        let isSelected = selected == reason

        return Button {
            pick(reason)
        } label: {
            HStack(spacing: 12) {
                Text(reason)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? SGTheme.mintDeep : SGTheme.paperTertiary,
                                      lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle().fill(SGTheme.mint).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(SGTheme.display(11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(isSelected ? SGTheme.mintDeep : SGTheme.hairline,
                                          lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
        .animation(SGTheme.springFast, value: isSelected)
    }

    private func pick(_ reason: String) {
        guard selected == nil else { return }
        selected = reason
        SGTheme.tick()
        onReason(reason)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        HardPaywallView()
            .environmentObject(OnboardingViewModel())
    }
}

#Preview("Decline survey") {
    DeclineSurveySheet { _ in }
}
