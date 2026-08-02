import SwiftUI

struct CreateFirstCardsOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var deckStore = DeckStore.shared

    @State private var showGenerateSheet = false
    @State private var selectedSource: InputSource = .text
    @State private var onboardingDeckIndex: Int? = nil

    private var onboardingDeckBinding: Binding<Deck> {
        Binding(
            get: {
                if let index = onboardingDeckIndex, index < deckStore.decks.count {
                    return deckStore.decks[index]
                }
                return Deck(name: "My First Deck", cards: [])
            },
            set: { newValue in
                if let index = onboardingDeckIndex, index < deckStore.decks.count {
                    deckStore.decks[index] = newValue
                }
            }
        )
    }

    var body: some View {
        OnboardingScaffold(
            mascot: .clipboard,
            headline: "Create your first\nflash cards",
            subtitle: "Choose how you'd like to add study material.",
            secondaryTitle: "Skip for now",
            secondaryAction: {
                Analytics.capture("onboarding_create_cards_skipped")
                onboardingViewModel.nextStep()
            }
        ) {
            Spacer()

            VStack(spacing: 14) {
                SourceOptionCard(
                    icon: "text.alignleft",
                    title: "Paste Text",
                    subtitle: "Paste notes, articles, or any text",
                    accentColor: SGTheme.mint
                ) {
                    selectedSource = .text
                    Analytics.capture("onboarding_create_cards_source_tapped", properties: ["source": "text"])
                    showGenerateSheet = true
                }

                SourceOptionCard(
                    imageName: "youtube-icon",
                    title: "YouTube Video",
                    subtitle: "Paste a YouTube link to generate cards",
                    accentColor: SGTheme.teal
                ) {
                    selectedSource = .youtube
                    Analytics.capture("onboarding_create_cards_source_tapped", properties: ["source": "youtube"])
                    showGenerateSheet = true
                }

                SourceOptionCard(
                    imageName: "quizlet",
                    title: "Import from Quizlet",
                    subtitle: "Import your existing Quizlet sets",
                    accentColor: SGTheme.mint
                ) {
                    selectedSource = .quizlet
                    Analytics.capture("onboarding_create_cards_source_tapped", properties: ["source": "quizlet"])
                    showGenerateSheet = true
                }
            }

            Spacer()
        }
        .onAppear {
            ensureDeckExists()
        }
        .sheet(isPresented: $showGenerateSheet, onDismiss: {
            // Check if cards were generated and auto-advance
            if let index = onboardingDeckIndex,
               index < deckStore.decks.count,
               !deckStore.decks[index].cards.isEmpty {
                Analytics.capture("onboarding_create_cards_completed", properties: [
                    "source": selectedSource.rawValue,
                    "card_count": deckStore.decks[index].cards.count
                ])
                onboardingViewModel.nextStep()
            }
        }) {
            AutoGenerateFlashcardsSheet(
                deck: onboardingDeckBinding,
                initialSource: selectedSource
            )
            .environmentObject(deckStore)
            .sgSheetChrome()
        }
    }

    private func ensureDeckExists() {
        if deckStore.decks.isEmpty {
            let newDeck = Deck(name: onboardingViewModel.newDeckName)
            deckStore.addDeck(newDeck)
            onboardingDeckIndex = 0
        } else {
            onboardingDeckIndex = 0
        }

        if let index = onboardingDeckIndex, index < deckStore.decks.count {
            deckStore.selectDeck(deckStore.decks[index])
        }
    }
}

// MARK: - Source Option Card

struct SourceOptionCard: View {
    var icon: String? = nil
    var imageName: String? = nil
    let title: String
    let subtitle: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    if let imageName = imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    } else if let icon = icon {
                        Image(systemName: icon)
                            .font(SGTheme.display(20, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)

                    Text(subtitle)
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(SGTheme.rowLabel)
                    .foregroundColor(SGTheme.paperTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .strokeBorder(SGTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(SGPressStyle())
    }
}

#Preview {
    CreateFirstCardsOnboardingView()
        .environmentObject(OnboardingViewModel())
}
