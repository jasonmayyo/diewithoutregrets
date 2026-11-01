import Foundation
import CryptoKit
import DeviceCheck

struct GeneratedFlashcard: Decodable {
    let regretPrompt: String
    let regret: String
    let choices: [String]
    let correctAnswerIndex: Int
    let backgroundExplanation: String
    /// Short topic label (set by generation; drives weakness/exam targeting).
    var topic: String? = nil

    var isValid: Bool {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let normalize: (String) -> String = { trim($0).precomposedStringWithCompatibilityMapping.lowercased() }
        let strings = [regretPrompt, regret, backgroundExplanation] + choices
        let blanks = regretPrompt.ranges(of: #/_{2,}/#)
        let context = regretPrompt.replacingOccurrences(of: "___", with: "").trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return choices.count == 4 && choices.indices.contains(correctAnswerIndex)
            && strings.allSatisfy { !trim($0).isEmpty && $0.utf16.count <= 4000 }
            && blanks.count == 1 && String(regretPrompt[blanks[0]]) == "___"
            && context.rangeOfCharacter(from: .alphanumerics) != nil
            && !FlashcardPrompt.isPlaceholder(context)
            && choices.allSatisfy { trim($0).utf16.count <= 120 && !$0.contains("__") }
            && Set(choices.map(normalize)).count == 4
            && trim(regret) == trim(choices[correctAnswerIndex])
            && (topic == nil || (!trim(topic!).isEmpty && topic!.utf16.count <= 80))
    }
}

enum FlashcardServiceError: LocalizedError, Equatable {
    case unavailable, unsupportedDevice, verificationFailed, invalidResponse
    case dailyLimit, rateLimited, inputTooLarge, alreadyGenerating, serviceAtCapacity, serviceBusy, timedOut

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "AI flashcard generation is temporarily unavailable. Please try again later. Your existing cards are safe."
        case .unsupportedDevice:
            return "AI generation needs a supported iPhone or iPad. You can still create cards manually or import Quizlet cards."
        case .verificationFailed:
            return "We couldn't verify this copy of Study Guard. Please use the latest App Store version and try again."
        case .invalidResponse:
            return "We couldn't create a complete set of flashcards. Please try again with clearer or shorter study material."
        case .dailyLimit:
            return "You've reached today's AI generation limit. Please try again tomorrow. Your existing cards are still available."
        case .rateLimited:
            return "Please wait a minute before generating another set of flashcards."
        case .inputTooLarge:
            return "This text is too long to process at once. Please split it into smaller sections."
        case .alreadyGenerating:
            return "Your flashcards are already being generated. Please wait for them to finish."
        case .serviceBusy:
            return "The AI service is busy. Please try again shortly. Your existing cards are safe."
        case .timedOut:
            return "Generation took too long. Please try again with a shorter section of your notes."
        case .serviceAtCapacity:
            return "Study Guard has reached its shared AI capacity. Please try again later or add cards manually. Your existing cards are safe."
        }
    }
}

struct FlashcardGenerationResult {
    struct Coverage: Decodable { let sections: Int; let completed: Int }
    let cards: [GeneratedFlashcard]
    let coverage: Coverage?
    var hasIncompleteCoverage: Bool {
        guard let coverage else { return false }
        return coverage.completed < coverage.sections
    }
}

@MainActor
protocol AppAttesting {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

private struct SystemAppAttestation: AppAttesting {
    var isSupported: Bool { DCAppAttestService.shared.isSupported }
    func generateKey() async throws -> String { try await DCAppAttestService.shared.generateKey() }
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)
    }
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
    }
}

/// The only AI transport used by the app. No provider key or shared bearer token
/// belongs here. App Attest's private signing key stays on the device.
@MainActor
final class FlashcardAPIClient {
    static let shared = FlashcardAPIClient()
    static let maximumInputBytes = 100_000
    /// The model rarely lands on exactly 50; accept a usable deck and cap it.
    static let minimumCards = 8
    static let maximumCards = 50
    private var isGenerating = false
    private let transport: (URLRequest) async throws -> (Data, URLResponse)
    private let defaults: UserDefaults
    private let baseURL: URL?
    private let attestation: any AppAttesting
    private enum RecoverableVerification: Error { case invalidKey, expiredChallenge }

    init(session: URLSession = .shared, defaults: UserDefaults = .standard,
         host: String? = Bundle.main.object(forInfoDictionaryKey: "StudyGuardAPIHost") as? String,
         attestation: (any AppAttesting)? = nil,
         transport: ((URLRequest) async throws -> (Data, URLResponse))? = nil) {
        self.attestation = attestation ?? SystemAppAttestation()
        self.transport = transport ?? { try await session.data(for: $0) }
        self.defaults = defaults
        // Configuration contains a public HTTPS hostname, never credentials.
        if let host, !host.isEmpty, !host.contains("$("),
           let url = URL(string: "https://" + host), url.host == host,
           url.user == nil, url.password == nil, url.port == nil,
           url.query == nil, url.fragment == nil, url.path.isEmpty {
            self.baseURL = url
        } else { self.baseURL = nil }
    }

    private var keyStorageName: String { "studyguard.appAttest.key.production.v1.\(baseURL?.host ?? "unconfigured")" }

    /// Generate a deck of flashcards. Supply `text` (document mode) and/or a
    /// `topic` (topic mode, for weak/near-exam top-ups); at least one is required.
    /// `count` and `difficulty` are optional hints. The unlock gate never depends
    /// on this — callers fall back to existing cards on any error.
    func generate(text: String? = nil, language: String,
                  topic: String? = nil, difficulty: String? = nil, count: Int? = nil) async throws -> [GeneratedFlashcard] {
        try await generateDeck(text: text, language: language, topic: topic, difficulty: difficulty, count: count).cards
    }

    func generateDeck(text: String? = nil, language: String,
                      topic: String? = nil, difficulty: String? = nil, count: Int? = nil) async throws -> FlashcardGenerationResult {
        guard baseURL != nil else { throw FlashcardServiceError.unavailable }
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var topicValue = String((topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").prefix(80))
        while topicValue.utf16.count > 80 { topicValue.removeLast() }
        let hasText = trimmedText.count >= 50
        guard hasText || !topicValue.isEmpty else { throw FlashcardServiceError.invalidResponse }
        if let text, text.utf8.count > Self.maximumInputBytes { throw FlashcardServiceError.inputTooLarge }
        let data = try await authenticatedPost("v1/flashcards", timeout: 185) { challenge, requestID in
            try JSONEncoder().encode(Payload(action: "generate_flashcards", text: hasText ? trimmedText : nil,
                language: language, topic: topicValue.isEmpty ? nil : topicValue, difficulty: difficulty,
                count: count, challenge: challenge, requestId: requestID))
        }
        return try Self.decodeGeneration(data, topic: topicValue.isEmpty ? nil : topicValue, count: count)
    }

    func generateDistractors(for cards: [(prompt: String, answer: String)], language: String) async throws -> [[String]] {
        guard !cards.isEmpty, cards.count <= Self.maximumCards else { throw FlashcardServiceError.invalidResponse }
        let data = try await authenticatedPost("v1/distractors", timeout: 70) { challenge, requestID in
            try JSONEncoder().encode(DistractorPayload(action: "generate_distractors",
                cards: cards.map { DistractorCard(prompt: $0.prompt, answer: $0.answer) },
                language: language, challenge: challenge, requestId: requestID))
        }
        guard let decoded = try? JSONDecoder().decode(DistractorsResponse.self, from: data),
              decoded.sets.count == cards.count else { throw FlashcardServiceError.invalidResponse }
        return decoded.sets.map(\.distractors)
    }

    func generateScript(_ context: MonsterScriptContext) async throws -> MonsterScriptBundle {
        let data = try await authenticatedPost("v1/script", timeout: 15) { challenge, requestID in
            try JSONEncoder().encode(ScriptPayload(action: "generate_script", context: context,
                challenge: challenge, requestId: requestID))
        }
        guard let bundle = try? JSONDecoder().decode(MonsterScriptBundle.self, from: data), bundle.isValid else {
            throw FlashcardServiceError.invalidResponse
        }
        return bundle
    }

    func askTutor(persona: String, card: MonsterTutorCard, question: String,
                  history: [MonsterTutorTurn]) async throws -> String {
        let personalizedQuestion = BuddyIdentity.load().tutorQuestion(question)
        let data = try await authenticatedPost("v1/tutor", timeout: 18) { challenge, requestID in
            try JSONEncoder().encode(TutorPayload(action: "ask_tutor", persona: persona, card: card,
                question: personalizedQuestion, history: Array(history.suffix(4)), challenge: challenge, requestId: requestID))
        }
        guard let result = try? JSONDecoder().decode(TutorResponse.self, from: data),
              !result.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              result.reply.utf16.count <= 2000 else { throw FlashcardServiceError.invalidResponse }
        return result.reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Serialize signed requests across generation, scripts and follow-ups. Apple
    /// assertion counters must reach the server in order, and enrollment must not race.
    private func authenticatedPost(_ path: String, timeout: TimeInterval,
                                   body makeBody: (String, String) throws -> Data) async throws -> Data {
        guard baseURL != nil else { throw FlashcardServiceError.unavailable }
        guard attestation.isSupported else { throw FlashcardServiceError.unsupportedDevice }
        guard !isGenerating else { throw FlashcardServiceError.alreadyGenerating }
        isGenerating = true
        defer { isGenerating = false }
        let requestID = UUID().uuidString
        for attempt in 0...1 {
            do {
                try Task.checkCancellation()
                let (keyID, challenge) = try await prepareChallenge()
                let body = try makeBody(challenge, requestID)
                let assertion: Data
                do { assertion = try await attestation.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body))) }
                catch { throw verificationError(error) }
                try Task.checkCancellation()
                return try await post(path, body: body, headers: [
                    "X-App-Attest-Key-ID": keyID, "X-App-Attest-Assertion": assertion.base64EncodedString(),
                ], timeout: timeout)
            } catch let recovery as RecoverableVerification {
                // These failures prove the paid operation was not accepted. Never
                // retry an uncertain timeout, 5xx, invalid assertion, or quota error.
                if recovery == .invalidKey { defaults.removeObject(forKey: keyStorageName) }
                if attempt == 1 { throw FlashcardServiceError.verificationFailed }
            }
        }
        throw FlashcardServiceError.verificationFailed
    }

    static func decodeCards(_ data: Data, topic: String? = nil, count: Int? = nil) throws -> [GeneratedFlashcard] {
        try decodeGeneration(data, topic: topic, count: count).cards
    }

    static func decodeGeneration(_ data: Data, topic: String? = nil, count: Int? = nil) throws -> FlashcardGenerationResult {
        let requested = count.map { min(max($0, 3), maximumCards) } ?? maximumCards
        let floor = max(3, min(8, Int(ceil(Double(requested) * 0.15))))
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawCards = root["cards"] as? [Any], rawCards.count <= 200 else {
            throw FlashcardServiceError.invalidResponse
        }
        // Decode each object independently: a null, missing key or wrong type in
        // one card must not discard the other usable cards.
        var seen = Set<String>()
        var cards = rawCards.compactMap { raw -> GeneratedFlashcard? in
            guard let object = raw as? [String: Any],
                  let bytes = try? JSONSerialization.data(withJSONObject: object),
                  let card = try? JSONDecoder().decode(GeneratedFlashcard.self, from: bytes), card.isValid else { return nil }
            let key = card.regretPrompt.precomposedStringWithCompatibilityMapping.lowercased()
                .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard seen.insert(key).inserted else { return nil }
            return card
        }
        guard cards.count >= floor else { throw FlashcardServiceError.invalidResponse }
        cards = Array(cards.prefix(min(maximumCards, requested)))
        if let topic = topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty {
            for i in cards.indices { cards[i].topic = String(topic.prefix(80)) }
        }
        var coverage: FlashcardGenerationResult.Coverage?
        if let raw = root["coverage"] as? [String: Any],
           let bytes = try? JSONSerialization.data(withJSONObject: raw),
           let decoded = try? JSONDecoder().decode(FlashcardGenerationResult.Coverage.self, from: bytes),
           (1...8).contains(decoded.sections), (0...decoded.sections).contains(decoded.completed) {
            coverage = decoded
        }
        return FlashcardGenerationResult(cards: cards, coverage: coverage)
    }

    /// Enrolls/verifies this installation without making a paid generation call.
    /// Internal so physical-device tests can verify Apple enrollment independently.
    func verifiedGenerationChallenge() async throws -> (String, String) {
        guard !isGenerating else { throw FlashcardServiceError.alreadyGenerating }
        guard attestation.isSupported else { throw FlashcardServiceError.unsupportedDevice }
        isGenerating = true
        defer { isGenerating = false }
        do { return try await prepareChallenge() }
        catch is RecoverableVerification { throw FlashcardServiceError.verificationFailed }
    }

    private func prepareChallenge() async throws -> (String, String) {
        try Task.checkCancellation()
        let keyID: String
        if let existing = defaults.string(forKey: keyStorageName) { keyID = existing }
        else {
            do { keyID = try await attestation.generateKey() }
            catch { throw FlashcardServiceError.verificationFailed }
            // Save before enrollment. If the server response is lost, the next
            // challenge tells us whether this key has already been registered.
            defaults.set(keyID, forKey: keyStorageName)
        }
        let challenge = try await fetchChallenge(keyID)
        if challenge.purpose == "generate" { return (keyID, challenge.challenge) }
        guard challenge.purpose == "attest" else { throw FlashcardServiceError.invalidResponse }
        let object: Data
        do {
            object = try await attestation.attestKey(keyID,
                clientDataHash: Data(SHA256.hash(data: Data(challenge.challenge.utf8))))
        } catch {
            throw verificationError(error)
        }
        let enrollment = Enrollment(keyId: keyID, challenge: challenge.challenge, attestation: object.base64EncodedString())
        _ = try await post("v1/attest", body: JSONEncoder().encode(enrollment))
        let next = try await fetchChallenge(keyID)
        guard next.purpose == "generate" else { throw FlashcardServiceError.verificationFailed }
        return (keyID, next.challenge)
    }

    private func verificationError(_ error: Error) -> Error {
        if Task.isCancelled { return CancellationError() }
        let nsError = error as NSError
        if nsError.domain == DCError.errorDomain && nsError.code == DCError.invalidKey.rawValue {
            return RecoverableVerification.invalidKey
        }
        return FlashcardServiceError.verificationFailed
    }

    private func fetchChallenge(_ keyID: String) async throws -> Challenge {
        let data = try await post("v1/challenge", body: JSONEncoder().encode(["keyId": keyID]))
        guard let result = try? JSONDecoder().decode(Challenge.self, from: data),
              !result.challenge.isEmpty, result.challenge.count <= 100 else { throw FlashcardServiceError.invalidResponse }
        return result
    }

    private func post(_ path: String, body: Data, headers: [String: String] = [:], timeout: TimeInterval = 15) async throws -> Data {
        try Task.checkCancellation()
        guard let baseURL else { throw FlashcardServiceError.unavailable }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body
        // Intentionally no automatic retry of paid generation requests.
        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw FlashcardServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error.code
            switch code {
            case "daily_limit": throw FlashcardServiceError.dailyLimit
            case "rate_limited": throw FlashcardServiceError.rateLimited
            case "generation_in_progress": throw FlashcardServiceError.alreadyGenerating
            case "input_too_large": throw FlashcardServiceError.inputTooLarge
            case "invalid_response", "invalid_request": throw FlashcardServiceError.invalidResponse
            case "service_limit": throw FlashcardServiceError.serviceAtCapacity
            case "service_busy": throw FlashcardServiceError.serviceBusy
            case "generation_timeout": throw FlashcardServiceError.timedOut
            case "key_not_registered" where http.statusCode == 401: throw RecoverableVerification.invalidKey
            case "invalid_challenge" where http.statusCode == 401:
                // An attestation object is single-use at Apple. If its enrollment
                // challenge expired, start with a fresh key; no paid work ran.
                throw path == "v1/attest" ? RecoverableVerification.invalidKey : RecoverableVerification.expiredChallenge
            case "attestation_failed", "invalid_assertion", "invalid_challenge", "key_not_registered":
                throw FlashcardServiceError.verificationFailed
            default: throw FlashcardServiceError.unavailable
            }
        }
        return data
    }

    private struct Challenge: Decodable { let challenge: String; let purpose: String }
    private struct Enrollment: Encodable { let keyId: String; let challenge: String; let attestation: String }
    private struct Payload: Encodable {
        let action: String; let text: String?; let language: String
        let topic: String?; let difficulty: String?; let count: Int?
        let challenge: String; let requestId: String
    }
    private struct ScriptPayload: Encodable {
        let action: String; let context: MonsterScriptContext; let challenge: String; let requestId: String
    }
    private struct DistractorCard: Encodable { let prompt: String; let answer: String }
    private struct DistractorPayload: Encodable {
        let action: String; let cards: [DistractorCard]; let language: String; let challenge: String; let requestId: String
    }
    private struct DistractorsResponse: Decodable {
        struct Set: Decodable { let distractors: [String] }
        let sets: [Set]
    }
    private struct TutorPayload: Encodable {
        let action: String; let persona: String; let card: MonsterTutorCard
        let question: String; let history: [MonsterTutorTurn]; let challenge: String; let requestId: String
    }
    private struct TutorResponse: Decodable { let reply: String }
    private struct ErrorResponse: Decodable {
        struct Detail: Decodable { let code: String }
        let error: Detail
    }
}
