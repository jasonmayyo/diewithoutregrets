//
//  MonsterScript.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 1): the OFFLINE, scripted persona voice. Each line is
//  keyed by persona + mood + context and filled with runtime vars. This is the
//  instant, offline brain for the unlock gate. Phase 2's live AI replaces these
//  at runtime but ALWAYS falls back here, so the gate never needs the network.
//  See Docs/TutorMonsterPlan.md §6a, §6f.
//

import Foundation

/// The context slot a scripted monster line fills.
enum MonsterContext {
    case greeting   // the opener when the chat appears
    case demand     // states the toll
    case correct    // reaction to a right answer
    case wrong      // reaction to a wrong answer
    case pass       // cleared the toll, time granted
    case fail       // bailed / earned nothing
    case sendoff    // final line before returning to the app
}

/// Runtime values a scripted line can interpolate.
struct MonsterScriptVars: Equatable {
    var app = "your apps"
    var count = 0            // gate encounters today
    var exam: String? = nil
    var examDays: Int? = nil
    var topic: String? = nil
    var questions = 0
    var minutes = 0
    var score = ""           // e.g. "4/6"
}

enum MonsterScript {

    /// A filled line for the given persona + mood + context. `seed` rotates the
    /// choice (pass a counter to avoid immediate repeats); deterministic for tests.
    static func line(persona: MonsterPersona,
                     mood: SGContract.MonsterMood,
                     context: MonsterContext,
                     vars: MonsterScriptVars = .init(),
                     seed: Int = Int.random(in: 0...9_999)) -> String {
        let bank = bank(personaID: persona.id, mood: mood, context: context)
        let chosen = bank.isEmpty ? [genericFallback(context)] : bank
        return fill(chosen[abs(seed) % chosen.count], vars: vars)
    }

    /// Replace {slots} in a template with runtime values.
    static func fill(_ template: String, vars: MonsterScriptVars) -> String {
        var s = template
        let map: [String: String] = [
            "{app}": vars.app,
            "{count}": String(vars.count),
            "{exam}": vars.exam ?? "your exam",
            "{days}": vars.examDays.map(String.init) ?? "a few",
            "{topic}": vars.topic ?? "this",
            "{questions}": String(vars.questions),
            "{minutes}": String(vars.minutes),
            "{score}": vars.score
        ]
        for (slot, value) in map { s = s.replacingOccurrences(of: slot, with: value) }
        return s
    }

    // MARK: - Banks

    /// Mood collapses to three tiers for copy: calm, mid, hot.
    private enum Tier {
        case calm, mid, hot
        init(_ m: SGContract.MonsterMood) {
            switch m {
            case .chill, .nudgy: self = .calm
            case .annoyed:       self = .mid
            default:             self = .hot
            }
        }
    }

    private static func genericFallback(_ c: MonsterContext) -> String {
        switch c {
        case .greeting: return "Back again?"
        case .demand:   return "Answer {questions} on {topic} and {app} is yours."
        case .correct:  return "Correct."
        case .wrong:    return "Not quite."
        case .pass:     return "Done. {minutes} minutes."
        case .fail:     return "Nothing earned this time."
        case .sendoff:  return "Go on then."
        }
    }

    private static func bank(personaID: String, mood: SGContract.MonsterMood, context: MonsterContext) -> [String] {
        let tier = Tier(mood)
        switch personaID {
        case MonsterPersona.diva.id:    return diva(tier, context)
        case MonsterPersona.willow.id:  return willow(tier, context)
        case MonsterPersona.coach.id:   return coach(tier, context)
        case MonsterPersona.gremlin.id: return gremlin(tier, context)
        default:                        return []
        }
    }

    // MARK: Zaza — the Diva
    private static func diva(_ t: Tier, _ c: MonsterContext) -> [String] {
        switch c {
        case .greeting:
            switch t {
            case .calm: return ["hiii 💅 quick one before you scroll."]
            case .mid:  return ["oh we're BACK. that's {count} times today bestie."]
            case .hot:  return ["{count} times on {app}?? no ma'am. sit down. 💀"]
            }
        case .demand:
            switch t {
            case .calm: return ["{questions} cards on {topic}, then go off."]
            case .mid:  return ["{questions} on {topic}. miss one and we run it back."]
            case .hot:  return ["{exam}'s in {days} days. {questions} on {topic}. NOW. 💀"]
            }
        case .correct: return ["ATE. 💅", "okAY you ate that.", "correct, periodt."]
        case .wrong:   return ["bestie... no. it's {score}.", "we're pretending that didn't happen. again."]
        case .pass:    return ["fine. FINE. {minutes} minutes. 👑", "you did it. {minutes} min. don't waste it."]
        case .fail:    return ["no answers, no {app}. 💔", "zero. we're not doing this."]
        case .sendoff: return ["go be unserious. 💅", "bye. come back smarter."]
        }
    }

    // MARK: Willow — the Nurturer
    private static func willow(_ t: Tier, _ c: MonsterContext) -> [String] {
        switch c {
        case .greeting:
            switch t {
            case .calm: return ["Hello, love. Just a little one first."]
            case .mid:  return ["Back again, pet? That's alright. Let's settle in."]
            case .hot:  return ["You've reached for {app} a fair bit today, love. Let's earn it properly."]
            }
        case .demand:
            switch t {
            case .calm: return ["Just {questions} on {topic}, take your time."]
            case .mid:  return ["{questions} on {topic}, love. We'll get them right together."]
            case .hot:  return ["{exam} is only {days} days away. {questions} on {topic}, come on now."]
            }
        case .correct: return ["That's my clever one.", "Lovely. Knew you had it.", "There it is."]
        case .wrong:   return ["Not to worry. It's {score}. Once more.", "Close, pet. Let's try that again."]
        case .pass:    return ["Well done. {minutes} minutes, enjoy.", "Lovely work. Off you pop, {minutes} min."]
        case .fail:    return ["No harm done. Come back when you're ready.", "That's alright. We'll try later."]
        case .sendoff: return ["Off you pop. I'll be here.", "Go on, love."]
        }
    }

    // MARK: Sarge — the Coach
    private static func coach(_ t: Tier, _ c: MonsterContext) -> [String] {
        switch c {
        case .greeting:
            switch t {
            case .calm: return ["On your feet. Quick set before {app}."]
            case .mid:  return ["{count} attempts today. Discipline. Let's go."]
            case .hot:  return ["{count} times?? That's not a student, that's a thumb athlete. MOVE."]
            }
        case .demand:
            switch t {
            case .calm: return ["{questions} reps on {topic}. Go."]
            case .mid:  return ["{questions} on {topic}. No skips. Earn it."]
            case .hot:  return ["{exam} in {days} days. {questions} on {topic}. All correct. MOVE."]
            }
        case .correct: return ["THAT'S what I'm talking about. Next.", "Good. Again.", "Solid. Keep moving."]
        case .wrong:   return ["Weak. It's {score}. Again.", "No. Lock it in. Again."]
        case .pass:    return ["Earned. {minutes} minutes. Dismissed.", "{minutes} on the clock. Don't waste it."]
        case .fail:    return ["Nothing. You don't quit on me. Back in.", "Zero earned. Try again, soldier."]
        case .sendoff: return ["Dismissed.", "Go. Come back stronger."]
        }
    }

    // MARK: Gnash — the Gremlin
    private static func gremlin(_ t: Tier, _ c: MonsterContext) -> [String] {
        switch c {
        case .greeting:
            switch t {
            case .calm: return ["ehehe. one lil question first 😈"]
            case .mid:  return ["{count} times today?? you're silly. feed me answers."]
            case .hot:  return ["{count}?? you're FERAL. takes one to know one. ANSWER. 😈"]
            }
        case .demand:
            switch t {
            case .calm: return ["{questions} on {topic} and i'll let you pass hehe"]
            case .mid:  return ["{questions} on {topic}. miss = we go AGAIN 😈"]
            case .hot:  return ["{exam} in {days}?? {questions} on {topic} RIGHT NOW. gremlin rules."]
            }
        case .correct: return ["YIPPEE 🎉 ok you're kinda smart ew", "correct?? suspicious. next 😈"]
        case .wrong:   return ["WRONG hehehe it's {score}. feed me the right one 😈", "NOPE. again again again."]
        case .pass:    return ["ugh FINE take your {minutes} minutes 😾", "{minutes} min. go. shoo."]
        case .fail:    return ["zero!! no {app} for you 😈", "nothing!! come back and suffer more."]
        case .sendoff: return ["shoo 😈", "byeeee come back soon hehe"]
        }
    }
}
