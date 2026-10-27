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

/// Placeholder palette for the monster chat. Swap for the design-shotgun output.
enum MonsterPalette {
    static let bg = Color(red: 0.05, green: 0.06, blue: 0.07)
    static let surface = Color(red: 0.12, green: 0.13, blue: 0.15)
    static let surfaceHi = Color(red: 0.17, green: 0.18, blue: 0.20)
    static let text = Color(white: 0.96)
    static let textDim = Color(white: 0.62)

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
    let accent: Color
    var body: some View {
        HStack {
            Label("+\(minutes) min unlocked", systemImage: "lock.open.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(accent, in: Capsule())
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
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonsterPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(enabled ? 0.5 : 0), lineWidth: 1.5)
        )
    }
}
