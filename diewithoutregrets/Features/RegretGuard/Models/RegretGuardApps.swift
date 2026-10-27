//
//  RegretGuardApps.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct Deck: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var cards: [Regret]
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, cards: [Regret] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.cards = cards
        self.createdAt = createdAt
    }
}

/// How a card asks for its answer in the quiz.
enum AnswerMode: String, Codable, Equatable {
    /// Tap one of several options (the original card type).
    case choices
    /// Type the answer from memory. The card stores the correct answer as
    /// its single choice, so every legacy surface still finds it at
    /// `choices[correctAnswerIndex]`.
    case typed
}

struct Regret: Identifiable, Codable, Equatable {
    let id: UUID
    var regretPrompt: String
    var regret: String
    let createdAt: Date
    var choices: [String]
    var correctAnswerIndex: Int
    var backgroundExplanation: String
    var answerMode: AnswerMode

    // MARK: Mastery (Leitner) + topic — Phase 0 foundation for the tutor-monster
    // selection engine. All defaulted so pre-existing saved cards decode unchanged
    // (see init(from:) and the memberwise init).
    /// Leitner box 1...5. 1 = weak/just-missed (seen often), 5 = mastered (seen rarely).
    var box: Int
    /// Lifetime times this card has been answered in a graded session.
    var timesSeen: Int
    /// Lifetime correct answers.
    var timesCorrect: Int
    /// When the card was last answered.
    var lastReviewedAt: Date?
    /// When the card next becomes due for review (nil = due now / never reviewed).
    var nextDueAt: Date?
    /// Subject/topic tag, used for weakness aggregation and exam weighting.
    var topic: String?

    /// The canonical correct answer text, valid for both modes.
    var correctAnswer: String {
        choices.indices.contains(correctAnswerIndex) ? choices[correctAnswerIndex] : ""
    }

    /// Older generated decks may store the question in `regret` and
    /// left the prompt as N/A. Recover only recognizable questions here:
    /// `regret` also stores answers, so using it blindly would reveal them.
    var quizPrompt: FlashcardPrompt {
        if !FlashcardPrompt.isPlaceholder(regretPrompt) {
            return FlashcardPrompt(regretPrompt)
        }
        let legacy = FlashcardPrompt(regret)
        let isAnswer = choices.contains { AnswerGrading.matches(regret, $0) }
        if !FlashcardPrompt.isPlaceholder(regret), !isAnswer,
           legacy.hasBlank || legacy.text.last.map({ "?？؟".contains($0) }) == true {
            return legacy
        }
        return FlashcardPrompt("Choose the correct answer.")
    }

    // MARK: Mastery helpers (Leitner spaced repetition)

    static let maxBox = 5
    static let weakBoxThreshold = 2

    /// 0 (brand new / just missed) ... 1 (mastered). Drives selection weighting.
    var masteryStrength: Double {
        Double(min(Self.maxBox, max(1, box)) - 1) / Double(Self.maxBox - 1)
    }

    /// A card the student keeps getting wrong or hasn't locked in yet.
    var isWeak: Bool { box <= Self.weakBoxThreshold }

    /// Lifetime accuracy, 0 when never seen.
    var accuracy: Double {
        timesSeen > 0 ? Double(timesCorrect) / Double(timesSeen) : 0
    }

    /// Due for review as of `now` (never-reviewed cards are always due).
    func isDue(asOf now: Date = Date()) -> Bool {
        guard let nextDueAt else { return true }
        return nextDueAt <= now
    }

    /// Days until a card in `box` is next due (Leitner intervals).
    static func leitnerIntervalDays(forBox box: Int) -> Int {
        switch box {
        case ...1: return 0   // missed or brand new: see again today
        case 2: return 1
        case 3: return 3
        case 4: return 7
        default: return 16
        }
    }

    /// Record a graded answer, moving the card through the Leitner boxes.
    /// Correct promotes one box (capped at `maxBox`); wrong resets to box 1.
    mutating func recordReview(correct: Bool, now: Date = Date()) {
        timesSeen += 1
        if correct {
            timesCorrect += 1
            box = min(Self.maxBox, max(1, box) + 1)
        } else {
            box = 1
        }
        lastReviewedAt = now
        let days = Self.leitnerIntervalDays(forBox: box)
        nextDueAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
    }

    init(id: UUID = UUID(),
         regretPrompt: String,
         regret: String,
         createdAt: Date = Date(),
         choices: [String],
         correctAnswerIndex: Int,
         backgroundExplanation: String,
         answerMode: AnswerMode = .choices,
         box: Int = 1,
         timesSeen: Int = 0,
         timesCorrect: Int = 0,
         lastReviewedAt: Date? = nil,
         nextDueAt: Date? = nil,
         topic: String? = nil) {
        self.id = id
        self.regretPrompt = regretPrompt
        self.regret = regret
        self.createdAt = createdAt
        self.choices = choices
        self.correctAnswerIndex = correctAnswerIndex
        self.backgroundExplanation = backgroundExplanation
        self.answerMode = answerMode
        self.box = box
        self.timesSeen = timesSeen
        self.timesCorrect = timesCorrect
        self.lastReviewedAt = lastReviewedAt
        self.nextDueAt = nextDueAt
        self.topic = topic
    }

    // Cards persisted before answerMode existed decode as .choices.
    // Mastery/topic fields are absent on older saves and default via decodeIfPresent.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        regretPrompt = try c.decode(String.self, forKey: .regretPrompt)
        regret = try c.decode(String.self, forKey: .regret)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        choices = try c.decode([String].self, forKey: .choices)
        correctAnswerIndex = try c.decode(Int.self, forKey: .correctAnswerIndex)
        backgroundExplanation = try c.decode(String.self, forKey: .backgroundExplanation)
        answerMode = try c.decodeIfPresent(AnswerMode.self, forKey: .answerMode) ?? .choices
        box = try c.decodeIfPresent(Int.self, forKey: .box) ?? 1
        timesSeen = try c.decodeIfPresent(Int.self, forKey: .timesSeen) ?? 0
        timesCorrect = try c.decodeIfPresent(Int.self, forKey: .timesCorrect) ?? 0
        lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        nextDueAt = try c.decodeIfPresent(Date.self, forKey: .nextDueAt)
        topic = try c.decodeIfPresent(String.self, forKey: .topic)
    }
}

/// Only an explicit blank makes a card a fill-in-the-blank exercise. Ordinary
/// questions, typed prompts and imported terms must not gain an appended blank.
struct FlashcardPrompt {
    enum Part: Equatable {
        case text(String)
        case blank
        case answer(String)
    }

    let text: String
    private let blankRange: Range<String.Index>?
    var hasBlank: Bool { blankRange != nil }

    init(_ text: String) {
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept older underscore lengths, but never fill several blanks with
        // a single answer or invent context for a bare placeholder.
        if let range = self.text.range(of: "_{2,}", options: .regularExpression),
           self.text[range.upperBound...].range(of: "_{2,}", options: .regularExpression) == nil,
           self.text.replacingCharacters(in: range, with: "").rangeOfCharacter(from: .alphanumerics) != nil {
            blankRange = range
        } else {
            blankRange = nil
        }
    }

    func parts(revealing answer: String? = nil) -> [Part] {
        guard let blankRange else { return [.text(text)] }
        var parts: [Part] = []
        let prefix = String(text[..<blankRange.lowerBound])
        let suffix = String(text[blankRange.upperBound...])
        if !prefix.isEmpty { parts.append(.text(prefix)) }
        parts.append(answer.map { .answer($0) } ?? .blank)
        if !suffix.isEmpty { parts.append(.text(suffix)) }
        return parts
    }

    static func isPlaceholder(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || ["n/a", "n / a", "not applicable", "null", "undefined"].contains(normalized)
    }
}

/// Grading for typed answers: strict equality after normalization. The quiz
/// gates real screen time, so no fuzzy matching — but nobody should fail on
/// casing, accents, stray spaces, smart quotes or a trailing period.
enum AnswerGrading {
    static func matches(_ input: String, _ expected: String) -> Bool {
        let a = normalize(input)
        return !a.isEmpty && a == normalize(expected)
    }

    static func normalize(_ s: String) -> String {
        var t = s
            .replacingOccurrences(of: "[\u{2018}\u{2019}\u{02BC}]", with: "'", options: .regularExpression)
            .replacingOccurrences(of: "[\u{201C}\u{201D}]", with: "\"", options: .regularExpression)
            .replacingOccurrences(of: "[\u{2013}\u{2014}]", with: "-", options: .regularExpression)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
        // Collapse all whitespace runs (including pasted newlines) to single spaces.
        t = t.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // A single trailing sentence mark never fails a card.
        while let last = t.last, ".?!".contains(last) {
            t.removeLast()
        }
        return t.trimmingCharacters(in: .whitespaces)
    }
}

extension Regret {
    static let regrets: [Regret] = [
        Regret(
            regretPrompt: "Not spending enough time with family",
            regret: "Not spending enough time with the people I love",
            choices: ["Option 1", "Option 2", "Option 3", "Option 4"],
            correctAnswerIndex: 0,
            backgroundExplanation: "Studies show people who prioritize family time report higher life satisfaction and lower end-of-life regrets."
        ),
        // Add other entries with background explanations
    ]
}

// MARK: - Deck mastery aggregation (tutor-monster foundation)

extension Deck {
    /// Distinct non-empty topics present in the deck, in first-seen order.
    var topics: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for t in cards.compactMap({ $0.topic }) where !t.isEmpty && seen.insert(t).inserted {
            out.append(t)
        }
        return out
    }

    /// Fraction of cards mastered (above the weak threshold). 0 when empty.
    var masteryFraction: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(cards.filter { !$0.isWeak }.count) / Double(cards.count)
    }

    /// Weak or overdue cards, worst first (lowest box, then longest overdue).
    func weakCards(asOf now: Date = Date()) -> [Regret] {
        cards.filter { $0.isWeak || $0.isDue(asOf: now) }
            .sorted { lhs, rhs in
                lhs.box != rhs.box
                    ? lhs.box < rhs.box
                    : (lhs.nextDueAt ?? .distantPast) < (rhs.nextDueAt ?? .distantPast)
            }
    }

    /// Per-topic weakness 0...1 (1 = every card weak/overdue). Untagged → "".
    func topicWeakness(asOf now: Date = Date()) -> [String: Double] {
        var total: [String: Int] = [:]
        var weak: [String: Int] = [:]
        for card in cards {
            let key = card.topic ?? ""
            total[key, default: 0] += 1
            if card.isWeak || card.isDue(asOf: now) { weak[key, default: 0] += 1 }
        }
        return total.reduce(into: [String: Double]()) { acc, pair in
            acc[pair.key] = pair.value > 0 ? Double(weak[pair.key] ?? 0) / Double(pair.value) : 0
        }
    }
}

// MARK: - Weighted card selection (tutor-monster unlock)

/// Replaces the plain random shuffle: favors weak/overdue cards and (when
/// provided) topics tied to the nearest exam, while keeping variety so a session
/// never feels like the same cards. Pure and deterministic given `rng`; falls
/// back to difficulty-blind random for brand-new decks with no history.
/// Phase 0 ships the engine; the live draw is switched over in Phase 1.
enum CardSelection {
    static func pick<G: RandomNumberGenerator>(
        from cards: [Regret],
        count: Int,
        examTopics: Set<String> = [],
        now: Date = Date(),
        using rng: inout G
    ) -> [Regret] {
        guard count > 0 else { return [] }
        guard cards.count > count else { return cards.shuffled(using: &rng) }

        func weight(_ card: Regret) -> Double {
            var w = 1.0
            w += (1.0 - card.masteryStrength) * 2.0                     // weakness
            if card.isDue(asOf: now) { w += 1.0 }                       // spaced repetition
            if let t = card.topic, examTopics.contains(t) { w += 1.5 }  // exam proximity
            return w
        }

        // Efraimidis-Spirakis weighted sampling without replacement.
        return cards
            .map { card -> (Regret, Double) in
                let u = Double.random(in: 1e-9...1, using: &rng)
                return (card, pow(u, 1.0 / max(weight(card), 0.0001)))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(count)
            .map(\.0)
    }

    static func pick(
        from cards: [Regret],
        count: Int,
        examTopics: Set<String> = [],
        now: Date = Date()
    ) -> [Regret] {
        var rng = SystemRandomNumberGenerator()
        return pick(from: cards, count: count, examTopics: examTopics, now: now, using: &rng)
    }
}

// MARK: - Exams (multi-exam model, replaces the single onboarding date)

/// An upcoming exam: subject + date + the topics it covers. The tutor monster
/// uses the nearest exam to drive pressure and topic weighting, and names it.
struct StudyExam: Identifiable, Codable, Equatable {
    let id: UUID
    var subject: String
    var date: Date
    var topics: [String]
    var createdAt: Date

    init(id: UUID = UUID(), subject: String, date: Date,
         topics: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.subject = subject
        self.date = date
        self.topics = topics
        self.createdAt = createdAt
    }

    /// Whole days from `now` until the exam (negative once it has passed).
    func daysUntil(from now: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day],
                                from: calendar.startOfDay(for: now),
                                to: calendar.startOfDay(for: date)).day ?? 0
    }

    var isUpcoming: Bool { daysUntil() >= 0 }
}

// MARK: - Monster personas (selectable tutor personalities)

/// A selectable tutor-monster personality — tone/voice only, never a real-world
/// demographic caricature. Referenced everywhere by `id`, so renaming is cheap.
struct MonsterPersona: Identifiable, Equatable {
    let id: String          // stable key; display names can change freely
    let name: String
    let tagline: String
    let accentHex: String   // per-persona accent color

    static let diva    = MonsterPersona(id: "diva",    name: "Zaza",   tagline: "sassy hype bestie", accentHex: "#FF2D95")
    static let willow  = MonsterPersona(id: "willow",  name: "Willow", tagline: "warm and calm",     accentHex: "#8FBF9F")
    static let coach   = MonsterPersona(id: "coach",   name: "Sarge",  tagline: "tough-love drill",  accentHex: "#2F6BFF")
    static let gremlin = MonsterPersona(id: "gremlin", name: "Gnash",  tagline: "chaotic menace",    accentHex: "#A6FF2D")

    /// Onboarding order (gentle first so it reads as the safe pick).
    static let all: [MonsterPersona] = [willow, diva, coach, gremlin]
    /// Safe default if onboarding is skipped.
    static let fallback = willow

    static func with(id: String?) -> MonsterPersona {
        all.first { $0.id == id } ?? fallback
    }
}
