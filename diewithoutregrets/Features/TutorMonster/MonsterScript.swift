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
        let noun = "flashcard"
        let questions = "\(count) \(noun)\(count == 1 ? "" : "s")"
        let topic = cleanLabel(vars.topic, limit: 60).map { " on \($0)" } ?? ""
        let deck = cleanLabel(vars.deck, limit: 80).map { " from your \($0) deck" } ?? " from your selected deck"
        let bank = promptBank(persona.id)
        return bank[max(0, seed) % bank.count]
            .replacingOccurrences(of: "{questions}", with: questions)
            .replacingOccurrences(of: "{topic}", with: topic)
            .replacingOccurrences(of: "{deck}", with: deck)
    }

    static func scrollCallout(persona: MonsterPersona = .diva, seed: Int) -> String {
        if persona.id != MonsterPersona.diva.id {
            let bank = peerScrollCallouts(persona.id)
            return bank[max(0, seed) % bank.count]
        }
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
                    "bro, {exam} time to lock in.",
                    "{Exam} let's see the prep, big man.",
                    "quick reality check. {exam}",
                    "{Exam} we need recall on the scoreboard.",
                    "yo. {exam} bring your focus.",
                    "{Exam} the comeback starts with this set.",
                    "bro, calendar check: {exam}",
                    "{Exam} let's put some work behind that confidence.",
                    "heads up, man. {exam}",
                    "{Exam} a focused set is the move.",
                    "no autopilot today, bro. {exam}",
                    "{Exam} alright. show me what stuck."
                ]
            case MonsterPersona.gremlin.id:
                return [
                    "bro. {exam} the plot is getting serious 💀",
                    "{Exam} surprise boss encounter: me.",
                    "yo, {exam} your study goblin has entered the chat.",
                    "{Exam} the calendar just dropped lore.",
                    "dude, {exam} I have questions. literally.",
                    "{Exam} welcome to the revision side quest.",
                    "psst, bro. {exam} you brought answers, right?",
                    "{Exam} let's inspect that brain inventory.",
                    "uhh, {exam} the feed is not on the syllabus.",
                    "{Exam} okay, human. time for a memory check.",
                    "bro, I checked the calendar. {exam} wild.",
                    "{Exam} no disappearing into the scroll dimension yet 😈"
                ]
            default:
                return [
                    "hey girl, {exam} let's make a little progress.",
                    "{Exam} low-key a good moment to see what stuck.",
                    "bestie, quick calendar check. {exam}",
                    "{Exam} breathe. we can start with one small set.",
                    "okay, {exam} I've got you for this round.",
                    "{Exam} let's give future-you a little support.",
                    "hey, {exam} we're taking this one card at a time.",
                    "{Exam} a little recall before the feed?",
                    "girl, {exam} let's see what feels solid.",
                    "{Exam} no spiralling. just the question in front of you.",
                    "a gentle reality check: {exam}",
                    "{Exam} come sit with me for a quick brain check."
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
            return [
                "yo, bro. quick set before the scroll.",
                "alright, man. let's get a little work in.",
                "back for screen time? show me the reps.",
                "lock in, bro. one set at a time.",
                "let's put a win on the board.",
                "you're here. make this round count.",
                "alright, big man. bring the focus.",
                "quick check. what do you actually remember?",
                "bro, the next few answers get your full attention.",
                "let's see the recall behind the confidence.",
                "new round. fresh chance to show up.",
                "yo. a little discipline, then we talk breaks."
            ]
        case MonsterPersona.gremlin.id:
            return [
                "bro spawned directly at my gate 😈",
                "yo, human. your study goblin is online.",
                "oh sick, a volunteer for my tiny quiz.",
                "dude, I have acquired questions.",
                "look who queued for the scroll side quest.",
                "bro, this lobby has a flashcard requirement.",
                "psst. got any spare brain cells for a quick set?",
                "welcome back to my extremely small boss fight.",
                "new challenger detected. bring snacks. and answers.",
                "yo. let's see what's in the brain inventory.",
                "I was minding my business. then you tried to scroll.",
                "bro really thought the gate was unattended 💀"
            ]
        default:
            return [
                "hey girl. a little brain check before the scroll?",
                "hi bestie. let's make a small win happen.",
                "okay, we're here. one card at a time.",
                "hey. take a breath and settle in with me.",
                "a tiny study moment? future-you might appreciate it.",
                "girl, let's see what you remember today.",
                "no need to rush. we can work through a little set.",
                "hey, welcome back. let's get your brain in the chat.",
                "low-key rooting for you already. ready?",
                "okay bestie, a little recall and then we check in.",
                "let's give the notes a quick moment of attention.",
                "hey girl. start where you are; I'm here."
            ]
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
                "{questions}{deck}. lock in, bro. show me the work.",
                "you want the scroll? start with {questions}{deck}.",
                "{questions}{deck}. read properly, then commit to an answer.",
                "alright, man. {questions}{deck}. let's see what stuck.",
                "we've got {questions}{deck}. focus for this set.",
                "back yourself with {questions}{deck}. one at a time.",
                "{questions}{deck}. bring the same energy you brought to the feed.",
                "here's the set: {questions}{deck}. your move, bro.",
                "{questions}{deck}. no speedrunning the question.",
                "I've picked {questions}{deck}. put that recall to work.",
                "first, {questions}{deck}. then we check what you earned.",
                "{questions}{deck}. small set, full attention. let's go."
            ]
        case MonsterPersona.gremlin.id:
            return [
                "{questions}{deck}. pay the brain toll, bro 😈",
                "your side quest: {questions}{deck}. feed me answers.",
                "I looted {questions}{deck}. let's see what you know.",
                "{questions}{deck}. no, the answers are not in the comments.",
                "bro, I brought {questions}{deck}. you bring the memory.",
                "{questions}{deck} between you and the feed. plot twist.",
                "quest loaded: {questions}{deck}. think before you click.",
                "{questions}{deck}. open the brain inventory, human.",
                "I require {questions}{deck}. extremely normal goblin behaviour.",
                "quick lore check: {questions}{deck}. your move, dude.",
                "{questions}{deck}. let's see if the knowledge survived the brainrot.",
                "bro, {questions}{deck}. this is the part where you cook."
            ]
        default:
            return [
                "{questions}{deck}, girl. take your time; I'm right here.",
                "let's try {questions}{deck}. a little focus, then we check in.",
                "I've picked {questions}{deck}. show me what feels familiar.",
                "okay bestie, {questions}{deck}. give yourself a second to think.",
                "{questions}{deck}. we're going one at a time.",
                "a quick confidence check: {questions}{deck}. ready?",
                "{questions}{deck}. you don't have to speedrun this.",
                "let's see what stuck with {questions}{deck}. you've got my attention.",
                "girl, {questions}{deck}. just do the next one in front of you.",
                "here's our little set: {questions}{deck}. settle in.",
                "{questions}{deck}. a small step still counts.",
                "we'll start with {questions}{deck}, then see what needs another look."
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

    static func roundReaction(persona: MonsterPersona, outcome: MonsterRoundOutcome,
                              vars: MonsterScriptVars, seed: Int) -> String {
        if persona.id == MonsterPersona.diva.id {
            return zazaRoundReaction(outcome: outcome, vars: vars, seed: seed)
        }
        let bank = peerRoundReactions(persona.id, outcome: outcome)
        return bank[max(0, seed) % bank.count]
    }

    static func sendoff(persona: MonsterPersona, outcome: MonsterRoundOutcome,
                        minutes: Int, seed: Int) -> String {
        if persona.id == MonsterPersona.diva.id {
            return zazaSendoff(outcome: outcome, minutes: minutes, seed: seed)
        }
        let bank = peerSendoffs(persona.id, outcome: minutes <= 0 ? .noCorrect : outcome == .perfect ? .perfect : .mixed)
        let time = "\(max(0, minutes)) minute\(minutes == 1 ? "" : "s")"
        return bank[max(0, seed) % bank.count].replacingOccurrences(of: "{time}", with: time)
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
        case MonsterPersona.coach.id: return "\(cards), bro. lock in for this set, then we check what you earned."
        case MonsterPersona.gremlin.id: return "\(cards), dude. a tiny side quest before the feed 😈"
        default: return "\(cards), girl. one at a time. I'll be right here."
        }
    }

    static func sheetRecap(persona: MonsterPersona, round: MonsterStudyRound,
                           followUp: MonsterStudyRound?, exam: String?, examDays: Int?, seed: Int = 0) -> String {
        let outcome = MonsterRoundOutcome(correctAnswers: round.correctCount, totalAnswers: round.questions.count)
        let reaction = roundReaction(persona: persona, outcome: outcome,
            vars: .init(exam: exam, examDays: examDays), seed: seed)
        if let followUp {
            let cards = followUp.cardDescription
            switch persona.id {
            case MonsterPersona.diva.id:
                return "\(reaction) \(cards) for one final set. then we're done, sister. your earned time stays."
            case MonsterPersona.coach.id:
                return "\(reaction) final set: \(cards). finish these, bro. your earned time stays."
            case MonsterPersona.gremlin.id:
                return "\(reaction) bonus quest: \(cards). last set, dude. I'm not stealing your earned time."
            default:
                return "\(reaction) let's try \(cards.lowercased()) for one last set. your earned time is safe."
            }
        }
        if round.isFollowUp {
            switch persona.id {
            case MonsterPersona.diva.id:
                return "\(reaction) that's our last set. let's see what you earned altogether."
            case MonsterPersona.coach.id:
                return "\(reaction) final set done, bro. let's total what you earned."
            case MonsterPersona.gremlin.id:
                return "\(reaction) quest finished, dude. let's check the total loot."
            default:
                return "\(reaction) that's our last set, girl. let's see what you earned overall."
            }
        }
        return reaction
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
            bank = ["{exam} is in {days} days, girl. let's give those tricky bits a little attention."]
        case MonsterPersona.coach.id:
            bank = ["{exam} in {days} days, bro. these are the gaps we're working on."]
        case MonsterPersona.gremlin.id:
            bank = ["{exam} in {days} days, dude. the tricky cards are back for a rematch 😈"]
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
            return ("tiny study check-in", "hey girl, a few flashcards when you have a moment? small wins count.")
        case MonsterPersona.coach.id:
            return ("time to lock in, bro", "no reps today? quick set. give your recall a little work.")
        case MonsterPersona.gremlin.id:
            return ("side quest available 😈", "bro, your study goblin requests a few answers. come check the lore.")
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
            case .calm: return ["hey girl. a little brain check before the scroll?"]
            case .mid:  return ["back again, bestie? let's give your attention a little reset."]
            case .hot:  return ["girl, {app} has had a lot of your attention today. let's make room for some recall."]
            }
        case .demand:
            switch t {
            case .calm: return ["{questions} cards on {topic}. no need to speedrun it."]
            case .mid:  return ["{questions} on {topic}, girl. one at a time; I'm here."]
            case .hot:  return ["{questions} on {topic}. let's put a little focus into this set, bestie."]
            }
        case .correct: return ["okay girl, you got that.", "little W. take it.", "yes, bestie. that one clicked."]
        case .wrong:   return ["not quite. take a second with the explanation.", "a little wobble. we can learn from that one."]
        case .pass:    return ["{minutes} minutes earned, girl. enjoy your break.", "a little win and {minutes} minutes for you."]
        case .fail:    return ["no time earned yet, bestie. let's review a little.", "rough round, girl. take a breath before the next try."]
        case .sendoff: return ["catch you later, girl.", "I'll be here for the next little study moment."]
        }
    }

    // MARK: Sarge — the Coach
    private static func coach(_ t: Tier, _ c: MonsterContext) -> [String] {
        switch c {
        case .greeting:
            switch t {
            case .calm: return ["lock in, bro. quick set before {app}."]
            case .mid:  return ["{count} attempts today, bro. give the recall some reps."]
            case .hot:  return ["{count} attempts? your thumb's had its workout, man. brain's turn."]
            }
        case .demand:
            switch t {
            case .calm: return ["{questions} reps on {topic}. let's go, bro."]
            case .mid:  return ["{questions} on {topic}. full attention for this set."]
            case .hot:  return ["{questions} on {topic}. lock in, man. we're working through this."]
            }
        case .correct: return ["that's a W, bro. keep the focus.", "solid rep. keep it moving.", "clean answer, man. respect."]
        case .wrong:   return ["a fumble, bro. read the explanation and learn the play.", "not that one. slow down and lock in the answer."]
        case .pass:    return ["earned, bro. {minutes} minutes. dismissed.", "{minutes} on the clock, man. solid work."]
        case .fail:    return ["nothing earned this set, bro. review and reset.", "zero minutes, man. prep for the next try."]
        case .sendoff: return ["catch you next round, bro.", "reset and come back focused."]
        }
    }

    // MARK: Gnash — the Gremlin
    private static func gremlin(_ t: Tier, _ c: MonsterContext) -> [String] {
        switch c {
        case .greeting:
            switch t {
            case .calm: return ["bro spawned at my gate. tiny brain quest first 😈"]
            case .mid:  return ["{count} attempts today? bro is farming screen time. feed me answers."]
            case .hot:  return ["{count} attempts? dude, the scroll quest is getting out of hand. brain checkpoint 😈"]
            }
        case .demand:
            switch t {
            case .calm: return ["{questions} on {topic}, bro. pay the brain toll."]
            case .mid:  return ["{questions} on {topic}. the lore check starts now 😈"]
            case .hot:  return ["{questions} on {topic}, dude. the goblin requests full brain activity."]
            }
        case .correct: return ["bro actually cooked that one 😈", "correct?? lore acquired.", "that's a W, dude. goblin approved."]
        case .wrong:   return ["that answer took a wrong turn, bro. check the walkthrough.", "oof. missing lore. the explanation's got you."]
        case .pass:    return ["loot acquired: {minutes} minutes, bro 😈", "{minutes} minutes. dude has escaped the goblin gate."]
        case .fail:    return ["zero scroll loot, bro. notes first.", "nothing earned, dude. review the lore before the rematch."]
        case .sendoff: return ["see you next quest, bro 😈", "goblin out. come back with more lore."]
        }
    }
}

// Each pool has twelve independently rotated lines. These voices describe the
// monster's personality; they do not infer or store the student's gender.
private extension MonsterScript {
    static func peerScrollCallouts(_ persona: String) -> [String] {
        switch persona {
        case MonsterPersona.coach.id:
            return [
                "and your thumb's already warming up for the feed. priorities, bro.",
                "the scroll can wait. bring that attention over here.",
                "bro, we are not letting autopilot call the shots.",
                "you had the app open in your head already, didn't you?",
                "feed later. show me some focus first.",
                "your thumb's putting in reps. let's get the brain involved.",
                "alright, man. quick detour before you disappear into the feed.",
                "I saw the scroll attempt. you're doing a set with me first.",
                "hold up, bro. give the recall a turn.",
                "the algorithm can sit on the bench for a minute.",
                "you've got energy for the feed. put a little of it here.",
                "lock in for this bit. we'll get to the break."
            ]
        case MonsterPersona.gremlin.id:
            return [
                "and bro immediately queued for the feed 💀",
                "scroll attempt detected. deploying one annoying goblin.",
                "dude tried to skip the brain checkpoint. bold.",
                "the algorithm called. I declined on your behalf 😈",
                "bro is speedrunning the path to the comments section.",
                "caught you. your thumb has terrible stealth stats.",
                "you were one tap away from a whole side quest, dude.",
                "the feed has enough lore. let's check your actual notes.",
                "bro, the scroll portal is temporarily under goblin management.",
                "I see the vision. unfortunately, I also see the flashcards.",
                "human wants brainrot. goblin requests brain activity.",
                "not you trying to sneak into the feed through my front door."
            ]
        default:
            return [
                "and the feed is already calling your name. I get it, girl.",
                "let's pause that little scroll reflex for a second.",
                "your brain wants a break. let's check in before you go.",
                "bestie, I saw that app attempt. quick study moment first?",
                "low-key tempting to disappear into the feed. stay with me a sec.",
                "girl, the scroll will still be there after a few cards.",
                "let's give your attention a tiny reset before the apps.",
                "I get the urge to scroll. let's make a little room for recall too.",
                "a little pause here might help future-you out.",
                "the feed can wait while we see what you remember.",
                "okay, tiny detour. you and me and a few flashcards.",
                "before the scroll takes over, let's do one thing for your studying."
            ]
        }
    }

    static func peerRoundReactions(_ persona: String, outcome: MonsterRoundOutcome) -> [String] {
        switch (persona, outcome) {
        case (MonsterPersona.coach.id, .perfect):
            return [
                "clean sweep, bro. you actually locked in.",
                "every answer right. that's a proper W.",
                "all correct, man. the prep showed up.",
                "no misses. that's the standard for this set.",
                "bro backed himself and delivered. full marks on the round.",
                "you cooked that set. every card correct.",
                "perfect round. keep that same focus.",
                "nothing slipped past you there. respect, bro.",
                "all of them. solid recall, solid work.",
                "that's a clean scorecard, man. well played.",
                "no fumbles in that set. you earned the praise.",
                "full sweep, bro. let the results do the talking."
            ]
        case (MonsterPersona.coach.id, .mixed):
            return [
                "some landed, some didn't. we've got gaps to close, bro.",
                "a few good reps. the missed ones need another set of eyes.",
                "you put points on the board, man. now look at what cost you.",
                "decent start. don't leave those misses on autopilot.",
                "bro, the notes still need work. you saw which parts.",
                "you got some right. bring that focus to the ones you missed.",
                "mixed round. take the feedback and use it.",
                "a couple of fumbles in there. go back to the explanations.",
                "some recall is solid. some needs reps. now we know.",
                "not a clean sweep, bro. the weak spots just made themselves clear.",
                "you've got a base to build on. tighten up the tricky bits.",
                "partial W, man. give the missed cards some proper attention."
            ]
        case (MonsterPersona.coach.id, .noCorrect):
            return [
                "none landed, bro. back to the notes, then another attempt.",
                "zero correct this set. reset your focus and read the explanations.",
                "that round was rough, man. start with one thing you didn't know.",
                "no points on the board yet. we've found what needs work.",
                "the recall wasn't there this round. prep before the next set.",
                "bro, we need a review session. those answers aren't sticking yet.",
                "none right this time. take the feedback and regroup.",
                "that set exposed the gaps. now put some work into them.",
                "zero correct, man. slow down and work through the material.",
                "no clean answers yet. give the notes your full attention.",
                "rough set, bro. one round doesn't decide the next one.",
                "we start again from the explanations. nothing landed in that round."
            ]
        case (MonsterPersona.gremlin.id, .perfect):
            return [
                "bro just cleared the whole boss fight. zero damage 😭",
                "all correct?? dude came with the entire brain inventory.",
                "clean sweep. the goblin has been outplayed 😈",
                "every card right. bro actually read the lore.",
                "you cooked the entire set. I'm filing a complaint.",
                "perfect round, dude. my quiz has been humbled.",
                "not a single miss. okay, brain has entered ranked mode.",
                "bro brought answers to an answer fight. devastating for me.",
                "all of them? the knowledge loot was stacked.",
                "full clear, human. the brainrot did not win this round.",
                "every answer landed. that's a ridiculous W, bro.",
                "dude beat my whole set. goblin respect has been acquired."
            ]
        case (MonsterPersona.gremlin.id, .mixed):
            return [
                "bro had some of the lore. the rest is still downloading.",
                "a few hits, a few side quests into the wrong answer 💀",
                "mixed loot, dude. revisit the cards that bit back.",
                "some answers cooked. others left the stove off.",
                "you found part of the brain inventory. let's locate the rest.",
                "partial clear, bro. those missed cards have unfinished business.",
                "some knowledge survived. some needs a respawn in your notes.",
                "dude, a few of those answers took the scenic route.",
                "some W answers in there. the misses need a little grinding.",
                "you landed some. the tricky cards are still in the quest log.",
                "bro knows pieces of the lore. time to fill the plot holes.",
                "the set fought back a little. check the explanations before the rematch."
            ]
        case (MonsterPersona.gremlin.id, .noCorrect):
            return [
                "bro, the brain inventory came up empty this round. notes time.",
                "zero correct. we may have skipped a lore chapter 💀",
                "dude, that set was a wipe. regroup with the explanations.",
                "none landed. the notes are offering a very useful side quest.",
                "the quiz won this one, bro. go study its moves.",
                "no correct loot yet. read a card, learn a thing, respawn.",
                "human, the answers did not load. give the material another look.",
                "bro went zero for the round. let's actually inspect the lore.",
                "rough boss fight, dude. the explanations are the walkthrough.",
                "none right this time. open the notes before the rematch.",
                "the recall is still buffering. one card at a time, bro.",
                "zero correct, human. the comeback quest starts in your notes."
            ]
        case (_, .perfect):
            return [
                "girl, you ate that. every card right, quietly iconic.",
                "all correct? bestie, give yourself some credit.",
                "a clean sweep. your recall really showed up today.",
                "okayyy, not a single miss. that's such a good little win.",
                "every answer right. low-key proud of you right now.",
                "girl, you backed yourself and got the whole set.",
                "perfect round. let that confidence sink in for a second.",
                "you knew every one. that work is paying off in this set.",
                "all of them, bestie. you can feel good about that.",
                "clean round, calm energy. you handled those cards.",
                "no misses. that was a very satisfying little slay.",
                "girl, the whole set was yours. take the win."
            ]
        case (_, .mixed):
            return [
                "some stuck, some need another look. we're getting a clearer picture, girl.",
                "you knew part of it, bestie. let's give the tricky bits some attention.",
                "a few wobbles, but you did get some right. that matters too.",
                "mixed round. no spiralling; now you know what to revisit.",
                "girl, some of those cards still need time with the notes.",
                "you've got a starting point. the missed ones tell us what comes next.",
                "some answers clicked. a little more review could help the others.",
                "okay bestie, there's progress and there's homework. both can be true.",
                "a little patchy in places. let's be kind to ourselves and review those gaps.",
                "you remembered some. the rest deserves another calm read-through.",
                "partial win, girl. give yourself credit, then check what caught you out.",
                "that round showed us the solid bits and the bits that need a little care."
            ]
        default:
            return [
                "none right this round, girl. breathe; let's start with the explanations.",
                "okay bestie, that set was rough. we can take the notes one bit at a time.",
                "zero correct this time. it's a starting point, not your whole story.",
                "those cards didn't click yet. give yourself room to learn them.",
                "girl, no spiralling. let's pick one thing from that set to understand first.",
                "no correct answers yet. a calm review is probably the move.",
                "the recall wasn't there today. take a breath and go back through the notes.",
                "that was a tough set, bestie. the explanations can help us make sense of it.",
                "none landed this time. we don't have to rush the next try.",
                "okay, the material needs more time. let's give it that.",
                "rough round, girl. you can learn from it without being mean to yourself.",
                "zero correct for now. start small: one card, one explanation, one thing learned."
            ]
        }
    }

    static func peerSendoffs(_ persona: String, outcome: MonsterRoundOutcome) -> [String] {
        switch (persona, outcome) {
        case (MonsterPersona.coach.id, .perfect):
            return [
                "{time} unlocked, bro. clean work. enjoy the break.",
                "go take your {time}. that's an earned W.",
                "{time} on the clock, man. you did the work.",
                "alright, bro. {time} to scroll. well played.",
                "bank the win and take your {time}. dismissed.",
                "clean set, earned break. {time} for you.",
                "you delivered. go enjoy {time} of scrolling.",
                "that's {time}, bro. give the focus a rest.",
                "solid work gets a proper break. enjoy your {time}.",
                "on the clock: {time}. enjoy the scroll, man.",
                "take the {time} you earned. keep that confidence.",
                "we're done here, bro. {time}. go enjoy it."
            ]
        case (MonsterPersona.coach.id, .mixed):
            return [
                "you earned {time}, bro. break first, then work on the misses.",
                "{time} on the clock. bring those tricky cards back into training later.",
                "take your {time}, man. we've got clear gaps to work on next.",
                "your correct answers earned {time}. use the feedback when you return.",
                "{time} unlocked, bro. don't lose track of what caught you out.",
                "bank your {time}. the missed cards are the next job.",
                "go enjoy {time} of scrolling. come back ready to sharpen the recall.",
                "that's {time} for this set. a review after the break is the move.",
                "take the {time} you earned. the work continues next round.",
                "{time}, man. reset, then give those gaps some focus.",
                "you've earned a {time} break. remember which answers need reps.",
                "alright, bro. {time} to scroll, with a few things to revisit later."
            ]
        case (MonsterPersona.coach.id, .noCorrect):
            return [
                "no scroll time earned, bro. review, reset, try again.",
                "apps stay locked this round. put the notes back in play.",
                "zero minutes from that set, man. prep for the next one.",
                "no unlock yet. take a focused look at the explanations.",
                "nothing banked this time. show up for the next set prepared.",
                "the break hasn't been earned yet, bro. back to the material.",
                "no app time this round. slow down and review the misses.",
                "still locked, man. learn the cards, then run another set.",
                "no minutes earned. a little prep before the next attempt.",
                "we're holding the scroll here, bro. review first.",
                "no break from this set. you've got another chance after some study.",
                "zero scroll time, man. reset the approach and come back."
            ]
        case (MonsterPersona.gremlin.id, .perfect):
            return [
                "fine, bro. {time} of scrolling. the goblin accepts defeat 😈",
                "loot collected: {time}. go be a little unserious, dude.",
                "{time} unlocked. you've escaped my extremely tiny dungeon.",
                "take your {time}, bro. that was a clean W.",
                "quest cleared. {time} in the bag. off you go, human.",
                "{time} to scroll. I will be dramatically sulking over here.",
                "bro earned {time}. the feed portal is open.",
                "you win this one, dude. enjoy your {time}.",
                "permission to collect brainrot: {time}. you earned the break.",
                "{time}, human. a worthy reward for outplaying my cards.",
                "go enjoy {time} of scrolling. goblin seal of approval.",
                "the gate is open for {time}, bro. try not to gloat."
            ]
        case (MonsterPersona.gremlin.id, .mixed):
            return [
                "you looted {time}, bro. the missed cards remain in the quest log.",
                "{time} unlocked. enjoy the feed, then revisit the missing lore.",
                "take your {time}, dude. those tricky cards want a rematch later.",
                "partial clear, real loot: {time}. go have your break.",
                "bro earned {time}. don't forget the plot holes in those notes.",
                "{time} to scroll. the explanations will be waiting after your side quest.",
                "here's your {time}, human. a few cards still have unfinished business.",
                "you banked {time}. the rest of the knowledge loot needs another visit.",
                "off you go for {time}, dude. come back for the missing pieces.",
                "on the timer: {time}. keep those tricky bits on your radar.",
                "take the {time} you earned, bro. the study quest continues later.",
                "feed portal open for {time}. review the fumbles after your break 😈"
            ]
        case (MonsterPersona.gremlin.id, .noCorrect):
            return [
                "no scroll loot this round, bro. notes first, rematch later.",
                "the feed portal is still locked. go collect some knowledge, dude.",
                "zero minutes earned. the notes have a side quest for you.",
                "no unlock yet, human. the explanations are the walkthrough.",
                "bro, no screen time dropped from that set. review and respawn.",
                "the goblin gate stays shut this round. learn the lore, then return.",
                "no app time earned, dude. let's reload after a little studying.",
                "zero scroll minutes. your next quest marker is on the notes.",
                "nothing in the loot chest yet. go get familiar with those cards.",
                "still locked, bro. the comeback arc needs a little prep.",
                "no break earned from that boss fight. check the guide before the rematch.",
                "the scroll stays on hold, human. one explanation at a time."
            ]
        case (_, .perfect):
            return [
                "enjoy your {time} of guilt-free scrolling, girl. you earned this.",
                "{time} for you, bestie. take a proper little break.",
                "go enjoy your {time}. that was a lovely win for your day.",
                "your {time} break is ready. let yourself enjoy it.",
                "girl, take your {time} and relax. you did the work.",
                "{time} unlocked. low-key a great moment to give your brain a rest.",
                "that's {time} to scroll, bestie. enjoy the win.",
                "go have your {time}. you've earned a little time off.",
                "a clean round and {time} for you. that feels good.",
                "enjoy the feed for {time}, girl. no study guilt needed for this break.",
                "take the {time} you earned. I'm rooting for more little wins like that.",
                "your break starts here: {time}. go enjoy yourself."
            ]
        case (_, .mixed):
            return [
                "you earned {time}, girl. enjoy the break, then revisit the tricky bits.",
                "{time} for you, bestie. a little review after the scroll could help.",
                "take your {time}. we know which cards need more attention now.",
                "your correct answers earned {time}. give your brain a breather.",
                "{time} unlocked. enjoy the break, then come back to those gaps gently.",
                "go have your {time}, girl. the missed cards can get another look later.",
                "that's {time} banked. take the break and keep the explanations in mind.",
                "enjoy a {time} break, bestie. small steps from here.",
                "you've earned {time}. a few wobbles don't erase what you did know.",
                "take your {time} to scroll. let's make room for a review afterwards.",
                "{time} for this round, girl. rest a little, then pick up the tricky bits.",
                "your {time} break is ready. we'll work on those misses next time."
            ]
        default:
            return [
                "no scroll time earned this round, girl. take a breath and review a little.",
                "the apps stay locked for now, bestie. try again when you've had a look at the notes.",
                "no minutes from this set. you can come back after a calm review.",
                "nothing earned yet. let's give the explanations some time before the next try.",
                "no unlock this round, girl. you don't have to rush the learning bit.",
                "the scroll is still on hold. start with one card that felt confusing.",
                "zero minutes earned this time, bestie. a fresh try can come after some revision.",
                "no app time yet. give yourself a moment to understand the material.",
                "still locked for now, girl. work through the notes at your own pace.",
                "no break earned from this set. take a breath before trying again.",
                "the apps will wait. no minutes earned yet, but you can keep learning.",
                "nothing to unlock this time, bestie. I'll be here when you're ready for another go."
            ]
        }
    }
}
