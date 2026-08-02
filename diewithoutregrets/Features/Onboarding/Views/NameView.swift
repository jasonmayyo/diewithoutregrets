//
//  NameView.swift
//  diewithoutregrets
//
//  Onboarding v3 quiz question 2 (night): student type. The answer is
//  echoed verbatim on the paywall ("Your College comeback plan"), so it's
//  stored without the emoji and titles must read naturally in that slot.
//

import SwiftUI

struct QuizStudentTypeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Consultant rule: 5 options max — "Learning for work" folds into
    // "Something else" (both fall back to the generic paywall copy).
    private let options: [(emoji: String, title: String)] = [
        ("🎓", "High school"),
        ("📚", "College"),
        ("🧪", "Grad school"),
        ("📝", "Studying for an exam"),
        ("➕", "Something else"),
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 2,
            question: "What best describes you?",
            subtitle: "Different students need different plans.",
            progress: OnboardingStep.quizStudentType.quizProgress
        ) {
            ForEach(options, id: \.title) { option in
                QuizOptionRow(
                    title: option.title,
                    emoji: option.emoji,
                    selected: viewModel.studentType == option.title
                ) {
                    guard !answered else { return }
                    answered = true
                    viewModel.selectQuizAnswer {
                        viewModel.studentType = option.title
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        QuizStudentTypeView()
            .environmentObject(OnboardingViewModel())
    }
}
