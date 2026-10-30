//
//  MonsterChatView.swift
//  A conversation with a tutor: contact header, text transcript and a pinned reply bar.
//

import SwiftUI

struct MonsterChatView: View {
    @StateObject private var session: MonsterSession
    @ObservedObject private var studyGuard = StudyGuardManager.shared
    @StateObject private var presenter = MonsterTranscriptPresenter(
        onMonsterMessage: { _ in MonsterChatHaptics.messageReceived() }
    )
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var showStudySheet = false
    @State private var showDeckPicker = false
    @State private var sheetInquiry: MonsterReplyTarget?

    private let onClose: () -> Void
    private let isUncovered: Bool

    init(session: MonsterSession,
         isUncovered: Bool = true,
         onClose: @escaping () -> Void = { NavigationModel.shared.returnHome() }) {
        _session = StateObject(wrappedValue: session)
        self.isUncovered = isUncovered
        self.onClose = onClose
    }

    private var revealed: Int { presenter.revealed }
    private var canPresent: Bool {
        isOnScreen && scenePhase == .active && isUncovered && !showStudySheet && !showDeckPicker
    }

    private var replyTarget: MonsterReplyTarget? {
        guard canPresent else { return nil }
        return MonsterReplyTarget.current(messages: session.messages, revealed: revealed,
                                   activeCard: session.activeCard,
                                   isThinking: presenter.isTyping || session.isThinking)
    }

    var body: some View {
        MonsterConversationView(
            persona: session.persona,
            messages: Array(session.messages.prefix(revealed)),
            isTyping: canPresent && (presenter.isTyping || session.isThinking),
            replyTarget: replyTarget,
            isFinished: session.isFinished && revealed >= session.messages.count,
            grantedMinutes: session.grantedMinutes,
            totalQuestions: session.method == .studySheet ? 0 : session.totalQuestions,
            secondsPerCorrectAnswer: session.secondsPerCorrectAnswer,
            allowanceSeconds: studyGuard.state == .metering
                ? max(0, studyGuard.totalMinutes - studyGuard.usedMinutes) * 60 : 0,
            onClose: onClose,
            onChoice: { messageID, index in
                guard replyTarget?.messageID == messageID,
                      let card = replyTarget?.card, card.choices.indices.contains(index) else { return }
                session.answer(choiceIndex: index)
            },
            onTyped: { messageID, text in
                guard replyTarget?.messageID == messageID,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                session.answer(typed: text)
            },
            isResponding: revealed < session.messages.count || session.isThinking,
            mediaPlaybackEnabled: canPresent,
            onAsk: { messageID, text in session.ask(text, about: messageID) },
            studyRound: session.studyRound,
            canClaimStudyTime: session.studySheetState == .readyToUnlock || session.studySheetState == .finished,
            projectedStudyMinutes: session.studyProjectedMinutes,
            pendingStudySeconds: session.method == .studySheet ? session.studyEarnedSeconds : nil,
            requestedInquiry: sheetInquiry,
            onOpenStudyRound: {
                guard revealed >= session.messages.count, session.beginStudyRound() else { return }
                sheetInquiry = nil
                showStudySheet = true
            },
            onClaimStudyTime: {
                guard revealed >= session.messages.count else { return }
                session.claimStudyTime()
            },
            deckName: session.deckName,
            studyDeckID: session.deckID,
            onChooseDeck: { showDeckPicker = true }
        )
        .id(session.roundID)
        .sheet(isPresented: $showDeckPicker, onDismiss: { updatePresentation() }) {
            DeckPickerSheet(
                subtitle: session.isFinished ? "Choose a deck to start a new round here."
                    : "Choose the flashcards for this chat. Time earned in this round is kept.",
                activeDeckID: session.deckID,
                onSelect: { _ in
                    let historyIDs = Set(session.isFinished ? [] : session.messages.map(\.id))
                    if session.switchToSelectedDeck() {
                        presenter.restoreHistory(session.messages.filter { historyIDs.contains($0.id) })
                        sheetInquiry = nil
                    }
                    showDeckPicker = false
                }
            )
            .environmentObject(DeckStore.shared)
        }
        .sheet(isPresented: $showStudySheet) {
            MonsterStudySheet(session: session) { sheetInquiry = $0 }
                .presentationDetents([.fraction(0.86), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(MonsterPalette.bg)
        }
        .onAppear {
            isOnScreen = true
            updatePresentation()
        }
        .onChange(of: canPresent) { _, _ in updatePresentation() }
        .onChange(of: session.messages.count) { _, _ in updatePresentation() }
        .onDisappear {
            isOnScreen = false
            presenter.pause()
            session.stop()
        }
    }

    private func updatePresentation() {
        // onAppear also runs under the lock cover. Scene activity alone isn't
        // visibility, and backgrounding does not necessarily call onDisappear.
        if canPresent { session.start() }
        presenter.update(messages: session.messages, isVisible: canPresent)
    }
}

/// Presentation-only view. Both quick replies and the composer answer the current
/// question through the local session. Explicit follow-ups use the separate tutor endpoint.
struct MonsterConversationView: View {
    let persona: MonsterPersona
    let messages: [MonsterMessage]
    let isTyping: Bool
    let replyTarget: MonsterReplyTarget?
    let isFinished: Bool
    let grantedMinutes: Int
    let totalQuestions: Int
    let secondsPerCorrectAnswer: Int
    /// The current Screen Time budget, refreshed by StudyGuardManager on return.
    /// Grants replace that budget; the animation must never add a second grant.
    let allowanceSeconds: Int
    let onClose: () -> Void
    let onChoice: (UUID, Int) -> Void
    let onTyped: (UUID, String) -> Void
    /// Includes the quiet reading beat between typing bubbles.
    var isResponding = false
    var mediaPlaybackEnabled = true
    var onAsk: (UUID, String) -> Void = { _, _ in }
    var studyRound: MonsterStudyRound? = nil
    var canClaimStudyTime = false
    var projectedStudyMinutes = 0
    var pendingStudySeconds: Int? = nil
    var requestedInquiry: MonsterReplyTarget? = nil
    var onOpenStudyRound: () -> Void = {}
    var onClaimStudyTime: () -> Void = {}
    var deckName: String? = nil
    var studyDeckID: UUID? = nil
    var onChooseDeck: (() -> Void)? = nil

    @State private var draft = ""
    @State private var inquiryTarget: MonsterReplyTarget?
    @State private var showAnswerChoices = true
    @State private var displayedAllowance = 0
    @State private var coinsBanked = 0
    @State private var flyingCoins: [QV2CoinModel] = []
    @State private var landedCoinIDs: Set<Int> = []
    @State private var rewardSerial = 0
    @State private var handledRewardIDs: Set<UUID> = []
    @State private var pendingRewards: [MonsterAnswerReward] = []
    @State private var rewardTask: Task<Void, Never>?
    @State private var rewardStart = 0
    @State private var rewardTarget = 0
    @State private var chipFrame: CGRect = .zero
    @State private var answerFrame: CGRect = .zero
    @State private var flightOrigin: CGRect = .zero
    @State private var scrollTask: Task<Void, Never>?
    @State private var followingLatest = true
    @State private var draggingTranscript = false
    @State private var transcriptHeight: CGFloat = 0
    @State private var transcriptBottom: CGFloat = 0
    @State private var latestRowHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var answerRewards: [MonsterAnswerReward] {
        MonsterAnswerReward.earned(in: messages, secondsPerCorrectAnswer: secondsPerCorrectAnswer)
    }

    private var hasSettled: Bool {
        isFinished || messages.contains(where: { if case .grant = $0.kind { return true }; return false })
    }

    private var isCelebrating: Bool {
        rewardTask != nil || !pendingRewards.isEmpty || !flyingCoins.isEmpty
    }

    private var showingEarnings: Bool { !hasSettled || isCelebrating }

    private var latestUserMessageID: UUID? {
        messages.last(where: { $0.sender == .user })?.id
    }

    /// Keep the question identity for context, independently of whether
    /// its answer controls are still available.
    private var presentedQuestion: MonsterReplyTarget? {
        guard let message = messages.last(where: { $0.card != nil }), let card = message.card else { return nil }
        return MonsterReplyTarget(messageID: message.id, card: card)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
        }
        .background(MonsterPalette.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { replyBar }
        .overlay {
            QV2CoinFlightOverlay(coins: flyingCoins, spawnFrame: flightOrigin,
                                 targetFrame: chipFrame, onLand: bankCoin)
                .accessibilityHidden(true)
        }
        .onAppear {
            // Restore a transcript's earnings without replaying old answers.
            handledRewardIDs = Set(answerRewards.map(\.id))
            settleReward()
        }
        .onChange(of: answerRewards) { _, rewards in celebrateAnswers(rewards) }
        .onChange(of: pendingStudySeconds) { _, _ in reconcileCounterIfIdle() }
        .onChange(of: requestedInquiry?.messageID) { _, _ in
            inquiryTarget = requestedInquiry
            draft = ""
        }
        .onChange(of: studyDeckID) { _, _ in
            draft = ""
            inquiryTarget = nil
            showAnswerChoices = true
        }
        .onChange(of: hasSettled) { _, _ in reconcileCounterIfIdle() }
        .onChange(of: allowanceSeconds) { _, _ in
            reconcileCounterIfIdle()
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { settleReward() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { settleReward() }
        }
        .onDisappear { settleReward(); scrollTask?.cancel() }
        .onChange(of: presentedQuestion?.messageID) { oldID, _ in
            // Keep a draft started during the introduction for the first typed
            // question. Later questions must not inherit a previous answer.
            if oldID != nil { draft = "" }
            inquiryTarget = nil
            showAnswerChoices = true
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MonsterPalette.text)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close chat")
            MonsterAvatarHeader(persona: persona, deckName: deckName, onChooseDeck: onChooseDeck)
            MonsterAllowanceChip(seconds: displayedAllowance, bump: coinsBanked, isEarning: showingEarnings)
                .background(QV2GlobalFrameReader { chipFrame = $0 })
                .layoutPriority(1)
        }
        // Keep the compact contact header readable; the transcript and reply
        // controls retain the user's full text size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.trailing, 20).padding(.leading, 4).padding(.vertical, 10)
        .background(MonsterPalette.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MonsterPalette.hairline).frame(height: 0.5)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // A short study round can use measured rows throughout. Lazy
                // height estimates were shifting the scroll offset on arrival.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        row(message, endsGroup: endsGroup(at: index),
                            sources: index > 0 ? messages[index - 1].sources : [])
                            .background {
                                if message.id == latestUserMessageID {
                                    QV2GlobalFrameReader { answerFrame = $0 }
                                }
                                if message.id == messages.last?.id {
                                    GeometryReader { geometry in
                                        Color.clear.preference(key: MonsterLatestRowHeight.self,
                                                               value: geometry.size.height)
                                    }
                                }
                            }
                            .padding(.bottom, endsGroup(at: index) ? 10 : 4)
                            .modifier(MonsterMessageArrival(isUser: message.sender == .user))
                            .id(message.id)
                    }
                    ZStack(alignment: .leading) {
                        Color.clear.frame(height: 42)
                        if isTyping {
                            MonsterTypingIndicator(name: persona.name)
                                .transition(.opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : MonsterChatMotion.feedback, value: isTyping)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: MonsterTranscriptBottom.self,
                                    value: geometry.frame(in: .named("monsterTranscript")).maxY)
                })
            }
            .coordinateSpace(name: "monsterTranscript")
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.height
            } action: { transcriptHeight = $0 }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(DragGesture(minimumDistance: 8)
                .onChanged { _ in draggingTranscript = true; scrollTask?.cancel() }
                .onEnded { _ in
                    draggingTranscript = false
                    followingLatest = transcriptBottom <= transcriptHeight + 60
                })
            .onAppear { scheduleScroll(proxy) }
            .onChange(of: MonsterTranscriptScrollRequest(messageID: messages.last?.id, height: transcriptHeight)) { _, _ in
                scheduleScroll(proxy)
            }
            .onChange(of: replyPanelID) { _, _ in
                // A safe-area inset can change without changing the scroll
                // view's measured frame. Keep the question above the new panel.
                scheduleScroll(proxy)
            }
            .onPreferenceChange(MonsterLatestRowHeight.self) { latestRowHeight = $0 }
            .onPreferenceChange(MonsterTranscriptBottom.self) { bottom in
                transcriptBottom = bottom
                if draggingTranscript || !followingLatest {
                    followingLatest = bottom <= transcriptHeight + 60
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !followingLatest {
                    Button {
                        followingLatest = true
                        scheduleScroll(proxy)
                    } label: {
                        Label("Latest", systemImage: "arrow.down")
                            .font(.caption.weight(.semibold))
                            .padding(12)
                            .background(MonsterPalette.bg, in: Capsule())
                            .overlay(Capsule().strokeBorder(MonsterPalette.hairline))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MonsterPalette.text)
                    .padding(12)
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : MonsterChatMotion.feedback, value: followingLatest)
        }
    }

    private func endsGroup(at index: Int) -> Bool {
        let rows = messages
        guard index + 1 < rows.count else { return true }
        let current = rows[index]
        let next = rows[index + 1]
        guard current.sender == next.sender, current.sender != .system,
              case .text = current.kind, case .text = next.kind else { return true }
        return false
    }

    @ViewBuilder
    private func row(_ message: MonsterMessage, endsGroup: Bool,
                     sources: [MonsterStudySource]) -> some View {
        switch message.kind {
        case let .text(text):
            VStack(alignment: .leading, spacing: 8) {
                MonsterTextBubble(text: text, sender: message.sender, endsGroup: endsGroup)
                if let reaction = message.reaction {
                    MonsterReactionView(reaction: reaction, playbackEnabled: mediaPlaybackEnabled,
                                        viewportHeight: transcriptHeight)
                }
            }
        case let .card(card):
            let priorCards = messages.prefix(while: { $0.id != message.id }).compactMap(\.card)
            let uniqueIDs = priorCards.reduce(into: [UUID]()) { ids, card in
                if !ids.contains(card.id) { ids.append(card.id) }
            }
            VStack(alignment: .leading, spacing: 6) {
                if !sources.isEmpty {
                    MonsterSourcesIndicator(sources: sources)
                }
                MonsterQuestionBubble(text: card.quizPrompt.text,
                    number: (uniqueIDs.firstIndex(of: card.id) ?? uniqueIDs.count) + 1,
                    total: totalQuestions, isRetry: uniqueIDs.contains(card.id), persona: persona,
                    canAsk: !isTyping && !isResponding) {
                    draft = ""
                    inquiryTarget = MonsterReplyTarget(messageID: message.id, card: card)
                }
            }
        case let .reveal(correct, answer, why):
            MonsterRevealBubble(correct: correct, answer: answer, why: why, endsGroup: endsGroup)
        case let .grant(minutes):
            MonsterGrantBubble(minutes: minutes)
        case let .studyRound(round):
            VStack(alignment: .leading, spacing: 6) {
                if !sources.isEmpty {
                    MonsterSourcesIndicator(sources: sources)
                }
                MonsterStudyInvitation(round: round, persona: persona,
                                       isCurrent: round.id == studyRound?.id && !canClaimStudyTime && !hasSettled)
            }
        case let .studyRecap(summary):
            MonsterStudyRecap(summary: summary, canAsk: !isTyping && !isResponding) { target in
                draft = ""
                inquiryTarget = target
            }
        }
    }

    private var presentedStudyRound: MonsterStudyRound? {
        guard let studyRound, messages.contains(where: {
            if case .studyRound(let round) = $0.kind { return round.id == studyRound.id }
            return false
        }) else { return nil }
        return studyRound
    }

    private var replyPanelID: MonsterReplyPanelID {
        if let inquiryTarget { return .inquiry(inquiryTarget.messageID) }
        if isFinished { return .finished }
        if let round = presentedStudyRound { return .study(round.id, canClaimStudyTime) }
        // The input keeps its identity as suggestions appear above it. Drafts
        // and keyboard focus must not reset just because a message arrives.
        return .composer
    }

    private var choiceTarget: MonsterReplyTarget? {
        guard inquiryTarget == nil, !isFinished,
              let replyTarget, replyTarget.card.answerMode == .choices else { return nil }
        return replyTarget
    }

    private var visibleChoicesID: UUID? {
        showAnswerChoices ? choiceTarget?.messageID : nil
    }

    private var replyBar: some View {
        VStack(spacing: 0) {
            replyContent
                .id(replyPanelID)
                .transition(.asymmetric(
                    insertion: MonsterChatMotion.arrival(reduceMotion: reduceMotion),
                    removal: .opacity))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
        .background {
            LinearGradient(stops: [
                .init(color: MonsterPalette.bg.opacity(0), location: 0),
                .init(color: MonsterPalette.bg.opacity(0.94), location: 0.28),
                .init(color: MonsterPalette.bg, location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .padding(.top, -28)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? nil : MonsterChatMotion.panel, value: replyPanelID)
        .animation(reduceMotion ? nil : MonsterChatMotion.panel, value: visibleChoicesID)
    }

    private var replyContent: some View {
        VStack(spacing: 12) {
            if isFinished && inquiryTarget == nil {
                HStack(spacing: 12) {
                    Text(grantedMinutes > 0 ? "You're all set." : "We'll try again next time.")
                        .font(.subheadline)
                        .foregroundStyle(MonsterPalette.textDim)
                    Spacer(minLength: 0)
                    Button(action: onClose) {
                        Text("Done").font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24).padding(.vertical, 13)
                            .background(MonsterPalette.text, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if let inquiry = inquiryTarget {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ask \(persona.name)").font(.caption.weight(.semibold))
                            Text(inquiry.card.quizPrompt.text).font(.caption).lineLimit(2)
                        }
                        .foregroundStyle(MonsterPalette.textDim)
                        Spacer(minLength: 0)
                        Button(studyRound != nil ? "Back to round" : isFinished ? "Back" : "Answer card") {
                            inquiryTarget = nil
                            draft = ""
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MonsterPalette.text)
                        .disabled(isTyping || isResponding)
                    }
                }
                if let round = presentedStudyRound, inquiryTarget == nil {
                    MonsterStudyButton(title: canClaimStudyTime
                        ? (projectedStudyMinutes > 0 ? "Unlock \(projectedStudyMinutes) min" : "Finish round")
                        : (round.answers.isEmpty ? "Start \(round.questions.count) flashcard\(round.questions.count == 1 ? "" : "s")" : "Continue round"),
                        enabled: !isTyping && !isResponding) {
                            inquiryTarget = nil
                            followingLatest = true
                            if canClaimStudyTime { onClaimStudyTime() } else { onOpenStudyRound() }
                        }
                    Text(canClaimStudyTime ? "Your round is done." : "\(persona.name) will meet you after the round.")
                        .font(.caption).foregroundStyle(MonsterPalette.textDim)
                } else {
                    if let target = choiceTarget, showAnswerChoices {
                        MonsterQuickReplies(choices: target.card.choices,
                                            enabled: !isTyping && !isResponding,
                                            onChoice: { index in
                            draft = ""
                            followingLatest = true
                            onChoice(target.messageID, index)
                        })
                        .id(target.messageID)
                        .transition(.asymmetric(
                            insertion: MonsterChatMotion.arrival(reduceMotion: reduceMotion),
                            removal: .opacity))
                    }
                    MonsterReplyComposer(
                        draft: $draft,
                        enabled: true,
                        placeholder: inquiryTarget != nil ? "Ask \(persona.name)…"
                            : visibleChoicesID != nil ? "Or type an answer…" : "Your answer…",
                        onSend: sendReply,
                        canSubmit: !isTyping && !isResponding && (inquiryTarget != nil || replyTarget != nil),
                        onFocusChanged: { focused in
                            if focused && showAnswerChoices {
                                withAnimation(reduceMotion ? nil : MonsterChatMotion.panel) {
                                    showAnswerChoices = false
                                }
                            }
                        },
                        maximumLength: inquiryTarget == nil ? nil : 1000,
                        accessibilityName: inquiryTarget == nil ? "Your answer" : "Your question",
                        showsChoices: visibleChoicesID != nil,
                        onToggleChoices: choiceTarget == nil ? nil : {
                            withAnimation(reduceMotion ? nil : MonsterChatMotion.panel) {
                                showAnswerChoices.toggle()
                            }
                        }
                    )
                }
            }
        }
    }

    private func sendReply() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        followingLatest = true
        if let inquiry = inquiryTarget {
            guard !isTyping, !isResponding, text.utf16.count <= 1000 else { return }
            draft = ""
            onAsk(inquiry.messageID, text)
            return
        }
        guard let target = replyTarget else { return }
        draft = ""
        onTyped(target.messageID, text)
    }

    private func scheduleScroll(_ proxy: ScrollViewProxy) {
        scrollTask?.cancel()
        guard followingLatest, !draggingTranscript else { return }
        scrollTask = Task { @MainActor in
            // Read the new row's layout, then run one transcript scroll. Row
            // fades do not animate layout. Never drag a reader out of history.
            do { try await Task.sleep(for: .milliseconds(40)) }
            catch { return }
            guard !Task.isCancelled, followingLatest, !draggingTranscript else { return }
            withAnimation(reduceMotion ? nil : MonsterChatMotion.conversation) {
                if let last = messages.last, last.card != nil,
                   latestRowHeight > transcriptHeight - 70 {
                    // Only oversized questions need a top anchor. Ordinary
                    // questions join the conversation without a jump upward.
                    proxy.scrollTo(last.id, anchor: .top)
                } else {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// Each newly visible correct verdict earns one flock. Queue fast answers so
    /// a later answer cannot cancel an earlier flight or lose its displayed time.
    private func celebrateAnswers(_ rewards: [MonsterAnswerReward]) {
        for reward in rewards where handledRewardIDs.insert(reward.id).inserted {
            pendingRewards.append(reward)
        }
        guard !reduceMotion, scenePhase == .active else {
            settleReward()
            return
        }
        startNextReward()
    }

    private func startNextReward() {
        guard rewardTask == nil, flyingCoins.isEmpty else { return }
        guard !pendingRewards.isEmpty else { reconcileCounterIfIdle(); return }
        let reward = pendingRewards.removeFirst()
        rewardTask = Task { @MainActor in
            // Let the user's answer bubble lay out and scroll into view first.
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            rewardStart = displayedAllowance
            rewardTarget = reward.totalSeconds
            flightOrigin = answerFrame
            rewardSerial += 1
            landedCoinIDs = []
            flyingCoins = QV2CoinModel.flock(of: 6, serial: rewardSerial)
            rewardTask = nil
        }
    }

    private func bankCoin(_ coin: QV2CoinModel) {
        guard flyingCoins.contains(where: { $0.id == coin.id }),
              landedCoinIDs.insert(coin.id).inserted else { return }
        let landed = landedCoinIDs.count
        QuizHaptics.coinLand(progress: Double(landed) / Double(coin.flockSize))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            // Retain fractional slices on the final coin so every correct
            // answer contributes exactly the session's frozen per-card rate.
            displayedAllowance = rewardStart + (rewardTarget - rewardStart) * landed / coin.flockSize
            coinsBanked += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            flyingCoins.removeAll { $0.id == coin.id }
            if flyingCoins.isEmpty { startNextReward() }
        }
    }

    private func reconcileCounterIfIdle() {
        guard !isCelebrating else { return }
        // The final grant replaces the pending total, including minute rounding.
        // It never spawns another flock or adds the same earnings a second time.
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            displayedAllowance = hasSettled ? max(0, allowanceSeconds) : (pendingStudySeconds ?? answerRewards.last?.totalSeconds ?? 0)
        }
    }

    private func settleReward() {
        rewardTask?.cancel()
        rewardTask = nil
        flyingCoins = []
        pendingRewards = []
        landedCoinIDs = []
        displayedAllowance = hasSettled ? max(0, allowanceSeconds) : (pendingStudySeconds ?? answerRewards.last?.totalSeconds ?? 0)
    }
}

private struct MonsterTranscriptScrollRequest: Equatable {
    let messageID: UUID?
    let height: CGFloat
}

private enum MonsterReplyPanelID: Hashable {
    case composer, finished
    case inquiry(UUID), study(UUID, Bool)
}

private struct MonsterLatestRowHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct MonsterTranscriptBottom: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
