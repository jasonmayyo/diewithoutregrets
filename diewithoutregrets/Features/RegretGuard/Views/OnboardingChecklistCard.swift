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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SGTheme.mint)

                Text("Get Started")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(SGTheme.paper)

                Spacer()

                Text("\(completedCount) of 3")
                    .font(.system(size: 13, weight: .semibold))
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SGTheme.glaze(0.1))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(SGTheme.mint)
                        .frame(width: geo.size.width * CGFloat(completedCount) / 3.0, height: 5)
                        .animation(.easeInOut(duration: 0.4), value: completedCount)
                }
            }
            .frame(height: 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 5]))
                .foregroundColor(SGTheme.mint.opacity(0.25))
        )
        
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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(SGTheme.ink)
                    } else {
                        Circle()
                            .stroke(SGTheme.glaze(0.2), lineWidth: 1.5)
                            .frame(width: 28, height: 28)

                        Text("\(stepNumber)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SGTheme.paperTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isCompleted ? SGTheme.paperTertiary : SGTheme.paper)
                        .strikethrough(isCompleted, color: SGTheme.paperTertiary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(SGTheme.paperSecondary)
                }

                Spacer()

                if !isCompleted && action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
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
