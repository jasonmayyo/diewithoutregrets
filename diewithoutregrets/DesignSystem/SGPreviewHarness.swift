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

    /// Tutor Monster (Phase 1) review hook: the app root presents the monster
    /// chat over a seeded locked state + deck for any -sg-preview-monster*
    /// argument. Suffixes tune it: -diva/-coach/-gremlin pick the persona,
    /// -feral forces a high-pressure mood.
    static var wantsMonsterPreview: Bool {
        ProcessInfo.processInfo.arguments
            .contains { $0.hasPrefix("-sg-preview-monster") }
    }

    static func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains(where: { $0.hasPrefix("-sg-preview") }) else { return }
        #if targetEnvironment(simulator)
        if args.contains("-sg-preview-sheet-deck") { seedSheetReviewDeck() }
        #endif

        if args.contains("-sg-preview-metering") {
            seed(.metering)
        }
        #if targetEnvironment(simulator)
        // Review the checkpoint race: the readout is zero before a lock arrives.
        if args.contains("-sg-preview-metering-zero") {
            seed(.metering)
            SGContract.sharedDefaults?.set(900.0, forKey: SGContract.Keys.budgetUsedSeconds)
            StudyGuardManager.shared.refresh()
        }
        #endif
        if args.contains("-sg-preview-locked") {
            seed(.locked)
        }
        if args.contains("-sg-preview-locked-yesterday") {
            seed(.locked)
            SGContract.sharedDefaults?.set(Date().timeIntervalSince1970 - 86_400,
                                          forKey: SGContract.Keys.budgetGrantedAt)
            StudyGuardManager.shared.refresh()
        }
        if args.contains("-sg-preview-shield-chat") {
            seed(.locked)
            SGContract.sharedDefaults?.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.shieldTapAt)
        }
        if args.contains("-sg-preview-quiz") {
            seed(.locked)
            NavigationModel.shared.navigate(to: .regretView)
        }
        if wantsQuizV2Preview {
            seed(.locked)
        }
        if wantsMonsterPreview {
            seed(.locked)
            applyMonsterPreviewTuning(args)
        }
        if args.contains("-sg-preview-return-instagram") {
            NavigationModel.shared.unlockReturnDestination = .app(bundleIdentifier: "com.burbn.instagram")
        }
        if args.contains("-sg-preview-return-category-instagram") {
            // Exercise the category-shield handoff, not a hard-coded view destination.
            let category = Data("preview-social-category".utf8)
            ShieldReturnContext.remember(tokenData: nil, bundleIdentifier: "com.burbn.instagram",
                                         categoryTokenData: category, in: SGContract.sharedDefaults)
            ShieldReturnContext.prepareCategoryReturn(for: category, in: SGContract.sharedDefaults)
            NavigationModel.shared.unlockReturnDestination = ShieldReturnContext.consumePending(in: SGContract.sharedDefaults)
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

    #if targetEnvironment(simulator)
    /// An explicitly requested review deck; never replaces any saved material.
    private static func seedSheetReviewDeck() {
        let name = "Biology · Sheet review"
        if let existing = DeckStore.shared.decks.first(where: { $0.name == name }) {
            DeckStore.shared.selectDeck(existing)
            return
        }
        let rows: [(String, [String], String)] = [
            ("Which organelle produces most of a cell's ATP?", ["Mitochondria", "Nucleus", "Ribosome", "Golgi apparatus"], "Mitochondria release energy from nutrients to produce ATP."),
            ("Which process converts light into chemical energy?", ["Photosynthesis", "Osmosis", "Fermentation", "Respiration"], "Photosynthesis stores light energy in glucose."),
            ("Which molecule stores genetic instructions?", ["DNA", "Protein", "Lipid", "Glucose"], "DNA carries the genetic instructions for cells."),
            ("What is the basic structural unit of living organisms?", ["The cell", "An organ", "A tissue", "A molecule"], "Cells are the smallest units of life."),
            ("Which structure controls what enters and leaves a cell?", ["Cell membrane", "Cell wall", "Ribosome", "Nucleolus"], "The cell membrane is selectively permeable."),
            ("Where are proteins assembled in a cell?", ["Ribosomes", "Lysosomes", "Vacuoles", "Chloroplasts"], "Ribosomes join amino acids to build proteins."),
            ("Which gas do plants release during photosynthesis?", ["Oxygen", "Nitrogen", "Carbon dioxide", "Hydrogen"], "Splitting water during photosynthesis releases oxygen.")
        ]
        let deck = Deck(name: name, cards: rows.map { row in
            Regret(regretPrompt: row.0, regret: row.1[0], choices: row.1,
                   correctAnswerIndex: 0, backgroundExplanation: row.2, topic: "Cell biology")
        })
        DeckStore.shared.addDeck(deck)
        DeckStore.shared.selectDeck(deck)
    }
    #endif

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

    private static func applyMonsterPreviewTuning(_ args: [String]) {
        if args.contains("-sg-preview-monster-diva") { PersonaStore.shared.select(.diva) }
        else if args.contains("-sg-preview-monster-coach") { PersonaStore.shared.select(.coach) }
        else if args.contains("-sg-preview-monster-gremlin") { PersonaStore.shared.select(.gremlin) }
        else { PersonaStore.shared.select(.willow) }

        if args.contains("-sg-preview-monster-feral"), let d = SGContract.sharedDefaults {
            // Hammer the gate counter + an imminent exam → feral mood for review.
            d.set(42, forKey: SGContract.gateEncounterKey(day: SGContract.dayStamp()))
            ExamStore.shared.exams = [StudyExam(subject: "Anatomy",
                                                date: Date().addingTimeInterval(2 * 86_400))]
        }
    }
}
#endif
