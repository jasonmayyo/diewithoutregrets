//
//  QuizV2View.swift
//  diewithoutregrets
//
//  Blocking-flow redesign: the new unlock quiz (fill-in-the-blank lesson
//  look). Runs the REAL quiz engine with the same contract as RegretView:
//
//  - One draw per lock session; retries reorder the SAME draw (missed
//    first), never a fresh roll.
//  - The grant fires synchronously at the final correct commit, before any
//    celebration choreography can put it at risk.
//  - Every card right or the run is sealed as failed.
//
//  This screen only handles the happy v2 path. Legacy users, empty-deck
//  rescue and already-unlocked entries fall back to RegretView, whose
//  battle-tested handling of those states is untouched. The decision is
//  made ONCE at init (same pattern as RegretView's lock stamp) so a state
//  flip mid-quiz (the grant moves .locked to .metering) can never swap the
//  screen out from under the celebration.
//
//  The palette aliases the Meadow tokens in SGTheme (see QuizV2Kit).
//

import SwiftUI

// The QV2 palette, QV2ChunkyStyle, QV2CTAButton and the failure ending
// live in QuizV2Kit.swift.

// MARK: - Screen

struct QuizV2View: View {
    @EnvironmentObject var deckStore: DeckStore
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false

    // Internal (not private): SGPreviewHarness routes preview launch
    // arguments to a concrete phase.
    enum Phase: Equatable {
        case answering
        case revealed(correct: Bool)
    }

    /// Decided once at entry, then frozen (see header). True routes the
    /// whole screen to RegretView.
    @State private var useLegacy: Bool

    // MARK: Quiz machine

    @State private var cards: [Regret] = []
    @State private var results: [Bool?] = []
    @State private var index = 0
    @State private var phase: Phase = .answering
    /// The armed (selected) answer; CHECK commits it.
    @State private var selected: Int?
    /// The committed answer, frozen for the reveal.
    @State private var committed: Int?
    @State private var hasIncorrect = false
    @State private var showEnding = false
    @State private var showEmergencySheet = false
    /// Updated by the streak ledger at the grant moment.
    @State private var streak = 1
    /// The displayed streak just before the grant, so the celebration can
    /// roll the numeral up from it (0 -> 1 on a fresh or broken streak).
    @State private var streakBefore = 0

    // Analytics bookkeeping (mirrors RegretView)
    @State private var attemptStartTime = Date()
    @State private var attemptNumber = 1
    @State private var answeredIndices: Set<Int> = []

    @ObservedObject private var studyGuard = StudyGuardManager.shared

    // MARK: Earned-time coins
    //
    // The real economy: each correct card is worth perCardSeconds of screen
    // time, visualized as a flock of coins that each bank a slice of it.
    // The grant itself is the whole draw's worth (rounded up to minutes,
    // floored at SGContract.minEarnedMinutes) and fires at the final commit;
    // the chip tops up to that real number as the last flock banks, so the
    // display always ends equal to what was granted.

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var earnedSeconds = 0
    @State private var coinsBanked = 0
    @State private var flyingCoins: [QV2CoinModel] = []
    @State private var coinSerial = 0
    /// Gates the progress-bar bump: a correct card fills the bar only once
    /// its first coin banks, so the fill reads as part of the earn payoff.
    @State private var coinsLandedThisCard = false
    /// The real grant, written at earnUnlock; the final flock's last coin
    /// rolls the chip up to it (the floor can exceed the per-card sum).
    @State private var grantedMinutes = 0
    @State private var chipFrame: CGRect = .zero
    @State private var ctaFrame: CGRect = .zero

    /// Coins per correct CHECK; together they bank the card's perCardSeconds.
    private let coinsPerCorrect = 5

    private var perCardSeconds: Int { studyGuard.perCardSeconds }

    /// One coin's slice of the card's worth; the last coin takes the
    /// remainder so the flock always sums exactly to perCardSeconds.
    private func coinValue(_ coin: QV2CoinModel) -> Int {
        let base = perCardSeconds / coin.flockSize
        return coin.index == coin.flockSize - 1
            ? perCardSeconds - base * (coin.flockSize - 1)
            : base
    }

    /// Bottom zone reserved under the options so they clear the tallest
    /// footer (the feedback panels) and sit still across phases.
    private let footerReserve: CGFloat = 222
    private let optionsGap: CGFloat = 32

    init() {
        let sg = StudyGuardManager.shared
        let deckHasCards = !(DeckStore.shared.selectedDeck?.cards.isEmpty ?? true)
        _useLegacy = State(initialValue: !(sg.isSetupComplete && sg.state == .locked && deckHasCards))
    }

    private var currentCard: Regret? {
        guard index < cards.count else { return nil }
        return cards[index]
    }

    private var isRevealed: Bool {
        if case .revealed = phase { return true }
        return false
    }

    private var correctCount: Int {
        results.compactMap { $0 }.filter { $0 }.count
    }

    var body: some View {
        if useLegacy {
            RegretView()
        } else {
            quizRoot
        }
    }

    private var quizRoot: some View {
        ZStack {
            if showEnding {
                ending
                    .transition(.opacity)
            } else if let card = currentCard {
                quizBody(card)
            }
        }
        .overlay {
            QV2CoinFlightOverlay(
                coins: flyingCoins,
                spawnFrame: ctaFrame,
                targetFrame: chipFrame,
                onLand: bankCoin
            )
        }
        .sheet(isPresented: $showEmergencySheet) {
            EmergencyUnlockSheet {
                NavigationModel.shared.returnHome()
            }
        }
        .onAppear(perform: setup)
    }

    // MARK: - Quiz body

    private func quizBody(_ card: Regret) -> some View {
        ZStack(alignment: .bottom) {
            QV2.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 10)

                sentence(card)
                    .padding(.top, 34)
                    .id("sentence-\(index)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Spacer(minLength: 16)

                options(card)
                    .padding(.bottom, optionsGap)
                    .id("options-\(index)")
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Color.clear.frame(height: footerReserve)
            }
            .padding(.horizontal, 20)

            footer(card)
        }
        .animation(SGTheme.springFast, value: phase)
        .animation(SGTheme.springFast, value: index)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Button(action: exitQuiz) {
                Image(systemName: "xmark")
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundColor(QV2.chrome)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SGPressStyle())
            .accessibilityLabel("Exit without unlocking")

            QV2ProgressBar(fraction: progressFraction, fill: progressColor)

            QV2EarnedChip(seconds: earnedSeconds, bump: coinsBanked)
                .background(QV2GlobalFrameReader { chipFrame = $0 })
        }
    }

    /// Wrong answers don't move the bar: the contract is every card right.
    /// A correct one moves it only when its first coin banks in the chip,
    /// so the fill lands as part of the earn payoff.
    private var progressFraction: CGFloat {
        guard !cards.isEmpty else { return 0 }
        let landed = phase == .revealed(correct: true) && coinsLandedThisCard ? index + 1 : index
        return CGFloat(landed) / CGFloat(cards.count)
    }

    private var progressColor: Color {
        phase == .revealed(correct: true) ? QV2.orange : QV2.green
    }

    // MARK: Sentence

    private func tokens(for card: Regret) -> [QV2Token] {
        var t = card.regretPrompt
            .split(separator: " ")
            .map { QV2Token.word(String($0)) }

        switch phase {
        case .answering:
            t.append(.blank)
        case .revealed(let correct):
            // Correct: the right word lands in green. Wrong: the committed
            // answer lands in red; the panel below teaches the right one.
            let filledIndex = correct ? card.correctAnswerIndex : (committed ?? card.correctAnswerIndex)
            if card.choices.indices.contains(filledIndex) {
                t += card.choices[filledIndex]
                    .split(separator: " ")
                    .map { QV2Token.fill(String($0), correct: correct) }
            }
        }
        return t
    }

    private func sentence(_ card: Regret) -> some View {
        QV2Flow(spacing: 7, lineSpacing: 22) {
            ForEach(Array(tokens(for: card).enumerated()), id: \.offset) { _, token in
                QV2TokenView(token: token)
            }
        }
    }

    // MARK: Options

    private func options(_ card: Regret) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(card.choices.enumerated()), id: \.offset) { idx, choice in
                Button {
                    tapTile(idx)
                } label: {
                    Text(choice)
                        .font(QV2.font(19, .medium))
                        .foregroundColor(tileStyle(for: idx, in: card).label)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 58)
                }
                .buttonStyle(QV2ChunkyStyle(
                    fill: tileStyle(for: idx, in: card).fill,
                    edge: tileStyle(for: idx, in: card).border,
                    depth: 2.5,
                    radius: 13,
                    bordered: true
                ))
                .disabled(isRevealed)
            }
        }
    }

    private func tileStyle(for idx: Int, in card: Regret) -> (fill: Color, border: Color, label: Color) {
        switch phase {
        case .answering:
            return selected == idx
                ? (QV2.blueTint, QV2.blueBorder, QV2.blue)
                : (.white, QV2.tileBorder, QV2.text)
        case .revealed(let correct):
            if idx == card.correctAnswerIndex {
                return (QV2.greenPanel, QV2.greenTileBorder, QV2.greenDeep)
            }
            if !correct && idx == committed {
                return (QV2.redPanel, QV2.redTileBorder, QV2.redDeep)
            }
            return (.white, QV2.tileBorder, QV2.text)
        }
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(_ card: Regret) -> some View {
        switch phase {
        case .answering:
            // No tap haptic: the commit composes its own verdict burst,
            // one press must never buzz twice.
            QV2CTAButton(title: "CHECK", enabled: selected != nil, action: commit)
                .background(QV2GlobalFrameReader { ctaFrame = $0 })
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

        case .revealed(correct: true):
            QV2FeedbackPanel(
                correct: true,
                title: QuizPraiseCapsule.line(for: index),
                detailLabel: card.backgroundExplanation.isEmpty ? nil : "Why:",
                detail: card.backgroundExplanation.isEmpty ? nil : card.backgroundExplanation
            ) {
                QV2CTAButton(title: "CONTINUE", variant: .green, action: advance)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .revealed(correct: false):
            QV2FeedbackPanel(
                correct: false,
                title: "Not quite",
                detailLabel: "Correct answer:",
                detail: card.choices.indices.contains(card.correctAnswerIndex)
                    ? card.choices[card.correctAnswerIndex]
                    : nil
            ) {
                VStack(spacing: 10) {
                    // One wrong answer already seals this run — the real way
                    // forward comes first.
                    QV2CTAButton(title: "RETRY FROM THE TOP", variant: .red) {
                        retryRun(source: "early_retry")
                    }
                    Button {
                        advance()
                    } label: {
                        Text("KEEP GOING")
                            .font(QV2.font(15, .bold))
                            .tracking(1.4)
                            .foregroundColor(QV2.redDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SGPressStyle())
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Endings

    @ViewBuilder
    private var ending: some View {
        if hasIncorrect {
            QuizV2FailureView(
                correctCount: correctCount,
                totalCount: cards.count,
                emergencyUnlocksRemaining: studyGuard.emergencyUnlocksRemaining,
                onRetry: { retryRun(source: "failure_screen") },
                onEmergency: { showEmergencySheet = true },
                onGiveUp: giveUp
            )
        } else {
            // The grant already happened at the final commit — this screen
            // is the receipt plus the streak habit loop.
            QuizV2StreakView(
                streak: streak,
                previousStreak: streakBefore,
                onClose: handleCelebrationCTA
            )
        }
    }

    // MARK: - Interaction

    private func tapTile(_ idx: Int) {
        guard case .answering = phase else { return }
        guard selected != idx else { return }
        QuizHaptics.selectTick()
        withAnimation(SGTheme.springFast) { selected = idx }
    }

    /// The moment of truth. Judges the selection, records it, and — on the
    /// final correct commit — grants the unlock RIGHT HERE, before any
    /// celebration choreography can put it at risk.
    private func commit() {
        guard case .answering = phase,
              let answer = selected,
              let card = currentCard else { return }

        let correct = answer == card.correctAnswerIndex
        committed = answer

        if index < results.count {
            results[index] = correct
        }
        if !correct { hasIncorrect = true }

        if correct {
            QuizHaptics.correctBurst()
            spawnCoinFlock()
        } else {
            QuizHaptics.wrongBuzz()
        }

        if !answeredIndices.contains(index) {
            answeredIndices.insert(index)
            Analytics.unlockQuestionAnswered(
                appName: "your apps",
                questionIndex: index,
                totalQuestions: cards.count,
                isCorrect: correct
            )
        }

        // Invariant: a grant requires every question answered correctly and
        // at least one question answered.
        if correct && !hasIncorrect && index == cards.count - 1 {
            earnUnlock()
        }

        withAnimation(SGTheme.springFast) {
            phase = .revealed(correct: correct)
            selected = nil
        }
    }

    private func advance() {
        guard isRevealed else { return }

        if index >= cards.count - 1 {
            // The chip leaves with the quiz body; ground any airborne coins
            // so they don't arc over the ending (banks become no-ops).
            flyingCoins = []
            withAnimation(SGTheme.spring) { showEnding = true }
            return
        }

        SGTheme.tick()
        withAnimation(SGTheme.springFast) {
            index += 1
            phase = .answering
            selected = nil
            committed = nil
            coinsLandedThisCard = false
        }
    }

    // MARK: - Coin flock

    private func spawnCoinFlock() {
        if reduceMotion {
            // No flight: bank the whole card's worth at once. No extra
            // haptic — the commit's correctBurst already marks the moment,
            // and one press must never buzz twice.
            earnedSeconds += perCardSeconds
            coinsBanked += 1
            coinsLandedThisCard = true
            return
        }
        coinSerial += 1
        flyingCoins.append(contentsOf: QV2CoinModel.flock(
            of: coinsPerCorrect,
            serial: coinSerial,
            cardIndex: index
        ))
    }

    private func bankCoin(_ coin: QV2CoinModel) {
        // A reset, exit or ending clears the flock but can't cancel the
        // flight timers; a coin that's no longer ours banks nothing.
        guard flyingCoins.contains(where: { $0.id == coin.id }) else { return }

        QuizHaptics.coinLand(progress: Double(coin.index + 1) / Double(coin.flockSize))
        let isLastOfFinalFlock = grantedMinutes > 0
            && coin.cardIndex == cards.count - 1
            && coin.index == coin.flockSize - 1
        withAnimation(SGTheme.springPop) {
            // The final coin of the run rolls the chip to the REAL grant
            // (the 5-minute floor can exceed the per-card sum).
            earnedSeconds = isLastOfFinalFlock
                ? grantedMinutes * 60
                : earnedSeconds + coinValue(coin)
            coinsBanked += 1
            // Stragglers from an already-advanced card keep banking time
            // but must not pre-arm the next card's progress gate.
            if coin.cardIndex == index {
                coinsLandedThisCard = true
            }
        }
        // Let the shrink-out finish before the coin leaves the tree.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            flyingCoins.removeAll { $0.id == coin.id }
        }
    }

    // MARK: - Setup / reset

    private func setup() {
        guard !useLegacy, let deck = deckStore.selectedDeck, !deck.cards.isEmpty else { return }
        guard cards.isEmpty else { return }   // re-appear must not re-roll the draw

        Analytics.unlockAttempted(
            appName: "your apps",
            unlockMethod: "flashcards",
            flashcardCount: flashcardCount,
            useAllCards: useAllCards,
            animationType: "quizv2",
            deckId: deck.id.uuidString,
            deckName: deck.name,
            availableCards: deck.cards.count
        )
        Telemetry.breadcrumb("Unlock attempted", category: "core_product",
                             data: ["app_name": "your apps",
                                    "deck_name": deck.name,
                                    "available_cards": deck.cards.count])
        attemptStartTime = Date()
        attemptNumber = 1

        // One draw per lock session — retries reorder THIS draw, they never
        // go back to the deck for a fresh roll.
        cards = useAllCards || flashcardCount >= deck.cards.count
            ? deck.cards.shuffled()
            : Array(deck.cards.shuffled().prefix(flashcardCount))
        resetRun()

        #if DEBUG
        driveForScreenshotsIfRequested()
        #endif
    }

    #if DEBUG
    /// Screenshot harness: unattended drivers that walk the machine through
    /// its states using the same functions the buttons call.
    ///   -sg-preview-quizv2-correct  land on the correct reveal
    ///   -sg-preview-quizv2-wrong    land on the wrong reveal
    ///   -sg-preview-quizv2-win      answer everything right, end on the
    ///                               celebration (exercises the real grant)
    ///   -sg-preview-quizv2-fail     answer everything wrong, end on the
    ///                               failure screen
    private func driveForScreenshotsIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-sg-preview-quizv2-correct") {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                selected = currentCard?.correctAnswerIndex
                commit()
            }
        } else if args.contains("-sg-preview-quizv2-wrong") {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let card = currentCard else { return }
                selected = card.choices.indices.first { $0 != card.correctAnswerIndex }
                commit()
            }
        } else if args.contains("-sg-preview-quizv2-win") {
            Task { @MainActor in
                while !showEnding {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    guard let card = currentCard else { break }
                    selected = card.correctAnswerIndex
                    commit()
                    // Long enough for the whole coin flock to bank (last
                    // coin ~1.26s after commit) so captures are settled.
                    try? await Task.sleep(nanoseconds: 1_700_000_000)
                    advance()
                }
            }
        } else if args.contains("-sg-preview-quizv2-fail") {
            Task { @MainActor in
                while !showEnding {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    guard let card = currentCard else { break }
                    selected = card.choices.indices.first { $0 != card.correctAnswerIndex }
                    commit()
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    advance()
                }
            }
        }
    }
    #endif

    private func resetRun() {
        index = 0
        phase = .answering
        selected = nil
        committed = nil
        hasIncorrect = false
        showEnding = false
        results = Array(repeating: nil, count: cards.count)
        answeredIndices = []
        earnedSeconds = 0
        coinsBanked = 0
        flyingCoins = []
        coinsLandedThisCard = false
        grantedMinutes = 0
    }

    private func retryRun(source: String) {
        Analytics.unlockRetried(
            appName: "your apps",
            correctCount: correctCount,
            totalQuestions: cards.count,
            attemptNumber: attemptNumber,
            source: source
        )
        attemptNumber += 1

        // Same cards, missed first — the contract is "every card right",
        // not "reshuffle until the draw gets easier".
        let paired = Array(zip(cards, results))
        cards =
            paired.filter { $0.1 == false }.map(\.0)
            + paired.filter { $0.1 == nil }.map(\.0)
            + paired.filter { $0.1 == true }.map(\.0)
        withAnimation(SGTheme.springFast) { resetRun() }
    }

    // MARK: - Earning + endings

    private func earnUnlock() {
        guard correctCount > 0 else { return }

        grantedMinutes = StudyGuardManager.shared.grantEarnedBudget(cardCount: cards.count)
        if reduceMotion {
            // The instant-bank path already ran for this card; snap the chip
            // straight to the real grant.
            earnedSeconds = grantedMinutes * 60
        }
        // current(), not count: a lapsed streak reads 0, so the roll-up
        // goes 0 -> 1 instead of counting backwards from the stale total.
        streakBefore = QV2Streak.current()
        streak = QV2Streak.recordSuccess()

        Analytics.unlockCompleted(
            appName: "your apps",
            correctCount: correctCount,
            totalQuestions: cards.count,
            hadRetries: attemptNumber > 1,
            durationSec: Date().timeIntervalSince(attemptStartTime),
            breakDurationMinutes: grantedMinutes
        )
    }

    /// Celebration CTA: pure navigation — the grant already happened.
    private func handleCelebrationCTA() {
        Analytics.capture("celebration_cta_tapped", properties: [
            "app_name": "your apps"
        ])
        NavigationModel.shared.returnHome()
    }

    private func giveUp() {
        Analytics.unlockCloseAnyway(
            appName: "your apps",
            currentStep: index * 2 + (isRevealed ? 1 : 0),
            totalSteps: cards.count * 2,
            hadIncorrectAnswers: hasIncorrect,
            durationSec: Date().timeIntervalSince(attemptStartTime)
        )
        // Back to the night home through the lock wipe, so light to dark is
        // authored rather than a jump cut.
        NavigationModel.shared.wipeTo(.lock) {
            NavigationModel.shared.returnHome()
        }
    }

    /// The top-corner exit: bail out with nothing earned. Apps stay locked.
    private func exitQuiz() {
        // Ground airborne coins so their landing haptics can't tick after
        // the user has left the quiz.
        flyingCoins = []
        Analytics.unlockCloseAnyway(
            appName: "your apps",
            currentStep: index * 2 + (isRevealed ? 1 : 0),
            totalSteps: cards.count * 2,
            hadIncorrectAnswers: hasIncorrect,
            durationSec: Date().timeIntervalSince(attemptStartTime)
        )
        NavigationModel.shared.returnHome()
    }
}

// MARK: - Feedback panel

private struct QV2FeedbackPanel<Actions: View>: View {
    let correct: Bool
    let title: String
    let detailLabel: String?
    let detail: String?
    @ViewBuilder let actions: Actions

    private var tint: Color { correct ? QV2.greenDeep : QV2.redDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(correct ? "sticker-checkmark" : "sticker-error")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                Text(title)
                    .font(QV2.font(24, .bold))
                    .foregroundColor(tint)
            }

            if let detailLabel, let detail {
                Text(detailLabel)
                    .font(QV2.font(17, .bold))
                    .foregroundColor(tint)
                    .padding(.top, 14)

                Text(detail)
                    .font(QV2.font(18, .medium))
                    .foregroundColor(tint)
                    .lineSpacing(3)
                    .padding(.top, 6)
            }

            actions
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .background((correct ? QV2.greenPanel : QV2.redPanel).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Progress bar

private struct QV2ProgressBar: View {
    let fraction: CGFloat
    let fill: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(QV2.track)

                Capsule()
                    .fill(fill)
                    .frame(width: max(16, geo.size.width * fraction))
                    .overlay(alignment: .top) {
                        // The shine stripe inside the fill.
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4.5)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                            .frame(width: max(16, geo.size.width * fraction))
                    }
            }
        }
        .frame(height: 16)
        .animation(.easeOut(duration: 0.35), value: fraction)
        .animation(.easeOut(duration: 0.2), value: fill)
    }
}

// MARK: - Sentence tokens

private enum QV2Token {
    case word(String)                    // dark text, gray dashed rule
    case fill(String, correct: Bool)     // revealed answer word: green or red
    case blank                           // solid line placeholder
}

private struct QV2TokenView: View {
    let token: QV2Token

    var body: some View {
        switch token {
        case .word(let s):
            ruled(Text(s).foregroundColor(QV2.text), rule: QV2.rule, dashed: true)
        case .fill(let s, let correct):
            ruled(Text(s).foregroundColor(correct ? QV2.green : QV2.redDeep),
                  rule: correct ? QV2.green : QV2.redDeep,
                  dashed: true)
        case .blank:
            ruled(Text(" ").frame(width: 64), rule: QV2.blankRule, dashed: false)
        }
    }

    private func ruled(_ content: some View, rule: Color, dashed: Bool) -> some View {
        content
            .font(QV2.font(19, .medium))
            .padding(.bottom, 7)
            .overlay(alignment: .bottom) {
                QV2Line()
                    .stroke(rule, style: StrokeStyle(
                        lineWidth: dashed ? 2.25 : 2.5,
                        dash: dashed ? [3.5, 3.25] : []
                    ))
                    .frame(height: 2.5)
            }
    }
}

private struct QV2Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

// MARK: - Wrapping token layout

private struct QV2Flow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    private struct Row {
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
        var height: CGFloat = 0
        var y: CGFloat = 0
    }

    private func rows(for width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(current)
                current = Row()
                x = 0
            }
            current.items.append((i, x, size))
            x += size.width + spacing
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }

        var y: CGFloat = 0
        for idx in rows.indices {
            rows[idx].y = y
            y += rows[idx].height + lineSpacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        let r = rows(for: width, subviews: subviews)
        let height = r.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in rows(for: bounds.width, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(
                        x: bounds.minX + item.x,
                        y: bounds.minY + row.y + row.height - item.size.height
                    ),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Quiz v2 (live)") {
    SGPreviewHarness.seed(.locked)
    return QuizV2View()
        .environmentObject(DeckStore.shared)
        .environmentObject(RegretStore.shared)
}
#endif
