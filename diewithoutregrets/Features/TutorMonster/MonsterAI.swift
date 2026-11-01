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

/// Explicit preferences, shared by onboarding, Profile and live tutor requests.
/// No gender is inferred from a name, pronoun choice or selected monster.
struct BuddyIdentity: Equatable {
    static let nameKey = "sg_buddyName"
    static let pronounsKey = "sg_buddyPronouns"
    static let genderKey = "sg_buddyGender"
    static let ruleKey = "sg_buddyRuleConfirmed"
    var name = ""
    var pronouns = "Just my name"
    var gender: String? = nil

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(name: defaults.string(forKey: nameKey) ?? "",
             pronouns: defaults.string(forKey: pronounsKey) ?? "Just my name",
             gender: defaults.string(forKey: genderKey))
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(Self.clean(name, limit: 30), forKey: Self.nameKey)
        defaults.set(Self.clean(pronouns, limit: 40), forKey: Self.pronounsKey)
        if let gender { defaults.set(Self.clean(gender, limit: 40), forKey: Self.genderKey) }
        else { defaults.removeObject(forKey: Self.genderKey) }
    }

    static func clean(_ text: String, limit: Int) -> String {
        String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(limit))
    }

    /// Uses the existing request contract so deployed tutor servers need no migration.
    /// This is user preference data alongside the question, not system authority.
    func tutorQuestion(_ question: String) -> String {
        guard !name.isEmpty else { return question }
        let genderContext = gender.map { " My gender is \(Self.clean($0, limit: 40))." } ?? ""
        let context = "My preferred name is \(Self.clean(name, limit: 30)); my preference for how to refer to me is \(Self.clean(pronouns, limit: 40)).\(genderContext) Avoid gendered nicknames. My study question: "
        var result = context + question
        while result.utf16.count > 1000 { result.removeLast() }
        return result
    }

    /// Only scripted banter passes here; saved card content is never rewritten.
    func addressBanter(_ text: String) -> String {
        guard !name.isEmpty else { return text }
        return text.replacingOccurrences(of: "\\b(girl|sister|bro|dude|man)\\b", with: "friend",
            options: [.regularExpression, .caseInsensitive])
    }
}

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
