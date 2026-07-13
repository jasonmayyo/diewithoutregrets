//
//  StudyConsistancy.swift
//  diewithoutregrets
//
//  Onboarding v2 — ScienceView: "The Study Guard Method" credibility beat.
//  The teaching mascot floats over one line of method framing, a mint
//  hairline, and the peer-review citation row (Cepeda 2006 + Steel 2007).
//  Merges the four old science screens into a single daylight beat.
//

import SwiftUI

struct ScienceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false
    @State private var ctaShown = false
    @State private var bobbing = false
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MascotView(pose: .teaching, loops: nil)
                .frame(width: 150, height: 150)
                .offset(y: bobbing ? -8 : 4)
                .fadeRise(shown, delay: 0.2)
                .padding(.bottom, 20)

            Text("The Study Guard Method")
                .font(SGTheme.display(30))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .fadeRise(shown, delay: 0.5)

            Text("Built on proven learning science: spaced repetition and friction design, grounded in peer-reviewed research.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
                .padding(.top, 10)
                .fadeRise(shown, delay: 0.8)

            Rectangle()
                .fill(SGTheme.mint.opacity(0.5))
                .frame(width: 56, height: 1)
                .padding(.vertical, 24)
                .fadeRise(shown, delay: 1.1)

            VStack(spacing: 14) {
                HStack(spacing: 28) {
                    // Equal-height logo slots; each logo keeps its established
                    // treatment (steel raw, common sense on a paper chip).
                    HStack {
                        Image("steel-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .frame(height: 30)

                    HStack {
                        Image("common-sense-media-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 18)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(SGTheme.paper)
                            )
                    }
                    .frame(height: 30)
                }

                Text("Based on Cepeda et al. 2006 (spaced repetition) and Steel 2007 (procrastination research)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(SGTheme.paperTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 44)
            }
            .fadeRise(shown, delay: 1.4)

            Spacer()

            OnbCTA(title: "Continue", visible: ctaShown) {
                viewModel.screenAction("science_continue")
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            guard !started else { return }
            started = true

            if UIAccessibility.isReduceMotionEnabled {
                shown = true
                ctaShown = true
                return
            }

            shown = true
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                bobbing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                ctaShown = true
            }
        }
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        ScienceView()
            .environmentObject(OnboardingViewModel())
    }
}
