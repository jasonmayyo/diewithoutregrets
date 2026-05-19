import SwiftUI

struct CreateFirstCardsOnboardingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @StateObject private var deckStore = DeckStore.shared

    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showOptions = false
    @State private var showSkip = false

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
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Text("Create your first\nflash cards")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)

                    Text("Choose how you'd like to add study material.")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .padding(.top, 8)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.4), value: showSubtitle)

                    Spacer()

                    VStack(spacing: 14) {
                        SourceOptionCard(
                            icon: "text.alignleft",
                            title: "Paste Text",
                            subtitle: "Paste notes, articles, or any text",
                            accentColor: Color(hex: 0x184449)
                        ) {
                            selectedSource = .text
                            Analytics.capture("onboarding_create_cards_source_tapped", properties: ["source": "text"])
                            showGenerateSheet = true
                        }

                        SourceOptionCard(
                            imageName: "youtube-icon",
                            title: "YouTube Video",
                            subtitle: "Paste a YouTube link to generate cards",
                            accentColor: Color(hex: 0x3FA4AE)
                        ) {
                            selectedSource = .youtube
                            Analytics.capture("onboarding_create_cards_source_tapped", properties: ["source": "youtube"])
                            showGenerateSheet = true
                        }

                        SourceOptionCard(
                            imageName: "quizlet",
                            title: "Import from Quizlet",
                            subtitle: "Import your existing Quizlet sets",
                            accentColor: Color(hex: 0x2BC391)
                        ) {
                            selectedSource = .quizlet
                            Analytics.capture("onboarding_create_cards_source_tapped", properties: ["source": "quizlet"])
                            showGenerateSheet = true
                        }
                    }
                    .opacity(showOptions ? 1 : 0)
                    .offset(y: showOptions ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: showOptions)

                    Spacer()

                    Button(action: {
                        Analytics.capture("onboarding_create_cards_skipped")
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Skip for now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .opacity(showSkip ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.9), value: showSkip)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showOptions = true
            showSkip = true
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
            .presentationCornerRadius(30)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.1))
                        .frame(width: 52, height: 52)

                    if let imageName = imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                    } else if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449))

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.25))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: 0xF5F7FA))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: 0x184449).opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateFirstCardsOnboardingView()
        .environmentObject(OnboardingViewModel())
}
