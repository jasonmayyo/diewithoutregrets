//
//  SGTheme.swift
//  diewithoutregrets
//
//  "Meadow" design tokens — the single source of truth for the v3 visual
//  identity: white daylight canvas, green as the only loud color. Every
//  color, type role, radius, and spacing constant lives here; views never
//  hardcode hex values.
//
//  Token names survive from the dark "Teal Ink" era so call sites didn't
//  have to churn — read them semantically: `ink` = canvas, `inkRaised` =
//  card surface, `paper` = primary text.
//

import SwiftUI

enum SGTheme {

    // MARK: - Colors

    /// The canvas — warm white, never pure #FFF.
    static let ink = Color(hex: 0xFDFDFB)
    /// Cards and raised surfaces.
    static let inkRaised = Color(hex: 0xF4F6F5)
    /// Elevated / selected surfaces.
    static let inkHigh = Color(hex: 0xEAEFEC)
    /// Hairline strokes for card edges.
    static let hairline = Color.black.opacity(0.07)
    /// Opaque deep partner for white button faces (the ledge under a white
    /// SGButton; translucent black vanishes against the night scenes).
    static let whiteDeep = Color(hex: 0xC9CFCB)

    /// Primary text — green-tinted near-black ink.
    static let paper = Color(hex: 0x14211D)
    static let paperSecondary = paper.opacity(0.55)
    static let paperTertiary = paper.opacity(0.45)
    static let paperDisabled = paper.opacity(0.3)

    /// THE action/progress accent (mascot belly, existing brand).
    static let mint = Color(hex: 0x2BC391)
    /// Deep green: button ledges, text/icons on light surfaces.
    static let mintDeep = Color(hex: 0x1E8A67)
    /// Soft mint: gradient tops, highlights.
    static let mintSoft = Color(hex: 0x8CE0C4)
    /// Pale mint wash: selected fills, chips (replaces ad-hoc mint.opacity).
    static let mintTint = Color(hex: 0xE9F8F1)
    /// Lock/alert accent (mascot horns). Deliberately not alarm-red.
    static let ember = Color(hex: 0xFF7A59)
    /// Deep ember: button ledges, text on light surfaces.
    static let emberDeep = Color(hex: 0xD9532F)
    /// Soft ember: highlights on the night scene.
    static let emberSoft = Color(hex: 0xFFB59E)
    /// Pale ember wash: wrong-answer fills.
    static let emberTint = Color(hex: 0xFFF0EA)
    /// True alarm red — the LOCK SCENE family only (lock wipe, stamp,
    /// locked home ripple). The one sanctioned exception to "ember, not
    /// alarm-red": the lock-out is a red-alert world; ember stays the
    /// in-flow lock accent everywhere else.
    static let alarm = Color(hex: 0xFF3B30)
    /// Deep alarm: button ledges and light-surface text on the lock scene.
    static let alarmDeep = Color(hex: 0xC2271E)
    /// Ring gradient partner and illustration accent.
    static let teal = Color(hex: 0x3FA4AE)
    /// Warning accent (camera-session warnings, cautions).
    static let amber = Color(hex: 0xFF9933)
    /// Illustration sun (onboarding art only).
    static let sun = Color(hex: 0xFFC83D)
    /// The cold-start splash artwork's exact background teal.
    static let splashTeal = Color(hex: 0x3DB8B5)

    // MARK: - Night scene (the locked state)

    /// Ember-tinted near-black: the ONE dark canvas. Locked home, lock stamp,
    /// shield, Live Activity all live here.
    static let night = Color(hex: 0x1B0E0A)
    /// Cards on night.
    static let nightRaised = Color.white.opacity(0.06)
    /// Strokes on night.
    static let nightHairline = Color.white.opacity(0.10)
    /// Text on night.
    static let nightText = Color.white
    static let nightTextSecondary = Color.white.opacity(0.65)
    static let nightTextTertiary = Color.white.opacity(0.45)

    // MARK: - Sky scene (onboarding villain arc ONLY, never the main app)

    static let skyTop = Color(hex: 0x0B1C33)
    static let skyMid = Color(hex: 0x123A66)
    static let skyDeep = Color(hex: 0x0B2444)
    /// Bottom readability vignette under the sky gradient.
    static let skyVignette = Color(hex: 0x081527)

    /// Subtle dark glaze — replaces the old white-on-dark glaze fills.
    /// Pass the opacity the old `Color.white.opacity(x)` used; it's remapped
    /// so the visual weight on white matches what x gave on ink.
    static func glaze(_ opacity: Double) -> Color {
        Color.black.opacity(min(0.35, opacity * 0.7))
    }

    /// Soft ambient card shadow — light theme uses shadow + hairline together.
    static let cardShadow = Color.black.opacity(0.06)

    /// The Guard Ring progress gradient.
    static let ringGradient = LinearGradient(
        colors: [mint, teal],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    /// The Meadow ground — the green hill the mascot stands on.
    static let meadowGradient = LinearGradient(
        colors: [Color(hex: 0x35CE9B), Color(hex: 0x9BE8CC)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Deeper meadow used over the clouds backdrop, where the light green
    /// crest doesn't separate enough from the blue sky.
    static let meadowGradientDeep = LinearGradient(
        colors: [Color(hex: 0x21B37F), Color(hex: 0x86E0BE)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Type
    //
    // One family decision: SF Rounded for display + ALL numerals, default SF
    // for body/labels/controls. Weights: bold display, semibold controls.

    /// Rounded display base. Prefer the named roles below at call sites.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Rounded numerals. Always monospacedDigit at call site.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// The giant hero minutes (home, focus countdown, celebration).
    static let heroDigit = numeral(96)
    /// The "h"/"m" unit beside the hero digits.
    static let heroUnit = Font.system(size: 42, weight: .medium, design: .rounded)

    /// Tab headers (SGScreenHeader) and the Hook title.
    static let screenTitle = display(34)
    /// Every onboarding/overlay/lock title.
    static let stepTitle = display(30)
    /// Sheet headers.
    static let sheetTitle = display(24)
    /// Legacy alias kept for existing call sites; new code uses stepTitle.
    static let headline = Font.system(size: 28, weight: .bold, design: .rounded)

    static let cardTitle = Font.system(size: 17, weight: .semibold)
    /// Quiz answer-tile label (was an inline font in QuizAnswerTile).
    static let tileLabel = Font.system(size: 16, weight: .medium)
    /// Settings-row / pill-label role (between micro and cardTitle).
    static let rowLabel = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 15)
    static let caption = Font.system(size: 13)
    /// Micro-labels: use with SGMicroLabel (uppercase + tracking).
    static let micro = Font.system(size: 12, weight: .semibold)
    /// The one label for full-size buttons.
    static let button = Font.system(size: 17, weight: .semibold)
    /// Compact/secondary button label.
    static let buttonSmall = Font.system(size: 15, weight: .semibold)

    // MARK: - Shape & spacing

    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 14
    static let sheetRadius: CGFloat = 28
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 24
    /// Bottom scroll inset that clears the floating tab bar.
    static let tabBarClearance: CGFloat = 96

    // MARK: - Elevation
    //
    // The only four shadow recipes in the app. Apply with .sgShadow(_:).

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    /// Standard card lift.
    static let shadowCard = Shadow(color: cardShadow, radius: 12, y: 4)
    /// Floating chrome (tab bar, meadow pills).
    static let shadowFloat = Shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    /// Accent glow for hero moments only.
    static func glow(_ tint: Color) -> Shadow {
        Shadow(color: tint.opacity(0.3), radius: 18, y: 5)
    }

    // MARK: - Motion

    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.85)
    /// Celebration pops only.
    static let springPop = Animation.spring(response: 0.35, dampingFraction: 0.6)

    // Quiz motion constants (durations in seconds) — the unlock quiz's
    // timing vocabulary, shared by QuizKit and RegretView.
    /// Correct-tile mint mask sweep.
    static let quizSweep: Double = 0.30
    /// Progress-segment fill sweep.
    static let quizSegmentFill: Double = 0.25
    /// Dwell on a correct reveal before the next card auto-advances.
    static let quizAdvanceDwell: Double = 0.8
    /// One full inhale-exhale of any breathing idle animation.
    static let breatheCycle: Double = 1.6

    // MARK: - Haptic grammar
    //
    // tick = small tap · gain = something good accrues · lock = something
    // locks/drains · beat = committing/advancing (CTA fire) · climax = the
    // big story moment · success/error = finishing/failing an exercise.
    // No raw generator calls outside this file.

    static func tick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func gain() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    static func lock() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
    }

    static func beat() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func climax() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
    }

    static func successHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func errorHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// The lock stamp landing: heavy slam, then the error tone.
    static func lockSlam() {
        climax()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { errorHaptic() }
    }

    /// Correct answer: soft tap, rigid snap, then the success chime.
    static func correctBurst() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { successHaptic() }
    }

    /// Wrong answer: error buzz with a heavy afterthud.
    static func wrongBuzz() {
        errorHaptic()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.6)
        }
    }

    /// Celebration count-up tick.
    static func celebrationTick() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
    }

    /// Celebration landing: success chime, then a rigid stamp.
    static func celebrationLanding() {
        successHaptic()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        }
    }

    // Legacy names, kept so existing call sites build; new code uses the
    // grammar above.
    static func tapHaptic() { tick() }
    static func tickDownHaptic() { lock() }
    static func tickUpHaptic() { gain() }
}
