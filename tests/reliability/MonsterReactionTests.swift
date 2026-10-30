import XCTest
import AVFoundation
import ImageIO
@testable import StudyReliability

final class MonsterReactionTests: XCTestCase {
    func testZazaOpeningReactionIsOccasionalAndReplacesTheCompletionAttachment() throws {
        let suite = "ZazaOpeningReactionTests." + UUID().uuidString
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        var shown: [Int] = []
        for visit in 0..<12 {
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            var picker = MonsterReactionPicker(seed: 0, defaults: defaults)
            if let reaction = picker.opening(persona: .diva) {
                XCTAssertEqual(reaction, .doubleTake)
                XCTAssertNil(picker.opening(persona: .diva))
                XCTAssertNil(picker.completedRound(correctAnswers: 4, totalAnswers: 4))
                shown.append(visit)
            } else {
                _ = picker.completedRound(correctAnswers: 4, totalAnswers: 4)
            }
        }
        XCTAssertEqual(shown, [0, 4, 8])
        for persona in [MonsterPersona.willow, .coach, .gremlin] {
            var picker = MonsterReactionPicker(seed: 0)
            XCTAssertNil(picker.opening(persona: persona))
        }
    }

    @MainActor func testZazaGifAccompaniesTheScrollCalloutAndDoesNotReplay() {
        let card = Regret(regretPrompt: "What do plants absorb?", regret: "light",
                          choices: ["light", "sand"], correctAnswerIndex: 0, backgroundExplanation: "")
        let store = DeckStore(); store.selectedDeck = Deck(name: "Biology", cards: [card])
        let persona = PersonaStore(); persona.persona = .diva
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, examStore: ExamStore(), personaStore: persona,
            studyGuard: manager, sharedDefaults: nil, method: .inChat,
            loadBundle: { _, _, _ in nil }, reactionSeed: 0)
        session.start()
        XCTAssertEqual(session.messages[1].reaction, .doubleTake)
        XCTAssertTrue(session.messages[2].text?.contains("1 flashcard from your Biology deck") == true)
        XCTAssertEqual(manager.grants, 0)
        let before = session.messages
        session.stop(); session.start()
        XCTAssertEqual(session.messages, before)
        session.answer(choiceIndex: 0)
        XCTAssertEqual(session.messages.filter { $0.reaction != nil }.count, 1)
        XCTAssertEqual(manager.grants, 1)
        session.stop()
    }

    func testBundledLibraryHasEveryPosterAndSilentLoop() async throws {
        XCTAssertEqual(MonsterReaction.allCases.count, 8)
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
        for seed in [0, 4, 8] {
            var picker = MonsterReactionPicker(seed: seed)
            let reaction = picker.completedRound(correctAnswers: 3, totalAnswers: 4)
            XCTAssertTrue(reaction.map { [MonsterReaction.rainbowRide, .delightedLaugh, .snackBreak].contains($0) } ?? false)
            XCTAssertNil(picker.completedRound(correctAnswers: 4, totalAnswers: 4),
                         "A session gets at most one attachment, even if completion is called twice")
        }
        for seed in [1, 2, 3] {
            var picker = MonsterReactionPicker(seed: seed)
            XCTAssertNil(picker.completedRound(correctAnswers: 4, totalAnswers: 4),
                         "Most sessions remain free of media")
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
                       "At least three successful rounds separate reactions across chat relaunches")
    }

    func testMediaCanOnlyAccompanyMonsterSpeechAndCannotEarnTime() {
        let reaction = MonsterMessage.monster("You got it!", reaction: .delightedLaugh)
        XCTAssertEqual(reaction.reaction, .delightedLaugh)
        XCTAssertTrue(MonsterAnswerReward.earned(in: [reaction], secondsPerCorrectAnswer: 75).isEmpty)
        XCTAssertNil(MonsterMessage(sender: .user, kind: .text("Hi"), reaction: .wideEyes).reaction)
        XCTAssertNil(MonsterMessage(sender: .monster, kind: .grant(minutes: 2), reaction: .rainbowRide).reaction)
    }

    @MainActor func testLiveSessionKeepsStudyTurnsFreeOfMediaAndGroupsCompletionBeforeTheBadge() throws {
        for seed in [0, 1, 8] {
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
                              "No memes in greetings, questions, or individual answer feedback")
                session.answer(choiceIndex: 0)
            }
            let media = session.messages.indices.filter { session.messages[$0].reaction != nil }
            XCTAssertEqual(media.count, seed == 1 ? 0 : 1)
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

    @MainActor func testStudySheetWaitsUntilTimeIsClaimedBeforeSendingMedia() throws {
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
