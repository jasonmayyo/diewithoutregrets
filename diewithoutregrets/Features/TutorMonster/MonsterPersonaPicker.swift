//
//  MonsterPersonaPicker.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 3): choosing your tutor monster. A shared persona list,
//  an onboarding-step wrapper ("Who's keeping you honest?"), and a settings screen
//  so existing users can switch. Styling is functional (SG tokens + onboarding
//  chrome) pending the /design-shotgun pass. See Docs/TutorMonsterPlan.md Appendix C.
//

import SwiftUI

/// The four monsters as tappable rows, persisted to PersonaStore. Reused by both
/// the onboarding step and the settings screen.
struct MonsterPersonaList: View {
    @ObservedObject private var store = PersonaStore.shared

    var body: some View {
        VStack(spacing: 10) {
            ForEach(MonsterPersona.all) { persona in
                row(persona)
            }
        }
    }

    private func row(_ persona: MonsterPersona) -> some View {
        let selected = store.selectedID == persona.id
        let accent = MonsterPalette.color(persona.accentHex)
        return Button {
            guard store.selectedID != persona.id else { return }
            store.select(persona)
            SGV5Haptics.play(.selection)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(accent)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(persona.name.prefix(1)))
                            .font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(persona.name).font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(SGTheme.paper)
                        Text(persona.tagline).font(.system(size: 12))
                            .foregroundStyle(SGTheme.paperSecondary)
                    }
                    Text("“\(MonsterScript.line(persona: persona, mood: .chill, context: .greeting, seed: 0))”")
                        .font(.system(size: 13)).italic()
                        .foregroundStyle(SGTheme.paperSecondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? accent : SGTheme.paperTertiary)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(SGTheme.inkRaised, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? accent : SGTheme.hairline, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Onboarding step (.persona): "Who's keeping you honest?" Mirrors SGV5StudyLevelView.
struct SGV5PersonaPickerView: View {
    @ObservedObject var viewModel: SGV5FlowModel

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.persona.progress,
                                onBack: { viewModel.previousPage() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SGV5QuizGhostSpeechBubble(question: "Who's keeping you honest?")
                    Text("Pick your tutor monster. It quizzes you to unlock your apps, in its own voice. You can switch any time.")
                        .font(.system(size: 15)).foregroundStyle(SGTheme.paperSecondary)
                    MonsterPersonaList()
                }
                .padding(.horizontal, 24).padding(.vertical, 22)
            }
            SGV5QuizContinueButton(isEnabled: true) {
                viewModel.trackUserInput(screenId: SGV5V5OnboardingStep.persona.rawValue,
                                         inputType: "persona", value: PersonaStore.shared.selectedID)
                viewModel.advanceV5()
            }
            .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper).tint(SGTheme.mintDeep)
    }
}

/// Settings screen (pushed from ProfileView) so existing users can choose/switch.
struct MonsterPersonaPickerScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SGScreenHeader(eyebrow: "Tutor Monster", title: "Choose your monster")
                Text("Pick who keeps you honest. You can switch any time.")
                    .font(SGTheme.body).foregroundStyle(SGTheme.paperSecondary)
                MonsterPersonaList()
            }
            .padding(SGTheme.screenPadding)
        }
        .background(SGTheme.ink.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
