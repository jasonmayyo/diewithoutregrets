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

enum MonsterRoundOutcome: String, CaseIterable {
    case perfect, mixed, noCorrect

    init(correctAnswers: Int, totalAnswers: Int) {
        if totalAnswers > 0, correctAnswers == totalAnswers { self = .perfect }
        else if correctAnswers > 0 { self = .mixed }
        else { self = .noCorrect }
    }
}

/// Runtime values a scripted line can interpolate.
struct MonsterScriptVars: Equatable {
    var app = "your apps"
    var count = 0            // gate encounters today
    var exam: String? = nil
    var examDays: Int? = nil
    var topic: String? = nil
    var deck: String? = nil
    var questions = 0
    var minutes = 0
    var score = ""           // e.g. "4/6"
}

/// Exhaust each shuffled set before reusing a line. Save the remaining choices,
/// not a session counter, so an app restart does not reset the conversation.
enum MonsterOpeningRotation {
    static func next(personaID: String, hasExam: Bool, defaults: UserDefaults?) -> (greeting: Int, prompt: Int) {
        (draw(personaID: personaID, lane: hasExam ? "examGreeting" : "greeting", defaults: defaults),
         draw(personaID: personaID, lane: "prompt", defaults: defaults))
    }

    /// Independent lanes keep a familiar structure without repeating the same
    /// greeting, challenge or outcome line on each visit.
    static func draw(personaID: String, lane: String, defaults: UserDefaults?) -> Int {
        let key = "sg_monsterOpening.v1.\(personaID).\(lane)"
        let saved = defaults?.dictionary(forKey: key)
        let last = saved?["last"] as? Int
        var bag = saved?["remaining"] as? [Int] ?? []
        let count = MonsterScript.openingVariantCount
        if bag.contains(where: { !(0..<count).contains($0) }) || Set(bag).count != bag.count { bag = [] }
        if bag.isEmpty {
            bag = Array(0..<count).shuffled()
            if bag.first == last, let index = bag.firstIndex(where: { $0 != last }) {
                bag.swapAt(0, index)
            }
        }
        let picked = bag.removeFirst()
        defaults?.set(["last": picked, "remaining": bag], forKey: key)
        return picked
    }
}

enum MonsterScript {

    /// Each lane is shuffled independently and persisted across new sessions.
    static let openingVariantCount = 12

    static func hasUpcomingExam(_ vars: MonsterScriptVars) -> Bool { examReminder(vars) != nil }

    static func openingGreeting(persona: MonsterPersona, mood: SGContract.MonsterMood,
                                vars: MonsterScriptVars, seed: Int) -> String {
        let exam = examReminder(vars)
        let bank = greetingBank(persona.id, hasExam: exam != nil)
        return bank[max(0, seed) % bank.count]
            .replacingOccurrences(of: "{exam}", with: exam ?? "")
            .replacingOccurrences(of: "{Exam}", with: exam.map(capitalizedFirst) ?? "")
    }

    static func openingPrompt(persona: MonsterPersona, vars: MonsterScriptVars,
                              studySheet: Bool = false, seed: Int) -> String {
        let count = max(0, vars.questions)
        let noun = studySheet || persona.id == MonsterPersona.diva.id ? "flashcard" : "question"
        let questions = "\(count) \(noun)\(count == 1 ? "" : "s")"
        let topic = cleanLabel(vars.topic, limit: 60).map { " on \($0)" } ?? ""
        let deck = cleanLabel(vars.deck, limit: 80).map { " from your \($0) deck" } ?? " from your selected deck"
        let bank = promptBank(persona.id)
        return bank[max(0, seed) % bank.count]
            .replacingOccurrences(of: "{questions}", with: questions)
            .replacingOccurrences(of: "{topic}", with: topic)
            .replacingOccurrences(of: "{deck}", with: deck)
    }

    static func scrollCallout(seed: Int) -> String {
        let bank = [
            "and you're out here trying to scroll. girl.",
            "but somehow your thumb has time for the feed?",
            "sister, I saw that little attempt to open your apps.",
            "the scroll was calling and you really picked up 😭",
            "oh, we're just gonna sneak past the revision? cute.",
            "your thumb said scroll. I'm saying hold on a second.",
            "don't look at me like that. you know why I'm here.",
            "you had a whole plan to disappear into that feed, didn't you?",
            "girl, put the scrolling thumb down for one minute.",
            "you and that feed are getting a little too comfortable.",
            "already reaching for the apps? let me interrupt that thought.",
            "the feed can survive without you for a few flashcards, sister."
        ]
        return bank[max(0, seed) % bank.count]
    }

    private static func greetingBank(_ persona: String, hasExam: Bool) -> [String] {
        if hasExam {
            switch persona {
            case MonsterPersona.diva.id:
                return [
                    "damn girl, {exam}",
                    "sister. {exam} we need to talk.",
                    "hold up, {exam} you remember that, right?",
                    "bestie, I checked the calendar. {exam}",
                    "oh babe. {exam} let's be so serious.",
                    "{Exam} yes, I brought the receipts 💅",
                    "girl, quick reality check: {exam}",
                    "sooo... {exam} how are we feeling?",
                    "{Exam} I'm gonna need a little proof of preparation.",
                    "before you get comfortable, {exam}",
                    "miss thing, {exam} I'm paying attention.",
                    "{Exam} okay. let's see where we're at."
                ]
            case MonsterPersona.coach.id:
                return [
                    "{Exam} Let's put in a focused round.",
                    "Quick check-in. {Exam}",
                    "Before the apps, a little practice. {Exam}",
                    "{Exam} What can you recall without looking?",
                    "Back to the task. {Exam}",
                    "{Exam} One step at a time. Start here.",
                    "Let's warm up your recall. {Exam}",
                    "{Exam} This is a good moment for a review.",
                    "Ready for a short set? {Exam}",
                    "{Exam} Focus on the question in front of you.",
                    "A few deliberate minutes now. {Exam}",
                    "{Exam} Let's see what you know."
                ]
            case MonsterPersona.gremlin.id:
                return [
                    "psst. {exam} let's see what stuck 😈",
                    "{Exam} surprise! it's revision time.",
                    "heheh, caught you before the scroll. {Exam}",
                    "tiny brain quest? {Exam}",
                    "{Exam} I've got a little challenge for you.",
                    "come closer, human. {exam}",
                    "{Exam} let's poke around that memory of yours.",
                    "one detour before your apps 😈 {Exam}",
                    "{Exam} ready to feed me some answers?",
                    "oh hello. excellent timing. {exam}",
                    "{Exam} a little practice won't bite. I might.",
                    "your friendly revision gremlin has arrived. {Exam}"
                ]
            default:
                return [
                    "{Exam} Let's do a little revision together, love.",
                    "Hello, love. {exam} Shall we have a gentle check-in?",
                    "A little pause before your apps. {Exam}",
                    "{Exam} We can take this one question at a time.",
                    "Come settle in for a moment. {Exam}",
                    "{Exam} Let's see what feels familiar.",
                    "Ready for a small review, love? {Exam}",
                    "{Exam} A little practice now can help.",
                    "I'm here for a quick check-in. {Exam}",
                    "{Exam} Take a breath. We'll start together.",
                    "Let's give your memory a little warm-up. {Exam}",
                    "{Exam} There's time for a thoughtful answer."
                ]
            }
        }
        switch persona {
        case MonsterPersona.diva.id:
            return ["well, well, well. look who needs a little screen time.", "hiii girl. yes, I'm on duty 💅",
                    "bestie, you thought I wasn't watching?", "oh, it's you. come here a second.",
                    "sister, we have a tiny bit of business first.", "look who found their way back to me.",
                    "okay girl, let's see what that brain is working with.", "miss thing has entered the chat.",
                    "hey babe. I have questions. literally.", "there she is. ready to back yourself?",
                    "girl, you came to the right gatekeeper.", "me again. your very nosy study bestie 💅"]
        case MonsterPersona.coach.id:
            return ["Let's get a focused set in.", "Quick review before the apps. Ready?",
                    "Time to put your recall to work.", "A short round. Give it your attention.",
                    "Let's find out what you remember.", "Settle in. First question coming up.",
                    "One focused step at a time.", "A little practice before you move on.",
                    "Let's make this study break count.", "Ready to test your recall?",
                    "Start where you are. We've got a round to do.", "Your next small win starts here."]
        case MonsterPersona.gremlin.id:
            return ["ehehe. a tiny brain quest first 😈", "surprise revision! my favourite kind.",
                    "human detected. answers requested.", "one little detour before the scroll.",
                    "what's hiding in that memory of yours?", "I've brought questions. you bring the brain.",
                    "psst. ready for a little challenge?", "welcome to my very small pop quiz 😈",
                    "let's find out what stuck, shall we?", "a little recall snack before your apps.",
                    "heheh. your study gremlin is on duty.", "come on in. the first question is waiting."]
        default:
            return ["Hello, love. Shall we do a little review?", "Let's take a quiet moment to practise.",
                    "A small check-in before your apps.", "Come settle in. We'll start gently.",
                    "Let's see what you remember today.", "One question at a time, love.",
                    "Ready for a little memory warm-up?", "I'm here. Let's work through a short round.",
                    "A little practice can go a long way.", "Take a breath, love. Ready when you are.",
                    "Let's make a little space for revision.", "Shall we try a few together?"]
        }
    }

    private static func promptBank(_ persona: String) -> [String] {
        switch persona {
        case MonsterPersona.diva.id:
            return [
                "I'm checking what you know before I let you scroll. {questions}{deck}. don't play with me, sister.",
                "show me those notes actually went in. {questions}{deck}, then we'll talk screen time.",
                "okay, back yourself. {questions}{deck}. I want answers, girl.",
                "you want the feed? let me see the recall. {questions}{deck}. your move 💅",
                "let's find out if you've got this. {questions}{deck}. think before you tap, babe.",
                "I'm not sending you off without a little brain check. {questions}{deck}. let's go.",
                "here's the deal, sister: {questions}{deck}. show me what stuck.",
                "receipts, please. {questions}{deck}. let's see what you can remember without peeking.",
                "alright miss thing, {questions}{deck}. put that confidence to work.",
                "we're doing {questions}{deck} before the scroll. give me your attention for a minute.",
                "I've pulled {questions}{deck}. make me proud, then we'll sort out your break.",
                "{questions}{deck}. a little proof you know what you're doing, sister. that's all I'm asking."
            ]
        case MonsterPersona.coach.id:
            return [
                "{questions}{topic}. One focused set.",
                "Start with {questions}{topic}. Take each one seriously.",
                "Today's round: {questions}{topic}.",
                "Let's test your recall with {questions}{topic}.",
                "I've lined up {questions}{topic}. Begin when you're ready.",
                "Work through {questions}{topic}. Think, then answer.",
                "Your next task is {questions}{topic}. Keep it steady.",
                "Let's tackle {questions}{topic}, one at a time.",
                "A short practice set: {questions}{topic}.",
                "{questions}{topic}. Focus on getting the idea clear.",
                "We'll review {questions}{topic}. Here's the first step.",
                "Give {questions}{topic} your full attention."
            ]
        case MonsterPersona.gremlin.id:
            return [
                "heheh. {questions}{topic}. feed me answers.",
                "your quest: {questions}{topic}. 😈",
                "I've found {questions}{topic} for our little challenge.",
                "{questions}{topic}. let's see what's in that brain.",
                "a tiny feast of {questions}{topic}. delicious.",
                "ready or nearly ready: {questions}{topic}.",
                "I brought {questions}{topic}. your move, human.",
                "let's poke at {questions}{topic} together.",
                "the challenge is {questions}{topic}. take your time.",
                "{questions}{topic}. show me what stuck 😈",
                "first, a little recall magic: {questions}{topic}.",
                "come on then. {questions}{topic} await."
            ]
        default:
            return [
                "Let's try {questions}{topic}, love. Take your time.",
                "I've picked {questions}{topic}. We'll work through this together.",
                "Shall we start with {questions}{topic}?",
                "Just {questions}{topic} for this round. No need to rush.",
                "Let's see what you remember with {questions}{topic}.",
                "We can practise with {questions}{topic}, one at a time.",
                "Here's our little round: {questions}{topic}.",
                "I'd like to go over {questions}{topic} with you.",
                "{questions}{topic}, love. Give yourself a moment to think.",
                "Let's warm up with {questions}{topic}.",
                "A little recall practice: {questions}{topic}.",
                "We'll begin with {questions}{topic}. I'm right here."
            ]
        }
    }

    private static func examReminder(_ vars: MonsterScriptVars) -> String? {
        guard let subject = cleanLabel(vars.exam, limit: 80), let days = vars.examDays, days >= 0 else { return nil }
        let generic = ["my exam", "your exam", "exam"].contains(subject.lowercased())
        let exam = generic ? "your exam" : "your \(subject)\(subject.lowercased().hasSuffix("exam") ? "" : " exam")"
        let when = days == 0 ? "today" : days == 1 ? "tomorrow" : "in \(days) days"
        return "\(exam) is \(when)."
    }

    private static func cleanLabel(_ value: String?, limit: Int) -> String? {
        let text = value?.split(whereSeparator: \.isWhitespace).joined(separator: " ") ?? ""
        return text.isEmpty ? nil : String(text.prefix(limit))
    }

    private static func capitalizedFirst(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Respond to the actual attempts, including misses corrected on a retry.
    /// These lines assess this round; they never promise an exam result or grant.
    static func zazaRoundReaction(outcome: MonsterRoundOutcome, vars: MonsterScriptVars, seed: Int) -> String {
        let bank: [String]
        switch outcome {
        case .perfect:
            bank = [
                "damnnn, okay girl. you know your 💩. every card right.",
                "all correct? sister, you came with receipts 💅",
                "not a single miss. okay, I'll put the attitude away for a second.",
                "girl, you cleared that whole round. I see you.",
                "every answer right. that's how you get me off your back.",
                "okayyy, brain. you didn't leave me one thing to complain about.",
                "you really said 'test me' and meant it. perfect round, babe.",
                "all of them? alright miss thing, I'll give you that one.",
                "sister, the recall is recalling. every card correct.",
                "look at you actually knowing the material. clean round 💅",
                "I had a whole speech ready. then you went and got everything right.",
                "damn. no misses, no notes from me. you handled that set."
            ]
        case .mixed:
            bank = [
                "yeah, those {notes} aren't gonna learn themselves, sister.",
                "some of that stuck. some of it clearly left the group chat.",
                "okay, you've got pieces of it. the ones you missed need another look.",
                "girl, a few of those answers were asking for help. let's remember which ones.",
                "you got some right, but I'm not ignoring those gaps, babe.",
                "a little knowledge, a little guesswork? revisit the tricky ones, sister.",
                "not a clean sweep. useful information, though: now you know what to review.",
                "some answers showed up ready. the others need a little more time with the notes.",
                "okay miss thing, there's work to do on the ones that caught you out.",
                "you did get some. but those {notes} still want your attention.",
                "I'm giving you credit for what you knew. I'm also remembering those misses.",
                "a few wobbles in there, girl. put those tricky cards on the revisit list."
            ]
        case .noCorrect:
            bank = [
                "girl. those {notes} need you more than the feed does right now.",
                "none right this round, sister. let's actually spend a moment with the material.",
                "okay, that set caught you out. read the explanations before we try again.",
                "babe, we're starting with the notes. that round gave us a clear answer.",
                "the recall did not clock in today. give those cards another look.",
                "not one landed, girl. take a breath and revisit the explanations.",
                "sister, this is our sign to open the {notes}.",
                "that round was rough. pick one thing you didn't know and start there.",
                "okay, now we know what needs work. those answers need some study time.",
                "the feed can wait. let's get familiar with those cards first, babe.",
                "no correct answers yet. I'm gonna need you and those notes to reconnect.",
                "girl, let's regroup. read through the tricky bits, then have another go."
            ]
        }
        let notes = hasUpcomingExam(vars)
            ? cleanLabel(vars.exam, limit: 80).map { "\($0) notes" } ?? "study notes" : "study notes"
        return bank[max(0, seed) % bank.count].replacingOccurrences(of: "{notes}", with: notes)
    }

    /// The local grant is the only source of the break duration.
    static func zazaSendoff(outcome: MonsterRoundOutcome, minutes: Int, seed: Int) -> String {
        let bank: [String]
        if minutes <= 0 {
            bank = [
                "no scroll time earned this round. come back and show me what stuck.",
                "the apps are staying locked for now, sister. try another round when you're ready.",
                "no time earned yet. a little revision, then you and me again.",
                "I can't hand you a break from this one, babe. give the material another go.",
                "no unlock this round. the next try is a fresh chance.",
                "zero scroll minutes this time. go get familiar with those answers.",
                "we haven't earned the scroll yet, girl. I'll be here for the next attempt.",
                "the feed's still on hold. take your time with the explanations.",
                "nothing to unlock this round, sister. let's come back better prepared.",
                "no app time from that set. you can try again after a little review.",
                "still locked, babe. read it, let it sink in, then come see me.",
                "no minutes earned this time. don't rush the next try, girl."
            ]
        } else if outcome == .perfect {
            bank = [
                "enjoy your {time} of guilt-free scrolling, girl. you earned that break.",
                "go on then. {time} to scroll, with my blessing 💅",
                "that's {time} for you, sister. enjoy the break.",
                "fine, go be unserious for {time}. that round earned it.",
                "take your {time}, babe. I'm letting you enjoy this win.",
                "{time} unlocked. go enjoy your feed without the study guilt.",
                "alright, I'll stop gatekeeping. {time}. have fun, girl.",
                "you did the work. go enjoy your {time} of scrolling.",
                "permission to scroll: granted. {time}, miss thing.",
                "your break is ready: {time}. go enjoy it.",
                "off you go, sister. {time} of earned scrolling.",
                "I'm a woman of my word. {time} for you. enjoy 💅"
            ]
        } else {
            bank = [
                "you earned {time}. have your break, then revisit the ones you missed.",
                "{time} to scroll, sister. those tricky cards are still on the list.",
                "take your {time}, babe. a little review after the break would help.",
                "that's {time} for you. enjoy the break, then give those gaps some attention.",
                "you've banked {time}. take the break and come back to the hard bits.",
                "okay, {time} of scrolling. let's work on those misses next time.",
                "your right answers earned {time}. enjoy the break, girl.",
                "off you go for {time}. we know which cards need more work now.",
                "{time} unlocked. don't forget what tripped you up, sister.",
                "take the {time} you earned. the next study round has a to-do list.",
                "a break's a break, babe. enjoy your {time}, then back to those tricky bits.",
                "here's your {time}. I'm rooting for fewer misses next round."
            ]
        }
        let time = "\(max(0, minutes)) minute\(minutes == 1 ? "" : "s")"
        return bank[max(0, seed) % bank.count].replacingOccurrences(of: "{time}", with: time)
    }

    static func sheetIntroduction(persona: MonsterPersona, count: Int) -> String {
        let cards = "\(count) flashcard\(count == 1 ? "" : "s")"
        switch persona.id {
        case MonsterPersona.diva.id: return "okay, \(cards). show me what you know, then we'll talk screen time. 💅"
        case MonsterPersona.coach.id: return "\(cards). One focused set. I'll check in when you're done."
        case MonsterPersona.gremlin.id: return "heheh. \(cards) between you and your apps. let's see what you've got. 😈"
        default: return "Let's try \(cards), love. Take your time. I'll be here when you're done."
        }
    }

    static func sheetRecap(persona: MonsterPersona, round: MonsterStudyRound,
                           followUp: MonsterStudyRound?, exam: String?, examDays: Int?, seed: Int = 0) -> String {
        let score = "\(round.correctCount) out of \(round.questions.count)"
        if persona.id == MonsterPersona.diva.id {
            let outcome = MonsterRoundOutcome(correctAnswers: round.correctCount, totalAnswers: round.questions.count)
            let reaction = zazaRoundReaction(outcome: outcome,
                vars: .init(exam: exam, examDays: examDays), seed: seed)
            if let followUp {
                return "\(reaction) \(followUp.cardDescription) for one final set. then we're done, sister. your earned time stays."
            }
            if round.isFollowUp { return "\(reaction) that's our last set. let's see what you earned altogether." }
            return reaction
        }
        if let followUp {
            let reminder: String
            if let exam, let days = examDays, days >= 0 {
                reminder = days == 0 ? " \(exam) is today." : " \(exam) is in \(days) day\(days == 1 ? "" : "s")."
            } else { reminder = "" }
            let extra = followUp.cardDescription.lowercased()
            switch persona.id {
            case MonsterPersona.diva.id: return "\(score)? okay, a little more practice.\(reminder) I've got \(extra) for you, then we're done. your earned time stays. 💅"
            case MonsterPersona.coach.id: return "\(score). We can sharpen that.\(reminder) One final set: \(extra). Your earned time stays."
            case MonsterPersona.gremlin.id: return "\(score)! a few gaps to fill.\(reminder) \(extra), then I'll let you go. keeping your earned time safe. 😈"
            default: return "\(score), love. Let's give the tricky bits a little more time.\(reminder) Just \(extra), then we're done. Your earned time is kept."
            }
        }
        if round.isFollowUp {
            return "\(score) on the follow-up. That's our last set. You can collect any time you've earned, and we can revisit the tricky bits next time."
        }
        switch persona.id {
        case MonsterPersona.diva.id: return "\(score). you did that. 💅 your screen time is ready — go collect it."
        case MonsterPersona.coach.id: return "\(score). Solid set. Collect your screen time. You've earned it."
        case MonsterPersona.gremlin.id: return "\(score)! okay, you win this one. go collect your screen time. 😈"
        default: return "\(score). Lovely work, love. Your screen time is ready when you are."
        }
    }

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

    /// A persona-voiced "why these cards" line (exam proximity + weakness),
    /// surfaced after the demand when an exam is upcoming (Phase 2 adaptive).
    static func reasonLine(persona: MonsterPersona,
                           vars: MonsterScriptVars,
                           seed: Int = Int.random(in: 0...9_999)) -> String {
        let bank: [String]
        switch persona.id {
        case MonsterPersona.diva.id:
            bank = ["and {exam}'s in {days} days?? we're drilling the stuff you keep fumbling. 💀"]
        case MonsterPersona.willow.id:
            bank = ["{exam} is only {days} days away, love, so these are the ones you keep slipping on."]
        case MonsterPersona.coach.id:
            bank = ["{exam} in {days} days. these are your weak reps. we fix them now."]
        case MonsterPersona.gremlin.id:
            bank = ["{exam} in {days}?? heheh. serving you the ones you're BAD at. 😈"]
        default:
            bank = ["{exam} is in {days} days, so these target your weak spots."]
        }
        return fill(bank[abs(seed) % bank.count], vars: vars)
    }

    /// Persona-voiced re-engagement nudge (title, body) for the daily notification.
    static func nudge(persona: MonsterPersona) -> (title: String, body: String) {
        switch persona.id {
        case MonsterPersona.diva.id:
            return ("your monster misses you 💅", "it's been a sec. come lock in a few before you scroll, bestie.")
        case MonsterPersona.willow.id:
            return ("a gentle nudge, love", "pop back when you can and we'll do a few together.")
        case MonsterPersona.coach.id:
            return ("back on the clock", "no reps today? let's fix that. a quick set and you're done.")
        case MonsterPersona.gremlin.id:
            return ("heheh. miss me?? 😈", "you've been quiet. feed me some answers.")
        default:
            return ("time to study", "a few flashcards keeps your streak alive.")
        }
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
