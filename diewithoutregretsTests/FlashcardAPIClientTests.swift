import XCTest
import DeviceCheck
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
        let cards = (0..<count).map { index -> [String: Any] in
            ["regretPrompt": "Item \(index): the term \"光\" means ___.", "regret": "light\nenergy",
             "choices": ["light\nenergy", "dark", "water", "wind"], "correctAnswerIndex": answer,
             "backgroundExplanation": "It means light.", "topic": "Vocabulary"]
        }
        return try JSONSerialization.data(withJSONObject: ["cards": cards])
    }

    @MainActor func testStructuredCardsPreserveQuotesAndUnicode() throws {
        let cards = try FlashcardAPIClient.decodeCards(response())
        XCTAssertEqual(cards.count, 50)
        XCTAssertEqual(cards.first?.regretPrompt, "Item 0: the term \"光\" means ___.")
        XCTAssertTrue(cards.first?.regret.contains("\n") == true)
    }

    @MainActor func testRejectsIncompleteDeckAndOutOfBoundsAnswer() throws {
        XCTAssertEqual(try FlashcardAPIClient.decodeCards(response(count: 49)).count, 49)
        XCTAssertEqual(try FlashcardAPIClient.decodeCards(response(count: 53)).count, 50)
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(response(count: 7)))
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(response(answer: 4)))
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(Data("{\"cards\":[".utf8)))
    }

    @MainActor func testTopicModeTagsCardsAndRelaxesFloorForSmallCounts() throws {
        // Topic mode stamps every card with the one requested topic.
        let tagged = try FlashcardAPIClient.decodeCards(response(count: 8), topic: "Bones", count: 8)
        XCTAssertEqual(tagged.count, 8)
        XCTAssertTrue(tagged.allSatisfy { $0.topic == "Bones" })
        // A small requested count relaxes the 20-card floor for top-ups...
        XCTAssertEqual(try FlashcardAPIClient.decodeCards(response(count: 6), count: 10).count, 6)
        // ...but a response far below even the relaxed floor still fails closed.
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(response(count: 2), count: 10))
        // Full decks accept partial results, but require eight usable cards.
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(response(count: 7)))
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
        XCTAssertEqual(try FlashcardAPIClient.decodeCards(JSONSerialization.data(withJSONObject: payload)).count, 49)
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

@MainActor
private final class FakeAppAttestation: AppAttesting {
    var isSupported = true
    var generated = 0
    var assertions = 0
    var invalidAssertionOnce = false
    func generateKey() async throws -> String { generated += 1; return "key-\(generated)" }
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data { Data("attested".utf8) }
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        assertions += 1
        if invalidAssertionOnce {
            invalidAssertionOnce = false
            throw NSError(domain: DCError.errorDomain, code: DCError.invalidKey.rawValue)
        }
        return Data("signed".utf8)
    }
}

final class FlashcardTransportReliabilityTests: XCTestCase {
    @MainActor private func makeClient(attestation: FakeAppAttestation,
        transport: @escaping (URLRequest) async throws -> (Data, URLResponse)) -> (FlashcardAPIClient, UserDefaults, String) {
        let name = "reliability.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (FlashcardAPIClient(defaults: defaults, host: "studyguard.test", attestation: attestation, transport: transport), defaults, name)
    }
    private func response(_ request: URLRequest, _ object: [String: Any], status: Int = 200) throws -> (Data, URLResponse) {
        (try JSONSerialization.data(withJSONObject: object), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    private var cards: [[String: Any]] {
        (0..<8).map { ["regretPrompt": "Fact \($0): plants absorb ___ during photosynthesis.", "regret": "light",
            "choices": ["light", "soil", "wind", "sand"], "correctAnswerIndex": 0,
            "backgroundExplanation": "Light provides energy.", "topic": "Plants"] }
    }

    @MainActor func testMalformedObjectsDoNotDiscardValidCardsAndCoverageSurvives() throws {
        let data = try JSONSerialization.data(withJSONObject: ["cards": cards + [["regretPrompt": 42]],
            "coverage": ["sections": 3, "completed": 2]])
        let result = try FlashcardAPIClient.decodeGeneration(data)
        XCTAssertEqual(result.cards.count, 8)
        XCTAssertTrue(result.hasIncompleteCoverage)
        var invalid = cards
        invalid[0]["regret"] = "different answer"
        invalid[1]["choices"] = ["light", "LIGHT", "wind", "sand"]
        XCTAssertThrowsError(try FlashcardAPIClient.decodeCards(JSONSerialization.data(withJSONObject: ["cards": invalid])))
    }

    @MainActor func testInvalidDeviceKeyRecoversOnceBeforePaidWork() async throws {
        let attest = FakeAppAttestation(); attest.invalidAssertionOnce = true
        var paidCalls = 0
        let (client, defaults, name) = makeClient(attestation: attest) { request in
            if request.url!.path == "/v1/challenge" { return try self.response(request, ["challenge": UUID().uuidString, "purpose": "generate"]) }
            paidCalls += 1
            return try self.response(request, ["cards": self.cards])
        }
        defer { defaults.removePersistentDomain(forName: name) }
        let result = try await client.generate(text: String(repeating: "notes ", count: 20), language: "English")
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(attest.generated, 2)
        XCTAssertEqual(paidCalls, 1)
    }

    @MainActor func testExpiredChallengeRetriesOnceWithoutRotatingKey() async throws {
        let attest = FakeAppAttestation()
        var submissions = 0
        let (client, defaults, name) = makeClient(attestation: attest) { request in
            if request.url!.path == "/v1/challenge" { return try self.response(request, ["challenge": UUID().uuidString, "purpose": "generate"]) }
            submissions += 1
            if submissions == 1 { return try self.response(request, ["error": ["code": "invalid_challenge"]], status: 401) }
            return try self.response(request, ["cards": self.cards])
        }
        defer { defaults.removePersistentDomain(forName: name) }
        _ = try await client.generate(text: String(repeating: "notes ", count: 20), language: "English")
        XCTAssertEqual(submissions, 2)
        XCTAssertEqual(attest.generated, 1)
    }

    @MainActor func testExpiredEnrollmentCreatesOneFreshKeyBeforeGeneration() async throws {
        let attest = FakeAppAttestation()
        var registered = false
        var enrollments = 0
        var generations = 0
        let (client, defaults, name) = makeClient(attestation: attest) { request in
            if request.url!.path == "/v1/challenge" {
                return try self.response(request, ["challenge": UUID().uuidString, "purpose": registered ? "generate" : "attest"])
            }
            if request.url!.path == "/v1/attest" {
                enrollments += 1
                if enrollments == 1 { return try self.response(request, ["error": ["code": "invalid_challenge"]], status: 401) }
                registered = true
                return try self.response(request, ["registered": true])
            }
            generations += 1
            return try self.response(request, ["cards": self.cards])
        }
        defer { defaults.removePersistentDomain(forName: name) }
        _ = try await client.generate(text: String(repeating: "notes ", count: 20), language: "English")
        XCTAssertEqual(attest.generated, 2)
        XCTAssertEqual(enrollments, 2)
        XCTAssertEqual(generations, 1)
    }

    @MainActor func testRepeatedVerificationFailureStopsAfterOneRecovery() async {
        let attest = FakeAppAttestation()
        var submissions = 0
        let (client, defaults, name) = makeClient(attestation: attest) { request in
            if request.url!.path == "/v1/challenge" { return try self.response(request, ["challenge": UUID().uuidString, "purpose": "generate"]) }
            submissions += 1
            return try self.response(request, ["error": ["code": "key_not_registered"]], status: 401)
        }
        defer { defaults.removePersistentDomain(forName: name) }
        do { _ = try await client.generate(text: String(repeating: "notes ", count: 20), language: "English"); XCTFail() }
        catch { XCTAssertEqual(error as? FlashcardServiceError, .verificationFailed) }
        XCTAssertEqual(submissions, 2)
        XCTAssertEqual(attest.generated, 2)
    }

    @MainActor func testTimeoutAndQuotaNeverReplayPaidWorkOrRotateKeys() async {
        for code in ["timeout", "service_limit", "service_busy", "invalid_assertion"] {
            let attest = FakeAppAttestation()
            var submissions = 0
            let (client, defaults, name) = makeClient(attestation: attest) { request in
                if request.url!.path == "/v1/challenge" { return try self.response(request, ["challenge": UUID().uuidString, "purpose": "generate"]) }
                submissions += 1
                if code == "timeout" { throw URLError(.timedOut) }
                return try self.response(request, ["error": ["code": code]], status: code == "invalid_assertion" ? 401 : 429)
            }
            do { _ = try await client.generate(text: String(repeating: "notes ", count: 20), language: "English"); XCTFail() }
            catch {
                if code == "service_limit" { XCTAssertEqual(error as? FlashcardServiceError, .serviceAtCapacity) }
                if code == "service_busy" { XCTAssertEqual(error as? FlashcardServiceError, .serviceBusy) }
            }
            XCTAssertEqual(submissions, 1)
            XCTAssertEqual(attest.generated, 1)
            defaults.removePersistentDomain(forName: name)
        }
    }

    @MainActor func testConcurrentScriptCannotRaceGenerationAssertionsAndCancellationDoesNotSubmit() async throws {
        let attest = FakeAppAttestation()
        var challengeStarted = false
        var submissions = 0
        let (client, defaults, name) = makeClient(attestation: attest) { request in
            if request.url!.path == "/v1/challenge" {
                challengeStarted = true
                try await Task.sleep(nanoseconds: 100_000_000)
                return try self.response(request, ["challenge": UUID().uuidString, "purpose": "generate"])
            }
            submissions += 1
            return try self.response(request, ["cards": self.cards])
        }
        defer { defaults.removePersistentDomain(forName: name) }
        let task = Task { try await client.generate(text: String(repeating: "notes ", count: 20), language: "English") }
        while !challengeStarted { await Task.yield() }
        do {
            _ = try await client.generateScript(.init(persona: "willow", mood: "chill", app: "apps", gateCount: 0,
                exam: nil, examDays: nil, topic: nil, questions: 3, minutes: 6))
            XCTFail("A concurrent signed request must not race the first one")
        } catch { XCTAssertEqual(error as? FlashcardServiceError, .alreadyGenerating) }
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch { }
        XCTAssertEqual(submissions, 0)
        XCTAssertEqual(attest.assertions, 0)
    }
}
