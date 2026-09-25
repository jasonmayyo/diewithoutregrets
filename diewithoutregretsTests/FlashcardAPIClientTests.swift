import XCTest
@testable import diewithoutregrets

final class FlashcardAPIClientTests: XCTestCase {
    @MainActor func testLiveProductionAppAttestEnrollment() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Apple App Attest enrollment requires a physical device")
        #else
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STUDY_GUARD_LIVE_ATTESTATION"] == "1",
                          "Opt in with the STUDY_GUARD_LIVE_ATTESTATION=1 build setting")
        let host = Bundle.main.object(forInfoDictionaryKey: "StudyGuardAPIHost") as? String
        try XCTSkipUnless(host == "studyguard-ai-staging.jason-749.workers.dev",
                          "Live enrollment requires the configured service hostname")
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "studyguard.attestation.production.smoke"))
        let client = FlashcardAPIClient(defaults: defaults, host: host)
        let first = try await client.verifiedGenerationChallenge()
        let second = try await client.verifiedGenerationChallenge()
        XCTAssertEqual(first.0, second.0, "An enrolled key must be reused")
        XCTAssertNotEqual(first.1, second.1, "Each operation needs a fresh challenge")
        #endif
    }

    private func response(count: Int = 50, answer: Int = 0) throws -> Data {
        let card: [String: Any] = [
            "regretPrompt": "What does \"光\" mean?", "regret": "A quoted example\nwith a newline",
            "choices": ["light", "dark"], "correctAnswerIndex": answer,
            "backgroundExplanation": "It means light.",
        ]
        return try JSONSerialization.data(withJSONObject: ["cards": Array(repeating: card, count: count)])
    }

    @MainActor func testStructuredCardsPreserveQuotesAndUnicode() throws {
        let cards = try FlashcardAPIClient.decodeCards(response())
        XCTAssertEqual(cards.count, 50)
        XCTAssertEqual(cards.first?.regretPrompt, "What does \"光\" mean?")
        XCTAssertTrue(cards.first?.regret.contains("\n") == true)
    }

    @MainActor func testRejectsIncompleteDeckAndOutOfBoundsAnswer() throws {
        XCTAssertEqual(try FlashcardAPIClient.decodeCards(response(count: 49)).count, 49)
        XCTAssertEqual(try FlashcardAPIClient.decodeCards(response(count: 53)).count, 50)
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(response(count: 19)))
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(response(answer: 2)))
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(Data("{\"cards\":[".utf8)))
    }

    @MainActor func testMissingEndpointFailsBeforeAnyNetworkRequest() async {
        let client = FlashcardAPIClient(host: nil)
        do {
            _ = try await client.generate(text: String(repeating: "study ", count: 20), language: "English")
            XCTFail("Generation must fail closed when unconfigured")
        } catch {
            XCTAssertEqual(error as? FlashcardServiceError, .unavailable)
        }
    }
}
