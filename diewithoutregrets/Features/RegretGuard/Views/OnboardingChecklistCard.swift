import SwiftUI

struct OnboardingChecklistCard: View {
    @EnvironmentObject var deckStore: DeckStore
    @AppStorage("hasSetUpShortcut") private var hasSetUpShortcut = false

    var onSetupShortcut: () -> Void
    var onCreateDeck: () -> Void
    var onGenerateCards: () -> Void

    private var shortcutCompleted: Bool { hasSetUpShortcut }
    private var deckCreated: Bool { !deckStore.decks.isEmpty }
    private var cardsGenerated: Bool { deckStore.decks.contains { !$0.cards.isEmpty } }

    private var completedCount: Int {
        [shortcutCompleted, deckCreated, cardsGenerated].filter { $0 }.count
    }

    var allCompleted: Bool {
        shortcutCompleted && deckCreated && cardsGenerated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449))

                Text("Get Started")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: 0x184449))

                Spacer()

                Text("\(completedCount) of 3")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.45))
            }

            // Steps
            VStack(spacing: 12) {
                ChecklistStepRow(
                    stepNumber: 1,
                    title: "Set up a shortcut",
                    subtitle: "Block distracting apps with automations",
                    isCompleted: shortcutCompleted,
                    action: shortcutCompleted ? nil : onSetupShortcut
                )

                ChecklistStepRow(
                    stepNumber: 2,
                    title: "Create a deck",
                    subtitle: "Organize your flash cards by topic",
                    isCompleted: deckCreated,
                    action: deckCreated ? nil : onCreateDeck
                )

                ChecklistStepRow(
                    stepNumber: 3,
                    title: "Generate flash cards",
                    subtitle: "Add cards from text, YouTube, or Quizlet",
                    isCompleted: cardsGenerated,
                    action: cardsGenerated ? nil : onGenerateCards
                )
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: 0x184449).opacity(0.08))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: 0x2BC391))
                        .frame(width: geo.size.width * CGFloat(completedCount) / 3.0, height: 5)
                        .animation(.easeInOut(duration: 0.4), value: completedCount)
                }
            }
            .frame(height: 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                .foregroundColor(Color(hex: 0x184449).opacity(0.2))
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Checklist Step Row

struct ChecklistStepRow: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 14) {
                // Completion indicator
                ZStack {
                    if isCompleted {
                        Circle()
                            .fill(Color(hex: 0x2BC391))
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color(hex: 0x184449).opacity(0.2), lineWidth: 1.5)
                            .frame(width: 28, height: 28)

                        Text("\(stepNumber)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCompleted ? Color(hex: 0x184449).opacity(0.45) : Color(hex: 0x184449))
                        .strikethrough(isCompleted, color: Color(hex: 0x184449).opacity(0.3))

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                }

                Spacer()

                if !isCompleted && action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.2))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

#Preview {
    OnboardingChecklistCard(
        onSetupShortcut: {},
        onCreateDeck: {},
        onGenerateCards: {}
    )
    .environmentObject(DeckStore.shared)
    .padding()
    .background(Color(hex: 0xF8F9FA))
}
