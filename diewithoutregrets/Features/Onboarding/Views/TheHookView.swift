//
//  TheHookView.swift
//  diewithoutregrets
//
//  Onboarding v3 screen 1 (daylight): the first impression. A clock-hand
//  carousel of framed app screenshots swings up top (each slide arcs in
//  from the right, settles centre over a mint glow, then arcs out left),
//  promise headline, mint CTA, plus the housekeeping App Store needs:
//  a restore path for existing subscribers and the Terms/Privacy links.
//

import SwiftUI
import RevenueCat

struct HookView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var entered = false
    @State private var showCTA = false
    @State private var slide = 0

    private let slides = ["welcome1", "welcome2", "welcome3"]
    private let slideTimer = Timer.publish(every: 3.4, on: .main, in: .common).autoconnect()

    // Restore flow (existing subscribers skip the funnel).
    @State private var isRestoring = false
    @State private var showRestoreSuccess = false
    @State private var showNoSubscription = false
    @State private var restoreErrorMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Screenshot hero: the rotating clock-hand carousel.
                HookScreenshotCarousel(images: slides, slide: slide,
                                       height: geometry.size.height * 0.52)
                    .padding(.top, 8)
                    .fadeRise(entered, delay: 0.1)
                    .accessibilityLabel("Screenshots of Study Guard")
                    .onReceive(slideTimer) { _ in
                        guard !reduceMotion else { return }
                        withAnimation(.spring(response: 0.85, dampingFraction: 0.86)) {
                            slide = (slide + 1) % slides.count
                        }
                    }

                Spacer(minLength: 16)

                VStack(spacing: 10) {
                    Text("You know you should be studying.")
                        .font(SGTheme.stepTitle)
                        .foregroundColor(SGTheme.paper)
                        .multilineTextAlignment(.center)
                        .fadeRise(entered, delay: reduceMotion ? 0 : 0.3)

                    Text("Study Guard locks your distracting apps until you do. No willpower required.")
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                        .fadeRise(entered, delay: reduceMotion ? 0 : 0.8)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 16)

                VStack(spacing: 14) {
                    OnbCTA(title: "I'm ready", visible: showCTA) {
                        viewModel.nextStep()
                    }

                    SGButton(title: isRestoring ? "Restoring..." : "I already have an account",
                             variant: .text,
                             enabled: !isRestoring,
                             loading: isRestoring) {
                        Task { await restorePurchases() }
                    }
                    .frame(minHeight: 44)
                    .fadeRise(showCTA)
                    .accessibilityLabel("Restore purchases")

                    // App Store requirement: legal links on the first screen.
                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)

                        Link("Privacy Policy", destination: URL(string: "https://studyguard.framer.website/legal/privacy-policy")!)
                            .font(SGTheme.caption)
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

/// Clock-hand screenshot carousel (the Secure welcome pattern): each slide
/// rotates about a point far below the frame, so it swings in from the
/// right along an arc, settles upright centre stage over a soft mint glow,
/// then swings out to the left as the next arrives.
private struct HookScreenshotCarousel: View {
    let images: [String]
    let slide: Int
    var height: CGFloat = 420

    /// Signed wheel position for a slide: 0 = centre stage, +1 = waiting
    /// off to the right, -1 = departed to the left. Wrap-aware so the
    /// sequence always reads right, centre, left.
    private func wheelDelta(_ index: Int) -> Double {
        Double(((index - slide + 1 + images.count) % images.count) - 1)
    }

    var body: some View {
        ZStack {
            // Mint halo behind centre stage so the screenshot lifts off
            // the dark ink backdrop.
            RadialGradient(
                colors: [
                    SGTheme.mint.opacity(0.30),
                    SGTheme.mint.opacity(0.10),
                    Color.clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: 230
            )
            .blur(radius: 30)
            .allowsHitTesting(false)

            ForEach(images.indices, id: \.self) { i in
                let delta = wheelDelta(i)
                Image(images[i])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
                    .sgShadow(SGTheme.shadowFloat)
                    // Rotating about a point far below the frame swings the
                    // screenshot along a clock-like arc: +28° parks it off
                    // the right edge, -28° off the left.
                    .rotationEffect(.degrees(delta * 28), anchor: UnitPoint(x: 0.5, y: 2.7))
                    .opacity(delta == 0 ? 1 : 0)
                    .animation(.easeOut(duration: 0.45), value: slide)
            }
        }
        .frame(height: height + 20)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        HookView()
            .environmentObject(OnboardingViewModel())
    }
}
