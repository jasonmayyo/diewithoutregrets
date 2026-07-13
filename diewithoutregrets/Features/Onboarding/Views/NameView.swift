//
//  NameView.swift
//  diewithoutregrets
//
//  Onboarding v2 quiz question 2 (night): student type. The answer is
//  echoed verbatim on the paywall, so it's stored without the emoji.
//

import SwiftUI

struct QuizStudentTypeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let options: [(emoji: String, title: String)] = [
        ("🎓", "High school"),
        ("📚", "College"),
        ("🧪", "Grad school"),
        ("📝", "Studying for exams"),
        ("💼", "Learning for work"),
        ("➕", "Other"),
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 2,
            question: "What best describes you?",
            subtitle: "Different students need different strategies.",
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
