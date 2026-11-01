//
//  MonsterMessage.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 1): the chat transcript model. A monster-chat session is
//  a list of these; MonsterChatView renders them and MonsterSession drives them.
//  See Docs/TutorMonsterPlan.md §6i.
//

import Foundation
import Combine

/// Presentation-only punctuation, shared by live replies and restored history.
/// Keep the source text intact for saved cards, submitted answers and grading.
enum MonsterDisplayCopy {
    static func text(_ source: String) -> String {
        guard source.contains("\u{2014}") else { return source }
        let withoutLeadingDash = source.replacingOccurrences(
            of: "(?m)^[\\t ]*\u{2014}[\\t ]*", with: "", options: .regularExpression)
        return withoutLeadingDash.replacingOccurrences(
            of: "[\\t ]*\u{2014}[\\t ]*", with: ", ", options: .regularExpression)
    }
}

/// Presentation owns a cursor, not the session. Hiding chat cancels the current
/// beat; returning restarts that beat rather than consuming time spent away.
@MainActor
final class MonsterTranscriptPresenter: ObservableObject {
    @Published private(set) var revealed = 0
    @Published private(set) var isTyping = false
    private(set) var isVisible = false
    private var messages: [MonsterMessage] = []
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private let sleep: (Duration) async throws -> Void
    private let onMonsterMessage: (MonsterMessage) -> Void

    init(sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
         onMonsterMessage: @escaping (MonsterMessage) -> Void = { _ in }) {
        self.sleep = sleep
        self.onMonsterMessage = onMonsterMessage
    }

    func update(messages: [MonsterMessage], isVisible: Bool) {
        self.messages = messages
        self.isVisible = isVisible
        guard isVisible else { pause(); return }
        guard task == nil, revealed < messages.count else { return }
        let token = UUID()
        generation = token
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.canContinue(token), self.revealed < self.messages.count {
                let next = self.messages[self.revealed]
                let previous = self.revealed > 0 ? self.messages[self.revealed - 1] : nil
                let pacing = MonsterMessagePacing.before(next, after: previous)
                self.isTyping = false
                do {
                    if pacing.readingPause > 0 {
                        try await self.sleep(.seconds(pacing.readingPause))
                    }
                    guard self.canContinue(token) else { return }
                    if pacing.typingDuration > 0 {
                        self.isTyping = true
                        try await self.sleep(.seconds(pacing.typingDuration))
                    }
                } catch {
                    // A cancelled older task must never clear a newer task.
                    if self.generation == token { self.task = nil; self.isTyping = false }
                    return
                }
                guard self.canContinue(token) else { return }
                self.isTyping = false
                self.revealed += 1
                // Arrival feedback belongs to the visible turn, never a row's
                // onAppear (which can run again when scrolling or returning).
                if next.sender == .monster { self.onMonsterMessage(next) }
            }
            guard self.generation == token else { return }
            self.isTyping = false
            self.task = nil
        }
    }

    func pause() {
        isVisible = false
        generation = UUID()
        task?.cancel()
        task = nil
        isTyping = false
    }

    /// Reset a replaced round, or keep existing history visible when switching
    /// decks. Cancels any old typing beat without replaying arrival feedback.
    func restoreHistory(_ messages: [MonsterMessage]) {
        pause()
        self.messages = messages
        revealed = messages.count
    }

    private func canContinue(_ token: UUID) -> Bool {
        isVisible && generation == token && !Task.isCancelled
    }

    deinit { task?.cancel() }
}

/// Old choices are never presented as input while an incoming turn is queued.
enum MonsterInlineReplyPhase: Equatable {
    case introduction, waiting(UUID), answering(UUID), complete

    static func current(messages: [MonsterMessage], replyTarget: MonsterReplyTarget?,
                        isFinished: Bool) -> Self {
        if isFinished { return .complete }
        if let replyTarget { return .answering(replyTarget.messageID) }
        if let last = messages.last(where: { $0.card != nil }) { return .waiting(last.id) }
        return .introduction
    }
}

/// Presentation timing only. The session still grades and grants locally without
/// waiting for animation. A buffered turn is revealed one message at a time.
struct MonsterMessagePacing {
    let readingPause: TimeInterval
    let typingDuration: TimeInterval

    static func before(_ message: MonsterMessage, after previous: MonsterMessage?) -> Self {
        // A sent answer or follow-up should appear as soon as the user sends it.
        guard message.sender != .user else { return Self(readingPause: 0, typingDuration: 0) }
        let readingPause: TimeInterval
        if let previous, previous.sender != .user {
            readingPause = min(2.4, 0.6 + Double(readableLength(previous)) * 0.012)
        } else {
            readingPause = 0
        }
        let typingDuration: TimeInterval
        switch message.kind {
        case .text, .card, .reveal:
            typingDuration = message.sender == .monster
                ? min(2.0, 1.2 + Double(readableLength(message)) * 0.008) : 0
        case .grant, .studyRound, .studyRecap:
            typingDuration = 0 // an allowance update is not a spoken reply
        }
        return Self(readingPause: readingPause, typingDuration: typingDuration)
    }

    private static func readableLength(_ message: MonsterMessage) -> Int {
        switch message.kind {
        case .text(let text): return text.count
        case .card(let card): return card.quizPrompt.text.count
        case .reveal(let correct, let answer, let why):
            return correct ? "Correct".count : answer.count + (why?.count ?? 0) + 14
        case .grant, .studyRound, .studyRecap: return 0
        }
    }
}

/// Visible progress follows local verdicts, not queued messages or AI replies.
/// Repeated attempts at one card never increase the round's total.
struct MonsterRoundProgress: Equatable {
    let total: Int
    let completed: Int

    init(messages: [MonsterMessage], total: Int, requiresCorrectAnswers: Bool) {
        self.total = max(0, total)
        var currentCard: UUID?
        var completedCards: Set<UUID> = []
        for message in messages {
            switch message.kind {
            case .card(let card): currentCard = card.id
            case .reveal(let correct, _, _):
                if let currentCard, correct || !requiresCorrectAnswers {
                    completedCards.insert(currentCard)
                }
                currentCard = nil
            default: break
            }
        }
        completed = min(self.total, completedCards.count)
    }

    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
}

/// Display rewards come only from local correct-answer verdicts. Message IDs
/// identify attempts, so re-rendering or scrolling cannot earn the same time twice.
/// This projection has no authority to grant or unlock anything.
struct MonsterAnswerReward: Identifiable, Equatable {
    let id: UUID
    let totalSeconds: Int

    static func earned(in messages: [MonsterMessage], secondsPerCorrectAnswer: Int) -> [Self] {
        guard secondsPerCorrectAnswer > 0 else { return [] }
        var seen: Set<UUID> = []
        var total = 0
        return messages.compactMap { message in
            guard case .reveal(correct: true, _, _) = message.kind,
                  seen.insert(message.id).inserted else { return nil }
            total = min(SGContract.maxEarnedMinutes * 60, total + secondsPerCorrectAnswer)
            return Self(id: message.id, totalSeconds: total)
        }
    }
}

/// Replies bind to the message occurrence, not the card ID: a missed card can
/// appear again later, and an earlier occurrence must never accept the new reply.
struct MonsterReplyTarget {
    let messageID: UUID
    let card: Regret

    static func current(messages: [MonsterMessage], revealed: Int,
                        activeCard: Regret?, isThinking: Bool) -> MonsterReplyTarget? {
        guard !isThinking, revealed >= messages.count,
              let activeCard, let last = messages.last(where: { $0.card != nil }),
              case let .card(card) = last.kind, card.id == activeCard.id else { return nil }
        return MonsterReplyTarget(messageID: last.id, card: card)
    }
}

/// Reading order of the six poses in each bundled 3-column, 2-row atlas.
enum MonsterExpression: Int, CaseIterable {
    case welcome, thinking, correct, retry, firm, celebrating

    static func idle(for mood: SGContract.MonsterMood) -> MonsterExpression {
        switch mood {
        case .chill: return .welcome
        case .nudgy: return .thinking
        case .annoyed: return .retry
        case .fedUp, .feral: return .firm
        }
    }
}

/// The material behind this round, shown separately from spoken messages.
struct MonsterStudySource: Identifiable, Equatable {
    enum Kind: String { case pdf, notes, youtube, quizlet, deck }
    let kind: Kind
    let title: String
    var id: String { kind.rawValue + ":" + title.lowercased() }

    var symbol: String {
        switch kind {
        case .pdf: return "doc.richtext"
        case .notes: return "note.text"
        case .youtube: return "play.rectangle"
        case .quizlet, .deck: return "rectangle.on.rectangle"
        }
    }

    var typeLabel: String {
        switch kind {
        case .pdf: return "PDF"
        case .notes: return "Notes"
        case .youtube: return "Video"
        case .quizlet: return "Quizlet"
        case .deck: return "Flashcard deck"
        }
    }

    static func selected(cards: [Regret], deckName: String?) -> [Self] {
        func label(_ raw: String?, fallback: String) -> String {
            let clean = raw?.split(whereSeparator: \.isWhitespace).joined(separator: " ") ?? ""
            return clean.isEmpty ? fallback : String(clean.prefix(160))
        }
        var sources: [Self] = []
        for card in cards {
            let entry: Self
            if let source = card.source {
                switch source.kind {
                case .pdf: entry = Self(kind: .pdf, title: label(source.title, fallback: "Uploaded PDF"))
                case .notes: entry = Self(kind: .notes, title: label(source.title, fallback: "Pasted notes"))
                case .youtube: entry = Self(kind: .youtube, title: label(source.title, fallback: "YouTube video"))
                case .quizlet: entry = Self(kind: .quizlet, title: label(source.title, fallback: "Imported Quizlet set"))
                }
            } else {
                entry = Self(kind: .deck, title: label(deckName, fallback: "Saved flashcards"))
            }
            if !sources.contains(where: { $0.id == entry.id }) { sources.append(entry) }
        }
        return sources
    }
}

/// One entry in the monster-chat transcript.
struct MonsterMessage: Identifiable, Equatable {
    enum Sender: Equatable { case monster, user, system }

    enum Kind: Equatable {
        /// A spoken line (monster, user echo, or a system note).
        case text(String)
        /// A flashcard the user must answer, rendered inline in the chat.
        case card(Regret)
        /// The post-answer verdict: whether it was right, the correct answer, and the "Why".
        case reveal(correct: Bool, answer: String, why: String?)
        /// The unlock payoff.
        case grant(minutes: Int)
        case studyRound(MonsterStudyRound)
        case studyRecap(MonsterStudySummary)
    }

    let id: UUID
    let sender: Sender
    var kind: Kind
    let createdAt: Date
    let reaction: MonsterReaction?
    let sources: [MonsterStudySource]

    init(id: UUID = UUID(), sender: Sender, kind: Kind, createdAt: Date = Date(),
         reaction: MonsterReaction? = nil, sources: [MonsterStudySource] = []) {
        self.id = id
        self.sender = sender
        self.kind = kind
        self.createdAt = createdAt
        if sender == .monster, case .text = kind {
            self.reaction = reaction
            self.sources = sources
        } else {
            self.reaction = nil
            self.sources = []
        }
    }

    // Convenience builders for the common text lines.
    static func monster(_ text: String, reaction: MonsterReaction? = nil,
                        sources: [MonsterStudySource] = []) -> MonsterMessage {
        .init(sender: .monster, kind: .text(text), reaction: reaction, sources: sources)
    }
    static func user(_ text: String) -> MonsterMessage { .init(sender: .user, kind: .text(text)) }
    static func system(_ text: String) -> MonsterMessage { .init(sender: .system, kind: .text(text)) }

    /// The plain text of a `.text` message, else nil.
    var text: String? {
        if case let .text(t) = kind { return t }
        return nil
    }

    /// The card of a `.card` message, else nil.
    var card: Regret? {
        if case let .card(c) = kind { return c }
        return nil
    }
}
