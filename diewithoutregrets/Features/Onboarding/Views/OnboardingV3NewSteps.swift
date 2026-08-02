//
//  OnboardingV3NewSteps.swift
//  diewithoutregrets
//
//  The steps added by onboarding v3: the 11pm feeling (Phase 1 opener for
//  the night), the exam-date quiz question (powers the paywall countdown),
//  and the no-willpower effort-killer screen (Phase 3).
//
//  TheFeelingIntroView ships here as its static version; Stage 3 adds the
//  word-by-word beat choreography and the daylight→night crossfade tie-in.
//

import SwiftUI

// MARK: - theFeeling

/// "It's 11pm." — says out loud what the student feels every night. Night
/// falls behind this screen (the container crossfades the sky as this step
/// enters); the beats land in the dark, the kicker gets the heavy haptic.
struct TheFeelingIntroView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @State private var showCTA = false

    /// Beat delays — 0 under Reduce Motion so everything is just there.
    private func at(_ delay: Double) -> Double { reduceMotion ? 0 : delay }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Text("It's 11pm.")
                    .font(SGTheme.stepTitle)
                    .foregroundColor(.white)
                    .fadeRise(shown, delay: at(0.2))

                Text("The plan was to start after dinner.")
                    .font(SGTheme.display(24))
                    .foregroundColor(.white.opacity(0.85))
                    .fadeRise(shown, delay: at(1.0))

                Text("Then you opened your phone.")
                    .font(SGTheme.display(24))
                    .foregroundColor(.white.opacity(0.85))
                    .fadeRise(shown, delay: at(1.8))

                (Text("Four hours. ")
                    + Text("Gone.").foregroundColor(SGTheme.ember)
                    + Text(" Again."))
                    .font(SGTheme.display(30))
                    .foregroundColor(.white)
                    .fadeRise(shown, delay: at(2.8))

                Text("And tomorrow, you'll promise yourself the same thing.")
                    .font(SGTheme.body)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .fadeRise(shown, delay: at(3.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SGTheme.screenPadding + 6)

            Spacer()

            OnbCTA(title: "That's me", night: true, visible: showCTA) {
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            shown = true
            if reduceMotion {
                showCTA = true
                return
            }
            // A tick as each line lands; the kicker hits harder.
            for delay in [0.2, 1.0, 1.8] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    SGTheme.tick()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                SGTheme.climax()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
                showCTA = true
            }
        }
    }
}

// MARK: - willpowerLie

/// "You've already tried willpower." — burns down the self-reliant fixes
/// (delete the apps, set a timer, one quick check) before the mascot offers
/// the lock. Each failed fix lands with a wrong-buzz; the reframe gets the
/// success haptic.
struct WillpowerLieView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let beats: [(tried: String, result: String)] = [
        ("Deleted the apps.", "Reinstalled them by Friday."),
        ("Set a study timer.", "Ignored it by 9pm."),
        ("\u{201C}Just one quick check.\u{201D}", "You know how that ends."),
    ]

    @State private var shown = false
    @State private var beatsLanded = 0
    @State private var showReframe = false
    @State private var showCTA = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 26) {
                Text("You've already tried willpower.")
                    .font(SGTheme.stepTitle)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .fadeRise(shown)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(beats.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(beats[index].tried)
                                .font(SGTheme.display(20, weight: .semibold))
                                .strikethrough(beatsLanded > index, color: SGTheme.ember)
                                .foregroundColor(.white.opacity(beatsLanded > index ? 0.55 : 0.9))
                            Text(beats[index].result)
                                .font(SGTheme.body)
                                .foregroundColor(SGTheme.ember)
                                .opacity(beatsLanded > index ? 1 : 0)
                        }
                        .fadeRise(beatsLanded > index)
                        .animation(SGTheme.springFast, value: beatsLanded)
                    }
                }

                Text("Every fix that relies on you breaks when you're tired.\nYou need one that doesn't.")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.mint)
                    .fixedSize(horizontal: false, vertical: true)
                    .fadeRise(showReframe)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SGTheme.screenPadding + 6)

            Spacer()

            OnbCTA(title: "Show me", night: true, visible: showCTA) {
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear { runChoreography() }
    }

    private func runChoreography() {
        shown = true
        if reduceMotion {
            beatsLanded = beats.count
            showReframe = true
            showCTA = true
            return
        }
        for index in beats.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(index) * 1.1) {
                beatsLanded = index + 1
                SGTheme.wrongBuzz()
            }
        }
        let reframeAt = 1.0 + Double(beats.count) * 1.1 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + reframeAt) {
            showReframe = true
            SGTheme.successHaptic()
            viewModel.screenAction("willpower_reframe_shown")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + reframeAt + 0.6) {
            showCTA = true
        }
    }
}

// MARK: - quizExamDate

/// Quiz question 5 (night): when's the next big exam? Feeds weeksToExam,
/// which powers the paywall's honest-urgency countdown.
struct QuizExamDateView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Titles must match OnboardingViewModel.weeksToExam's switch exactly.
    private let options = [
        "Within a month",
        "1–2 months away",
        "3+ months away",
        "No exams, just deadlines",
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 5,
            question: "When's your next big exam?",
            subtitle: "We'll build your comeback around it.",
            progress: OnboardingStep.quizExamDate.quizProgress
        ) {
            ForEach(options, id: \.self) { option in
                QuizOptionRow(
                    title: option,
                    selected: viewModel.examTiming == option
                ) {
                    guard !answered else { return }
                    answered = true
                    viewModel.selectQuizAnswer {
                        viewModel.examTiming = option
                    }
                }
            }
        }
    }
}

// MARK: - noWillpower

/// The effort-and-sacrifice killer: you keep your phone, you keep your
/// apps. Deliberately calm — no choreography, the restraint is the point.
struct NoWillpowerView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            MascotView(pose: .idle, loops: nil)
                .frame(width: 132, height: 132)
                .shadow(color: SGTheme.mint.opacity(0.3), radius: 22)
                .fadeRise(shown, delay: 0.1)
                .padding(.bottom, 28)

            VStack(spacing: 16) {
                Text("You keep your phone.\nYou keep your apps.")
                    .font(SGTheme.stepTitle)
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)
                    .fadeRise(shown, delay: 0.35)

                Text("No deleting Instagram. No grayscale monk mode. No 30-day detox you'll quit by day three. You just study first.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
                    .fadeRise(shown, delay: 0.7)

                Text("Zero willpower required. That's the point.")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.mintDeep)
                    .multilineTextAlignment(.center)
                    .fadeRise(shown, delay: 1.1)
            }
            .padding(.horizontal, SGTheme.screenPadding)

            Spacer()

            OnbCTA(title: "Continue", visible: shown) {
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear { shown = true }
    }
}

#Preview("theFeeling") {
    ZStack {
        NightSkyBackdrop()
        TheFeelingIntroView()
            .environmentObject(OnboardingViewModel())
    }
}

#Preview("quizExamDate") {
    ZStack {
        NightSkyBackdrop()
        QuizExamDateView()
            .environmentObject(OnboardingViewModel())
    }
}

#Preview("noWillpower") {
    NoWillpowerView()
        .environmentObject(OnboardingViewModel())
}
