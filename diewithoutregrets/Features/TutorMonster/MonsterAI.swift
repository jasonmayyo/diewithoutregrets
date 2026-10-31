//
//  MonsterAI.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 2): the LIVE AI voice. One call per unlock fetches a
//  personalized session-script bundle from the Worker (reusing the flashcard
//  App Attest flow). It is strictly best-effort: on ANY failure
//  (offline, timeout, error, unsupported, unconfigured) it returns nil and the
//  session uses the offline scripted banks. The session starts before this request.
//  See Docs/TutorMonsterPlan.md §6f.
//

import Foundation

/// A personalized set of persona lines for one unlock session, from the Worker.
struct MonsterScriptBundle: Decodable {
    let greeting: String
    let demand: String
    let reason: String
    let correct: [String]
    let wrong: [String]
    let pass: String
    let fail: String
    let sendoff: String

    var isValid: Bool {
        let line: (String) -> Bool = { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf16.count <= 300 }
        return [greeting, demand, reason, pass, fail, sendoff].allSatisfy(line)
            && (1...6).contains(correct.count) && correct.allSatisfy(line)
            && (1...6).contains(wrong.count) && wrong.allSatisfy(line)
    }
}

struct MonsterTutorCard: Encodable {
    let prompt: String
    let answer: String
    let explanation: String

    init(_ card: Regret) {
        func bounded(_ value: String) -> String {
            var result = String(value.prefix(4000))
            while result.utf16.count > 4000 { result.removeLast() }
            return result
        }
        prompt = bounded(card.quizPrompt.text)
        answer = bounded(card.correctAnswer)
        explanation = bounded(card.backgroundExplanation)
    }
}

struct MonsterTutorTurn: Encodable {
    let question: String
    let reply: String
}

/// The app-observable context sent to the Worker to personalize the bundle.
struct MonsterScriptContext: Encodable {
    let persona: String      // persona id (diva/willow/coach/gremlin)
    let mood: String         // mood case name (chill/nudgy/annoyed/fedUp/feral)
    let app: String
    let gateCount: Int
    let exam: String?
    let examDays: Int?
    let topic: String?
    let questions: Int
    let minutes: Int
}

enum MonsterAI {
    /// Optional voice enrichment. The session starts locally and never awaits it.
    @MainActor
    static func fetchBundle(persona: MonsterPersona,
                            mood: SGContract.MonsterMood,
                            vars: MonsterScriptVars) async -> MonsterScriptBundle? {
        let context = MonsterScriptContext(
            persona: persona.id, mood: String(describing: mood), app: vars.app,
            gateCount: vars.count, exam: vars.exam, examDays: vars.examDays,
            topic: vars.topic, questions: vars.questions, minutes: vars.minutes
        )
        return try? await FlashcardAPIClient.shared.generateScript(context)
    }
}
