// Infrastructure fakes for host-free tests. The card model, transport, session,
// script banks, and reply-target selection compile directly from production files.
import SwiftUI
final class DeckStore {
    static let shared = DeckStore()
    var selectedDeck: Deck?
    var recorded: [UUID: Bool] = [:]
    var reviewWrites: [(deckID: UUID, outcomes: [UUID: Bool])] = []
    func recordOutcomes(_ outcomes: [UUID: Bool], deckID: UUID) {
        recorded = outcomes
        reviewWrites.append((deckID, outcomes))
    }
}
final class ExamStore {
    static let shared = ExamStore()
    var exams: [StudyExam] = []
    var nextExam: StudyExam? {
        get { exams.filter(\.isUpcoming).min { $0.date < $1.date } }
        set { exams = newValue.map { [$0] } ?? [] }
    }
}
final class PersonaStore { static let shared = PersonaStore(); var persona = MonsterPersona.willow }
final class StudyGuardManager {
    static let shared = StudyGuardManager()
    var grants = 0
    func grantEarnedBudget(results: [Bool?], perCardSeconds: Int) -> Int {
        grants += 1
        return SGContract.completedQuizMinutes(results: results, perCardSeconds: perCardSeconds)
    }
}
enum QV2Streak { static func recordSuccess() -> Bool { true } }
enum MonsterNudges { static func rescheduleAfterStudy(persona: MonsterPersona) {} }
