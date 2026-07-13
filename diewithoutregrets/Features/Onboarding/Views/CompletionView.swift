//
//  CompletionView.swift
//  diewithoutregrets
//
//  Final onboarding screen (v2, screen 28): mascot celebration on the
//  aurora meadow with confetti. Re-verifies Pro before completing — a
//  lapsed entitlement bounces back to the paywall, OneThing-style — then
//  flips hasCompletedOnboarding and fires the completion analytics.
//

import SwiftUI
import RevenueCat

struct CompletionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var shown = false
    @State private var showConfetti = false
    @State private var isVerifying = false
    @State private var showVerifyError = false

    var body: some View {
        ZStack {
            SGAuroraBackground(intensity: 0.5)

            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
                    .zIndex(1)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()

                MascotView(pose: .idle, loops: nil)
                    .frame(height: 160)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: shown)

                Text("You're all set.")
                    .font(SGTheme.headline)
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .fadeRise(shown, delay: 0.4)

                Text("Your monster is on duty.\nTime to make your hours count.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 36)
                    .fadeRise(shown, delay: 0.55)

                Spacer()

                Button(action: completeIfPro) {
                    HStack(spacing: 8) {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("Let's go")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(SGTheme.mint, in: Capsule(style: .continuous))
                    .shadow(color: SGTheme.mint.opacity(0.25), radius: 14, y: 4)
                }
                .buttonStyle(SGPressStyle())
                .disabled(isVerifying)
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.bottom, 16)
                .fadeRise(shown, delay: 0.7)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            shown = true
            SGTheme.successHaptic()
            if !UIAccessibility.isReduceMotionEnabled {
                withAnimation(.easeOut(duration: 0.5)) {
                    showConfetti = true
                }
            }
        }
        .alert("Verification failed", isPresented: $showVerifyError) {
            Button("Retry") { completeIfPro() }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Couldn't verify your subscription. Check your connection and try again.")
        }
    }

    // MARK: - Completion

    /// The Pro re-check: onboarding v2 has no skip past the paywall, so a
    /// lapsed or refunded entitlement here goes back to it instead of
    /// unlocking the app.
    private func completeIfPro() {
        guard !isVerifying else { return }
        isVerifying = true

        Purchases.shared.getCustomerInfo { customerInfo, error in
            DispatchQueue.main.async {
                isVerifying = false

                // Couldn't reach RevenueCat: don't bounce a paying user to
                // the paywall on a network hiccup. Stay here and offer retry.
                guard error == nil, let customerInfo = customerInfo else {
                    showVerifyError = true
                    return
                }

                // Only bounce when we positively see zero active entitlements.
                guard !customerInfo.entitlements.active.isEmpty else {
                    Analytics.capture("onboarding_completion_pro_recheck_failed", properties: [
                        "flow_version": "sg_v2"
                    ])
                    viewModel.currentStep = .paywall
                    return
                }
                complete()
            }
        }
    }

    private func complete() {
        Analytics.capture("onboarding_completed", properties: [
            "age_range": viewModel.selectedAge,
            "student_type": viewModel.studentType,
            "screen_time": viewModel.screenTime,
            "peak_scroll_time": viewModel.peakScrollTime,
            "deck_name": viewModel.newDeckName,
            "guarded_token_count": SGContract.sharedDefaults.flatMap { SGContract.decodeSelection($0) }.map { SGContract.tokenCount($0) } ?? 0,
            "flow_version": "sg_v2"
        ])

        AdsTracker.trackCompleteRegistration()

        SGTheme.successHaptic()
        hasCompletedOnboarding = true
    }
}

// MARK: - Confetti (also used by QuizKit's session completion)

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    /// Celebration palette — every piece reads on the ink canvas.
    var colors: [Color] = [
        SGTheme.mint,
        SGTheme.teal,
        SGTheme.paper,
        SGTheme.ember
    ]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onAppear { createParticles() }
        .onReceive(timer) { _ in updateParticles() }
    }

    private func createParticles() {
        particles = (0..<40).map { _ in
            ConfettiParticle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 3,
                color: colors.randomElement() ?? SGTheme.mint,
                rotation: Double.random(in: 0...360)
            )
        }
    }

    private func updateParticles() {
        withAnimation(.linear(duration: 0.1)) {
            particles = particles.filter { $0.isActive }
            particles.indices.forEach { i in
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy
                particles[i].vy += 0.5
                particles[i].rotation += particles[i].vr
                particles[i].scale *= 0.99
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double = Double.random(in: -10...10)
    var vy: Double = Double.random(in: -50...(-20))
    var color: Color
    var rotation: Double
    var vr: Double = Double.random(in: -10...10)
    var scale: Double = 1.0
    var isActive: Bool {
        y < UIScreen.main.bounds.height + 100 && scale > 0.1
    }
}

#Preview {
    CompletionView()
        .environmentObject(OnboardingViewModel())
}
