//
//  AgeSelectView.swift
//  diewithoutregrets
//
//  Onboarding v3 quiz question 1 (night): age range. Auto-advances on
//  selection while the container's clipboard monster takes a note.
//

import SwiftUI

struct QuizAgeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Consultant rule: never more than 5 options, and none a real student
    // wouldn't pick (nobody 65 is downloading a student app).
    private let options = [
        "Under 14",
        "14–17",
        "18–22",
        "23–29",
        "30 or over",
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 1,
            question: "How old are you?",
            subtitle: "We'll tune the plan to where you are in life.",
            progress: OnboardingStep.quizAge.quizProgress
        ) {
            ForEach(options, id: \.self) { option in
                QuizOptionRow(
                    title: option,
                    selected: viewModel.selectedAge == option
                ) {
                    guard !answered else { return }
                    answered = true
                    viewModel.selectQuizAnswer {
                        viewModel.selectedAge = option
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        QuizAgeView()
            .environmentObject(OnboardingViewModel())
    }
}
