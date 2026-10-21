// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4GhostView.swift
//  OneThing
//
//  Ghost mascot component for V4 onboarding.
//  Uses existing ghost assets with tint/glow modifiers for different moods.
//  Replace placeholders with real assets when available.
//

import SwiftUI
import Lottie

// MARK: - Ghost Mood

enum SGV5GhostMood {
    case neutral
    case concerned
    case sad
    case hopeful
    case happy
    case celebrating
    case clipboard
}

// MARK: - V4 Ghost View

struct SGV5V4GhostView: View {
    let mood: SGV5GhostMood
    var size: CGFloat = 100

    @State private var floating = false

    /// Animated Lottie file for each mood (replaces the old static PNGs).
    private var lottieName: String {
        switch mood {
        case .neutral:     return "1_idle"
        case .concerned:   return "2_Looking down"
        case .sad:         return "2_Looking down"
        case .hopeful:     return "1_idle"
        case .happy:       return "1_idle"
        case .celebrating: return "1_idle"
        case .clipboard:   return "3_clipboard"
        }
    }

    private var glowColor: Color {
        switch mood {
        case .neutral, .concerned: return SGTheme.paper.opacity(0.15)
        case .sad:                 return Color(red: 0.6, green: 0.7, blue: 1.0).opacity(0.2)
        case .hopeful:             return Color(red: 1.0, green: 0.9, blue: 0.7).opacity(0.2)
        case .happy:               return SGTheme.mint.opacity(0.25)
        case .celebrating:         return Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.3)
        case .clipboard:           return SGTheme.paper.opacity(0.1)
        }
    }

    var body: some View {
        LottieView(animation: .named(lottieName))
            .playing(loopMode: .loop)
            .frame(width: size, height: size)
            .shadow(color: glowColor, radius: 20, x: 0, y: 4)
            .shadow(color: glowColor, radius: 40, x: 0, y: 0)
            .offset(y: floating ? -6 : 6)
            .animation(
                .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: floating
            )
            .onAppear { floating = true }
    }
}

// MARK: - Preview


