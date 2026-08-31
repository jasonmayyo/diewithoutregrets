//
//  UsageIntervalOnboarding.swift
//  diewithoutregrets
//
//  Final Screen Time setup step: pick the usage interval (how long the user
//  can scroll before the guarded apps lock) and start monitoring.
//  completeSetup() failures never block onboarding — the Guard-tab checklist
//  finishes whatever is missing later.
//

import SwiftUI

struct UsageIntervalOnboarding: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    /// The unlock rule the commitment screen wrote (restored subscribers
    /// skip that screen and keep whatever they had).
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3

    @State private var selectedMinutes: Int = SGContract.defaultIntervalMinutes

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        OnboardingScaffold(
            mascot: .clipboard,
            mascotReplayKey: selectedMinutes,
            headline: "How long until your apps lock?",
            subtitle: "Scroll this long and he steps in. Then your rule kicks in: \(flashcardCount) flashcards buys \(StudyGuardManager.shared.earnedMinutes(forCardCount: flashcardCount)) minutes back. Fresh start every morning.",
            ctaTitle: "Start guarding",
            ctaAction: {
                startGuarding()
            }
        ) {
            Spacer()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SGContract.allowedIntervals, id: \.self) { minutes in
                    IntervalPill(
                        minutes: minutes,
                        isSelected: selectedMinutes == minutes,
                        isRecommended: minutes == SGContract.defaultIntervalMinutes
                    ) {
                        selectedMinutes = minutes
                        StudyGuardManager.shared.updateInterval(minutes)
                        SGTheme.beat()
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            // Reflect anything already persisted (e.g. user came back a step).
            selectedMinutes = StudyGuardManager.shared.intervalMinutes
            StudyGuardManager.shared.updateInterval(selectedMinutes)
        }
    }

    private func startGuarding() {
        StudyGuardManager.shared.updateInterval(selectedMinutes)

        switch StudyGuardManager.shared.completeSetup() {
        case .success:
            Analytics.capture("screen_time_setup_completed", properties: [
                "interval_minutes": selectedMinutes,
                "surface": "onboarding"
            ])
        case .failure(.monitoringFailed):
            Analytics.capture("setup_monitoring_failed", properties: [
                "reason": "monitoringFailed",
                "surface": "onboarding"
            ])
        case .failure(.notAuthorized):
            Analytics.capture("screen_time_setup_deferred", properties: [
                "reason": "notAuthorized"
            ])
        case .failure(.emptySelection):
            Analytics.capture("screen_time_setup_deferred", properties: [
                "reason": "emptySelection"
            ])
        }

        // Never block here — the Guard tab checklist finishes setup later.
        onboardingViewModel.nextStep()
    }
}

private struct IntervalPill: View {
    let minutes: Int
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(minutes) min")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                if isRecommended {
                    Text("Recommended")
                        .font(SGTheme.micro)
                        .foregroundColor(SGTheme.mint)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(isSelected ? SGTheme.mintTint : SGTheme.inkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? SGTheme.mint : (isRecommended ? SGTheme.mint.opacity(0.4) : SGTheme.hairline),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(SGPressStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    UsageIntervalOnboarding()
        .environmentObject(OnboardingViewModel())
}
