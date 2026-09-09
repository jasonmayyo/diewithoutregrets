//
//  SGPreviewHarness.swift
//  diewithoutregrets
//
//  DEBUG-only: seeds app state from launch arguments so every visual state
//  can be screenshot-reviewed in the Simulator (where Screen Time doesn't
//  run). Usage:
//    simctl launch <sim> <bundle> -hasCompletedOnboarding YES -sg-preview-locked
//  Arguments: -sg-preview-metering | -sg-preview-locked | -sg-preview-quiz
//

#if DEBUG
import Foundation

@MainActor
enum SGPreviewHarness {

    enum Scenario {
        case metering
        case locked
    }

    /// Blocking-flow redesign review hook — the app root presents the new
    /// quiz directly (with a seeded locked state + deck) when any
    /// -sg-preview-quizv2* argument is present. The suffixed variants
    /// auto-drive the machine so every state can be screenshot unattended
    /// (see QuizV2View.driveForScreenshotsIfRequested).
    static var wantsQuizV2Preview: Bool {
        ProcessInfo.processInfo.arguments
            .contains { $0.hasPrefix("-sg-preview-quizv2") }
    }

    static func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains(where: { $0.hasPrefix("-sg-preview") }) else { return }

        if args.contains("-sg-preview-metering") {
            seed(.metering)
        }
        if args.contains("-sg-preview-locked") {
            seed(.locked)
        }
        if args.contains("-sg-preview-quiz") {
            seed(.locked)
            NavigationModel.shared.navigate(to: .regretView)
        }
        if wantsQuizV2Preview {
            seed(.locked)
        }
    }

    /// Seed a scenario directly — Xcode #Previews can't pass launch
    /// arguments, so they call this instead.
    static func seed(_ scenario: Scenario) {
        guard let d = SGContract.sharedDefaults else { return }

        seedDeckIfNeeded()

        switch scenario {
        case .metering:
            seedGuardState(d, state: SGContract.StateValue.metering, usedSeconds: 480)
        case .locked:
            seedGuardState(d, state: SGContract.StateValue.locked, usedSeconds: 900)
            d.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.lockedAt)
        }

        // Keep reconcile/refresh from reverting seeded state (no real
        // Screen Time authorization exists in the Simulator).
        StudyGuardManager.shared.previewFrozen = true
        StudyGuardManager.shared.refresh()
    }

    private static func seedGuardState(_ d: UserDefaults, state: String, usedSeconds: Double) {
        d.set(true, forKey: SGContract.Keys.setupComplete)
        d.set(true, forKey: SGContract.Keys.guardEnabled)
        d.set(15, forKey: SGContract.Keys.intervalMinutes)
        d.set(15, forKey: SGContract.Keys.armedThresholdMinutes)
        d.set(state, forKey: SGContract.Keys.state)
        d.set(Date().timeIntervalSince1970 - 600, forKey: SGContract.Keys.budgetGrantedAt)
        d.set(900.0, forKey: SGContract.Keys.budgetTotalSeconds)
        d.set(usedSeconds, forKey: SGContract.Keys.budgetUsedSeconds)
        d.set(false, forKey: SGContract.Keys.needsReauth)
    }

    private static func seedDeckIfNeeded() {
        guard DeckStore.shared.decks.isEmpty else { return }
        let deck = Deck(name: "Biology 101", cards: [
            Regret(regretPrompt: "What organelle is known as the powerhouse of the cell?",
                   regret: "Mitochondria",
                   choices: ["Mitochondria", "Ribosome", "Nucleus", "Golgi apparatus"],
                   correctAnswerIndex: 0,
                   backgroundExplanation: "Mitochondria generate most of the cell's ATP, its chemical energy currency."),
            Regret(regretPrompt: "What is the process plants use to convert light into energy?",
                   regret: "Photosynthesis",
                   choices: ["Respiration", "Photosynthesis", "Fermentation", "Osmosis"],
                   correctAnswerIndex: 1,
                   backgroundExplanation: "Photosynthesis converts light, water and CO₂ into glucose and oxygen."),
            Regret(regretPrompt: "Which molecule carries genetic information?",
                   regret: "DNA",
                   choices: ["RNA", "Protein", "DNA", "Lipid"],
                   correctAnswerIndex: 2,
                   backgroundExplanation: "DNA stores the genetic instructions for development and function."),
            Regret(regretPrompt: "What is the basic structural unit of all living organisms?",
                   regret: "The cell",
                   choices: ["The cell"],
                   correctAnswerIndex: 0,
                   backgroundExplanation: "Cell theory holds that all living things are composed of cells, the smallest unit of life.",
                   answerMode: .typed),
        ])
        DeckStore.shared.addDeck(deck)
        DeckStore.shared.selectDeck(deck)
    }
}
#endif
