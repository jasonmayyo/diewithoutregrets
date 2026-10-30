import XCTest
@testable import StudyReliability

final class MonsterOpeningTests: XCTestCase {
    private func card(source: FlashcardSource? = nil) -> Regret {
        Regret(regretPrompt: "What do plants absorb?", regret: "light",
               choices: ["light", "sand"], correctAnswerIndex: 0,
               backgroundExplanation: "Light supplies energy.", topic: "Photosynthesis", source: source)
    }

    func testExamOpenersUseTodayTomorrowAndTheActualCountdownForEveryPersona() {
        for persona in [MonsterPersona.diva, .willow, .coach, .gremlin] {
            for (days, phrase) in [(0, "today"), (1, "tomorrow"), (2, "in 2 days")] {
                let vars = MonsterScriptVars(exam: "Biology", examDays: days, questions: 3)
                let line = MonsterScript.openingGreeting(persona: persona, mood: .chill, vars: vars, seed: 0)
                XCTAssertTrue(line.contains("Biology exam is \(phrase)"))
                XCTAssertFalse(line.contains("0 days"))
                XCTAssertFalse(line.contains("1 days"))
            }
            for vars in [MonsterScriptVars(), .init(exam: "Biology", examDays: -1),
                         .init(exam: " ", examDays: 2), .init(exam: "Biology")] {
                let line = MonsterScript.openingGreeting(persona: persona, mood: .feral, vars: vars, seed: 0)
                XCTAssertFalse(line.contains("exam"), "Missing/past dates must not create an exam deadline")
            }
        }
    }

    func testSourceIndicatorUsesOnlySelectedMaterialsAndKeepsLegacyCardsHonest() {
        let pdf = card(source: .init(kind: .pdf, title: "Cell Biology.pdf"))
        let notes = card(source: .init(kind: .notes))
        XCTAssertEqual(MonsterStudySource.selected(cards: [pdf, pdf], deckName: "Biology"),
                       [.init(kind: .pdf, title: "Cell Biology.pdf")])
        XCTAssertEqual(MonsterStudySource.selected(cards: [notes], deckName: "Biology"),
                       [.init(kind: .notes, title: "Pasted notes")])
        XCTAssertEqual(MonsterStudySource.selected(cards: [card()], deckName: "Biology"),
                       [.init(kind: .deck, title: "Biology")])
        let mixed = MonsterStudySource.selected(cards: [pdf, notes, card()], deckName: "Biology")
        XCTAssertEqual(mixed.count, 3)
        XCTAssertEqual(mixed.map(\.kind), [.pdf, .notes, .deck])
        XCTAssertTrue(MonsterStudySource.selected(cards: [], deckName: nil).isEmpty)
    }

    func testEveryPersonaHasTwelveDistinctOpenersAndPromptsUsingRealStudyContext() {
        for persona in [MonsterPersona.diva, .willow, .coach, .gremlin] {
            for hasExam in [false, true] {
                let vars = MonsterScriptVars(exam: hasExam ? "Biology" : nil,
                    examDays: hasExam ? 2 : nil, topic: "Photosynthesis", deck: "Biology", questions: 3)
                let greetings = (0..<12).map {
                    MonsterScript.openingGreeting(persona: persona, mood: .chill, vars: vars, seed: $0)
                }
                let prompts = (0..<12).map {
                    MonsterScript.openingPrompt(persona: persona, vars: vars, seed: $0)
                }
                XCTAssertEqual(Set(greetings).count, 12)
                XCTAssertEqual(Set(prompts).count, 12)
                for greeting in greetings {
                    XCTAssertEqual(greeting.contains("Biology exam is in 2 days"), hasExam)
                    XCTAssertFalse(greeting.contains("{"))
                }
                for prompt in prompts {
                    XCTAssertTrue(prompt.contains(persona.id == MonsterPersona.diva.id
                        ? "3 flashcards from your Biology deck" : "3 questions on Photosynthesis"))
                    XCTAssertFalse(prompt.contains("PDF"))
                    XCTAssertFalse(prompt.contains("{"))
                }
            }
        }
    }

    func testOpeningRotationPersistsAndDoesNotRepeatWithinEachCycleOrAtItsBoundary() throws {
        let suite = "MonsterOpeningTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for persona in [MonsterPersona.diva, .willow, .coach, .gremlin] {
            var lastGreeting: Int?, lastPrompt: Int?
            for _ in 0..<3 {
                var greetings: Set<Int> = [], prompts: Set<Int> = []
                for _ in 0..<12 {
                    // A fresh defaults instance simulates constructing a later session.
                    let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
                    let choice = MonsterOpeningRotation.next(personaID: persona.id, hasExam: true, defaults: reopened)
                    XCTAssertNotEqual(choice.greeting, lastGreeting)
                    XCTAssertNotEqual(choice.prompt, lastPrompt)
                    greetings.insert(choice.greeting); prompts.insert(choice.prompt)
                    lastGreeting = choice.greeting; lastPrompt = choice.prompt
                }
                XCTAssertEqual(greetings.count, 12)
                XCTAssertEqual(prompts.count, 12)
            }
        }
    }

    func testSourceSurvivesSavingAndChoiceUpgradeWithoutBreakingOldCards() throws {
        var original = card(source: .init(kind: .pdf, title: "Cell Biology.pdf"))
        original.answerMode = .typed
        original.choices = ["light"]
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(Regret.self, from: data), original)
        XCTAssertEqual(original.promotedToChoices(with: ["sand", "water", "rock"])?.source, original.source)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "source")
        let legacy = try JSONDecoder().decode(Regret.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(legacy.source)
        XCTAssertEqual(legacy.id, original.id)
        XCTAssertEqual(legacy.correctAnswer, original.correctAnswer)
        old["source"] = ["kind": "future-source", "title": "Still a usable card"]
        XCTAssertNil(try JSONDecoder().decode(Regret.self, from: JSONSerialization.data(withJSONObject: old)).source)
    }

    @MainActor func testBothStudyModesOpenWithExamAndSourceBeforeTheFirstQuestionOffline() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!
        for method in [MonsterStudyMethod.inChat, .studySheet] {
            let decks = DeckStore()
            decks.selectedDeck = Deck(name: "Biology", cards: [card(source: .init(kind: .pdf, title: "Cell Biology.pdf"))])
            let exams = ExamStore()
            exams.nextExam = StudyExam(subject: "Biology", date: Calendar.current.date(byAdding: .day, value: 2, to: now)!)
            let persona = PersonaStore(); persona.persona = .diva
            let session = MonsterSession(deckStore: decks, examStore: exams, personaStore: persona,
                studyGuard: StudyGuardManager(), sharedDefaults: nil, now: now, method: method,
                loadBundle: { _, _, _ in nil })
            session.start()
            XCTAssertEqual(session.messages.count, 4, "Exam, scrolling call-out, deck challenge, then the card/round")
            XCTAssertTrue(session.messages[0].text?.contains("Biology exam is in 2 days") == true)
            XCTAssertFalse(session.messages[2].text?.contains("Cell Biology.pdf") == true)
            XCTAssertEqual(session.messages[2].sources, [.init(kind: .pdf, title: "Cell Biology.pdf")])
            XCTAssertTrue(session.messages[2].text?.contains("1 flashcard from your Biology deck") == true)
            XCTAssertFalse(session.isThinking)
            let opening = session.messages
            session.start()
            XCTAssertEqual(session.messages, opening)
            session.stop()
        }
    }

    func testZazaOutcomeAndSendoffLanesDoNotRepeatAcrossRestarts() throws {
        let suite = "ZazaVoiceTests." + UUID().uuidString
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        for lane in ["scrollCallout", "result.perfect", "result.mixed", "result.noCorrect",
                     "sendoff.perfect", "sendoff.mixed", "sendoff.noGrant"] {
            var last: Int?
            for _ in 0..<3 {
                var seen: Set<Int> = []
                for _ in 0..<12 {
                    let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
                    let picked = MonsterOpeningRotation.draw(personaID: "diva", lane: lane, defaults: reopened)
                    XCTAssertNotEqual(picked, last)
                    XCTAssertTrue(seen.insert(picked).inserted)
                    last = picked
                }
            }
        }
    }

    func testZazaCopyHasDistinctOutcomesAndNeverPromisesTimeAfterAZeroGrant() {
        let vars = MonsterScriptVars(exam: "Biology", examDays: 2)
        XCTAssertEqual(Set((0..<12).map { MonsterScript.scrollCallout(seed: $0) }).count, 12)
        for outcome in MonsterRoundOutcome.allCases {
            let replies = (0..<12).map { MonsterScript.zazaRoundReaction(outcome: outcome, vars: vars, seed: $0) }
            XCTAssertEqual(Set(replies).count, 12)
            XCTAssertTrue(replies.allSatisfy { !$0.contains("{") && !$0.contains("unlocked") })
            for minutes in [0, 1, 7] {
                let endings = (0..<12).map { MonsterScript.zazaSendoff(outcome: outcome, minutes: minutes, seed: $0) }
                XCTAssertEqual(Set(endings).count, 12)
                for ending in endings {
                    XCTAssertFalse(ending.contains("{"))
                    if minutes > 0 { XCTAssertTrue(ending.contains("\(minutes) minute")) }
                    else {
                        XCTAssertFalse(ending.contains("unlocked"))
                        XCTAssertFalse(ending.contains("guilt-free"))
                    }
                }
            }
        }
        XCTAssertEqual(MonsterRoundOutcome(correctAnswers: 3, totalAnswers: 3), .perfect)
        XCTAssertEqual(MonsterRoundOutcome(correctAnswers: 3, totalAnswers: 4), .mixed,
                       "A later correction must not erase the earlier miss from the tone")
        XCTAssertEqual(MonsterRoundOutcome(correctAnswers: 0, totalAnswers: 3), .noCorrect)
    }

    @MainActor func testZazaReopeningKeepsCopyAndSwitchingUsesTheNewDeckAndRemainingCount() throws {
        let suite = "ZazaDeckVoiceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DeckStore(); store.selectedDeck = Deck(name: "Biology", cards: [card(), card(), card()])
        let persona = PersonaStore(); persona.persona = .diva
        let session = MonsterSession(deckStore: store, examStore: ExamStore(), personaStore: persona,
            studyGuard: StudyGuardManager(), sharedDefaults: defaults, method: .inChat,
            loadBundle: { _, _, _ in nil })
        session.start()
        let opening = session.messages
        session.stop(); session.start()
        XCTAssertEqual(session.messages, opening)
        session.answer(choiceIndex: 0)
        let remaining = session.totalQuestions - 1
        store.selectedDeck = Deck(name: "Chemistry", cards: [card(), card(), card()])
        XCTAssertTrue(session.switchToSelectedDeck())
        XCTAssertTrue(session.messages.last(where: { !$0.sources.isEmpty })?.text?
            .contains("\(remaining) flashcard\(remaining == 1 ? "" : "s") from your Chemistry deck") == true)
        session.stop()
    }

    @MainActor func testZazaEndingsMatchPerfectMixedAndZeroResultsAndTheActualGrant() throws {
        for hits in [0, 1, 3] {
            let suite = "ZazaResultTests." + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let outcome = MonsterRoundOutcome(correctAnswers: hits, totalAnswers: 3)
            for lane in ["result.\(outcome.rawValue)", "sendoff.\(hits == 0 ? "noGrant" : outcome.rawValue)"] {
                defaults.set(["remaining": [0]], forKey: "sg_monsterOpening.v1.diva.\(lane)")
            }
            let now = Date()
            let cards = (0..<3).map { _ in
                var item = card(); item.lastReviewedAt = now
                return item
            }
            let store = DeckStore(); store.selectedDeck = Deck(name: "Biology", cards: cards)
            let manager = StudyGuardManager()
            let persona = PersonaStore(); persona.persona = .diva
            let session = MonsterSession(deckStore: store, examStore: ExamStore(), personaStore: persona,
                studyGuard: manager, sharedDefaults: defaults, now: now, method: .inChat,
                loadBundle: { _, _, _ in nil }, reactionSeed: 1)
            session.start()
            XCTAssertEqual(session.totalQuestions, 3)
            for index in 0..<3 { session.answer(choiceIndex: index < hits ? 0 : 1) }
            XCTAssertTrue(session.isFinished)
            XCTAssertEqual(manager.grants, 1)
            let recap = try XCTUnwrap(session.messages.firstIndex { $0.sender == .system && $0.text?.hasPrefix("Recap:") == true })
            let reaction = try XCTUnwrap(session.messages[recap - 2].text)
            XCTAssertEqual(reaction, hits == 3
                ? "damnnn, okay girl. you know your 💩. every card right."
                : hits == 1 ? "yeah, those study notes aren't gonna learn themselves, sister."
                : "girl. those study notes need you more than the feed does right now.")
            let ending = try XCTUnwrap(session.messages[recap - 1].text)
            XCTAssertEqual(session.messages[recap - 2].sender, .monster)
            XCTAssertEqual(session.messages[recap - 1].sender, .monster,
                           "The outcome and sendoff stay together above the recap and unlock badge")
            if hits == 0 {
                XCTAssertEqual(session.grantedMinutes, 0)
                XCTAssertTrue(ending.contains("no scroll time earned"))
                XCTAssertFalse(session.messages.contains { if case .grant = $0.kind { return true }; return false })
            } else {
                XCTAssertTrue(ending.contains("\(session.grantedMinutes) minutes"))
                let grant = try XCTUnwrap(session.messages.firstIndex { if case .grant = $0.kind { return true }; return false })
                XCTAssertGreaterThan(grant, recap, "The outcome is spoken before the visible unlock notice")
                XCTAssertEqual(grant, session.messages.count - 1)
                XCTAssertEqual(ending.contains("guilt-free"), hits == 3)
            }
            let settled = session.messages
            session.start(); session.answer(choiceIndex: 0)
            XCTAssertEqual(session.messages, settled)
            XCTAssertEqual(manager.grants, 1)
            session.stop()
        }
    }
}
