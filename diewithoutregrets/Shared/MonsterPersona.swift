import Foundation

// MARK: - Monster personas (selectable tutor personalities)

/// A selectable tutor-monster personality — tone/voice only, never a real-world
/// demographic caricature. Referenced everywhere by `id`, so renaming is cheap.
struct MonsterPersona: Identifiable, Equatable {
    let id: String          // stable key; display names can change freely
    let name: String
    let tagline: String
    let accentHex: String   // per-persona accent color

    static let diva    = MonsterPersona(id: "diva",    name: "Zaza",   tagline: "sassy hype bestie", accentHex: "#FF2D95")
    static let willow  = MonsterPersona(id: "willow",  name: "Willow", tagline: "warm and calm",     accentHex: "#8FBF9F")
    static let coach   = MonsterPersona(id: "coach",   name: "Sarge",  tagline: "tough-love drill",  accentHex: "#2F6BFF")
    static let gremlin = MonsterPersona(id: "gremlin", name: "Gnash",  tagline: "chaotic menace",    accentHex: "#A6FF2D")

    /// Onboarding order (gentle first so it reads as the safe pick).
    static let all: [MonsterPersona] = [willow, diva, coach, gremlin]
    /// Safe default if onboarding is skipped.
    static let fallback = willow

    /// Bundled, approved character art. Persisted persona IDs stay unchanged.
    var artworkAsset: String {
        switch id {
        case "diva": return "monster-zaza-atlas"
        case "coach": return "monster-sarge-atlas"
        case "gremlin": return "monster-gnash-atlas"
        default: return "monster-willow-atlas"
        }
    }

    static func with(id: String?) -> MonsterPersona {
        all.first { $0.id == id } ?? fallback
    }

    /// Read on every shield render so an extension never retains an old choice.
    static func selected(in defaults: UserDefaults?) -> MonsterPersona {
        with(id: defaults?.string(forKey: SGContract.Keys.selectedPersonaID))
    }
}

/// Shared, testable copy for both app and category shields. Names are supplied by
/// Apple's shield configuration context, never guessed from a token.
struct MonsterShieldCopy {
    let persona: MonsterPersona
    let destination: String

    init(persona: MonsterPersona, applicationName: String?, fallback: String = "this app") {
        self.persona = persona
        let name = applicationName?.trimmingCharacters(in: .whitespacesAndNewlines)
        destination = name.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    var title: String { "\(persona.name) has locked \(destination)" }
    var subtitle: String { "Chat with \(persona.name) and answer a few flashcards to earn access to \(destination)." }
    var button: String { "Ask Permission" }
}

