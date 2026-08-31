//
//  YourScreenTimeView.swift
//  diewithoutregrets
//
//  Onboarding v3 quiz question 3 (night): self-reported daily screen time.
//  The chosen range drives every personalized number downstream (the
//  semester grid drain, the chart, the imagine promise, the paywall
//  headline and countdown).
//

import SwiftUI

struct QuizScreenTimeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let options: [(range: String, judgment: String)] = [
        ("2-4 hours", "About average"),
        ("4-6 hours", "More than a part-time job"),
        ("6-8 hours", "This is costing you grades"),
        ("8+ hours", "Time to take it back"),
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 4,
            question: "How much time do you spend on your phone each day?",
            subtitle: "Be honest, this stays between us.",
            progress: OnboardingStep.quizScreenTime.quizProgress
        ) {
            ForEach(options, id: \.range) { option in
                QuizOptionRow(
                    title: option.range,
                    subtext: option.judgment,
                    selected: viewModel.screenTime == option.range
                ) {
                    guard !answered else { return }
                    answered = true
                    viewModel.selectQuizAnswer {
                        viewModel.screenTime = option.range
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        QuizScreenTimeView()
            .environmentObject(OnboardingViewModel())
    }
}
