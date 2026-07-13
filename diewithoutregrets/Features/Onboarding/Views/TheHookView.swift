//
//  TheHookView.swift
//  diewithoutregrets
//
//  Onboarding v2 screen 1 (daylight): the first impression. Mockup video up
//  top, promise headline, mint CTA, plus the housekeeping App Store needs:
//  a restore path for existing subscribers and the Terms/Privacy links.
//

import SwiftUI
import RevenueCat

struct HookView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var entered = false
    @State private var showCTA = false

    // Restore flow (existing subscribers skip the funnel).
    @State private var isRestoring = false
    @State private var showRestoreSuccess = false
    @State private var showNoSubscription = false
    @State private var restoreErrorMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video hero, framed on an ink card (same treatment as the
                // retired PayWallView).
                LoopingVideoPlayer(videoName: "mockupvideo", videoExtension: "mp4")
                    .frame(height: geometry.size.height * 0.52)
                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .fill(SGTheme.inkRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                    .strokeBorder(SGTheme.hairline, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.top, 8)
                    .fadeRise(entered, delay: 0.1)
                    .accessibilityLabel("Video demonstration of Study Guard")

                Spacer(minLength: 16)

                VStack(spacing: 10) {
                    Text("Scroll less. Study more.")
                        .font(SGTheme.display(34))
                        .foregroundColor(SGTheme.paper)
                        .multilineTextAlignment(.center)
                        .fadeRise(entered, delay: reduceMotion ? 0 : 0.3)

                    Text("Study Guard locks your distracting apps until you've studied.")
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                        .fadeRise(entered, delay: reduceMotion ? 0 : 0.8)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 16)

                VStack(spacing: 14) {
                    OnbCTA(title: "Get started", visible: showCTA) {
                        viewModel.nextStep()
                    }

                    Button {
                        Task { await restorePurchases() }
                    } label: {
                        HStack(spacing: 6) {
                            if isRestoring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: SGTheme.paperSecondary))
                                    .scaleEffect(0.7)
                            }
                            Text(isRestoring ? "Restoring..." : "I already have an account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(SGTheme.paperSecondary)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .disabled(isRestoring)
                    .fadeRise(showCTA)
                    .accessibilityLabel("Restore purchases")

                    // App Store requirement: legal links on the first screen.
                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.footnote)
                            .foregroundColor(SGTheme.paperSecondary)

                        Link("Privacy Policy", destination: URL(string: "https://studyguard.framer.website/legal/privacy-policy")!)
                            .font(.footnote)
                            .foregroundColor(SGTheme.paperSecondary)
                    }
                    .fadeRise(showCTA)
                }
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            entered = true
            if reduceMotion {
                showCTA = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showCTA = true
                }
            }
        }
        .alert("Welcome back", isPresented: $showRestoreSuccess) {
            Button("Continue") {
                viewModel.skipToSetupAfterRestore()
            }
        } message: {
            Text("Your subscription is active. Let's set up this device.")
        }
        .alert("No subscription found", isPresented: $showNoSubscription) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find a previous purchase on this account.")
        }
        .alert("Restore Error", isPresented: .constant(restoreErrorMessage != nil)) {
            Button("OK") {
                restoreErrorMessage = nil
            }
        } message: {
            Text(restoreErrorMessage ?? "Unknown error")
        }
    }

    // MARK: - Restore purchases

    private func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        Analytics.restorePurchasesAttempted(surface: "onboarding_hook")

        do {
            // Invalidate cache before restore to get fresh data.
            Purchases.shared.invalidateCustomerInfoCache()
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            let customerInfo = try await Purchases.shared.restorePurchases()

            if !customerInfo.entitlements.active.isEmpty {
                Analytics.restorePurchasesSucceeded(surface: "onboarding_hook", hasActiveEntitlements: true)
                await MainActor.run {
                    showRestoreSuccess = true
                }
            } else {
                Analytics.restorePurchasesSucceeded(surface: "onboarding_hook", hasActiveEntitlements: false)
                await MainActor.run {
                    showNoSubscription = true
                }
            }
        } catch {
            Analytics.restorePurchasesFailed(surface: "onboarding_hook", error: error.localizedDescription)
            Telemetry.capture(error,
                              tags: ["feature": "paywall", "surface": "onboarding_hook", "operation": "restore_purchases"])
            await MainActor.run {
                restoreErrorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        HookView()
            .environmentObject(OnboardingViewModel())
    }
}
