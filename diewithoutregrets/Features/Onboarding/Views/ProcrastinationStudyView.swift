//
//  ProcrastinationStudyView.swift
//  diewithoutregrets
//
//  Onboarding v3 quiz question 4 (night): peak scroll time. Three larger
//  image-card options with tinted SF symbol thumbs, so we know which hours
//  to protect first.
//

import SwiftUI

struct QuizScrollTimesView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    /// Moon-glow blue for the "In bed" thumb. Illustration one-off, not
    /// chrome — it exists only for this artwork and never leaves this view.
    private static let moonBlue = Color(hex: 0x7BA3FF)

    private let options: [(title: String, icon: String, tint: Color)] = [
        ("While studying", "sun.max.fill", SGTheme.sun),
        ("In bed", "moon.fill", moonBlue),
        ("Honestly, all day", "infinity", SGTheme.ember),
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 4,
            question: "When do you scroll when you should be studying?",
            subtitle: "So he knows when to guard hardest.",
            progress: OnboardingStep.quizScrollTimes.quizProgress
        ) {
            ForEach(options, id: \.title) { option in
                ScrollTimeCard(
                    title: option.title,
                    icon: option.icon,
                    tint: option.tint,
                    selected: viewModel.peakScrollTime == option.title
                ) {
                    guard !answered else { return }
                    answered = true
                    viewModel.selectQuizAnswer {
                        viewModel.peakScrollTime = option.title
                    }
                }
            }
        }
    }
}

/// Larger image-card option for the scroll-times question: 56pt tinted
/// symbol circle + title + radio, night styling.
private struct ScrollTimeCard: View {
    let title: String
    let icon: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(SGTheme.display(24, weight: .semibold))
                        .foregroundColor(tint)
                }

                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(OnbNight.textPrimary)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle().fill(Color.white).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(SGTheme.micro.weight(.bold))
                            .foregroundColor(SGTheme.skyTop)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(OnbNight.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(selected ? OnbNight.cardBorderSelected : OnbNight.cardBorder,
                                          lineWidth: selected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
        .animation(SGTheme.springFast, value: selected)
    }
}

#Preview {
    ZStack {
        NightSkyBackdrop()
        QuizScrollTimesView()
            .environmentObject(OnboardingViewModel())
    }
}
