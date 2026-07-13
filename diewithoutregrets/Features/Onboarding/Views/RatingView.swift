//
//  RatingView.swift
//  diewithoutregrets
//
//  NotificationPrimerView (onboarding v2, screen 25): the "stay on track"
//  explainer plus the actual UNUserNotificationCenter request, moved here
//  from the retired FreeTrialReminderView. Both allow and deny advance;
//  "Not now" skips the request entirely.
//

import SwiftUI
import UserNotifications

struct NotificationPrimerView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false
    @State private var isRequestingPermission = false
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(SGTheme.mint.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .overlay(Circle().strokeBorder(SGTheme.mint.opacity(0.25), lineWidth: 1))

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(SGTheme.ember, SGTheme.mint)
            }
            .fadeRise(shown)

            Text("Stay on track")
                .font(SGTheme.headline)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .fadeRise(shown, delay: 0.15)

            Text("Get a heads up when your apps lock and reminders to keep your streak alive.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)
                .padding(.horizontal, 40)
                .fadeRise(shown, delay: 0.3)

            Spacer()

            Button(action: requestNotificationPermission) {
                HStack(spacing: 8) {
                    if isRequestingPermission {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text("Enable notifications")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(SGTheme.mint, in: Capsule(style: .continuous))
                .shadow(color: SGTheme.mint.opacity(0.25), radius: 14, y: 4)
            }
            .buttonStyle(SGPressStyle())
            .disabled(isRequestingPermission)
            .padding(.horizontal, SGTheme.screenPadding)
            .fadeRise(shown, delay: 0.45)

            Button {
                guard !isRequestingPermission, !didFinish else { return }
                didFinish = true
                viewModel.screenAction("notifications_skipped")
                viewModel.nextStep()
            } label: {
                Text("Not now")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SGTheme.paperSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(isRequestingPermission)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .fadeRise(shown, delay: 0.55)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .onAppear { shown = true }
    }

    // Ported verbatim from FreeTrialReminderView, minus the paywall handoff:
    // the flow just advances once the dialog resolves.
    private func requestNotificationPermission() {
        guard !isRequestingPermission, !didFinish else { return }
        isRequestingPermission = true
        Analytics.capture("onboarding_notification_permission_requested")

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                didFinish = true

                if let error = error {
                    print("🔔 Notification permission error: \(error)")
                } else {
                    print("🔔 Notification permission granted: \(granted)")
                }
                Analytics.onboardingNotificationPermission(granted: granted)

                if granted {
                    SGTheme.successHaptic()
                }
                viewModel.nextStep()
            }
        }
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        NotificationPrimerView()
    }
    .environmentObject(OnboardingViewModel())
}
