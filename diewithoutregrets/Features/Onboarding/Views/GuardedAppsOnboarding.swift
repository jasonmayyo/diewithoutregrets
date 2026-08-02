//
//  GuardedAppsOnboarding.swift
//  diewithoutregrets
//
//  Screen Time replacement for the old Shortcuts-based AppSelectionOnboarding.
//  Embeds the system FamilyActivityPicker; the selection is handed straight
//  to StudyGuardManager so the engine can guard it. Enforces the 50-token
//  shield cap with revert. Skipping is allowed — the Guard-tab checklist
//  finishes setup post-onboarding.
//

import SwiftUI
import FamilyControls

struct GuardedAppsOnboarding: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @ObservedObject private var manager = StudyGuardManager.shared

    @State private var localSelection = FamilyActivitySelection()
    @State private var previousSelection = FamilyActivitySelection()
    @State private var showLimitAlert = false
    @State private var isRequestingAuth = false

    private var selectionCount: Int {
        SGContract.tokenCount(localSelection)
    }

    private var selectionIsEmpty: Bool {
        SGContract.isSelectionEmpty(localSelection)
    }

    var body: some View {
        GeometryReader { geometry in
            OnboardingScaffold(
                headline: "Which apps steal your time?",
                subtitle: "Pick the ones he locks when your scroll time runs out.",
                ctaTitle: "Lock them in",
                ctaEnabled: !selectionIsEmpty,
                ctaAction: {
                    lockThemIn()
                },
                secondaryTitle: "Skip for now",
                secondaryAction: {
                    onboardingViewModel.nextStep()
                }
            ) {
                Group {
                    if manager.authorizationStatus == .approved {
                        VStack(spacing: 8) {
                            // The system picker can't be styled — ink chrome
                            // around it is all we get.
                            FamilyActivityPicker(selection: $localSelection)
                                .frame(height: max(380, min(450, geometry.size.height * 0.55)))
                                .clipShape(RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous))
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                        .fill(SGTheme.inkRaised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                                .strokeBorder(SGTheme.hairline, lineWidth: 1)
                                        )
                                )

                            Text("\(selectionCount) of \(SGContract.maxSelectionTokens) selected")
                                .font(SGTheme.caption.weight(.medium))
                                .foregroundColor(SGTheme.paperTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        authorizationPrompt
                    }
                }

                Spacer(minLength: 16)
            }
        }
        .onAppear {
            // Seed from the engine so returning users see their saved picks.
            localSelection = manager.selection
            previousSelection = localSelection
        }
        .onChange(of: localSelection) { _, newValue in
            if SGContract.tokenCount(newValue) > SGContract.maxSelectionTokens {
                localSelection = previousSelection
                showLimitAlert = true
            } else {
                previousSelection = newValue
            }
        }
        .alert("That's the limit", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can guard up to \(SGContract.maxSelectionTokens) apps, categories, and websites. Remove one to add another.")
        }
    }

    // Shown when Screen Time access is missing (user skipped the previous
    // step or revoked it) — the picker renders an empty list without it.
    private var authorizationPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(SGTheme.display(44, weight: .light))
                .foregroundColor(SGTheme.mint)

            Text("Study Guard needs Screen Time access to show your apps here.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 24)

            // While the system auth dialog is up the button dims (disabled)
            // and shows SGButton's loading spinner as the in-flight look.
            SGButton(
                title: "Allow Screen Time access",
                fullWidth: true,
                enabled: !isRequestingAuth,
                loading: isRequestingAuth
            ) {
                requestAuthorization()
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(380, min(450, UIScreen.main.bounds.height * 0.45)))
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
        )
    }

    private func requestAuthorization() {
        guard !isRequestingAuth else { return }
        isRequestingAuth = true

        Task { @MainActor in
            let ok = await StudyGuardManager.shared.requestAuthorization()
            Analytics.capture("screen_time_auth_result", properties: [
                "granted": ok,
                "surface": "onboarding_apps_reprompt"
            ])
            isRequestingAuth = false
            if ok {
                onboardingViewModel.triggerHapticFeedback()
            }
        }
    }

    private func lockThemIn() {
        let result = StudyGuardManager.shared.updateSelection(localSelection)

        if case .refusedTooMany = result {
            localSelection = previousSelection
            showLimitAlert = true
            return
        }

        Analytics.capture("guarded_apps_selected", properties: [
            "app_count": localSelection.applicationTokens.count,
            "category_count": localSelection.categoryTokens.count,
            "web_domain_count": localSelection.webDomainTokens.count,
            "surface": "onboarding"
        ])

        onboardingViewModel.nextStep()
    }
}

#Preview {
    GuardedAppsOnboarding()
        .environmentObject(OnboardingViewModel())
}
