//
//  MonsterPersonaPicker.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 3): choosing your tutor monster. A shared persona list,
//  an onboarding-step wrapper ("Who's keeping you honest?"), and a settings screen
//  so existing users can switch. Styling is functional (SG tokens + onboarding
//  chrome), with the approved cast artwork. See Docs/TutorMonsterPlan.md Appendix C.
//

import SwiftUI

/// The four monsters as illustrated cards, persisted to PersonaStore. Reused by both
/// the onboarding step and the settings screen.
struct MonsterPersonaList: View {
    @ObservedObject private var store = PersonaStore.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12),
              count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MonsterPersona.all) { persona in
                    card(persona)
                }
            }
            Text("“\(BuddyOnboardingCopy.greeting(store.persona))”")
                .font(.subheadline)
                .foregroundStyle(SGTheme.paper)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(MonsterPalette.accent(store.persona).opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 20))
                .accessibilityLabel("\(store.persona.name) says: \(BuddyOnboardingCopy.greeting(store.persona))")
        }
    }

    private func card(_ persona: MonsterPersona) -> some View {
        let selected = store.selectedID == persona.id
        let accent = MonsterPalette.color(persona.accentHex)
        return Button {
            guard store.selectedID != persona.id else { return }
            store.select(persona)
            SGV5Haptics.play(.selection)
        } label: {
            VStack(spacing: 10) {
                MonsterArtwork(asset: persona.artworkAsset,
                               expression: selected ? .correct : .welcome, size: 112)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(selected ? MonsterPalette.text : SGTheme.paperTertiary)
                    }
                VStack(spacing: 4) {
                    Text(persona.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(SGTheme.paper)
                    Text(persona.tagline)
                        .font(.subheadline)
                        .foregroundStyle(SGTheme.paperSecondary)
                        .lineLimit(2, reservesSpace: true)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.center)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(selected ? accent.opacity(0.12) : SGTheme.inkRaised,
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? accent : SGTheme.hairline, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(persona.name), \(persona.tagline)")
        .accessibilityHint("Choose this tutor monster")
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick your buddy")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    MonsterPersonaList()
                }
                .padding(.horizontal, 24).padding(.vertical, 16)
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
