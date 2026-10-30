import Foundation

/// Phase 3 content enrichment for the Tutor Monster: a user-initiated "top up"
/// of weak / near-exam topics, and multiple-choice distractor backfill for typed
/// cards. Every path here is a DELIBERATE, user-triggered action — never silent
/// or background — so it respects the Worker's small generation budget, and it is
/// fully offline-safe: on any failure the user's decks are left exactly as they
/// were. None of this is on the unlock gate's critical path.
@MainActor
final class DeckEnrichment: ObservableObject {
    static let shared = DeckEnrichment()

    enum Phase: Equatable { case idle, generating, backfilling }
    enum Difficulty: String, CaseIterable { case easy, medium, hard }

    @Published private(set) var phase: Phase = .idle
    /// User-facing message for the last failed action, else nil.
    @Published var lastError: String?

    /// Small by default: a top-up should sip the generation budget, not drain it.
    static let defaultTopUpCount = 10

    private let client: FlashcardAPIClient
    private let deckStore: DeckStore

    init(client: FlashcardAPIClient? = nil, deckStore: DeckStore = .shared) {
        self.client = client ?? .shared
        self.deckStore = deckStore
    }

    var isWorking: Bool { phase != .idle }

    // MARK: - Topic top-up

    /// Generate fresh cards for `topic`, tag them, and append them to `deckID`.
    /// Returns the number of cards added (0 on any failure, with `lastError` set).
    @discardableResult
    func topUp(topic rawTopic: String, into deckID: UUID,
               difficulty: Difficulty = .medium,
               count: Int = DeckEnrichment.defaultTopUpCount,
               language: String = "English") async -> Int {
        let topic = rawTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty, phase == .idle,
              deckStore.decks.contains(where: { $0.id == deckID }) else { return 0 }
        phase = .generating
        lastError = nil
        defer { phase = .idle }
        do {
            let cards = try await client.generate(language: language, topic: topic,
                                                  difficulty: difficulty.rawValue, count: count)
            let regrets = cards.map { card in
                Regret(regretPrompt: card.regretPrompt, regret: card.regret,
                       choices: card.choices, correctAnswerIndex: card.correctAnswerIndex,
                       backgroundExplanation: card.backgroundExplanation,
                       topic: card.topic ?? topic)
            }
            // Re-read the deck after the await; the user may have changed it.
            guard !regrets.isEmpty, var deck = deckStore.decks.first(where: { $0.id == deckID }) else { return 0 }
            deck.cards.append(contentsOf: regrets)
            deckStore.updateDeck(deck)
            return regrets.count
        } catch {
            lastError = (error as? FlashcardServiceError)?.localizedDescription
                ?? "Couldn't generate new cards right now. Your deck is unchanged."
            return 0
        }
    }

    // MARK: - Multiple-choice distractor backfill

    /// Upgrade up to `limit` of the typed cards in `deckID` to multiple choice by
    /// generating distractors. Cards that can't be upgraded fairly (fewer than
    /// three usable distractors) are left as typed. Returns the number upgraded.
    @discardableResult
    func backfillDistractors(in deckID: UUID,
                             limit: Int = 50, // matches the server MAX_DISTRACTOR_CARDS / FlashcardAPIClient.maximumCards
                             language: String = "English") async -> Int {
        guard phase == .idle, let deck = deckStore.decks.first(where: { $0.id == deckID }) else { return 0 }
        // Match the server's per-card caps (prompt <= 500, answer <= 200): an oversized
        // card would 400 the whole batch, so skip it — it simply stays typed.
        let typed = deck.cards.filter { (card: Regret) -> Bool in
            guard card.answerMode == .typed else { return false }
            return card.regretPrompt.utf16.count <= 500 && card.correctAnswer.utf16.count <= 200
        }
        let cardsToUpgrade = Array(typed.prefix(limit))
        guard !cardsToUpgrade.isEmpty else { return 0 }
        phase = .backfilling
        lastError = nil
        defer { phase = .idle }
        let inputs = cardsToUpgrade.map { (prompt: $0.regretPrompt, answer: $0.correctAnswer) }
        do {
            let sets = try await client.generateDistractors(for: inputs, language: language)
            guard sets.count == cardsToUpgrade.count,
                  var fresh = deckStore.decks.first(where: { $0.id == deckID }) else { return 0 }
            var upgraded = 0
            for (i, original) in cardsToUpgrade.enumerated() {
                guard let index = fresh.cards.firstIndex(where: { $0.id == original.id }),
                      fresh.cards[index].answerMode == .typed,
                      let promoted = fresh.cards[index].promotedToChoices(with: sets[i]) else { continue }
                fresh.cards[index] = promoted
                upgraded += 1
            }
            if upgraded > 0 { deckStore.updateDeck(fresh) }
            return upgraded
        } catch {
            lastError = (error as? FlashcardServiceError)?.localizedDescription
                ?? "Couldn't add answer options right now. Your cards are unchanged."
            return 0
        }
    }

    // MARK: - Candidate analysis (pure, no network)

    /// Topics of the nearest exam that are thin or weak across the user's decks,
    /// weakest first — the natural top-up candidates to surface. A topic with no
    /// cards at all counts as maximally weak.
    static func examTopUpTopics(exam: StudyExam?, decks: [Deck], now: Date = Date(),
                                weaknessThreshold: Double = 0.4, thinThreshold: Int = 6) -> [String] {
        guard let exam else { return [] }
        let linked = StudyMaterialLinks.decks(for: exam, in: decks)
        guard !linked.isEmpty else { return [] }
        let allCards: [Regret] = linked.flatMap { $0.cards }
        struct Candidate { let topic: String; let weakness: Double; let count: Int }
        var candidates: [Candidate] = []
        for topic in exam.topics {
            let cards = allCards.filter { $0.topic == topic }
            let weakCount = cards.filter { $0.isWeak || $0.isDue(asOf: now) }.count
            let weakness = cards.isEmpty ? 1.0 : Double(weakCount) / Double(cards.count)
            if cards.count < thinThreshold || weakness >= weaknessThreshold {
                candidates.append(Candidate(topic: topic, weakness: weakness, count: cards.count))
            }
        }
        candidates.sort { lhs, rhs in
            lhs.weakness != rhs.weakness ? lhs.weakness > rhs.weakness : lhs.count < rhs.count
        }
        return candidates.map { $0.topic }
    }

    /// The deck best suited to receive cards for `topic`: the one already holding
    /// the most cards for it, else the selected deck, else the first deck.
    func targetDeckID(forTopic topic: String, exam: StudyExam? = nil) -> UUID? {
        if let exam {
            return StudyMaterialLinks.topUpDeck(for: topic, exam: exam, decks: deckStore.decks,
                                               selectedID: deckStore.selectedDeck?.id)
        }
        let byTopic = deckStore.decks
            .map { (id: $0.id, count: $0.cards.filter { $0.topic == topic }.count) }
            .filter { $0.count > 0 }
            .max { $0.count < $1.count }?.id
        return byTopic ?? deckStore.selectedDeck?.id ?? deckStore.decks.first?.id
    }
}
