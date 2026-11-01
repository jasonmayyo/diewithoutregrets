import Foundation
import SwiftUI

enum BuddyOnboardingPhase: Int, Codable, CaseIterable {
    // Raw values stay stable so saved drafts keep decoding. The on-screen order is
    // defined by `flowOrder`, not by these values.
    case name, pronouns, level, subject, exam, age, materials, practice, practiceReview, rule, offer
    case permission, apps, firstRound, notifications

    /// The guided-chat order. Notes are uploaded before the exam date, and the
    /// subject is derived from those notes instead of asked, so `subject` sits with
    /// the other skipped phases and is filled in automatically.
    static let flowOrder: [BuddyOnboardingPhase] = [
        .name, .pronouns, .level, .age, .subject,
        .materials, .exam,
        .practice, .practiceReview, .rule, .offer,
        .permission, .apps, .firstRound, .notifications
    ]

    /// Phases the user answers in chat, in flow order. Gender and age come from the
    /// regular screens, the per-round rule is retired, and the subject is detected
    /// from the uploaded notes rather than asked.
    static let activePhases: [BuddyOnboardingPhase] =
        flowOrder.filter { ![.pronouns, .age, .rule, .subject].contains($0) }

    /// Position in the on-screen flow (skipped phases included).
    var flowIndex: Int { Self.flowOrder.firstIndex(of: self) ?? 0 }

    var screenNumber: Int {
        let index = Self.activePhases.firstIndex { $0.flowIndex >= flowIndex } ?? (Self.activePhases.count - 1)
        return SGV5V5OnboardingStep.preChatScreenCount + index + 1
    }
    var progress: Double { Double(screenNumber) / Double(SGV5V5OnboardingStep.progressCount) }
    var chapter: String {
        switch self {
        case .name, .pronouns, .level: return "Getting to know you"
        case .materials, .subject, .exam, .age: return "Build your first deck"
        case .practice, .practiceReview, .rule: return "Try studying together"
        case .offer: return "Your study plan"
        default: return "Set up your guard"
        }
    }
}

struct BuddyOnboardingEntry: Identifiable, Codable {
    var id = UUID()
    var text: String
    var isUser = false
    var reaction: String?
    var message: MonsterMessage {
        .init(id: id, sender: isUser ? .user : .monster, kind: .text(text),
              reaction: reaction.flatMap(MonsterReaction.init(rawValue:)))
    }
}

struct BuddyOnboardingState: Codable {
    static let key = "sg_buddyOnboarding.v1"
    var phase: BuddyOnboardingPhase = .name
    var entries: [BuddyOnboardingEntry] = []
    var personaID: String?
    var deckID: UUID?
    var examID: UUID?
    var practiceCard: Regret?
    var practicePassed = false
    var practiceAttempts: Int? = nil
    var guardConfigured = false
    var setupDeferred = false
    var firstRoundMinutes: Int?
    var pronounsAnswered: Bool? = nil
    /// Set when the chosen practice deck is a sample, so its subject is never linked
    /// to the user's real exam. Optional so older drafts keep decoding.
    var skipExamLink: Bool? = nil

    /// Practice has no reference to the earning engine or mastery writeback.
    mutating func answerPractice(_ answer: String) -> Bool? {
        guard phase == .practice, let card = practiceCard else { return nil }
        let correct = AnswerGrading.matches(answer, card.correctAnswer)
        practiceAttempts = (practiceAttempts ?? 0) + 1
        practicePassed = correct
        if correct { phase = .practiceReview }
        return correct
    }
}

enum BuddyOnboardingCopy {
    static func greeting(_ persona: MonsterPersona) -> String {
        switch persona.id {
        case "diva": return "I’m Zaza. Your screen time has main-character energy. Your notes deserve a cameo."
        case "coach": return "Sarge reporting for duty. Your thumb has trained enough. Time for your brain."
        case "gremlin": return "I’m Gnash. I eat procrastination. Your phone is an all-you-can-eat buffet."
        default: return "Hey, I’m Willow. Let’s give your notes the attention your For You page gets."
        }
    }

    static func welcome(name: String, persona: MonsterPersona) -> String {
        switch persona.id {
        case "diva": return "\(name) it is. Name remembered. Doomscrolling privileges under review."
        case "coach": return "\(name). Welcome to the squad. Your thumb’s retirement party starts now."
        case "gremlin": return "\(name). Excellent. I’ve added you to my extremely legal goblin records."
        default: return "Nice to meet you, \(name). Tiny steps. Suspiciously good memes. We’ve got this."
        }
    }

    static func prompt(_ phase: BuddyOnboardingPhase, name: String, subject: String,
                       persona: MonsterPersona, card: Regret?) -> String {
        switch phase {
        case .name: return "What should I call you? A first name or nickname works."
        case .pronouns: return "How should I refer to you? You can pick pronouns, type your own, or just use your name."
        case .level: return "Where are you in your study journey?"
        case .subject: return "Which module or topic should we work on first, \(name)? For example, COS 210, Data Structures, or Cell Biology."
        case .exam: return "Got a test or exam coming up for \(subject)? Add the date if you know it."
        case .age: return "Which age range are you in? It helps me keep things right for you."
        case .materials:
            switch persona.id {
            case "diva": return "Drop your notes, \(name). A PDF is the main act, but a Quizlet export or a YouTube lecture work too. I’ll read them and name the subject for you."
            case "coach": return "Notes on the table, \(name). A PDF works best. A Quizlet export or a YouTube lecture are fine too. I’ll label the subject myself."
            case "gremlin": return "Feed me your notes, \(name). A PDF is my favorite snack, though a Quizlet export or a YouTube lecture also chew nicely. I’ll sniff out the subject."
            default: return "Send your notes, \(name). A PDF is best, and a Quizlet export or a YouTube lecture work too. I’ll figure out the subject from them."
            }
        case .practice: return card?.quizPrompt.text ?? "Let’s find a card we can practice with."
        case .practiceReview: return "That’s how we’ll study together. Ask me about the answer, or let’s make your plan. This was practice. No app time earned yet."
        case .rule: return "Each correct flashcard earns 1 minute of scrolling."
        case .offer: return "Your buddy, your cards, your plan. Let’s make it official."
        case .permission: return "I’m back, \(name). One permission lets me guard the apps you choose. iOS will ask you to allow Screen Time access."
        case .apps:
            return persona.id == "gremlin" ? "Which apps go in goblin jail, \(name)? Choose them, then confirm when you’re ready to start guarding."
                : "Which apps are stealing the spotlight, \(name)? Choose them, then confirm when you’re ready to start guarding."
        case .firstRound: return "Your guard is on. Let’s do a real round with your saved cards and earn your first break."
        case .notifications: return "Want a friendly reminder to study? Notifications are optional."
        }
    }
}

@MainActor
extension SGV5FlowModel {
    var buddyPersona: MonsterPersona { PersonaStore.shared.persona }
    var buddyName: String { buddyIdentity.name.isEmpty ? "friend" : buddyIdentity.name }

    func buddySay(_ text: String, isUser: Bool = false, reaction: MonsterReaction? = nil) {
        buddy.entries.append(.init(text: text, isUser: isUser, reaction: reaction?.rawValue))
    }

    func buddyBegin() {
        if buddy.phase == .rule { resumeRetiredRuleQuestion() }
        refreshPendingStudyPrompt()
        let pending = buddy.phase
        let next = buddyUnansweredPhase(startingAt: pending)
        if next != pending {
            // Remove only the obsolete unanswered prompt, never completed replies.
            let prompt = BuddyOnboardingCopy.prompt(pending, name: buddyName,
                subject: v5Profile.subjectLabel, persona: buddyPersona, card: buddy.practiceCard)
            if let last = buddy.entries.last, !last.isUser, last.text == prompt {
                buddy.entries.removeLast()
            }
            buddy.phase = next
            if !buddy.entries.isEmpty { buddyPrompt() }
        }
        if buddy.entries.isEmpty {
            buddy.personaID = buddyPersona.id
            // Guaranteed once; stored in the transcript, so resuming never rerolls it.
            var picker = MonsterReactionPicker()
            buddySay(BuddyOnboardingCopy.greeting(buddyPersona), reaction: picker.opening(persona: buddyPersona, guaranteed: true))
            buddyPrompt()
        } else if buddy.personaID != buddyPersona.id {
            buddy.personaID = buddyPersona.id
            buddySay("\(buddyPersona.name) here. I’ve got your progress. Let’s pick up where you left off.")
        }
    }

    private func resumeRetiredRuleQuestion() {
        if let last = buddy.entries.last, !last.isUser,
           last.text.hasPrefix("A few correct cards before you scroll. What feels doable?") ||
           last.text == BuddyOnboardingCopy.prompt(.rule, name: buddyName,
                subject: v5Profile.subjectLabel, persona: buddyPersona, card: buddy.practiceCard) {
            buddy.entries.removeLast()
        }
        if buddy.practicePassed {
            buddyContinueToOffer()
        } else {
            buddyMove(to: buddy.practiceCard == nil ? .materials : .practice)
        }
    }

    /// Refresh only an unanswered legacy question. Completed conversation stays intact.
    private func refreshPendingStudyPrompt() {
        let oldPrompt: String
        switch buddy.phase {
        case .subject: oldPrompt = "What are we studying, \(buddyName)?"
        case .exam: oldPrompt = "When’s your next \(v5Profile.subjectLabel) exam? No date yet is completely fine."
        default: return
        }
        guard let index = buddy.entries.indices.last, !buddy.entries[index].isUser,
              buddy.entries[index].text == oldPrompt else { return }
        buddy.entries[index].text = BuddyOnboardingCopy.prompt(buddy.phase, name: buddyName,
            subject: v5Profile.subjectLabel, persona: buddyPersona, card: buddy.practiceCard)
    }

    func buddyPrompt() {
        buddySay(BuddyOnboardingCopy.prompt(buddy.phase, name: buddyName, subject: v5Profile.subjectLabel,
                                            persona: buddyPersona, card: buddy.practiceCard))
    }

    func buddyMove(to phase: BuddyOnboardingPhase) {
        buddy.phase = buddyUnansweredPhase(startingAt: phase)
        syncV5Profile()
        buddyPrompt()
    }

    /// Skip answered profile questions while keeping practice and setup reachable.
    /// Walks `flowOrder` (not raw values) so the on-screen order can differ from the
    /// stable Codable raw values.
    func buddyUnansweredPhase(startingAt phase: BuddyOnboardingPhase) -> BuddyOnboardingPhase {
        var next = phase
        while true {
            let answered: Bool
            switch next {
            case .name: answered = !buddyIdentity.name.isEmpty
            case .pronouns: answered = v5Profile.gender != nil || buddy.pronounsAnswered == true
            case .level: answered = v5Profile.studyLevel != nil
            // The subject is detected from the uploaded notes, never asked, so it is
            // always treated as answered and the walk passes straight through it.
            case .subject: answered = true
            case .exam: answered = v5Profile.examDate != nil || v5Profile.noExamYet == true
            case .age: answered = v5Profile.ageBracket != nil
            default: return next
            }
            guard answered, let index = BuddyOnboardingPhase.flowOrder.firstIndex(of: next),
                  index + 1 < BuddyOnboardingPhase.flowOrder.count else { return next }
            next = BuddyOnboardingPhase.flowOrder[index + 1]
        }
    }

    func buddySubmitText(_ raw: String) {
        let value = BuddyIdentity.clean(raw, limit: buddy.phase == .name ? 30 : buddy.phase == .pronouns ? 40 : buddy.phase == .practice ? 4000 : 160)
        guard !value.isEmpty else { return }
        switch buddy.phase {
        case .name:
            var identity = buddyIdentity
            identity.name = value
            saveBuddyIdentity(identity)
            buddySay(value, isUser: true)
            buddySay(BuddyOnboardingCopy.welcome(name: value, persona: buddyPersona))
            buddyMove(to: .pronouns)
        case .pronouns:
            var identity = buddyIdentity
            identity.pronouns = value
            saveBuddyIdentity(identity)
            buddy.pronounsAnswered = true
            buddySay(value, isUser: true)
            buddyMove(to: .level)
        case .subject:
            // Retained only for saved drafts that stopped on the old subject question.
            // New users never reach this phase; notes come next in the current flow.
            v5Profile.subject = value
            buddySay(value, isUser: true)
            buddyMove(to: .materials)
        case .practice:
            guard let card = buddy.practiceCard, let correct = buddy.answerPractice(value) else { return }
            buddySay(value, isUser: true)
            if correct {
                let praise: String
                switch buddyPersona.id {
                case "diva": praise = "Correct. The brain is braining. We love to see it."
                case "coach": praise = "Correct. One brain rep done. Your thumb is on leave."
                case "gremlin": praise = "CORRECT. Brain loot acquired. Goblin approved."
                default: praise = "Exactly. One little W for you. One tiny defeat for the doomscroll."
                }
                buddySay(praise)
                buddyPrompt()
            } else {
                buddySay("Not quite. The answer is \(card.correctAnswer). \(card.backgroundExplanation) Let’s try that once more.")
                buddyPrompt()
            }
        default: break
        }
    }

    func buddyChooseLevel(_ level: SGV5V5OnboardingProfile.StudyLevel) {
        guard buddy.phase == .level else { return }
        v5Profile.studyLevel = level
        buddySay(level.title, isUser: true)
        // Notes come next: the upload gives us the subject, so we never ask for it.
        buddyMove(to: .materials)
    }

    func buddyChooseExam(_ date: Date?, exams: ExamStore = .shared) {
        guard buddy.phase == .exam else { return }
        if let date, Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date()) { return }
        v5Profile.examDate = date
        v5Profile.noExamYet = date == nil
        // The deck already exists (notes were uploaded first), so link it now.
        buddyLinkDeckToExam(exams: exams)
        buddySay(date?.formatted(date: .abbreviated, time: .omitted) ?? "No date yet", isUser: true)
        buddySay("Let’s try one card together. This is just practice, so no app time is earned yet.")
        buddyMove(to: .practice)
    }

    /// Link the chosen practice deck to the user's exam once both exist. A sample
    /// deck never inherits the user's real exam.
    private func buddyLinkDeckToExam(exams: ExamStore) {
        guard buddy.skipExamLink != true, let date = v5Profile.examDate, let deckID = buddy.deckID else { return }
        let existing = buddy.examID.flatMap { id in exams.exams.first { $0.id == id } }
            ?? exams.exams.first { $0.subject == v5Profile.studySubject && Calendar.current.isDate($0.date, inSameDayAs: date) }
        var exam = existing ?? StudyExam(subject: v5Profile.studySubject, date: date)
        if !exam.deckIDs.contains(deckID) { exam.deckIDs.append(deckID) }
        if existing == nil { exams.add(exam) } else { exams.update(exam) }
        buddy.examID = exam.id
    }

    func buddyChooseAge(_ age: SGV5V5OnboardingProfile.AgeBracket) {
        guard buddy.phase == .age else { return }
        v5Profile.ageBracket = age
        buddySay(age.title, isUser: true)
        buddyMove(to: .materials)
    }

    /// Placeholder name for the draft deck created before we know the subject. It is
    /// renamed to the detected subject once the notes produce cards.
    static let buddyDraftDeckName = "My study notes"

    /// The subject inferred from a deck's cards: the most common card topic, ties
    /// broken by first appearance. Nil when no card carries a topic.
    static func buddyDerivedSubject(from deck: Deck) -> String? {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for case let topic? in deck.cards.map(\.topic) {
            let value = topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            if counts[value] == nil { order.append(value) }
            counts[value, default: 0] += 1
        }
        return order.sorted {
            counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]!
                : order.firstIndex(of: $0)! < order.firstIndex(of: $1)!
        }.first
    }

    /// Reuse the same draft deck after cancellation or failed generation.
    func buddyPrepareDeck(in store: DeckStore) -> UUID {
        if let id = buddy.deckID, store.decks.contains(where: { $0.id == id }) { return id }
        // The subject is unknown until the notes are read, so start with a neutral
        // placeholder and rename it in buddyUseDeck.
        let name = v5Profile.studySubject.isEmpty ? Self.buddyDraftDeckName : v5Profile.studySubject
        let deck = Deck(name: name)
        store.addDeck(deck)
        buddy.deckID = deck.id
        return deck.id
    }

    func buddyUseDeck(_ deck: Deck, in store: DeckStore, linkExam: Bool = true, confirmation: String? = nil) {
        guard buddy.phase == .materials, let card = deck.cards.first(where: \.isUsableForStudy) else { return }
        store.selectDeck(deck)
        buddy.deckID = deck.id
        buddy.practiceCard = card
        buddy.practicePassed = false
        buddy.practiceAttempts = 0
        buddy.skipExamLink = !linkExam
        // Detect the subject from the uploaded notes so the user never types it, and
        // name the draft deck after it. A saved deck or sample keeps its own name.
        if v5Profile.studySubject.isEmpty, let subject = Self.buddyDerivedSubject(from: deck) {
            v5Profile.subject = subject
            if deck.name == Self.buddyDraftDeckName {
                var renamed = deck
                renamed.name = subject
                store.updateDeck(renamed)
                store.selectDeck(renamed)
            }
        }
        let deckName = store.selectedDeck?.name ?? deck.name
        buddySay(confirmation ?? "Use \(deckName)", isUser: true)
        buddySay("Your \(v5Profile.subjectLabel) cards are ready. One quick thing before we practice.")
        // The exam date comes next now that we have the subject.
        buddyMove(to: .exam)
    }

    func buddyUseSample(in store: DeckStore) {
        guard buddy.phase == .materials else { return }
        // Label it honestly; a Biology sample never impersonates the user's subject.
        let name = "Study Guard sample · Biology"
        let deck = store.decks.first { $0.name == name && $0.cards.contains(where: \.isUsableForStudy) }
            ?? Deck(name: name, cards: Self.buddySampleCards)
        if !store.decks.contains(where: { $0.id == deck.id }) { store.addDeck(deck) }
        buddySay("We’ll use a short Biology sample. You can add your own notes later.")
        // Sample material must not be linked to an unrelated real exam.
        buddyUseDeck(deck, in: store, linkExam: false)
    }

    func buddyContinueToOffer() {
        guard [.practiceReview, .rule].contains(buddy.phase), buddy.practicePassed else { return }
        // Reuse the existing persisted earning contract: five cards at 60 seconds
        // each. Correct cards earn one minute even in a shorter round.
        v5Profile.studyRule = .five
        buddyMove(to: .offer)
    }

    func buddyShowOffer() {
        guard buddy.phase == .offer else { return }
        if accessVerified { startSetupAfterPurchase() } else { currentPageIndex = 506 }
    }

    func buddyDeferSetup() {
        guard [.permission, .apps, .firstRound].contains(buddy.phase) else { return }
        buddy.setupDeferred = true
        buddySay(buddy.guardConfigured ? "We can study later. Your guard is already on. Home has an Unlock apps button."
                 : "We can finish this from Home. Your apps aren’t guarded yet.")
        buddyMove(to: .notifications)
    }

    static var buddySampleCards: [Regret] {
        let items = [
            ("Which organelle produces most of a cell’s ATP?", "Mitochondrion", "Nucleus", "Ribosome", "Mitochondria release energy from nutrients to produce ATP."),
            ("Which molecule stores genetic information?", "DNA", "ATP", "Glucose", "DNA carries genetic instructions in its nucleotide sequence."),
            ("What do ribosomes make?", "Proteins", "Lipids", "DNA", "Ribosomes join amino acids to build proteins."),
            ("Which process lets plants convert light into chemical energy?", "Photosynthesis", "Diffusion", "Digestion", "Photosynthesis uses light to help produce sugars from carbon dioxide and water."),
            ("Which structure controls what enters and leaves a cell?", "Cell membrane", "Ribosome", "Nucleolus", "The cell membrane is selectively permeable and regulates movement into and out of the cell.")
        ]
        return items.map { q, answer, a, b, explanation in
            Regret(regretPrompt: q, regret: answer, choices: [a, answer, b], correctAnswerIndex: 1,
                   backgroundExplanation: explanation, topic: "Biology")
        }
    }
}
