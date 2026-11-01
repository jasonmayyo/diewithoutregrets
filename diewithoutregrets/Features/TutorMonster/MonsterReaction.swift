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
    case stunnedDriver = "stunned-driver"
    case awkwardWave = "awkward-wave"
    case raisedFingerCat = "raised-finger-cat"
    case unimpressedDog = "unimpressed-dog"
    case spaceDogShrug = "space-dog-shrug"
    case thinkingMonkey = "thinking-monkey"
    case grinningDog = "grinning-dog"
    case sideEyeSip = "side-eye-sip"
    case sleepyDog = "sleepy-dog"
    case holdingItIn = "holding-it-in"

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
        case .stunnedDriver: return 1206.0 / 1047
        case .awkwardWave: return 688.0 / 467
        case .raisedFingerCat: return 725.0 / 646
        case .unimpressedDog: return 840.0 / 748
        case .spaceDogShrug: return 752.0 / 721
        case .thinkingMonkey: return 677.0 / 674
        case .grinningDog: return 680.0 / 458
        case .sideEyeSip: return 750.0 / 676
        case .sleepyDog: return 673.0 / 505
        case .holdingItIn: return 1003.0 / 989
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
        case .stunnedDriver: return "A driver staring ahead in disbelief"
        case .awkwardWave: return "A person giving an awkward wave"
        case .raisedFingerCat: return "A cat wearing glasses with a raised finger"
        case .unimpressedDog: return "A dog giving an unimpressed look"
        case .spaceDogShrug: return "A dog in a cartoon space suit shrugging"
        case .thinkingMonkey: return "A monkey looking thoughtful with a finger by its mouth"
        case .grinningDog: return "A dog with a wide, excited grin"
        case .sideEyeSip: return "A wide-eyed person sipping a drink through a straw"
        case .sleepyDog: return "A dog lying down with its eyes closed and tongue out"
        case .holdingItIn: return "A costumed character puffing out their cheeks"
        }
    }

    func resourceURL(extension ext: String, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: rawValue, withExtension: ext, subdirectory: "MonsterReactions")
    }
}

/// Opening and completion reactions have their own cadence. Four consecutive
/// misses always get a GIF, independently of other media in this chat.
struct MonsterReactionPicker {
    static let alwaysOpeningPreferenceKey = "sg_creatorAlwaysOpeningReaction"
    private static let gapKey = "sg_monsterReaction.completedRoundGap.v1"
    private let seed: Int
    private let defaults: UserDefaults?
    private var consideredOpening = false
    private var consideredCompletion = false
    private var attachedOpening = false
    private var consecutiveWrongAnswers = 0

    init(seed: Int = Int.random(in: 0..<10_000), defaults: UserDefaults? = nil) {
        self.seed = max(0, seed) % 10_000
        self.defaults = defaults
    }

    mutating func opening(persona: MonsterPersona, guaranteed: Bool = false) -> MonsterReaction? {
        guard !consideredOpening, !consideredCompletion else { return nil }
        consideredOpening = true
        // The session seed is uniform over 0..<10_000. The completion cooldown
        // must not suppress or change the requested opening probability.
        guard guaranteed || seed % 10 < 6 else { return nil }
        let pool: [MonsterReaction]
        switch persona.id {
        case MonsterPersona.willow.id:
            pool = [.delightedLaugh, .doubleTake, .awkwardSmile, .awkwardWave,
                    .raisedFingerCat, .spaceDogShrug, .thinkingMonkey, .grinningDog, .sleepyDog]
        case MonsterPersona.coach.id:
            pool = [.doubleTake, .sideEye, .wideEyes, .stunnedDriver,
                    .raisedFingerCat, .unimpressedDog, .thinkingMonkey, .holdingItIn]
        case MonsterPersona.gremlin.id:
            pool = [.doubleTake, .delightedLaugh, .facepalm, .wideEyes, .stunnedDriver,
                    .raisedFingerCat, .spaceDogShrug, .grinningDog, .sideEyeSip, .sleepyDog, .holdingItIn]
        default:
            pool = [.doubleTake, .delightedLaugh, .sideEye, .wideEyes, .stunnedDriver,
                    .awkwardWave, .unimpressedDog, .spaceDogShrug, .sideEyeSip, .holdingItIn]
        }
        let key = "sg_monsterReaction.lastOpening.v1.\(persona.id)"
        let last = defaults?.string(forKey: key)
        let available = pool.filter { $0.rawValue != last }
        let reaction = available[(seed / 10) % available.count]
        defaults?.set(reaction.rawValue, forKey: key)
        attachedOpening = true
        return reaction
    }

    /// Count only accepted, locally graded answers. Correct answers reset the
    /// streak; continued misses trigger again at eight, twelve, and so on.
    mutating func answer(correct: Bool) -> MonsterReaction? {
        guard !correct else {
            consecutiveWrongAnswers = 0
            return nil
        }
        consecutiveWrongAnswers += 1
        guard consecutiveWrongAnswers % 4 == 0 else { return nil }
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

        // Keep at least three eligible strong rounds between completion
        // celebrations. Opening reactions are independent of this counter.
        let remaining = remainingGap
        guard remaining == 0 else {
            defaults?.set(remaining - 1, forKey: Self.gapKey)
            return nil
        }
        defaults?.set(3 + seed % 2, forKey: Self.gapKey)
        let pool: [MonsterReaction] = [.rainbowRide, .delightedLaugh, .snackBreak, .grinningDog]
        return pool[(seed / 4) % pool.count]
    }
}
