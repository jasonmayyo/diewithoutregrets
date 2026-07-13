//
//  AgeSelectView.swift
//  diewithoutregrets
//
//  Onboarding v2 quiz question 1 (night): age range. Auto-advances on
//  selection while the container's clipboard monster takes a note.
//

import SwiftUI

struct QuizAgeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Same ranges as the retired AvgScreenTimeViewModel age options.
    private let options = [
        "Under 14",
        "14 - 18",
        "19 - 25",
        "26 - 34",
        "35 - 44",
        "45 - 55",
        "56 - 65",
        "Over 65",
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 1,
            question: "How old are you?",
            subtitle: "This helps us tailor your plan to your life stage.",
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
