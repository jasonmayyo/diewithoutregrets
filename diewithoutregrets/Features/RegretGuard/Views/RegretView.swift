//
//  RegretView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretView: View {
    @EnvironmentObject var deckStore: DeckStore
    @StateObject private var viewModel = RegretViewModel()
    @State private var currentStep: Int = 0
    @State private var showFinalMessage = false
    @State private var selectedAnswer: Int?
    @State private var showLockAnimation = true
    @State private var hasIncorrectAnswers = false
    @State private var questionResults: [Bool?] = []
    @State private var selectedRegrets: [Regret] = []
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @AppStorage("selectedAnimationType") private var selectedAnimationType: String = AnimationType.lockAnimation.rawValue
    @AppStorage("flashcardBreakDuration") private var flashcardBreakDuration: Int = 5

    /// Wall-clock start of the current attempt — used to measure how long
    /// users spend in the unlock flow before completing or rage-quitting.
    @State private var attemptStartTime: Date = Date()
    /// How many attempts (including retries) for this app open.
    @State private var attemptNumber: Int = 1
    /// Tracks which questions we've already emitted an "answered" event for
    /// so we don't double-count if the view re-renders.
    @State private var answeredQuestionIndices: Set<Int> = []

    let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")

    @ObservedObject private var studyGuard = StudyGuardManager.shared
    /// v2 = Screen Time engine live; legacy = Shortcuts flow (pre-migration).
    private var isV2: Bool { studyGuard.isSetupComplete }

    /// v2 invariant: a locked user must always have a legitimate unlock path.
    /// When the selected deck is missing/empty, this state routes into card
    /// creation instead of the success screen (which would be a free unlock).
    @State private var showDeckRescue = false
    /// v2: entered via a stale notification while already unlocked.
    @State private var alreadyUnlocked = false
    @State private var showNewCardSheet = false
    @State private var showEmergencySheet = false

    private var currentAppName: String {
        isV2 ? "your apps" : (sharedDefaults?.string(forKey: "LastGuardedApp") ?? "unknown")
    }
    
    var body: some View {
        ZStack {
            // Endings own the whole canvas — no quiz header above them.
            if showFinalMessage && !showDeckRescue && !alreadyUnlocked {
                if hasIncorrectAnswers {
                    QuizFailureView(
                        correctCount: questionResults.compactMap { $0 }.filter { $0 }.count,
                        totalCount: selectedRegrets.count,
                        emergencyUnlocksRemaining: isV2 ? studyGuard.emergencyUnlocksRemaining : nil,
                        giveUpTitle: isV2 ? "Give up for now" : "Close \(currentAppName)",
                        onRetry: retryQuestions,
                        onEmergency: { showEmergencySheet = true },
                        onGiveUp: {
                            if isV2 {
                                NavigationModel.shared.returnHome()
                            } else {
                                navigateToReport()
                            }
                        }
                    )
                } else {
                    // The time-unlocked celebration: circle-mask reveal,
                    // count-up with ticking haptics, ring draw, confetti.
                    UnlockCelebrationView(
                        minutes: isV2 ? studyGuard.intervalMinutes : flashcardBreakDuration,
                        ctaTitle: isV2
                            ? "Start my \(studyGuard.intervalMinutes) minutes"
                            : "Unlock \(currentAppName)",
                        onStart: handleUnlock
                    )
                }
            } else {
            VStack {
                // Lock Icon and Progress Bar
                VStack {
                    MascotView(pose: .lookingDown, loops: 2)
                        .frame(width: 72, height: 72)
                        .padding(.top, 2)
                    
                    QuizProgressBar(results: questionResults, currentIndex: currentStep / 2)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                }
                
                // Main Content
                Group {
                    if showDeckRescue || alreadyUnlocked {
                        rescueView
                    } else if !showFinalMessage {
                        VStack(spacing: 0) {
                            // Guard against index out of range
                            if !selectedRegrets.isEmpty && currentStep/2 < selectedRegrets.count {
                                let currentRegret = selectedRegrets[currentStep/2]
                                
                                // Question
                                Text(currentRegret.regretPrompt)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .foregroundColor(SGTheme.paper)
                                    .font(currentStep % 2 == 1
                                          ? .system(size: 17, weight: .semibold, design: .rounded)
                                          : .system(size: 21, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 30)
                                    .padding(.top, currentStep % 2 == 1 ? 20 : 70)
                                    .padding(.bottom, currentStep % 2 == 1 ? 5 : 15)
                                    .scaleEffect(currentStep % 2 == 1 ? 0.95 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: currentStep)
                                
                                // Explanation View
                                if currentStep % 2 == 1 {
                                    ScrollView {
                                        Text(currentRegret.backgroundExplanation)
                                            .font(.subheadline)
                                            .foregroundColor(SGTheme.paperSecondary)
                                            .padding(.horizontal, 30)
                                            .padding(.top, 5)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                    .frame(maxHeight: 150)
                                    .padding(.bottom, 10)
                                }
                                Spacer()
                                
                                // Answer Options
                                if currentStep % 2 == 0 {
                                    ScrollView {
                                        VStack(spacing: 14) {
                                            ForEach(Array(currentRegret.choices.enumerated()), id: \.offset) { index, choice in
                                                QuizAnswerTile(
                                                    text: choice,
                                                    state: selectedAnswer == index ? .selected : .idle
                                                ) {
                                                    QuizHaptics.selectTick()
                                                    selectedAnswer = index
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                    }
                                    .frame(maxHeight: 300) // Limit height to prevent overflow
                                } else {
                                    // Answer Reveal: the correct tile sweeps
                                    // mint, the miss shakes, the rest dim.
                                    ScrollView {
                                        VStack(spacing: 14) {
                                            ForEach(Array(currentRegret.choices.enumerated()), id: \.offset) { index, choice in
                                                QuizAnswerTile(
                                                    text: choice,
                                                    state: revealState(for: index, in: currentRegret)
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                    }
                                    .frame(maxHeight: 300) // Limit height to prevent overflow
                                }
                            } else {
                                // Fallback if no regrets or index out of range
                                Text("No questions available")
                                    .foregroundColor(SGTheme.paperSecondary)
                                    .padding()
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                
                // Bottom Control
                if !showFinalMessage && !showDeckRescue && !alreadyUnlocked {
                    SGPrimaryButton(
                        title: controlButtonText,
                        tint: canAdvance ? SGTheme.mint : SGTheme.inkHigh,
                        labelColor: canAdvance ? .white : SGTheme.paperTertiary,
                        action: handleTap
                    )
                    .disabled(!canAdvance)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 12)
                    .animation(SGTheme.springFast, value: canAdvance)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            }

            if showLockAnimation {
                if selectedAnimationType == AnimationType.memeVideo.rawValue {
                    MemeVideoView()
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    MascotLockOverlay()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }

        }
        .background(SGAuroraBackground(intensity: 0.6).ignoresSafeArea())
        .sheet(isPresented: $showNewCardSheet, onDismiss: {
            // Card added? Reload the quiz with it.
            if let deck = deckStore.selectedDeck, !deck.cards.isEmpty {
                showDeckRescue = false
                setupView()
            }
        }) {
            if let binding = rescueDeckBinding {
                NewFlashcardSheet(deck: binding)
                    .sgSheetChrome()
            }
        }
        .sheet(isPresented: $showEmergencySheet) {
            EmergencyUnlockSheet {
                NavigationModel.shared.returnHome()
            }
        }
        .onAppear {
            setupView()
            withAnimation(.easeInOut(duration: 0.3)) {
                showLockAnimation = true
            }
            // Different timing for meme video vs lock animation
            let dismissDelay = selectedAnimationType == AnimationType.memeVideo.rawValue ? 5.0 : 1.5
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLockAnimation = false
                }
            }
        }
    }
    
    // MARK: - v2 rescue states

    /// Binding into the selected deck for the rescue card-creation sheet.
    private var rescueDeckBinding: Binding<Deck>? {
        guard let deck = deckStore.selectedDeck else { return nil }
        return Binding(
            get: { deckStore.selectedDeck ?? deck },
            set: { updated in
                deckStore.updateDeck(updated)
            }
        )
    }

    @ViewBuilder
    private var rescueView: some View {
        VStack(spacing: 16) {
            Spacer()

            if alreadyUnlocked {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 44))
                    .foregroundColor(SGTheme.mint)
                Text("You're already unlocked")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(SGTheme.paper)
                Text("You've got about \(max(0, studyGuard.totalMinutes - studyGuard.usedMinutes)) minutes left before your apps lock again.")
                    .font(.subheadline)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            } else {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 44))
                    .foregroundColor(SGTheme.paper)
                Text("Your deck is empty")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(SGTheme.paper)
                Text("Add a flashcard and answer it to unlock your apps.")
                    .font(.subheadline)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()

            VStack(spacing: 12) {
                if alreadyUnlocked {
                    Button {
                        NavigationModel.shared.returnHome()
                    } label: {
                        Text("Done")
                            .foregroundColor(SGTheme.paper)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(SGTheme.inkHigh)
                            .cornerRadius(50)
                    }
                } else {
                    Button {
                        ensureDeckExists()
                        showNewCardSheet = true
                    } label: {
                        Text("Add a flashcard")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(SGTheme.mint)
                            .cornerRadius(50)
                    }

                    Button {
                        NavigationModel.shared.unlockMethodOverride = "trueFocus"
                    } label: {
                        Text("Do a focus session instead")
                            .foregroundColor(SGTheme.paper)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(SGTheme.glaze(0.08))
                            .cornerRadius(50)
                    }

                    Button {
                        showEmergencySheet = true
                    } label: {
                        Text("Emergency unlock (\(studyGuard.emergencyUnlocksRemaining) left this week)")
                            .foregroundColor(SGTheme.paperSecondary)
                            .font(.subheadline)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
    }

    /// Rescue path may fire with no deck at all — create and select one so
    /// NewFlashcardSheet has somewhere to save.
    private func ensureDeckExists() {
        if deckStore.selectedDeck == nil {
            let deck = Deck(name: "My First Deck")
            deckStore.addDeck(deck)
            deckStore.selectDeck(deck)
        }
    }

    /// Reveal-step tile states: the correct tile sweeps mint, the user's
    /// miss shakes, everything else dims.
    private func revealState(for index: Int, in regret: Regret) -> QuizTileState {
        if index == regret.correctAnswerIndex { return .revealedCorrect }
        if index == selectedAnswer { return .revealedWrong }
        return .dimmed
    }

    private var canAdvance: Bool {
        currentStep % 2 == 1 || selectedAnswer != nil
    }

    private var controlButtonText: String {
        if currentStep % 2 == 0 {
            return selectedAnswer == nil ? "Select an answer" : "Check answer"
        }
        return "Next question"
    }
    
    private func handleTap() {
        guard !selectedRegrets.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            // Guard against index out of range
            guard !selectedRegrets.isEmpty && currentStep < selectedRegrets.count * 2 else {
                showFinalMessage = true
                return
            }
            
            if currentStep % 2 == 0 {
                guard selectedAnswer != nil else { return }
            }
            
            let previousStep = currentStep
            currentStep += 1
            
            // Update progress bar when answering
            if currentStep % 2 == 1 {
                let questionIndex = (currentStep - 1) / 2
                guard questionIndex < selectedRegrets.count else { return }
                
                let currentRegret = selectedRegrets[questionIndex]
                let isCorrect = selectedAnswer == currentRegret.correctAnswerIndex
                
                // Ensure questionResults has enough elements
                while questionResults.count <= questionIndex {
                    questionResults.append(nil)
                }
                
                questionResults[questionIndex] = isCorrect

                // The moment of truth gets its own haptic composition.
                if isCorrect {
                    QuizHaptics.correctBurst()
                } else {
                    QuizHaptics.wrongBuzz()
                    hasIncorrectAnswers = true
                }

                if !answeredQuestionIndices.contains(questionIndex) {
                    answeredQuestionIndices.insert(questionIndex)
                    Analytics.unlockQuestionAnswered(
                        appName: currentAppName,
                        questionIndex: questionIndex,
                        totalQuestions: selectedRegrets.count,
                        isCorrect: isCorrect
                    )
                }
            }
            
            if currentStep % 2 == 0 {
                selectedAnswer = nil
            }
            
            if currentStep >= selectedRegrets.count * 2 {
                showFinalMessage = true
            }
        }
    }
    
    private func setupView() {
        // Add debug prints
        print("RegretView setup started")
        defer { print("RegretView setup completed") }

        // v2: entered while already unlocked (stale notification / deeplink) —
        // nothing to unlock, don't run a pointless quiz.
        if isV2, studyGuard.state != .locked {
            alreadyUnlocked = true
            showDeckRescue = false
            return
        }
        alreadyUnlocked = false

        // Validate deck selection
        guard let deck = deckStore.selectedDeck else {
            print("🚨 Critical error: No deck selected in RegretView")
            // Track the broken state too — if this fires often it's a real bug.
            Analytics.capture("unlock_attempted_no_deck", properties: [
                "app_name": currentAppName
            ])
            if isV2 {
                // Free-unlock guard: the success screen would hand out a grant
                // with zero questions answered. Route into card creation instead.
                showDeckRescue = true
            } else {
                showFinalMessage = true
            }
            return
        }

        print("Processing deck: \(deck.name)")
        print("Deck contains \(deck.cards.count) cards")

        guard !deck.cards.isEmpty else {
            print("⚠️ Empty deck selected")
            Analytics.capture("unlock_attempted_empty_deck", properties: [
                "app_name": currentAppName,
                "deck_name": deck.name
            ])
            if isV2 {
                showDeckRescue = true
            } else {
                showFinalMessage = true
            }
            return
        }
        showDeckRescue = false

        Analytics.unlockAttempted(
            appName: currentAppName,
            unlockMethod: "flashcards",
            flashcardCount: flashcardCount,
            useAllCards: useAllCards,
            animationType: selectedAnimationType,
            deckId: deck.id.uuidString,
            deckName: deck.name,
            availableCards: deck.cards.count
        )
        Telemetry.breadcrumb("Unlock attempted", category: "core_product",
                             data: ["app_name": currentAppName,
                                    "deck_name": deck.name,
                                    "available_cards": deck.cards.count])
        attemptStartTime = Date()
        attemptNumber = 1

        DispatchQueue.main.async {
               self.selectedRegrets = useAllCards || flashcardCount >= deck.cards.count
                   ? deck.cards.shuffled()
                   : Array(deck.cards.shuffled().prefix(flashcardCount))
               self.resetView()
           }
    }
    
    private func resetView() {
            currentStep = 0
            showFinalMessage = false
            selectedAnswer = nil
            hasIncorrectAnswers = false
            questionResults = Array(repeating: nil, count: selectedRegrets.count)
            answeredQuestionIndices = []
            viewModel.reset() // Use viewModel's reset instead
        }
    
    private func retryQuestions() {
        guard let deck = deckStore.selectedDeck else { return }

        let correctSoFar = questionResults.compactMap { $0 }.filter { $0 }.count
        Analytics.unlockRetried(
            appName: currentAppName,
            correctCount: correctSoFar,
            totalQuestions: selectedRegrets.count,
            attemptNumber: attemptNumber
        )
        attemptNumber += 1

        // If useAllCards is true or if user selected more cards than available, use all cards
        if useAllCards || flashcardCount >= deck.cards.count {
            selectedRegrets = deck.cards.shuffled()
        } else {
            selectedRegrets = Array(deck.cards.shuffled().prefix(flashcardCount))
        }
        resetView()
    }
    
    private func handleUnlock() {
        let correctCount = questionResults.compactMap { $0 }.filter { $0 }.count

        if isV2 {
            // Invariant: a grant requires at least one correctly answered
            // question — the empty-deck path can never reach here.
            guard correctCount > 0, !hasIncorrectAnswers else { return }
            // Grant synchronously the moment the unlock is earned — never
            // inside the animation delay (a background/kill mid-animation
            // would eat the earned unlock).
            StudyGuardManager.shared.grantFreshBudget(reason: .quiz)
        }

        Analytics.unlockCompleted(
            appName: currentAppName,
            correctCount: correctCount,
            totalQuestions: selectedRegrets.count,
            hadRetries: attemptNumber > 1,
            durationSec: Date().timeIntervalSince(attemptStartTime),
            breakDurationMinutes: isV2 ? studyGuard.intervalMinutes : flashcardBreakDuration
        )

        // The celebration screen WAS the unlock moment — go straight home,
        // where the countdown rolls the new minutes in.
        if isV2 {
            NavigationModel.shared.returnHome()
        } else {
            // Legacy Shortcuts flow — unchanged until the user migrates.
            let currentTime = Date().timeIntervalSince1970
            sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
            sharedDefaults?.set(true, forKey: "UserAllowedBreak")
            sharedDefaults?.set(flashcardBreakDuration, forKey: "BreakDurationMinutes")
            sharedDefaults?.synchronize()

            if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                UIApplication.shared.open(getAppURL(for: appName), options: [:])
            }
            NavigationModel.shared.returnHome()
        }
    }
    
    /// Legacy-only escape hatch ("Close Anyway"). v2 uses the emergency
    /// unlock ledger instead.
    private func navigateToReport() {
        Analytics.unlockCloseAnyway(
            appName: currentAppName,
            currentStep: currentStep,
            totalSteps: selectedRegrets.count * 2,
            hadIncorrectAnswers: hasIncorrectAnswers,
            durationSec: Date().timeIntervalSince(attemptStartTime)
        )
        NavigationModel.shared.returnHome()
    }
    
    private func getAppURL(for appName: String) -> URL {
        let scheme = getUrlScheme(for: appName)
        return URL(string: scheme) ?? URL(string: "instagram://") ?? URL(string: "https://instagram.com") ?? URL(fileURLWithPath: "/")
    }
    
    private func getUrlScheme(for appName: String) -> String {
        switch appName.lowercased() {
        case "instagram": return "instagram://"
        case "youtube": return "youtube://"
        case "tiktok": return "tiktok://"
        case "threads": return "threads://"
        case "snapchat": return "snapchat://"
        case "netflix": return "netflix://"
        case "facebook": return "facebook://"
        case "bereal": return "bereal://"
        case "reddit": return "reddit://"
        case "x": return "x://"
        case "safari": return "https://google.com"
        case "clash royale": return "clashroyale://"
        default: return "instagram://"
        }
    }
}



#Preview {
    let deckStore = DeckStore.shared
    let sampleDeck = Deck(
        name: "Sample Deck",
        cards: [
            Regret(
                regretPrompt: "Sample Question",
                regret: "Correct Answer",
                choices: ["Correct Answer", "Wrong 1", "Wrong 2", "Wrong 3"],
                correctAnswerIndex: 0,
                backgroundExplanation: "Sample explanation"
            )
        ]
    )
    deckStore.selectedDeck = sampleDeck
    
    return RegretView()
        .environmentObject(deckStore)
}
