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
        let strings = [regretPrompt, regret, backgroundExplanation] + choices
        return [2, 4].contains(choices.count) && choices.indices.contains(correctAnswerIndex)
            && strings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 4000 }
            && !FlashcardPrompt.isPlaceholder(regretPrompt)
            && (!regretPrompt.contains("__") || FlashcardPrompt(regretPrompt).hasBlank)
    }
}

enum FlashcardServiceError: LocalizedError, Equatable {
    case unavailable, unsupportedDevice, verificationFailed, invalidResponse
    case dailyLimit, rateLimited, inputTooLarge, alreadyGenerating

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
        }
    }
}

/// The only AI transport used by the app. No provider key or shared bearer token
/// belongs here. App Attest's private signing key stays on the device.
@MainActor
final class FlashcardAPIClient {
    static let shared = FlashcardAPIClient()
    static let maximumInputBytes = 100_000
    /// The model rarely lands on exactly 50; accept a usable deck and cap it.
    static let minimumCards = 20
    static let maximumCards = 50
    private var isGenerating = false
    private let session: URLSession
    private let defaults: UserDefaults
    private let baseURL: URL?
    private let attestation = DCAppAttestService.shared

    init(session: URLSession = .shared, defaults: UserDefaults = .standard,
         host: String? = Bundle.main.object(forInfoDictionaryKey: "StudyGuardAPIHost") as? String) {
        self.session = session
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
        guard !isGenerating else { throw FlashcardServiceError.alreadyGenerating }
        guard baseURL != nil else { throw FlashcardServiceError.unavailable }
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // The server bounds topic at 80 chars; clamp so a long label can't 400 the request.
        let topicValue = String((topic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").prefix(80))
        let hasText = trimmedText.count >= 50
        guard hasText || !topicValue.isEmpty else { throw FlashcardServiceError.invalidResponse }
        if let text, text.utf8.count > Self.maximumInputBytes { throw FlashcardServiceError.inputTooLarge }
        guard attestation.isSupported else { throw FlashcardServiceError.unsupportedDevice }
        isGenerating = true
        defer { isGenerating = false }

        let (keyID, challenge) = try await verifiedGenerationChallenge()
        let payload = Payload(action: "generate_flashcards",
                              text: hasText ? text : nil, language: language,
                              topic: topicValue.isEmpty ? nil : topicValue,
                              difficulty: difficulty, count: count,
                              challenge: challenge, requestId: UUID().uuidString)
        // Sign these exact bytes; the server must not re-serialize before verifying.
        let body = try JSONEncoder().encode(payload)
        let assertion: Data
        do { assertion = try await attestation.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body))) }
        catch {
            clearInvalidKey(error)
            throw FlashcardServiceError.verificationFailed
        }
        let data = try await post("v1/flashcards", body: body, headers: [
            "X-App-Attest-Key-ID": keyID,
            "X-App-Attest-Assertion": assertion.base64EncodedString(),
        ])
        return try Self.decodeCards(data, topic: topicValue.isEmpty ? nil : topicValue, count: count)
    }

    /// Backfill multiple-choice distractors for typed cards. One call enriches a
    /// whole batch. The caller discards any option matching its answer and only
    /// promotes a card when three usable, distinct distractors survive. Offline-safe:
    /// any failure leaves the cards exactly as they were (typed).
    func generateDistractors(for cards: [(prompt: String, answer: String)], language: String) async throws -> [[String]] {
        guard !isGenerating else { throw FlashcardServiceError.alreadyGenerating }
        guard baseURL != nil else { throw FlashcardServiceError.unavailable }
        guard !cards.isEmpty, cards.count <= Self.maximumCards else { throw FlashcardServiceError.invalidResponse }
        guard attestation.isSupported else { throw FlashcardServiceError.unsupportedDevice }
        isGenerating = true
        defer { isGenerating = false }

        let (keyID, challenge) = try await verifiedGenerationChallenge()
        let payload = DistractorPayload(action: "generate_distractors",
            cards: cards.map { DistractorCard(prompt: $0.prompt, answer: $0.answer) },
            language: language, challenge: challenge, requestId: UUID().uuidString)
        let body = try JSONEncoder().encode(payload)
        let assertion: Data
        do { assertion = try await attestation.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body))) }
        catch {
            clearInvalidKey(error)
            throw FlashcardServiceError.verificationFailed
        }
        let data = try await post("v1/distractors", body: body, headers: [
            "X-App-Attest-Key-ID": keyID,
            "X-App-Attest-Assertion": assertion.base64EncodedString(),
        ])
        guard let decoded = try? JSONDecoder().decode(DistractorsResponse.self, from: data),
              decoded.sets.count == cards.count else { throw FlashcardServiceError.invalidResponse }
        return decoded.sets.map(\.distractors)
    }

    /// Fetch a personalized Tutor Monster session script. Reuses the same App
    /// Attest flow as generate(); throws on any failure so the caller falls back
    /// to the offline scripted banks. Cheap vs. flashcard generation (short output).
    func generateScript(_ context: MonsterScriptContext) async throws -> MonsterScriptBundle {
        guard baseURL != nil else { throw FlashcardServiceError.unavailable }
        guard attestation.isSupported else { throw FlashcardServiceError.unsupportedDevice }
        let (keyID, challenge) = try await verifiedGenerationChallenge()
        let payload = ScriptPayload(action: "generate_script", context: context,
                                    challenge: challenge, requestId: UUID().uuidString)
        let body = try JSONEncoder().encode(payload)
        let assertion: Data
        do { assertion = try await attestation.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body))) }
        catch {
            clearInvalidKey(error)
            throw FlashcardServiceError.verificationFailed
        }
        let data = try await post("v1/script", body: body, headers: [
            "X-App-Attest-Key-ID": keyID,
            "X-App-Attest-Assertion": assertion.base64EncodedString(),
        ])
        guard let bundle = try? JSONDecoder().decode(MonsterScriptBundle.self, from: data) else {
            throw FlashcardServiceError.invalidResponse
        }
        return bundle
    }

    /// `topic`, when set, overrides every card's label (topic mode generates one
    /// subject). `count` is the number requested; it relaxes the minimum-card floor
    /// for small top-ups (mirrors the Worker) while keeping the 20-card floor for
    /// full 50-card decks.
    static func decodeCards(_ data: Data, topic: String? = nil, count: Int? = nil) throws -> [GeneratedFlashcard] {
        let requested = count.map { min(max($0, 3), maximumCards) } ?? maximumCards
        let floor = max(3, min(minimumCards, Int(ceil(Double(requested) * 0.5))))
        guard let result = try? JSONDecoder().decode(CardsResponse.self, from: data),
              result.cards.count >= floor, result.cards.allSatisfy(\.isValid) else {
            throw FlashcardServiceError.invalidResponse
        }
        var cards = Array(result.cards.prefix(min(maximumCards, requested)))
        if let topic = topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty {
            for i in cards.indices { cards[i].topic = topic }
        }
        return cards
    }

    /// Enrolls/verifies this installation without making a paid generation call.
    /// Internal so physical-device tests can verify Apple enrollment independently.
    func verifiedGenerationChallenge() async throws -> (String, String) {
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
            clearInvalidKey(error)
            throw FlashcardServiceError.verificationFailed
        }
        let enrollment = Enrollment(keyId: keyID, challenge: challenge.challenge, attestation: object.base64EncodedString())
        _ = try await post("v1/attest", body: JSONEncoder().encode(enrollment))
        let next = try await fetchChallenge(keyID)
        guard next.purpose == "generate" else { throw FlashcardServiceError.verificationFailed }
        return (keyID, next.challenge)
    }

    private func clearInvalidKey(_ error: Error) {
        let nsError = error as NSError
        // App Attest keys do not survive a reinstall/restore. Only discard a
        // proven invalid device key; outages and 429s must not reset quotas.
        if nsError.domain == DCError.errorDomain && nsError.code == DCError.invalidKey.rawValue {
            defaults.removeObject(forKey: keyStorageName)
        }
    }

    private func fetchChallenge(_ keyID: String) async throws -> Challenge {
        let data = try await post("v1/challenge", body: JSONEncoder().encode(["keyId": keyID]))
        guard let result = try? JSONDecoder().decode(Challenge.self, from: data),
              !result.challenge.isEmpty, result.challenge.count <= 100 else { throw FlashcardServiceError.invalidResponse }
        return result
    }

    private func post(_ path: String, body: Data, headers: [String: String] = [:]) async throws -> Data {
        guard let baseURL else { throw FlashcardServiceError.unavailable }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = path == "v1/flashcards" ? 185 : path == "v1/distractors" ? 70 : 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = body
        // Intentionally no automatic retry of paid generation requests.
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FlashcardServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error.code
            if code == "key_not_registered" { defaults.removeObject(forKey: keyStorageName) }
            switch code {
            case "daily_limit": throw FlashcardServiceError.dailyLimit
            case "rate_limited": throw FlashcardServiceError.rateLimited
            case "generation_in_progress": throw FlashcardServiceError.alreadyGenerating
            case "input_too_large": throw FlashcardServiceError.inputTooLarge
            case "invalid_response", "invalid_request": throw FlashcardServiceError.invalidResponse
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
    private struct CardsResponse: Decodable { let cards: [GeneratedFlashcard] }
    private struct ErrorResponse: Decodable {
        struct Detail: Decodable { let code: String }
        let error: Detail
    }
}
