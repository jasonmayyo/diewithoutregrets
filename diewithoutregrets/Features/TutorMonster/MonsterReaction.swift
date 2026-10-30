import Foundation

/// A closed, local library: a reply can attach an approved reaction, never a
/// provider URL. Media is presentation only and has no part in grading or grants.
enum MonsterReaction: String, CaseIterable, Hashable {
    case wideEyes = "wide-eyes"
    case rainbowRide = "rainbow-ride"
    case awkwardSmile = "awkward-smile"
    case sideEye = "side-eye"
    case facepalm
    case delightedLaugh = "delighted-laugh"
    case doubleTake = "double-take"
    case snackBreak = "snack-break"

    var isAnimated: Bool {
        switch self {
        case .delightedLaugh, .doubleTake, .snackBreak: return true
        default: return false
        }
    }

    var aspectRatio: Double {
        switch self {
        case .wideEyes: return 644.0 / 663
        case .rainbowRide: return 502.0 / 505
        case .awkwardSmile: return 492.0 / 427
        case .sideEye: return 504.0 / 392
        case .facepalm: return 497.0 / 505
        case .delightedLaugh: return 498.0 / 514
        case .doubleTake: return 510.0 / 518
        case .snackBreak: return 460.0 / 468
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .wideEyes: return "A wide-eyed, surprised emoji"
        case .rainbowRide: return "A delighted character riding a unicorn beneath a rainbow"
        case .awkwardSmile: return "A mouse with an awkward smile"
        case .sideEye: return "An animated character peeking over a rock with a skeptical look"
        case .facepalm: return "A person covering their face in disbelief"
        case .delightedLaugh: return "A delighted laugh"
        case .doubleTake: return "A surprised double take"
        case .snackBreak: return "A child happily enjoying a snack"
        }
    }

    func resourceURL(extension ext: String, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: rawValue, withExtension: ext, subdirectory: "MonsterReactions")
    }
}

/// Occasional opening disbelief for Zaza or a strong-round celebration.
/// Persist the gap so reopening chat cannot trigger back-to-back reactions.
struct MonsterReactionPicker {
    private static let gapKey = "sg_monsterReaction.completedRoundGap.v1"
    private let seed: Int
    private let defaults: UserDefaults?
    private var consideredCompletion = false
    private var attachedOpening = false

    init(seed: Int = Int.random(in: 0..<10_000), defaults: UserDefaults? = nil) {
        self.seed = max(0, seed) % 10_000
        self.defaults = defaults
    }

    mutating func opening(persona: MonsterPersona) -> MonsterReaction? {
        guard persona.id == MonsterPersona.diva.id, !attachedOpening, !consideredCompletion,
              seed % 2 == 0, remainingGap == 0 else { return nil }
        attachedOpening = true
        defaults?.set(3 + seed % 2, forKey: Self.gapKey)
        return .doubleTake
    }

    private var remainingGap: Int {
        min(4, max(0, defaults?.object(forKey: Self.gapKey) as? Int ?? seed % 4))
    }

    mutating func completedRound(correctAnswers: Int, totalAnswers: Int) -> MonsterReaction? {
        guard !consideredCompletion, !attachedOpening else { return nil }
        consideredCompletion = true
        guard totalAnswers > 0, correctAnswers > 0, correctAnswers <= totalAnswers,
              Double(correctAnswers) / Double(totalAnswers) >= 0.75 else { return nil }

        // Start at a random point in the cadence, then leave at least three
        // successful rounds entirely free of media after every attachment.
        let remaining = remainingGap
        guard remaining == 0 else {
            defaults?.set(remaining - 1, forKey: Self.gapKey)
            return nil
        }
        defaults?.set(3 + seed % 2, forKey: Self.gapKey)
        let pool: [MonsterReaction] = [.rainbowRide, .delightedLaugh, .snackBreak]
        return pool[(seed / 4) % pool.count]
    }
}
