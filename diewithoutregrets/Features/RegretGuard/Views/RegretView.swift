//
//  RegretView.swift
//  diewithoutregrets
//
//  The unlock quiz — the toll booth between a locked phone and earned
//  minutes. Redesigned around zero dead time:
//
//  - One tap arms a tile, a second tap on it commits (the bottom Check
//    button is the always-present fallback and the VoiceOver path).
//  - Correct answers auto-advance after a short dwell; the praise capsule
//    pauses the advance and opens the explanation for anyone who wants it.
//  - A wrong answer offers "Retry from the top" immediately — no doomed
//    march through cards that can no longer unlock anything.
//  - The grant fires synchronously at the final correct commit, never
//    inside celebration choreography, so backgrounding mid-celebration can
//    never eat an earned unlock.
//  - Retries reshuffle the SAME drawn cards (missed first), so the deck
//    can't be re-rolled for an easier draw.
//
//  The lock stamp plays once per lock (cold entry only): its visibility is
//  decided at init, so the overlay never mounts-then-vanishes — that ghost
//  mount used to fire orphaned slam haptics and replay the unlock wipe over
//  the live quiz.
//

import SwiftUI

struct RegretView: View {
    @EnvironmentObject var deckStore: DeckStore
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @AppStorage("flashcardBreakDuration") private var flashcardBreakDuration: Int = 5

    // MARK: Quiz machine

    private enum QuizPhase: Equatable {
        case answering
        case revealed(correct: Bool)
    }

    @State private var selectedRegrets: [Regret] = []
    @State private var questionResults: [Bool?] = []
    @State private var questionIndex = 0
    @State private var phase: QuizPhase = .answering
    /// The armed (tap-once) answer; a second tap on it commits.
    @State private var armedAnswer: Int?
    /// When the current answer was armed — a commit inside 150ms is treated
    /// as an accidental double-tap and ignored.
    @State private var armedAt: Date = .distantPast
    /// The committed answer, frozen for the reveal.
    @State private var committedAnswer: Int?
    /// Total commits this session — the tap-to-confirm hint only shows
    /// before the first one.
    @State private var commitCount = 0
    /// The praise capsule was tapped: explanation open, auto-advance off.
    @State private var expandedWhy = false
    @State private var advanceTask: Task<Void, Never>?

    @State private var showFinalMessage = false
    @State private var hasIncorrectAnswers = false

    // MARK: Entry / endings

    /// Cold entry only: the monster stamps once per lock. Decided at INIT —
    /// mounting the overlay and hiding it in onAppear would still run its
    /// scheduled haptics and hand-off wipe (the old "replies twice" ghost).
    @State private var showLockAnimation: Bool
    /// House entrance: header → question → tiles rise in, staggered.
    @State private var entered = false

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

    init() {
        // Stamp not yet seen for this lock → cold entry plays it.
        _showLockAnimation = State(initialValue: !Self.stampSeen())
    }

    private var currentAppName: String {
        isV2 ? "your apps" : (sharedDefaults?.string(forKey: "LastGuardedApp") ?? "unknown")
    }

    private var currentRegret: Regret? {
        guard questionIndex < selectedRegrets.count else { return nil }
        return selectedRegrets[questionIndex]
    }

    private var isRevealed: Bool {
        if case .revealed = phase { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Endings own the whole canvas — no quiz header above them.
            if showFinalMessage && !showDeckRescue && !alreadyUnlocked {
                if hasIncorrectAnswers {
                    QuizFailureView(
                        correctCount: correctCount,
                        totalCount: selectedRegrets.count,
                        results: questionResults,
                        emergencyUnlocksRemaining: isV2 ? studyGuard.emergencyUnlocksRemaining : nil,
                        giveUpTitle: isV2 ? "Give up for now" : "Close \(currentAppName)",
                        onRetry: { retryQuestions(source: "failure_screen") },
                        onEmergency: { showEmergencySheet = true },
                        onGiveUp: giveUp
                    )
                    .transition(.opacity)
                } else {
                    // The grant already happened at the final commit — this
                    // screen is the receipt: one stamp, one haptic, CTA live.
                    UnlockCelebrationView(
                        minutes: isV2 ? studyGuard.intervalMinutes : flashcardBreakDuration,
                        ctaTitle: isV2
                            ? "Start my \(studyGuard.intervalMinutes) minutes"
                            : "Unlock \(currentAppName)",
                        onStart: handleCelebrationCTA
                    )
                    .transition(.opacity)
                }
            } else {
                quizBody
            }

            if showLockAnimation {
                // Cold entry only (stamp not yet seen this lock): the
                // monster stamps on the NIGHT scene, then crossfades into
                // the daylight quiz while its rise-in plays (the house
                // rule: the stamp always hands off by crossfade). Entries
                // from the locked home skip this — already stamped.
                MascotLockOverlay(
                    subtitle: "Earn it back with your flashcards.",
                    background: SGTheme.night,
                    onDark: true,
                    usesExitMask: false
                ) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLockAnimation = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
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
            if showLockAnimation {
                markStampSeen()
            }
            withAnimation(SGTheme.spring) { entered = true }
        }
        .onDisappear {
            advanceTask?.cancel()
        }
    }

    // MARK: - Quiz body

    private var quizBody: some View {
        VStack(spacing: 0) {
            headerRail
                .sgRiseIn(entered)

            if showDeckRescue || alreadyUnlocked {
                rescueView
            } else if let regret = currentRegret {
                questionUnit(regret)
                    .id(questionIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                controlZone(regret)
            } else {
                Text("No questions available")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .padding()
                    .frame(maxHeight: .infinity)
            }
        }
    }

    /// One 44pt rail: exit on the leading edge, progress stretching the
    /// middle, "2/3" count trailing. No wordmark, no second label row.
    private var headerRail: some View {
        HStack(spacing: 12) {
            // Same 32pt circle in a 44pt target as SGSheetHeader's close.
            // Escape hatch: leave without unlocking; apps stay locked.
            Button(action: exitQuiz) {
                Image(systemName: "xmark")
                    .font(SGTheme.caption.weight(.bold))
                    .foregroundColor(SGTheme.paperSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(SGTheme.glaze(0.06)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SGPressStyle())
            .accessibilityLabel("Exit without unlocking")

            if !showDeckRescue && !alreadyUnlocked {
                QuizProgressBar(results: questionResults, currentIndex: questionIndex)

                Text("\(min(questionIndex + 1, max(selectedRegrets.count, 1)))/\(selectedRegrets.count)")
                    .font(SGTheme.numeral(13))
                    .monospacedDigit()
                    .foregroundColor(SGTheme.paperTertiary)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// The question and its tiles: prompt in the top third, tiles anchored
    /// to the thumb zone above the control. ONE tile identity per choice —
    /// reveals mutate its state in place, so the show plays exactly once
    /// (never a fading ghost tile under a fresh one).
    private func questionUnit(_ regret: Regret) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(regret.regretPrompt)
                .font(SGTheme.display(24))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                .sgRiseIn(entered, delay: 0.06)

            Spacer(minLength: 22)

            VStack(spacing: 10) {
                ForEach(Array(regret.choices.enumerated()), id: \.offset) { index, choice in
                    QuizAnswerTile(
                        text: choice,
                        state: tileState(for: index, in: regret),
                        confirmHint: commitCount == 0
                    ) {
                        tapTile(index)
                    }
                }
            }
            .sgRiseIn(entered, delay: 0.12)
        }
        .padding(.horizontal, SGTheme.screenPadding)
    }

    /// The bottom zone: Check fallback while answering, praise capsule or
    /// wrong-panel + ways forward after the reveal.
    @ViewBuilder
    private func controlZone(_ regret: Regret) -> some View {
        VStack(spacing: 12) {
            switch phase {
            case .answering:
                // Fallback + VoiceOver commit path; the tiles' tap-tap is
                // the fast lane. No button haptic — the commit composes its
                // own verdict burst, one press must never buzz twice.
                SGButton(
                    title: "Check",
                    enabled: armedAnswer != nil,
                    debounceWindow: 0.25,
                    tapHaptic: false
                ) {
                    commit()
                }

            case .revealed(correct: true):
                if expandedWhy {
                    QuizFeedbackPanel(
                        correct: true,
                        title: QuizPraiseCapsule.line(for: questionIndex),
                        explanation: regret.backgroundExplanation,
                        initiallyExpanded: true
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    SGButton(title: "Continue", debounceWindow: 0.25) {
                        advance()
                    }
                } else {
                    // The dwell beat: praise drops in while the next card
                    // queues itself. Tapping pauses to learn.
                    Button {
                        openWhy()
                    } label: {
                        QuizPraiseCapsule(
                            text: QuizPraiseCapsule.line(for: questionIndex),
                            showsWhy: !regret.backgroundExplanation.isEmpty
                        )
                    }
                    .buttonStyle(SGPressStyle())
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            case .revealed(correct: false):
                QuizFeedbackPanel(
                    correct: false,
                    title: "Not quite",
                    explanation: regret.backgroundExplanation
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))

                // One wrong answer already seals this run — offer the real
                // way forward first instead of a doomed march.
                SGButton(title: "Retry from the top",
                         variant: .ember,
                         debounceWindow: 0.25) {
                    retryQuestions(source: "early_retry")
                }

                SGButton(title: "Keep going", variant: .text, debounceWindow: 0.25) {
                    advance()
                }
            }
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .animation(SGTheme.springFast, value: phase)
        .animation(SGTheme.springFast, value: expandedWhy)
        .sgRiseIn(entered, delay: 0.18)
    }

    // MARK: - Tile interaction

    private func tileState(for index: Int, in regret: Regret) -> QuizTileState {
        switch phase {
        case .answering:
            return armedAnswer == index ? .selected : .idle
        case .revealed(let correct):
            if index == regret.correctAnswerIndex { return .revealedCorrect }
            if !correct && index == committedAnswer { return .revealedWrong }
            return .dimmed
        }
    }

    private func tapTile(_ index: Int) {
        guard case .answering = phase else { return }
        if armedAnswer == index {
            // Second tap on the armed tile commits — unless it landed
            // within 150ms of arming (an accidental double-tap).
            guard Date().timeIntervalSince(armedAt) >= 0.15 else { return }
            commit()
        } else {
            QuizHaptics.selectTick()
            withAnimation(SGTheme.springFast) { armedAnswer = index }
            armedAt = Date()
        }
    }

    /// The moment of truth. Judges the armed answer, records it, and — on
    /// the final correct commit — grants the unlock RIGHT HERE, before any
    /// celebration choreography can put it at risk.
    private func commit() {
        guard case .answering = phase,
              let answer = armedAnswer,
              let regret = currentRegret else { return }

        let correct = answer == regret.correctAnswerIndex
        committedAnswer = answer
        commitCount += 1

        if questionIndex < questionResults.count {
            questionResults[questionIndex] = correct
        }
        if !correct { hasIncorrectAnswers = true }

        // The verdict composition IS the press feedback (the Check button
        // and the tiles stay silent on this press).
        if correct {
            QuizHaptics.correctBurst()
        } else {
            QuizHaptics.wrongBuzz()
        }

        if !answeredQuestionIndices.contains(questionIndex) {
            answeredQuestionIndices.insert(questionIndex)
            Analytics.unlockQuestionAnswered(
                appName: currentAppName,
                questionIndex: questionIndex,
                totalQuestions: selectedRegrets.count,
                isCorrect: correct
            )
        }

        // Invariant: a grant requires every question answered correctly and
        // at least one question answered — the empty-deck rescue path can
        // never reach here.
        if correct && !hasIncorrectAnswers && questionIndex == selectedRegrets.count - 1 {
            earnUnlock()
        }

        withAnimation(SGTheme.springFast) {
            phase = .revealed(correct: correct)
            armedAnswer = nil
        }

        if correct {
            scheduleAutoAdvance()
        }
    }

    // MARK: - Advancing

    private func scheduleAutoAdvance() {
        advanceTask?.cancel()
        advanceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(SGTheme.quizAdvanceDwell * 1_000_000_000))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        advanceTask?.cancel()
        guard isRevealed else { return }

        if questionIndex >= selectedRegrets.count - 1 {
            withAnimation(SGTheme.spring) { showFinalMessage = true }
            return
        }

        SGTheme.tick()
        withAnimation(SGTheme.springFast) {
            questionIndex += 1
            phase = .answering
            committedAnswer = nil
            expandedWhy = false
        }
    }

    /// Praise capsule tap: hold the advance, open the learning.
    private func openWhy() {
        advanceTask?.cancel()
        Analytics.capture("unlock_explanation_opened", properties: [
            "question_index": questionIndex,
            "deck_name": deckStore.selectedDeck?.name ?? "unknown"
        ])
        withAnimation(SGTheme.springFast) { expandedWhy = true }
    }

    // MARK: - Setup / reset

    private func setupView() {
        // v2: entered while already unlocked (stale notification / deeplink) —
        // nothing to unlock, don't run a pointless quiz.
        if isV2, studyGuard.state != .locked {
            alreadyUnlocked = true
            showDeckRescue = false
            return
        }
        alreadyUnlocked = false

        guard let deck = deckStore.selectedDeck else {
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

        guard !deck.cards.isEmpty else {
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
            animationType: "lock",
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

        // One draw per lock session — retries reorder THIS draw, they never
        // go back to the deck for a fresh roll.
        selectedRegrets = useAllCards || flashcardCount >= deck.cards.count
            ? deck.cards.shuffled()
            : Array(deck.cards.shuffled().prefix(flashcardCount))
        resetRun()
    }

    private func resetRun() {
        advanceTask?.cancel()
        questionIndex = 0
        phase = .answering
        armedAnswer = nil
        committedAnswer = nil
        expandedWhy = false
        showFinalMessage = false
        hasIncorrectAnswers = false
        questionResults = Array(repeating: nil, count: selectedRegrets.count)
        answeredQuestionIndices = []
    }

    private func retryQuestions(source: String) {
        Analytics.unlockRetried(
            appName: currentAppName,
            correctCount: correctCount,
            totalQuestions: selectedRegrets.count,
            attemptNumber: attemptNumber,
            source: source
        )
        attemptNumber += 1

        // Same cards, missed first — the contract is "every card right",
        // not "reshuffle until the draw gets easier".
        let paired = Array(zip(selectedRegrets, questionResults))
        selectedRegrets =
            paired.filter { $0.1 == false }.map(\.0)
            + paired.filter { $0.1 == nil }.map(\.0)
            + paired.filter { $0.1 == true }.map(\.0)
        withAnimation(SGTheme.springFast) { resetRun() }
    }

    private var correctCount: Int {
        questionResults.compactMap { $0 }.filter { $0 }.count
    }

    // MARK: - Earning + endings

    /// The unlock is earned NOW — grant synchronously, then celebrate.
    /// (Backgrounding or a crash during the celebration can no longer eat
    /// an earned unlock, and the home hero's roll-in becomes the single
    /// count-up moment.)
    private func earnUnlock() {
        // The final result was written just before this call, so
        // correctCount already includes it. At least one correct answer is
        // the free-unlock invariant.
        guard correctCount > 0 else { return }

        if isV2 {
            StudyGuardManager.shared.grantFreshBudget(reason: .quiz)
        } else {
            // Legacy Shortcuts flow: record the break the moment it's
            // earned; the CTA still opens the guarded app.
            let currentTime = Date().timeIntervalSince1970
            sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
            sharedDefaults?.set(true, forKey: "UserAllowedBreak")
            sharedDefaults?.set(flashcardBreakDuration, forKey: "BreakDurationMinutes")
            sharedDefaults?.synchronize()
        }

        Analytics.unlockCompleted(
            appName: currentAppName,
            correctCount: correctCount,
            totalQuestions: selectedRegrets.count,
            hadRetries: attemptNumber > 1,
            durationSec: Date().timeIntervalSince(attemptStartTime),
            breakDurationMinutes: isV2 ? studyGuard.intervalMinutes : flashcardBreakDuration
        )
    }

    /// Celebration CTA: pure navigation — the grant already happened.
    private func handleCelebrationCTA() {
        Analytics.capture("celebration_cta_tapped", properties: [
            "app_name": currentAppName
        ])

        if !isV2 {
            // Legacy: reopen the guarded app the user was locked out of.
            if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                UIApplication.shared.open(getAppURL(for: appName), options: [:])
            }
        }
        NavigationModel.shared.returnHome()
    }

    private func giveUp() {
        Analytics.unlockCloseAnyway(
            appName: currentAppName,
            currentStep: questionIndex * 2 + (isRevealed ? 1 : 0),
            totalSteps: selectedRegrets.count * 2,
            hadIncorrectAnswers: hasIncorrectAnswers,
            durationSec: Date().timeIntervalSince(attemptStartTime)
        )
        if isV2 {
            // Back to the night home through the lock wipe, so light → dark
            // is authored rather than a jump cut.
            NavigationModel.shared.wipeTo(.lock) {
                NavigationModel.shared.returnHome()
            }
        } else {
            NavigationModel.shared.returnHome()
        }
    }

    /// The top-corner exit: bail out with nothing earned. Apps stay locked;
    /// reuses the close-anyway analytics so rage-quits are counted.
    private func exitQuiz() {
        Analytics.unlockCloseAnyway(
            appName: currentAppName,
            currentStep: questionIndex * 2 + (isRevealed ? 1 : 0),
            totalSteps: selectedRegrets.count * 2,
            hadIncorrectAnswers: hasIncorrectAnswers,
            durationSec: Date().timeIntervalSince(attemptStartTime)
        )
        NavigationModel.shared.returnHome()
    }

    // MARK: - Lock stamp bookkeeping

    private static func currentGrantStamp() -> Double {
        SGContract.sharedDefaults?.double(forKey: SGContract.Keys.budgetGrantedAt) ?? 0
    }

    /// Legacy flow (stamp == 0) stamps every time, matching the old rules.
    private static func stampSeen() -> Bool {
        let stamp = currentGrantStamp()
        return stamp != 0
            && UserDefaults.standard.double(forKey: RegretGuard.lockRevealStampKey) == stamp
    }

    private func markStampSeen() {
        let stamp = Self.currentGrantStamp()
        guard stamp != 0 else { return }
        UserDefaults.standard.set(stamp, forKey: RegretGuard.lockRevealStampKey)
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

            MascotView(pose: alreadyUnlocked ? .idle : .lookingDown, loops: 2)
                .frame(width: 120, height: 120)

            if alreadyUnlocked {
                Text("You're already unlocked")
                    .font(SGTheme.display(22))
                    .foregroundColor(SGTheme.paper)
                Text("You've got about \(max(0, studyGuard.totalMinutes - studyGuard.usedMinutes)) minutes left before your apps lock again.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Your deck is empty")
                    .font(SGTheme.display(22))
                    .foregroundColor(SGTheme.paper)
                Text("Add a flashcard and answer it to unlock your apps.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                if alreadyUnlocked {
                    SGButton(title: "Done", variant: .ghost) {
                        NavigationModel.shared.returnHome()
                    }
                } else {
                    SGButton(title: "Add a flashcard") {
                        ensureDeckExists()
                        showNewCardSheet = true
                    }

                    SGButton(title: "Do a focus session instead", variant: .ghost) {
                        NavigationModel.shared.unlockMethodOverride = "trueFocus"
                    }

                    SGButton(title: "Emergency unlock (\(studyGuard.emergencyUnlocksRemaining) left this week)",
                             variant: .text) {
                        showEmergencySheet = true
                    }
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)
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

    // MARK: - Legacy app reopening

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
