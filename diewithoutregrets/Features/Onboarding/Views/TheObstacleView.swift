//
//  TheObstacleView.swift
//  diewithoutregrets
//
//  Onboarding v2 screen 3 (night): the hope pivot. Two opposing marquees of
//  study-life icons sandwich a rotating aspiration line over the fixed
//  promise "Scroll less.", with the first trust badges underneath.
//

import SwiftUI

struct FightingBackView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let icons = [
        "book.fill", "moon.stars.fill", "figure.run", "brain.head.profile",
        "pencil", "graduationcap.fill", "dumbbell.fill", "music.note",
        "paintbrush.fill", "cup.and.saucer.fill", "bed.double.fill",
    ]

    private let aspirations = [
        "Study more.", "Sleep more.", "Remember more.", "Stress less.", "Live more.",
    ]

    @State private var entered = false
    @State private var showCTA = false
    @State private var aspirationIndex = 0

    private let rotationTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            iconMarquee(reverse: false)
                .fadeRise(entered, delay: 0.2)

            Spacer()

            VStack(spacing: 14) {
                // The rotating aspiration, pushed up and out on a 2.5s beat.
                ZStack {
                    Text(aspirations[aspirationIndex])
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(SGTheme.mint)
                        .id(aspirationIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                .frame(height: 48)
                .clipped()
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: aspirationIndex)

                Text("Scroll less.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundColor(OnbNight.textPrimary)

                Text("Replace mindless scrolling with the work that gets you there.")
                    .font(SGTheme.body)
                    .foregroundColor(OnbNight.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }
            .fadeRise(entered, delay: 0.5)

            Spacer()

            iconMarquee(reverse: true)
                .fadeRise(entered, delay: 0.2)

            Spacer()

            TrustBadges(night: true)
                .fadeRise(entered, delay: 0.9)
                .padding(.bottom, 28)

            OnbCTA(title: "Let's go", night: true, visible: showCTA) {
                viewModel.screenAction("lets_go_tapped")
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            entered = true
            if reduceMotion {
                showCTA = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    showCTA = true
                }
            }
        }
        .onReceive(rotationTimer) { _ in
            guard !reduceMotion else { return }
            aspirationIndex = (aspirationIndex + 1) % aspirations.count
        }
    }

    // MARK: - Icon strips

    @ViewBuilder
    private func iconMarquee(reverse: Bool) -> some View {
        if reduceMotion {
            HStack(spacing: 14) {
                iconStrip
            }
            .frame(maxWidth: .infinity)
            .clipped()
        } else {
            MarqueeRow(speed: 26, reverse: reverse) {
                HStack(spacing: 14) {
                    iconStrip
                }
                .padding(.horizontal, 7)
            }
            .frame(height: 52)
        }
    }

    private var iconStrip: some View {
        ForEach(icons, id: \.self) { icon in
            Circle()
                .fill(OnbNight.chipFill)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                )
                .opacity(0.35)
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        FightingBackView()
            .environmentObject(OnboardingViewModel())
    }
}
