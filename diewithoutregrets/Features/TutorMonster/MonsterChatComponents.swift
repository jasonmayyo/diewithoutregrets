//
//  MonsterChatComponents.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 1): chat UI building blocks. PLACEHOLDER styling — a
//  self-contained dark palette with per-persona accents, deliberately NOT the
//  SGTheme night/ember lock scene. The real look is authored later via
//  /design-shotgun. See Docs/TutorMonsterPlan.md §6h, §6i.
//

import SwiftUI

/// "Meadow Study Buddy" palette (/design-shotgun 2026-10-28, direction A): light +
/// green, consistent with the app's home; the persona accent is the pop. Deliberately
/// NOT the night/ember lock scene. Tracks SGTheme Meadow tokens.
enum MonsterPalette {
    static let bg = Color(red: 0.992, green: 0.992, blue: 0.984)          // #FDFDFB canvas
    static let surface = Color(red: 0.945, green: 0.953, blue: 0.949)     // #F1F3F2 monster bubbles
    static let surfaceHi = Color(red: 0.965, green: 0.973, blue: 0.969)   // #F6F8F7 tiles / input
    static let cardBg = Color.white                                        // the flashcard
    static let hairline = Color.black.opacity(0.07)
    static let text = Color(red: 0.102, green: 0.141, blue: 0.125)        // #1A2420
    static let textDim = Color(red: 0.420, green: 0.478, blue: 0.455)     // #6B7A74
    static let successBg = Color(red: 0.890, green: 0.969, blue: 0.937)   // #E3F7EF earned-time
    static let successText = Color(red: 0.118, green: 0.541, blue: 0.404) // #1E8A67 mint deep

    static func accent(_ persona: MonsterPersona) -> Color { color(persona.accentHex) }

    /// #RRGGBB or #RGB → Color.
    static func color(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: " #"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var n: UInt64 = 0
        Scanner(string: s).scanHexInt64(&n)
        return Color(red: Double((n >> 16) & 0xFF) / 255,
                     green: Double((n >> 8) & 0xFF) / 255,
                     blue: Double(n & 0xFF) / 255)
    }
}

struct MonsterAvatarHeader: View {
    let persona: MonsterPersona
    var mood: SGContract.MonsterMood = .chill
    private var accent: Color { MonsterPalette.accent(persona) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [accent, accent.opacity(0.5)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(persona.name.prefix(1)))
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(persona.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(MonsterPalette.text)
                Text(persona.tagline).font(.system(size: 12)).foregroundStyle(MonsterPalette.textDim)
            }
            Spacer()
        }
    }
}

struct MonsterTypingIndicator: View {
    let tint: Color
    @State private var on = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(tint).frame(width: 7, height: 7)
                    .opacity(on ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.55).repeatForever().delay(Double(i) * 0.18), value: on)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(MonsterPalette.surface, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { on = true }
    }
}

struct MonsterTextBubble: View {
    let text: String
    let sender: MonsterMessage.Sender
    let accent: Color
    var body: some View {
        if sender == .system {
            Text(text).font(.system(size: 12)).foregroundStyle(MonsterPalette.textDim)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack {
                if sender == .user { Spacer(minLength: 44) }
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(sender == .user ? .white : MonsterPalette.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(sender == .user ? accent : MonsterPalette.surface,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                if sender != .user { Spacer(minLength: 44) }
            }
        }
    }
}

/// A persona reaction sticker (Phase 3): a small bundled image, left-aligned like a
/// monster line. Offline — the asset ships in the catalog. Real per-persona art is a
/// /design-shotgun task; this reuses the existing sticker set.
struct MonsterMediaBubble: View {
    let asset: String
    let label: String
    var body: some View {
        HStack {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .padding(10)
                .background(MonsterPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel(label)
            Spacer(minLength: 44)
        }
    }
}

struct MonsterRevealBubble: View {
    let correct: Bool
    let answer: String
    let why: String?
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? Color.green : Color.red)
                    Text(correct ? "Nice." : "Answer: \(answer)")
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(MonsterPalette.text)
                }
                if let why, !why.isEmpty {
                    Text(why).font(.system(size: 13)).foregroundStyle(MonsterPalette.textDim)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(MonsterPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 44)
        }
    }
}

struct MonsterGrantBubble: View {
    let minutes: Int
    var body: some View {
        HStack {
            Label("+\(minutes) min unlocked", systemImage: "lock.open.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MonsterPalette.successText)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(MonsterPalette.successBg, in: Capsule())
            Spacer(minLength: 44)
        }
    }
}

struct MonsterCardBubble: View {
    let card: Regret
    let accent: Color
    let enabled: Bool
    let onChoice: (Int) -> Void
    let onTyped: (String) -> Void
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.quizPrompt.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MonsterPalette.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if card.answerMode == .typed {
                HStack(spacing: 8) {
                    TextField("type your answer", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(MonsterPalette.text)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(MonsterPalette.surfaceHi, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .disabled(!enabled)
                    Button {
                        let t = typed; typed = ""; onTyped(t)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 28)).foregroundStyle(accent)
                    }
                    .disabled(!enabled || typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                ForEach(Array(card.choices.enumerated()), id: \.offset) { idx, choice in
                    Button { onChoice(idx) } label: {
                        Text(choice)
                            .font(.system(size: 15))
                            .foregroundStyle(MonsterPalette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(MonsterPalette.surfaceHi, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(MonsterPalette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonsterPalette.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(enabled ? accent.opacity(0.55) : MonsterPalette.hairline, lineWidth: enabled ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}
