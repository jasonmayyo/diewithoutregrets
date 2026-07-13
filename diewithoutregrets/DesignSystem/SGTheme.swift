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

    /// Primary text — green-tinted near-black ink.
    static let paper = Color(hex: 0x14211D)
    static let paperSecondary = paper.opacity(0.55)
    static let paperTertiary = paper.opacity(0.45)
    static let paperDisabled = paper.opacity(0.3)

    /// THE action/progress accent (mascot belly, existing brand).
    static let mint = Color(hex: 0x2BC391)
    /// Deep green for text/icons on light surfaces where mint fails contrast.
    static let mintDeep = Color(hex: 0x1E8A67)
    /// Lock/alert accent (mascot horns). Deliberately not alarm-red.
    static let ember = Color(hex: 0xFF7A59)
    /// Deep ember for text on light surfaces.
    static let emberDeep = Color(hex: 0xD9532F)
    /// Ring gradient partner and illustration accent.
    static let teal = Color(hex: 0x3FA4AE)

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

    /// Big rounded numerals (countdown). Always monospacedDigit at call site.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Screen/onboarding headlines.
    static let headline = Font.system(size: 28, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15)
    static let caption = Font.system(size: 13)
    /// Micro-labels: use with SGMicroLabel (uppercase + tracking).
    static let micro = Font.system(size: 12, weight: .semibold)

    // MARK: - Shape & spacing

    static let cardRadius: CGFloat = 20
    static let tileRadius: CGFloat = 14
    static let sheetRadius: CGFloat = 28
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 24
    /// Bottom scroll inset that clears the floating tab bar.
    static let tabBarClearance: CGFloat = 96

    // MARK: - Motion

    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.85)

    // MARK: - Haptics

    static func tapHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func tickDownHaptic() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9)
    }

    static func tickUpHaptic() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    static func successHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func errorHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
