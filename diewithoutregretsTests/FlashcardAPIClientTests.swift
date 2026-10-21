import XCTest
@testable import diewithoutregrets

final class FlashcardAPIClientTests: XCTestCase {
    /// Explicit opt-in only: this makes one paid request through the live Worker.
    /// It validates generation without saving cards or changing the user's decks.
    @MainActor func testLiveProductionFlashcardGeneration() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Live generation requires physical-device App Attest")
        #else
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STUDY_GUARD_LIVE_GENERATION"] == "1",
                          "Opt in with STUDY_GUARD_LIVE_GENERATION=1 for one paid generation")
        let host = Bundle.main.object(forInfoDictionaryKey: "StudyGuardAPIHost") as? String
        try XCTSkipUnless(host == "studyguard-ai-staging.jason-749.workers.dev",
                          "Live generation requires the production service hostname")
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "studyguard.attestation.production.smoke"))
        let client = FlashcardAPIClient(defaults: defaults, host: host)
        let text = """
        Biology revision: Cells are the basic units of life. The cell membrane controls
        what enters and leaves a cell. Cytoplasm is where many chemical reactions occur.
        The nucleus contains genetic material. DNA carries genetic instructions.
        Genes are sections of DNA. Chromosomes contain DNA. Mitochondria release energy
        through aerobic respiration. Ribosomes make proteins. Plant cell walls contain
        cellulose. Chloroplasts contain chlorophyll. Chlorophyll absorbs light for
        photosynthesis. Photosynthesis uses carbon dioxide and water to make glucose
        and oxygen. Plants store glucose as starch. Root hair cells absorb water and
        mineral ions. Xylem transports water through plants. Phloem transports dissolved
        sugars. Stomata allow gases to move into and out of leaves. Guard cells control
        stomatal openings. Transpiration is water loss from leaves. Diffusion moves
        particles from higher to lower concentration. Osmosis is the movement of water
        across a partially permeable membrane. Active transport requires energy to move
        substances against a concentration gradient. Enzymes are biological catalysts.
        High temperatures can denature enzymes. Amylase breaks down starch. Proteases
        break down proteins. Lipases break down fats. Red blood cells carry oxygen using
        haemoglobin. White blood cells help defend against pathogens. Platelets help
        blood clot. The heart pumps blood. Arteries carry blood away from the heart.
        Veins carry blood toward the heart. Capillaries exchange substances with tissues.
        Alveoli are air sacs where gas exchange occurs in the lungs. The diaphragm helps
        ventilate the lungs. Kidneys filter blood and produce urine. Neurons transmit
        electrical impulses. Hormones are chemical messengers transported in the blood.
        """
        let cards = try await client.generate(text: text, language: "English")
        XCTAssertTrue((FlashcardAPIClient.minimumCards...FlashcardAPIClient.maximumCards).contains(cards.count))
        XCTAssertTrue(cards.allSatisfy(\.isValid))
        print("Live production generation returned \(cards.count) validated flashcards.")
        #endif
    }

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

    @MainActor func testRejectsPlaceholderPromptsAndMalformedBlanks() throws {
        for prompt in ["N/A", " n / a ", "Not applicable", "null", "undefined", "___", " ___. ", "___ requires ___"] {
            let card = GeneratedFlashcard(regretPrompt: prompt, regret: "effort",
                choices: ["effort", "perfection", "avoidance", "conflict"], correctAnswerIndex: 0,
                backgroundExplanation: "Relationships take practice.")
            XCTAssertFalse(card.isValid, prompt)
        }
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: response()) as? [String: Any])
        var cards = try XCTUnwrap(payload["cards"] as? [[String: Any]])
        cards[0]["regretPrompt"] = "N/A"
        payload["cards"] = cards
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(JSONSerialization.data(withJSONObject: payload)))
    }

    func testClozeReplacesOnlyTheBlankAndPreservesContext() {
        let prompt = FlashcardPrompt("Relationships require ongoing ___ and self-awareness.")
        XCTAssertEqual(prompt.parts(), [.text("Relationships require ongoing "), .blank, .text(" and self-awareness.")])
        XCTAssertEqual(prompt.parts(revealing: "effort"), [.text("Relationships require ongoing "), .answer("effort"), .text(" and self-awareness.")])
        XCTAssertEqual(prompt.parts(revealing: "perfection"), [.text("Relationships require ongoing "), .answer("perfection"), .text(" and self-awareness.")])
    }

    func testBlankAtEitherEndAndUnicodePreservePunctuation() {
        XCTAssertEqual(FlashcardPrompt("___ powers the cell.").parts(revealing: "ATP"), [.answer("ATP"), .text(" powers the cell.")])
        XCTAssertEqual(FlashcardPrompt("The answer is ___.").parts(revealing: "42"), [.text("The answer is "), .answer("42"), .text(".")])
        XCTAssertEqual(FlashcardPrompt("光的意思是____。").parts(revealing: "light"), [.text("光的意思是"), .answer("light"), .text("。")])
    }

    func testOrdinaryQuestionsAndImportedTermsNeverAppendAnswers() {
        for text in ["What does light mean?", "True or false: plants need light.", "Photosynthesis"] {
            let prompt = FlashcardPrompt(text)
            XCTAssertFalse(prompt.hasBlank)
            XCTAssertEqual(prompt.parts(), [.text(text)])
            XCTAssertEqual(prompt.parts(revealing: "A full-sentence answer."), [.text(text)])
        }
    }

    func testLegacyPlaceholderRecoversQuestionWithoutLeakingAnswer() {
        var card = Regret(regretPrompt: "N/A", regret: "What do healthy relationships require?",
            choices: ["You must always be perfect in relationships.",
                      "Relationships require ongoing effort and self-awareness.",
                      "Once you learn, you never need to practice again.",
                      "You should avoid all conflict."], correctAnswerIndex: 1,
            backgroundExplanation: "Relationships take practice.")
        XCTAssertEqual(card.quizPrompt.text, "What do healthy relationships require?")
        card.regret = card.correctAnswer
        XCTAssertEqual(card.quizPrompt.text, "Choose the correct answer.")
        XCTAssertEqual(card.quizPrompt.parts(revealing: card.choices[2]), [.text("Choose the correct answer.")])
        card.regret = "N/A"
        XCTAssertEqual(card.quizPrompt.text, "Choose the correct answer.")
        card.regretPrompt = "Relationships require ___."
        card.answerMode = .typed
        XCTAssertEqual(card.quizPrompt.parts(revealing: "ongoing effort"), [.text("Relationships require "), .answer("ongoing effort"), .text(".")])
    }
}
