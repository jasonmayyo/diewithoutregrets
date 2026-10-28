//
//  MonsterAI.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 2): the LIVE AI voice. One call per unlock fetches a
//  personalized session-script bundle from the Worker (reusing the flashcard
//  App Attest flow). It is strictly best-effort and time-boxed: on ANY failure
//  (offline, timeout, error, unsupported, unconfigured) it returns nil and the
//  session uses the offline scripted banks. The gate never waits on the network.
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
    /// Fetch a personalized session script, or nil on ANY failure. Time-boxed so
    /// the unlock never stalls; the caller falls back to the scripted banks.
    static func fetchBundle(persona: MonsterPersona,
                            mood: SGContract.MonsterMood,
                            vars: MonsterScriptVars,
                            timeout: TimeInterval = 3.0) async -> MonsterScriptBundle? {
        let context = MonsterScriptContext(
            persona: persona.id,
            mood: String(describing: mood),
            app: vars.app,
            gateCount: vars.count,
            exam: vars.exam,
            examDays: vars.examDays,
            topic: vars.topic,
            questions: vars.questions,
            minutes: vars.minutes
        )
        return await withTaskGroup(of: MonsterScriptBundle?.self) { group in
            group.addTask { @MainActor in
                try? await FlashcardAPIClient.shared.generateScript(context)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
