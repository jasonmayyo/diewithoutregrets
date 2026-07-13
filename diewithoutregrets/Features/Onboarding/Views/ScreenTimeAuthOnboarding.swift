//
//  ScreenTimeAuthOnboarding.swift
//  diewithoutregrets
//
//  Post-purchase Screen Time pair (onboarding v2): the value explainer that
//  primes Apple's scary FamilyControls dialog, then the actual request.
//  Denial never blocks onboarding — both grant and deny advance; the
//  Guard-tab checklist catches missing access later.
//

import SwiftUI
import FamilyControls

// MARK: - Screen 21: the explainer

/// Value framing BEFORE the OS dialog: what Screen Time access does for the
/// user and the privacy promise, delivered by the clipboard monster.
struct ScreenTimeExplainerView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MascotView(pose: .clipboard)
                .frame(height: 130)
                .fadeRise(shown)

            Text("Screen Time access")
                .font(SGTheme.headline)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .fadeRise(shown, delay: 0.15)

            Text("Study Guard uses Apple's Screen Time to lock your distracting apps. Your app activity stays on your device. We never see it.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)
                .padding(.horizontal, 36)
                .fadeRise(shown, delay: 0.3)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12))
                Text("Private by design. Backed by Apple.")
                    .font(.system(size: 12))
            }
            .foregroundColor(SGTheme.paperTertiary)
            .padding(.bottom, 14)
            .fadeRise(shown, delay: 0.45)

            OnbCTA(title: "Continue", visible: shown) {
                viewModel.screenAction("explainer_continue")
                viewModel.nextStep()
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .onAppear { shown = true }
    }
}

// MARK: - Screen 22: the request

/// The actual FamilyControls authorization. Fires the OS dialog, logs
/// screen_time_auth_result, and advances on BOTH grant and deny.
struct ScreenTimePermissionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false
    @State private var isRequesting = false
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(SGTheme.mint.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .overlay(Circle().strokeBorder(SGTheme.mint.opacity(0.25), lineWidth: 1))

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(SGTheme.mint)
            }
            .fadeRise(shown)

            Text("Allow access")
                .font(SGTheme.headline)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .fadeRise(shown, delay: 0.15)

            Text("iOS will ask with a system dialog. Allow it and your monster does the rest.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)
                .padding(.horizontal, 40)
                .fadeRise(shown, delay: 0.3)

            Spacer()

            Button(action: requestAccess) {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text("Allow Screen Time access")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(SGTheme.mint, in: Capsule(style: .continuous))
                .shadow(color: SGTheme.mint.opacity(0.25), radius: 14, y: 4)
            }
            .buttonStyle(SGPressStyle())
            .disabled(isRequesting)
            .padding(.horizontal, SGTheme.screenPadding)
            .fadeRise(shown, delay: 0.45)

            Button {
                guard !isRequesting, !didFinish else { return }
                didFinish = true
                viewModel.screenAction("screen_time_deferred")
                viewModel.nextStep()
            } label: {
                Text("Set up later from the Guard tab")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SGTheme.paperSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(isRequesting)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .fadeRise(shown, delay: 0.55)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .onAppear { shown = true }
    }

    private func requestAccess() {
        guard !isRequesting, !didFinish else { return }
        isRequesting = true

        Task { @MainActor in
            let ok = await StudyGuardManager.shared.requestAuthorization()
            Analytics.capture("screen_time_auth_result", properties: [
                "granted": ok,
                "surface": "onboarding"
            ])
            isRequesting = false
            didFinish = true

            if ok {
                SGTheme.successHaptic()
            }
            // Denial never blocks — the Guard-tab checklist finishes later.
            viewModel.nextStep()
        }
    }
}

#Preview("Explainer") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        ScreenTimeExplainerView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("Permission") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        ScreenTimePermissionView()
    }
    .environmentObject(OnboardingViewModel())
}
