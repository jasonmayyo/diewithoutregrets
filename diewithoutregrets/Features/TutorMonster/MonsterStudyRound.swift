import Foundation

enum MonsterStudyMethod: String, CaseIterable, Identifiable {
    case inChat
    case studySheet

    static let preferenceKey = "sg_monsterStudyMethod"
    static let defaultMethod: Self = .inChat
    var id: String { rawValue }
    var title: String { self == .studySheet ? "Study sheet" : "In chat" }

    static func selected(in defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? defaultMethod
    }
}

struct MonsterStudyQuestion: Identifiable, Equatable {
    let id = UUID()
    let card: Regret
}

struct MonsterStudyAnswer: Identifiable, Equatable {
    let id: UUID // question occurrence, including a new ID when revisiting a card
    let correct: Bool
    let text: String
    let choiceIndex: Int?
    var reaction: MonsterReaction? = nil
}

/// A finite, locally graded batch. Advancing requires an explicit Next tap.
struct MonsterStudyRound: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let questions: [MonsterStudyQuestion]
    let isFollowUp: Bool
    let freshCount: Int
    var index = 0
    var answers: [MonsterStudyAnswer] = []

    init(title: String, cards: [Regret], isFollowUp: Bool = false, freshCount: Int? = nil) {
        self.title = title
        self.questions = cards.map { MonsterStudyQuestion(card: $0) }
        self.isFollowUp = isFollowUp
        self.freshCount = freshCount ?? cards.count
    }

    var requiredCorrect: Int { Int(ceil(Double(questions.count) * 0.75)) }
    var correctCount: Int { answers.filter(\.correct).count }
    var isComplete: Bool { !questions.isEmpty && answers.count == questions.count }
    var currentQuestion: MonsterStudyQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    var currentAnswer: MonsterStudyAnswer? { answers.first { $0.id == currentQuestion?.id } }
    var cardDescription: String {
        let count = questions.count
        if !isFollowUp { return "\(count) flashcard\(count == 1 ? "" : "s")" }
        if freshCount == count { return "\(count) new card\(count == 1 ? "" : "s")" }
        if freshCount == 0 { return "\(count) card\(count == 1 ? "" : "s") to revisit" }
        return "\(freshCount) new · \(count - freshCount) to revisit"
    }
}

struct MonsterStudySummary: Equatable {
    let round: MonsterStudyRound
    let earnedSeconds: Int
}

enum MonsterStudySheetState {
    case offered, active, readyToUnlock, finished
}
