import SwiftUI

struct OnboardingChecklistCard: View {
    @EnvironmentObject var deckStore: DeckStore
    @ObservedObject private var guardManager = StudyGuardManager.shared

    var onSetupGuard: () -> Void
    var onCreateDeck: () -> Void
    var onGenerateCards: () -> Void

    private var guardSetUp: Bool { guardManager.isSetupComplete }
    private var deckCreated: Bool { !deckStore.decks.isEmpty }
    private var cardsGenerated: Bool { deckStore.decks.contains { !$0.cards.isEmpty } }

    private var completedCount: Int {
        [guardSetUp, deckCreated, cardsGenerated].filter { $0 }.count
    }

    var allCompleted: Bool {
        guardSetUp && deckCreated && cardsGenerated
    }

    var body: some View {
        SGCard(shadowed: false, dashed: SGTheme.mint) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    Image("sticker-rocket")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)

                    Text("Get Started")
                        .font(SGTheme.display(18))
                        .foregroundColor(SGTheme.paper)

                    Spacer()

                    Text("\(completedCount) of 3")
                        .font(SGTheme.caption.weight(.semibold))
                        .foregroundColor(SGTheme.paperSecondary)
                }

                // Steps
                VStack(spacing: 12) {
                    ChecklistStepRow(
                        stepNumber: 1,
                        title: "Choose apps to guard",
                        subtitle: "Pick the apps Study Guard locks when your scroll time runs out",
                        isCompleted: guardSetUp,
                        action: guardSetUp ? nil : onSetupGuard
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
                SGProgressBar(progress: Double(completedCount) / 3.0, thin: true)
            }
        }
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
                            .fill(SGTheme.mint)
                            .frame(width: 28, height: 28)

                        Image(systemName: "checkmark")
                            .font(SGTheme.micro.weight(.bold))
                            .foregroundColor(SGTheme.ink)
                    } else {
                        Circle()
                            .stroke(SGTheme.glaze(0.2), lineWidth: 1.5)
                            .frame(width: 28, height: 28)

                        Text("\(stepNumber)")
                            .font(SGTheme.caption.weight(.semibold))
                            .foregroundColor(SGTheme.paperTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SGTheme.body.weight(.semibold))
                        .foregroundColor(isCompleted ? SGTheme.paperTertiary : SGTheme.paper)
                        .strikethrough(isCompleted, color: SGTheme.paperTertiary)

                    Text(subtitle)
                        .font(SGTheme.micro.weight(.regular))
                        .foregroundColor(SGTheme.paperSecondary)
                }

                Spacer()

                if !isCompleted && action != nil {
                    Image(systemName: "chevron.right")
                        .font(SGTheme.micro)
                        .foregroundColor(SGTheme.paperTertiary)
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
        onSetupGuard: {},
        onCreateDeck: {},
        onGenerateCards: {}
    )
    .environmentObject(DeckStore.shared)
    .padding()
    .background(SGTheme.ink)
}
