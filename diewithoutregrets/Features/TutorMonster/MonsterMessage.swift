//
//  MonsterMessage.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 1): the chat transcript model. A monster-chat session is
//  a list of these; MonsterChatView renders them and MonsterSession drives them.
//  See Docs/TutorMonsterPlan.md §6i.
//

import Foundation

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
        /// A persona reaction sticker: an asset-catalog image name + an accessibility label.
        case media(asset: String, label: String)
    }

    let id: UUID
    let sender: Sender
    var kind: Kind
    let createdAt: Date

    init(id: UUID = UUID(), sender: Sender, kind: Kind, createdAt: Date = Date()) {
        self.id = id
        self.sender = sender
        self.kind = kind
        self.createdAt = createdAt
    }

    // Convenience builders for the common text lines.
    static func monster(_ text: String) -> MonsterMessage { .init(sender: .monster, kind: .text(text)) }
    static func user(_ text: String) -> MonsterMessage { .init(sender: .user, kind: .text(text)) }
    static func system(_ text: String) -> MonsterMessage { .init(sender: .system, kind: .text(text)) }
    static func sticker(_ asset: String, label: String) -> MonsterMessage { .init(sender: .monster, kind: .media(asset: asset, label: label)) }

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
