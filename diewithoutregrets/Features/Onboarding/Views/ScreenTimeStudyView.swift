//
//  ScreenTimeStudyView.swift
//  diewithoutregrets
//
//  Onboarding v2 screen 4 (night): the mascot reveal. Your monster stands
//  center stage while fake notification banners bombard him from the top.
//  As the flood peaks he snaps angry, three descriptor words land on you
//  (Distracted. Exhausted. Behind.), then the mint pivot: he's here to win
//  your time back.
//

import SwiftUI

struct MeetYourGuardView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let descriptors = ["Distracted.", "Exhausted.", "Behind."]

    @State private var started = false
    @State private var bannersActive = false
    @State private var angry = false
    @State private var showTitle = false
    @State private var descriptorCount = 0
    @State private var showPivot = false
    @State private var showCTA = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 0) {
                Spacer()

                // The monster, glowing mint until the notifications get to him.
                ZStack {
                    MascotView(pose: .idle, loops: nil)
                        .opacity(angry ? 0 : 1)

                    Image("angrey")
                        .resizable()
                        .scaledToFit()
                        .opacity(angry ? 1 : 0)
                        .scaleEffect(angry ? 1 : 0.7)
                }
                .frame(width: 200, height: 200)
                .shadow(color: SGTheme.mint.opacity(0.4), radius: 28)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: angry)

                Text("This is your study monster.")
                    .font(SGTheme.display(26))
                    .foregroundColor(OnbNight.textPrimary)
                    .multilineTextAlignment(.center)
                    .fadeRise(showTitle)
                    .padding(.top, 26)
                    .padding(.horizontal, 32)

                // The descriptors are about YOU, not him.
                HStack(spacing: 10) {
                    ForEach(descriptors.indices, id: \.self) { index in
                        Text(descriptors[index])
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(SGTheme.ember)
                            .opacity(descriptorCount > index ? 1 : 0)
                            .scaleEffect(descriptorCount > index ? 1 : 1.5)
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: descriptorCount)
                    }
                }
                .padding(.top, 18)

                Text("He's here to win your time back.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SGTheme.mint)
                    .fadeRise(showPivot)
                    .padding(.top, 16)
                    .padding(.horizontal, 32)

                Spacer()

                OnbCTA(title: "I'm ready", night: true, visible: showCTA) {
                    viewModel.screenAction("im_ready_tapped")
                    viewModel.nextStep()
                }
                .padding(.bottom, 12)
            }

            // The bombardment. Soft haptic per banner comes from the overlay.
            NotificationBannerOverlay(active: bannersActive)
                .padding(.top, 8)
        }
        .onAppear(perform: start)
    }

    // MARK: - Choreography

    private func start() {
        guard !started else { return }
        started = true

        if reduceMotion {
            // Collapse to the final beat: angry monster, all copy, CTA.
            viewModel.screenAction("notification_cascade_started")
            viewModel.screenAction("monster_angry")
            showTitle = true
            angry = true
            descriptorCount = descriptors.count
            showPivot = true
            showCTA = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showTitle = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            bannersActive = true
            viewModel.screenAction("notification_cascade_started")
        }

        // The flood peaks and he snaps.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            angry = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            viewModel.screenAction("monster_angry")
        }

        for index in descriptors.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0 + Double(index) * 0.35) {
                descriptorCount = index + 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.2) {
            bannersActive = false
            showPivot = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
            showCTA = true
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        MeetYourGuardView()
            .environmentObject(OnboardingViewModel())
    }
}
