import Foundation

/// A known app launch link, never a guessed URL or a fallback to a different app.
struct ShieldReturnDestination: Codable, Equatable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    static func app(bundleIdentifier: String) -> Self? {
        let entry: (String, String)
        switch bundleIdentifier {
        case "com.burbn.instagram": entry = ("Instagram", "instagram://")
        case "com.google.ios.youtube": entry = ("YouTube", "youtube://")
        case "com.zhiliaoapp.musically": entry = ("TikTok", "tiktok://")
        case "com.toyopagroup.picaboo": entry = ("Snapchat", "snapchat://")
        case "com.facebook.Facebook": entry = ("Facebook", "fb://")
        case "com.atebits.Tweetie2": entry = ("X", "twitter://")
        case "com.reddit.Reddit": entry = ("Reddit", "reddit://")
        case "com.netflix.Netflix": entry = ("Netflix", "netflix://")
        case "com.burbn.barcelona": entry = ("Threads", "barcelona://")
        case "com.bereal.ft": entry = ("BeReal", "bereal://")
        default: return nil
        }
        guard let url = URL(string: entry.1) else { return nil }
        return Self(bundleIdentifier: bundleIdentifier, name: entry.0, url: url)
    }
}

/// The configuration extension knows the bundle ID; the action extension only
/// receives an opaque token. Match that exact token at tap time, then hand off
/// a one-use destination. Rendering a shield alone must never set a return app.
enum ShieldReturnContext {
    private static let candidatesKey = SGContract.Keys.shieldReturnCandidates
    private static let pendingKey = SGContract.Keys.pendingShieldReturn

    private struct Candidate: Codable {
        let bundleIdentifier: String
        let recordedAt: TimeInterval
    }

    private struct Pending: Codable {
        let bundleIdentifier: String
        let tappedAt: TimeInterval
    }

    static func remember(tokenData: Data?, bundleIdentifier: String?,
                         in defaults: UserDefaults?, now: Date = Date()) {
        guard let defaults, let tokenData else { return }
        var candidates = loadCandidates(defaults)
        let key = tokenData.base64EncodedString()
        if let bundleIdentifier, ShieldReturnDestination.app(bundleIdentifier: bundleIdentifier) != nil {
            candidates[key] = Candidate(bundleIdentifier: bundleIdentifier, recordedAt: now.timeIntervalSince1970)
        } else {
            candidates.removeValue(forKey: key)
        }
        // Bounded local cache; Screen Time can retain configurations for several apps.
        let newest = candidates.sorted { $0.value.recordedAt > $1.value.recordedAt }.prefix(50)
        if let data = try? JSONEncoder().encode(Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })) {
            defaults.set(data, forKey: candidatesKey)
            defaults.synchronize()
        }
    }

    static func prepareReturn(for tokenData: Data?, in defaults: UserDefaults?, now: Date = Date()) {
        guard let defaults else { return }
        defer { defaults.synchronize() }
        defaults.removeObject(forKey: pendingKey)
        guard let tokenData,
              let candidate = loadCandidates(defaults)[tokenData.base64EncodedString()],
              let data = try? JSONEncoder().encode(Pending(bundleIdentifier: candidate.bundleIdentifier,
                                                         tappedAt: now.timeIntervalSince1970)) else { return }
        defaults.set(data, forKey: pendingKey)
    }

    static func consumePending(in defaults: UserDefaults?, now: Date = Date()) -> ShieldReturnDestination? {
        guard let defaults else { return nil }
        defer {
            defaults.removeObject(forKey: pendingKey)
            defaults.synchronize()
        }
        guard let data = defaults.data(forKey: pendingKey),
              let pending = try? JSONDecoder().decode(Pending.self, from: data) else { return nil }
        let age = now.timeIntervalSince1970 - pending.tappedAt
        guard age >= 0, age < 120 else { return nil }
        return ShieldReturnDestination.app(bundleIdentifier: pending.bundleIdentifier)
    }

    static func clear(in defaults: UserDefaults) {
        defaults.removeObject(forKey: candidatesKey)
        defaults.removeObject(forKey: pendingKey)
    }

    private static func loadCandidates(_ defaults: UserDefaults) -> [String: Candidate] {
        guard let data = defaults.data(forKey: candidatesKey),
              let candidates = try? JSONDecoder().decode([String: Candidate].self, from: data) else { return [:] }
        return candidates
    }
}
