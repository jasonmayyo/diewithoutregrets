import XCTest
@testable import StudyReliability

@MainActor
private final class AuditHangingAttestation: AppAttesting {
    var isSupported = true
    var continuation: CheckedContinuation<String, Error>?
    func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data { Data() }
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data { Data() }
}

final class MonsterReleaseAuditTests: XCTestCase {
    // These are characterization probes: passing confirms the reported defect.
    @MainActor func testPunctuationAnswerIsAcceptedIntoAnUnfinishableChat() {
        let card = Regret(regretPrompt: "Which punctuation mark ends a question?", regret: "?",
            choices: ["?"], correctAnswerIndex: 0, backgroundExplanation: "A question mark.", answerMode: .typed)
        XCTAssertTrue(card.isUsableForStudy)
        XCTAssertFalse(AnswerGrading.matches(card.correctAnswer, card.correctAnswer))
        let suite = "AuditPunctuation.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        for _ in 0..<6 { SGContract.recordGateEncounter(preferences) }
        let store = DeckStore(); store.selectedDeck = Deck(name: "Punctuation", cards: [card])
        let manager = StudyGuardManager()
        let session = MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: preferences,
            creatorDefaults: preferences, method: .inChat, loadBundle: { _, _, _ in nil })
        session.start()
        XCTAssertGreaterThanOrEqual(session.dials.mood, .annoyed)
        for _ in 0..<20 { session.answer(typed: "?") }
        XCTAssertFalse(session.isFinished)
        XCTAssertNotNil(session.activeCard)
        XCTAssertEqual(manager.grants, 0)
        session.stop()
    }

    @MainActor func testCancellationDoesNotReleaseSharedAITransportDuringAppleCall() async throws {
        let suite = "AuditAttestation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let attest = AuditHangingAttestation()
        let client = FlashcardAPIClient(defaults: defaults, host: "audit.invalid", attestation: attest,
            transport: { _ in throw URLError(.cancelled) })
        let task = Task { try await client.generateScript(.init(persona: "willow", mood: "chill", app: "apps",
            gateCount: 0, exam: nil, examDays: nil, topic: nil, questions: 3, minutes: 6)) }
        while attest.continuation == nil { await Task.yield() }
        task.cancel()
        await Task.yield()
        let card = Regret(regretPrompt: "What is 1+1?", regret: "2", choices: ["2"], correctAnswerIndex: 0,
            backgroundExplanation: "One plus one is two.", answerMode: .typed)
        do {
            _ = try await client.askTutor(persona: "willow", card: .init(card), question: "Why?", history: [])
            XCTFail("Expected the cancelled operation to still hold the lock")
        } catch { XCTAssertEqual(error as? FlashcardServiceError, .alreadyGenerating) }
        attest.continuation?.resume(throwing: CancellationError())
        _ = try? await task.value
    }

    @MainActor func testClosingAndRecreatingChatLosesEarnedButUnclaimedProgress() {
        let suite = "AuditProgress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: BuddyIdentity.ruleKey); defaults.set(5, forKey: "flashcardCount")
        let store = DeckStore()
        store.selectedDeck = Deck(name: "Numbers", cards: (0..<5).map { i in
            Regret(regretPrompt: "What number follows \(i)?", regret: "\(i+1)", choices: ["\(i+1)", "wrong"],
                correctAnswerIndex: 0, backgroundExplanation: "Count forward.")
        })
        let manager = StudyGuardManager()
        func makeSession() -> MonsterSession {
            MonsterSession(deckStore: store, studyGuard: manager, sharedDefaults: nil,
                creatorDefaults: defaults, method: .inChat, loadBundle: { _, _, _ in nil })
        }
        let first = makeSession(); first.start(); first.answer(choiceIndex: 0); first.answer(choiceIndex: 0)
        XCTAssertEqual(first.studyEarnedSeconds, 120)
        first.stop()
        let replacement = makeSession(); replacement.start()
        XCTAssertEqual(replacement.studyEarnedSeconds, 0)
        XCTAssertEqual(replacement.totalQuestions, 5)
        XCTAssertTrue(store.reviewWrites.isEmpty)
        XCTAssertEqual(manager.grants, 0)
        replacement.stop()
    }
}
