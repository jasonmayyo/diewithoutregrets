//
//  UnlockMethodChoiceView.swift
//  diewithoutregrets
//
//  Post-purchase setup (v2, screen 26): pick how locked apps unlock —
//  flashcards or a True Focus session. Writes "unlockMethod" on selection;
//  the view model persists quiz answers + person properties automatically
//  when this step advances (nextStep → saveUserData).
//

import SwiftUI

struct UnlockMethodChoiceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"

    var body: some View {
        OnboardingScaffold(
            mascot: .clipboard,
            mascotReplayKey: unlockMethod.hashValue,
            headline: "How do you want to unlock your apps?",
            subtitle: "You can always change this later.",
            ctaTitle: "Continue",
            ctaAction: {
                viewModel.nextStep()
            }
        ) {
            Spacer()

            VStack(spacing: 14) {
                UnlockMethodCard(
                    icon: "rectangle.stack.fill",
                    title: "Flashcards",
                    subtitle: "Answer cards from your decks",
                    selected: unlockMethod == "flashcards"
                ) {
                    unlockMethod = "flashcards"
                    viewModel.triggerHapticFeedback()
                }

                UnlockMethodCard(
                    icon: "eye.fill",
                    title: "True Focus",
                    subtitle: "Camera-verified focus sessions",
                    selected: unlockMethod == "trueFocus"
                ) {
                    unlockMethod = "trueFocus"
                    viewModel.triggerHapticFeedback()
                }
            }

            Spacer()
        }
    }
}

/// Large selectable card in the SGOptionTile language: mint wash + border
/// when selected, raised ink tile otherwise.
private struct UnlockMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selected ? SGTheme.mintTint : SGTheme.inkHigh)
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(SGTheme.display(20, weight: .medium))
                        .foregroundColor(selected ? SGTheme.mint : SGTheme.paperTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)

                    Text(subtitle)
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(selected ? SGTheme.mint : SGTheme.hairline, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle()
                            .fill(SGTheme.mint)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(SGTheme.micro.weight(.bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(SGTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(selected ? SGTheme.mintTint : SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(selected ? SGTheme.mint : SGTheme.hairline,
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
    UnlockMethodChoiceView()
        .environmentObject(OnboardingViewModel())
}
