import XCTest
import AVFoundation
import ImageIO
@testable import StudyReliability

final class MonsterReactionTests: XCTestCase {
    func testCreatorOverrideGuaranteesOneOpeningReactionForEveryPersonaAndSeed() {
        for persona in MonsterPersona.all {
            for seed in 0..<10_000 {
                var picker = MonsterReactionPicker(seed: seed)
                XCTAssertNotNil(picker.opening(persona: persona, guaranteed: true))
                XCTAssertNil(picker.opening(persona: persona, guaranteed: true))
            }
        }
    }

    @MainActor func testCreatorPreferencePersistsAndOnlyChangesNewOpenings() throws {
        let suite = "MonsterCreatorReactionTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = MonsterReactionPicker.alwaysOpeningPreferenceKey
        XCTAssertFalse(defaults.bool(forKey: key))
        for method in [MonsterStudyMethod.inChat, .studySheet] {
            defaults.set(true, forKey: key)
            let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
            let session = makeSession(method: method, seed: 6, creatorDefaults: reopened)
            session.start()
            XCTAssertNotNil(session.messages.first?.reaction)
            XCTAssertEqual(session.messages.compactMap(\.reaction).count, 1)
            let sent = session.messages
            defaults.set(false, forKey: key)
            session.stop(); session.start()
            XCTAssertEqual(session.messages, sent, "The toggle must not edit an existing opening")
            let next = makeSession(method: method, seed: 6, creatorDefaults: reopened)
            next.start()
            XCTAssertNil(next.messages.first?.reaction, "Turning off restores the normal probability")
            session.stop(); next.stop()
        }
    }

    func testFourMissesAlwaysSendAnAnimatedReactionWithoutFloodingEveryMiss() {
        for seed in [0, 6] {
            var picker = MonsterReactionPicker(seed: seed)
            _ = picker.opening(persona: .willow)
            for miss in 1...12 {
                let reaction = picker.answer(correct: false)
                XCTAssertEqual(reaction != nil, miss.isMultiple(of: 4))
                if let reaction { XCTAssertTrue(reaction.isAnimated) }
            }
            for _ in 0..<3 { XCTAssertNil(picker.answer(correct: false)) }
            XCTAssertNil(picker.answer(correct: true))
            for _ in 0..<3 { XCTAssertNil(picker.answer(correct: false)) }
            XCTAssertNotNil(picker.answer(correct: false), "A correct answer resets the consecutive count")
        }
    }

    @MainActor func testInlineMissReactionSurvivesPauseAndResetsAfterACorrectAnswer() throws {
        for persona in MonsterPersona.all {
            for seed in [0, 6] {
                let session = makeSession(persona: persona, method: .inChat, seed: seed)
                session.start()
                // The correct answer breaks the first streak. Both choice and
                // typed submissions contribute to the subsequent four misses.
                for (index, correct) in [false, false, false, true, false, false, false, false].enumerated() {
                    if index == 7 {
                        session.stop()
                        session.answer(choiceIndex: 1) // paused submissions do not count
                        session.start()
                    }
                    let before = session.messages.count
                    session.answer(choiceIndex: 99) // invalid submissions do not count
                    if index.isMultiple(of: 2) {
                        session.answer(choiceIndex: correct ? 0 : 1)
                    } else {
                        session.answer(typed: correct ? "light" : "sand")
                    }
                    let feedback = session.messages.dropFirst(before).filter { $0.text != nil && $0.sender == .monster }
                    XCTAssertEqual(feedback.compactMap(\.reaction).count, index == 7 ? 1 : 0)
                    if index == 7 { XCTAssertEqual(feedback.first?.reaction, .doubleTake) }
                }
                XCTAssertEqual(session.studyEarnedSeconds, session.secondsPerCorrectAnswer,
                               "Only the correct answer earns time")
                let sent = session.messages
                session.stop(); session.start()
                XCTAssertEqual(session.messages, sent)
                session.stop()
            }
        }
    }

    @MainActor func testSheetMissReactionBelongsToTheFourthAnswerAndSurvivesResume() throws {
        let session = makeSession(method: .studySheet, seed: 0)
        session.start()
        XCTAssertNotNil(session.messages.first?.reaction)
        XCTAssertTrue(session.beginStudyRound())
        for index in 0..<4 {
            if index == 3 { session.stop(); session.start(); XCTAssertTrue(session.beginStudyRound()) }
            let id = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
            session.answerStudyChoice(questionID: UUID(), index: 1)
            session.answerStudyChoice(questionID: id, index: 1)
            for _ in 0..<4 { session.answerStudyChoice(questionID: id, index: 1) }
            XCTAssertEqual(session.studyRound?.currentAnswer?.reaction != nil, index == 3,
                           "Duplicate or stale submissions cannot advance the miss count")
            if index < 3 { XCTAssertFalse(session.advanceStudyRound(questionID: id)) }
        }
        XCTAssertEqual(session.studyRound?.currentAnswer?.reaction, .doubleTake)
        XCTAssertEqual(session.studyEarnedSeconds, 0)
        let answer = session.studyRound?.currentAnswer
        session.stop(); session.start(); XCTAssertTrue(session.beginStudyRound())
        XCTAssertEqual(session.studyRound?.currentAnswer, answer)
        XCTAssertTrue(session.advanceStudyRound(questionID: try XCTUnwrap(answer?.id)))
        XCTAssertTrue(session.beginStudyRound())
        let next = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
        session.answerStudyChoice(questionID: next, index: 1)
        XCTAssertNil(session.studyRound?.currentAnswer?.reaction, "The next miss should not repeat the GIF")
        session.stop()
    }

    @MainActor func testSheetMissCountCarriesIntoFollowUpAndCorrectAnswersResetIt() throws {
        for correctIndex in [0, 3] {
            let session = makeSession(method: .studySheet, seed: 6)
            session.start()
            XCTAssertTrue(session.beginStudyRound())
            for index in 0..<4 {
                let id = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
                session.answerStudyChoice(questionID: id, index: index == correctIndex ? 0 : 1)
                XCTAssertNil(session.studyRound?.currentAnswer?.reaction)
                _ = session.advanceStudyRound(questionID: id)
            }
            XCTAssertTrue(session.studyRound?.isFollowUp == true)
            XCTAssertTrue(session.beginStudyRound())
            let id = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
            session.answerStudyChoice(questionID: id, index: 1)
            XCTAssertEqual(session.studyRound?.currentAnswer?.reaction != nil, correctIndex == 0)
            session.stop()
        }
    }

    @MainActor private func makeSession(persona: MonsterPersona = .willow, method: MonsterStudyMethod,
                                       seed: Int, creatorDefaults: UserDefaults = .standard) -> MonsterSession {
        let cards = (0..<20).map { index in
            Regret(regretPrompt: "Question \(index): what do plants absorb?", regret: "light",
                   choices: ["light", "sand"], correctAnswerIndex: 0,
                   backgroundExplanation: "Light supplies energy.")
        }
        let store = DeckStore(); store.selectedDeck = Deck(name: "Biology", cards: cards)
        let personaStore = PersonaStore(); personaStore.persona = persona
        return MonsterSession(deckStore: store, examStore: ExamStore(), personaStore: personaStore,
            studyGuard: StudyGuardManager(), sharedDefaults: nil, creatorDefaults: creatorDefaults,
            method: method, loadBundle: { _, _, _ in nil }, reactionSeed: seed)
    }

    func testEveryPersonaSendsAnOpeningReactionForSixtyPercentOfSeeds() {
        var allOpeningVariants: Set<MonsterReaction> = []
        for persona in MonsterPersona.all {
            var shown = 0
            var variants: Set<MonsterReaction> = []
            for seed in 0..<10_000 {
                var picker = MonsterReactionPicker(seed: seed)
                if let reaction = picker.opening(persona: persona) {
                    shown += 1
                    variants.insert(reaction)
                    XCTAssertNil(picker.completedRound(correctAnswers: 4, totalAnswers: 4),
                                 "An opening attachment replaces the completion attachment")
                }
                XCTAssertNil(picker.opening(persona: persona), "An opening decision cannot be replayed")
            }
            XCTAssertEqual(shown, 6_000, persona.name)
            XCTAssertGreaterThanOrEqual(variants.count, 3)
            XCTAssertTrue(variants.contains(where: \.isAnimated))
            XCTAssertTrue(variants.contains(where: { !$0.isAnimated }))
            XCTAssertFalse(variants.contains(.snackBreak), "The snack loop belongs with an earned break")
            allOpeningVariants.formUnion(variants)
        }
        let newStickers: Set<MonsterReaction> = [.stunnedDriver, .awkwardWave, .raisedFingerCat,
            .unimpressedDog, .spaceDogShrug, .thinkingMonkey, .grinningDog, .sideEyeSip, .sleepyDog, .holdingItIn]
        XCTAssertTrue(newStickers.isSubset(of: allOpeningVariants), "Every new sticker must be available in chat")
    }

    func testOpeningChanceIgnoresCompletionCooldownAndRemembersTheLastReaction() throws {
        let suite = "MonsterOpeningReactionTests." + UUID().uuidString
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        for persona in MonsterPersona.all {
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defaults.set(4, forKey: "sg_monsterReaction.completedRoundGap.v1")
            var shown = 0
            var previous: MonsterReaction?
            for seed in 0..<100 {
                let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
                var picker = MonsterReactionPicker(seed: seed, defaults: reopened)
                if let reaction = picker.opening(persona: persona) {
                    shown += 1
                    XCTAssertNotEqual(reaction, previous, "Consecutive attachments should vary across sessions")
                    previous = reaction
                }
            }
            XCTAssertEqual(shown, 60)
            XCTAssertEqual(defaults.integer(forKey: "sg_monsterReaction.completedRoundGap.v1"), 4)
        }
    }

    @MainActor func testOpeningMediaFollowsTheFirstMessageAndNeverRerollsOnResume() throws {
        for persona in MonsterPersona.all {
            for method in [MonsterStudyMethod.inChat, .studySheet] {
                for seed in [0, 6] {
                    let card = Regret(regretPrompt: "What do plants absorb?", regret: "light",
                        choices: ["light", "sand"], correctAnswerIndex: 0, backgroundExplanation: "")
                    let store = DeckStore(); store.selectedDeck = Deck(name: "Biology", cards: [card])
                    let personaStore = PersonaStore(); personaStore.persona = persona
                    let manager = StudyGuardManager()
                    let session = MonsterSession(deckStore: store, examStore: ExamStore(), personaStore: personaStore,
                        studyGuard: manager, sharedDefaults: nil, method: method,
                        loadBundle: { _, _, _ in nil }, reactionSeed: seed)
                    session.start()
                    XCTAssertEqual(session.messages[0].reaction != nil, seed == 0)
                    XCTAssertTrue(session.messages.dropFirst().allSatisfy { $0.reaction == nil })
                    XCTAssertTrue(session.messages[2].text?.contains("1 flashcard from your Biology deck") == true)
                    XCTAssertEqual(manager.grants, 0)
                    let before = session.messages
                    session.stop(); session.start()
                    XCTAssertEqual(session.messages, before)
                    if method == .inChat {
                        session.answer(choiceIndex: 0)
                    } else {
                        XCTAssertTrue(session.beginStudyRound())
                        let questionID = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
                        session.answerStudyChoice(questionID: questionID, index: 0)
                        XCTAssertTrue(session.advanceStudyRound(questionID: questionID))
                        session.claimStudyTime()
                    }
                    XCTAssertEqual(session.messages.filter { $0.reaction != nil }.count, seed == 0 ? 1 : 0)
                    XCTAssertEqual(manager.grants, 1)
                    session.stop()
                }
            }
        }
    }

    func testBundledLibraryHasEveryPosterAndSilentLoop() async throws {
        XCTAssertEqual(MonsterReaction.allCases.count, 18)
        for reaction in MonsterReaction.allCases {
            let poster = try XCTUnwrap(reaction.resourceURL(extension: "jpg", bundle: .module))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(poster as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(Double(image.width) / Double(image.height), reaction.aspectRatio, accuracy: 0.01)
            if reaction.isAnimated {
                let url = try XCTUnwrap(reaction.resourceURL(extension: "mp4", bundle: .module))
                let asset = AVURLAsset(url: url)
                let audio = try await asset.loadTracks(withMediaType: .audio)
                let video = try await asset.loadTracks(withMediaType: .video)
                let duration = try await asset.load(.duration).seconds
                XCTAssertTrue(audio.isEmpty, "Reactions must never interrupt the user's audio")
                XCTAssertEqual(video.count, 1)
                XCTAssertTrue((1...6).contains(duration))
                if reaction == .snackBreak {
                    XCTAssertEqual(duration, 4.3, accuracy: 0.04,
                                   "Do not reintroduce the Control Center footage at the end")
                }
            }
        }
    }

    func testOnlyStrongCompletedRoundsCanReceiveAReaction() {
        for (correct, total) in [(0, 0), (0, 4), (1, 4), (2, 3), (5, 4)] {
            var picker = MonsterReactionPicker(seed: 0)
            XCTAssertNil(picker.completedRound(correctAnswers: correct, totalAnswers: total))
        }
        for seed in [0, 4, 8, 12] {
            var picker = MonsterReactionPicker(seed: seed)
            let reaction = picker.completedRound(correctAnswers: 3, totalAnswers: 4)
            XCTAssertTrue(reaction.map { [MonsterReaction.rainbowRide, .delightedLaugh, .snackBreak, .grinningDog].contains($0) } ?? false)
            XCTAssertNil(picker.completedRound(correctAnswers: 4, totalAnswers: 4),
                         "Completion gets at most one attachment, even if called twice")
        }
        for seed in [1, 2, 3] {
            var picker = MonsterReactionPicker(seed: seed)
            XCTAssertNil(picker.completedRound(correctAnswers: 4, totalAnswers: 4),
                         "Completion reactions retain their quieter cadence")
        }
    }

    func testReactionGapSurvivesNewSessionsAndDefaultsInstances() throws {
        let suite = "MonsterReactionTests.\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        var shown: [Int] = []
        for session in 0..<20 {
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            var picker = MonsterReactionPicker(seed: 0, defaults: defaults)
            if picker.completedRound(correctAnswers: 4, totalAnswers: 4) != nil { shown.append(session) }
        }
        XCTAssertEqual(shown, [0, 4, 8, 12, 16],
                       "At least three eligible strong rounds separate completion reactions across chat relaunches")
    }

    func testMediaCanOnlyAccompanyMonsterSpeechAndCannotEarnTime() {
        let reaction = MonsterMessage.monster("You got it!", reaction: .delightedLaugh)
        XCTAssertEqual(reaction.reaction, .delightedLaugh)
        XCTAssertTrue(MonsterAnswerReward.earned(in: [reaction], secondsPerCorrectAnswer: 75).isEmpty)
        XCTAssertNil(MonsterMessage(sender: .user, kind: .text("Hi"), reaction: .wideEyes).reaction)
        XCTAssertNil(MonsterMessage(sender: .monster, kind: .grant(minutes: 2), reaction: .rainbowRide).reaction)
    }

    @MainActor func testCorrectStudyTurnsHaveNoMediaAndCompletionGroupsBeforeTheBadge() throws {
        for seed in [16, 7, 8] {
            let cards = (0..<3).map { index in
                Regret(regretPrompt: "Question \(index): what do plants absorb?", regret: "light",
                       choices: ["light", "sand"], correctAnswerIndex: 0,
                       backgroundExplanation: "Light supplies energy.")
            }
            let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: cards)
            let manager = StudyGuardManager()
            let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
                                         method: .inChat, loadBundle: { _, _, _ in nil }, reactionSeed: seed)
            session.start()
            XCTAssertTrue(session.messages.allSatisfy { $0.reaction == nil })
            for _ in 0..<session.totalQuestions {
                XCTAssertTrue(session.messages.allSatisfy { $0.reaction == nil },
                              "Correct answers do not trigger the missed-answer GIF")
                session.answer(choiceIndex: 0)
            }
            let media = session.messages.indices.filter { session.messages[$0].reaction != nil }
            XCTAssertEqual(media.count, seed == 7 ? 0 : 1)
            let grant = try XCTUnwrap(session.messages.firstIndex { if case .grant = $0.kind { return true }; return false })
            XCTAssertTrue(media.allSatisfy { $0 < grant })
            XCTAssertEqual(grant, session.messages.count - 1,
                           "The unlock badge follows all closing dialogue after the local grant succeeds")
            if seed == 8 {
                XCTAssertEqual(session.messages.last(where: { $0.sender == .monster && $0.text != nil })?.reaction, .snackBreak,
                               "The snack clip accompanies the earned-break sendoff")
            }
            XCTAssertEqual(manager.grants, 1)
            let sent = session.messages
            session.start(); session.answer(choiceIndex: 0)
            XCTAssertEqual(session.messages, sent)
            XCTAssertEqual(manager.grants, 1)
            session.stop()
        }
    }

    @MainActor func testStudySheetWaitsUntilTimeIsClaimedBeforeSendingCelebrationMedia() throws {
        let card = Regret(regretPrompt: "What do plants absorb?", regret: "light",
                          choices: ["light", "sand"], correctAnswerIndex: 0,
                          backgroundExplanation: "Light supplies energy.")
        let store = DeckStore(); store.selectedDeck = Deck(name: "Test", cards: [card])
        let session = MonsterSession(deckStore: store, studyGuard: StudyGuardManager(), sharedDefaults: nil,
                                     method: .studySheet, reactionSeed: 8)
        session.start()
        XCTAssertTrue(session.beginStudyRound())
        let id = try XCTUnwrap(session.studyRound?.currentQuestion?.id)
        session.answerStudyChoice(questionID: id, index: 0)
        XCTAssertTrue(session.advanceStudyRound(questionID: id))
        XCTAssertTrue(session.messages.allSatisfy { $0.reaction == nil })
        session.claimStudyTime()
        XCTAssertEqual(session.messages.filter { $0.reaction != nil }.count, 1)
        XCTAssertEqual(session.messages.last(where: { $0.text != nil })?.reaction, .snackBreak)
        guard case .grant = session.messages.last?.kind else {
            return XCTFail("The unlock badge should follow the study-sheet sendoff")
        }
        session.claimStudyTime()
        XCTAssertEqual(session.messages.filter { $0.reaction != nil }.count, 1)
        session.stop()
    }
}
