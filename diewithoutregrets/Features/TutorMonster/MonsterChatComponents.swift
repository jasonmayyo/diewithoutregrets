//
//  MonsterChatComponents.swift
//  Text-first Meadow chat, with character identity kept in the contact portrait.
//

import SwiftUI

enum MonsterPalette {
    static let bg = Color(red: 0.992, green: 0.992, blue: 0.984)
    static let surface = Color(red: 0.945, green: 0.953, blue: 0.949)
    static let surfaceHi = Color(red: 0.965, green: 0.973, blue: 0.969)
    static let hairline = Color.black.opacity(0.07)
    static let text = Color(red: 0.102, green: 0.141, blue: 0.125)
    static let textDim = Color(red: 0.420, green: 0.478, blue: 0.455)
    static let successBg = Color(red: 0.890, green: 0.969, blue: 0.937)
    static let successText = Color(red: 0.118, green: 0.541, blue: 0.404)

    static func accent(_ persona: MonsterPersona) -> Color { color(persona.accentHex) }

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

/// Clips the original image at display time, preserving the source artwork and alpha.
private struct MonsterAtlasCrop: View {
    let asset: String
    let region: CGRect
    let size: CGFloat

    var body: some View {
        let scale = size / max(region.width, region.height)
        Image(asset)
            .resizable()
            .interpolation(.high)
            .frame(width: 1536 * scale, height: 1024 * scale)
            .offset(x: -region.minX * scale, y: -region.minY * scale)
            .frame(width: region.width * scale, height: region.height * scale, alignment: .topLeading)
            .clipped()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Full-body art is reserved for choosing a character, rather than chat messages.
struct MonsterArtwork: View {
    let asset: String
    var expression: MonsterExpression = .welcome
    var size: CGFloat = 112

    private var region: CGRect {
        let column = expression.rawValue % 3
        let row = expression.rawValue / 3
        // Preserve the welcoming hand without leaking it into the adjacent pose.
        if asset == "monster-zaza-atlas", row == 0 {
            if column == 0 { return CGRect(x: 0, y: 0, width: 528, height: 512) }
            if column == 1 { return CGRect(x: 528, y: 0, width: 496, height: 512) }
        }
        return CGRect(x: column * 512, y: row * 512, width: 512, height: 512)
    }

    var body: some View {
        MonsterAtlasCrop(asset: asset, region: region, size: size)
    }
}

/// A stable head-and-shoulders portrait, like a contact photo in a messaging app.
struct MonsterProfilePicture: View {
    let persona: MonsterPersona
    var size: CGFloat = 42

    private var portraitRegion: CGRect {
        switch persona.id {
        case "diva": return CGRect(x: 136, y: 24, width: 320, height: 320)
        case "coach": return CGRect(x: 104, y: 12, width: 320, height: 320)
        case "gremlin": return CGRect(x: 88, y: 16, width: 368, height: 368)
        default: return CGRect(x: 132, y: 30, width: 320, height: 320)
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(MonsterPalette.accent(persona).opacity(0.14))
            MonsterAtlasCrop(asset: persona.artworkAsset, region: portraitRegion, size: size - 4)
                .offset(y: 2)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(MonsterPalette.hairline, lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

struct MonsterAvatarHeader: View {
    let persona: MonsterPersona
    var deckName: String? = nil
    var onChooseDeck: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            MonsterProfilePicture(persona: persona)
            if let onChooseDeck {
                Button(action: onChooseDeck) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(persona.name).font(.headline).foregroundStyle(MonsterPalette.text)
                        HStack(spacing: 4) {
                            Text(deckName ?? "Choose flashcards").lineLimit(1).truncationMode(.tail)
                            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                        }
                        .font(.caption)
                        .foregroundStyle(MonsterPalette.textDim)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change flashcards")
                .accessibilityValue(deckName ?? "No deck selected")
            } else {
                Text(persona.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(MonsterPalette.text)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Always-visible allowance beside the contact name. Uses the same hourglass
/// artwork as the quiz's earn animation, with the quieter chat styling.
struct MonsterAllowanceChip: View {
    let seconds: Int
    let bump: Int
    var isEarning = false
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            Image("sticker-hourglass")
                .resizable().scaledToFit().frame(width: 20, height: 20)
            Text(QV2EarnedChip.label(seconds: max(0, seconds)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
        }
        .foregroundStyle(MonsterPalette.text)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(pulsing ? MonsterPalette.successBg : MonsterPalette.surface, in: Capsule())
        .scaleEffect(pulsing ? 1.1 : 1, anchor: .trailing)
        .fixedSize(horizontal: true, vertical: true)
        .task(id: bump) {
            guard bump > 0, !reduceMotion else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) { pulsing = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { pulsing = false }
        }
        .onChange(of: reduceMotion) { _, reduced in if reduced { pulsing = false } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isEarning ? "Screen time earned this round" : "Screen time allowance")
        .accessibilityValue(QV2EarnedChip.spokenLabel(seconds: max(0, seconds)))
        .accessibilityHint(isEarning ? "Finish this round to unlock your earned time." : "")
    }
}

struct MonsterTypingIndicator: View {
    var name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(MonsterPalette.textDim)
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.7 : (on ? 0.9 : 0.3))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.6)
                        .repeatForever().delay(Double(i) * 0.16), value: on)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
        .background(MonsterPalette.surface, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) is typing")
        .onAppear { on = true }
    }
}

/// Compact attribution attached to the first question or study invitation.
struct MonsterSourcesIndicator: View {
    let sources: [MonsterStudySource]

    private var label: String {
        sources.count == 1 ? sources[0].title : "\(sources.count) study sources"
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(MonsterPalette.textDim)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.leading, 2)
            .accessibilityLabel("Study sources: \(sources.map(\.title).joined(separator: ", "))")
    }
}

struct MonsterTextBubble: View {
    let text: String
    let sender: MonsterMessage.Sender
    var endsGroup = true

    private var isUser: Bool { sender == .user }

    var body: some View {
        if sender == .system {
            Text(text)
                .font(.caption)
                .foregroundStyle(MonsterPalette.textDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
        } else {
            HStack(spacing: 0) {
                if isUser { Spacer(minLength: 44) }
                Text(text)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : MonsterPalette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.horizontal, 15).padding(.vertical, 11)
                    .background(isUser ? MonsterPalette.text : MonsterPalette.surface,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: !isUser && endsGroup ? 6 : 20,
                            bottomTrailingRadius: isUser && endsGroup ? 6 : 20,
                            topTrailingRadius: 20))
                if !isUser { Spacer(minLength: 36) }
            }
        }
    }
}

struct MonsterQuestionBubble: View {
    let text: String
    let number: Int
    let total: Int
    let isRetry: Bool
    let persona: MonsterPersona
    let canAsk: Bool
    let onAsk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle")
                    .accessibilityHidden(true)
                Text("QUESTION \(number) OF \(total)")
                if isRetry { Text("· TRY AGAIN") }
            }
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(MonsterPalette.textDim)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(MonsterPalette.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Button(action: onAsk) {
                Label("Ask about this question", systemImage: "bubble.left")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MonsterPalette.textDim)
                    .frame(minHeight: 36, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canAsk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonsterPalette.accent(persona).opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(MonsterPalette.accent(persona).opacity(0.25), lineWidth: 1))
    }
}

/// Verdicts are explicit and local; the persona's chat is a separate message.
struct MonsterRevealBubble: View {
    let correct: Bool
    let answer: String
    let why: String?
    var endsGroup = true

    private var explanation: String {
        let opening = "The answer is \(answer)."
        guard let why, !why.isEmpty else { return opening }
        return opening + "\n\n" + why
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(correct ? "Correct" : "Not quite", systemImage: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(correct ? MonsterPalette.successText : MonsterPalette.textDim)
            if !correct {
                MonsterTextBubble(text: explanation, sender: .monster, endsGroup: endsGroup)
            }
        }
        .padding(.top, 2)
    }
}

struct MonsterGrantBubble: View {
    let minutes: Int

    var body: some View {
        Label("\(minutes) min unlocked", systemImage: "lock.open")
            .font(.caption.weight(.medium))
            .foregroundStyle(MonsterPalette.successText)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(MonsterPalette.successBg, in: Capsule())
            .frame(maxWidth: .infinity)
    }
}

/// Answer choices behave like suggested replies. The sent answer appears in the transcript.
struct MonsterQuickReplies: View {
    let choices: [String]
    var enabled = true
    let onChoice: (Int) -> Void
    var selectedIndex: Int? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columnCount: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 2 }

    var body: some View {
        Group {
            // Standard four-choice cards size to their actual text. There is
            // no fixed-height inner scroller to clip the second row.
            if dynamicTypeSize.isAccessibilitySize || choices.count > 4 {
                ScrollView { grid }
                    .frame(maxHeight: 180)
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                grid.fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!enabled)
        .animation(reduceMotion ? nil : MonsterChatMotion.feedback, value: selectedIndex)
        .animation(reduceMotion ? nil : MonsterChatMotion.feedback, value: enabled)
    }

    private var grid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(0..<((choices.count + columnCount - 1) / columnCount), id: \.self) { row in
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        let index = row * columnCount + column
                        if choices.indices.contains(index) {
                            let selected = selectedIndex == index
                            Button { onChoice(index) } label: {
                                Text(choices[index])
                                    .font(.subheadline)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundStyle(MonsterPalette.text)
                                    .padding(.horizontal, 15).padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, minHeight: 48, maxHeight: .infinity, alignment: .leading)
                                    .background(selected ? MonsterPalette.surface : .white,
                                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(MonsterPalette.text.opacity(selected ? 0.18 : 0.055), lineWidth: 0.5))
                                    .shadow(color: .black.opacity(0.035), radius: 8, y: 3)
                                    .opacity(enabled || selected ? 1 : 0.62)
                            }
                            .buttonStyle(MonsterReplyPressStyle())
                            .accessibilityLabel("Reply: \(choices[index])")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .modifier(MonsterMessageArrival(delay: Double(index) * 0.035))
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }
}

enum MonsterChatMotion {
    static let conversation = Animation.smooth(duration: 0.38, extraBounce: 0)
    static let panel = Animation.smooth(duration: 0.38, extraBounce: 0)
    static let message = Animation.smooth(duration: 0.36, extraBounce: 0)
    static let feedback = Animation.easeInOut(duration: 0.18)

    static func arrival(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12))
    }
}

/// Scrolling owns transcript movement; each new row only fades and settles.
/// Animating the entire stack as well causes a second competing layout motion.
struct MonsterMessageArrival: ViewModifier {
    var isUser = false
    var delay: Double = 0
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(arrived || reduceMotion ? 1 : 0)
            .scaleEffect(arrived || reduceMotion ? 1 : 0.97,
                         anchor: isUser ? .bottomTrailing : .bottomLeading)
            .offset(y: arrived || reduceMotion ? 0 : 14)
            .task {
                guard !arrived else { return }
                // Commit the initial frame before animating. An onAppear
                // mutation can be coalesced with insertion and skip the fade.
                if !reduceMotion {
                    do { try await Task.sleep(for: .seconds(0.02 + delay)) }
                    catch { return }
                }
                withAnimation(reduceMotion ? nil : MonsterChatMotion.message) { arrived = true }
            }
    }
}

@MainActor
enum MonsterChatHaptics {
    private static let incoming = UIImpactFeedbackGenerator(style: .soft)

    static func messageReceived() {
        incoming.impactOccurred(intensity: 0.55)
        incoming.prepare()
    }
}

private struct MonsterReplyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MonsterReplyComposer: View {
    @Binding var draft: String
    let enabled: Bool
    let placeholder: String
    let onSend: () -> Void
    /// Drafting can stay available while the next question is arriving.
    var canSubmit = true
    var onFocusChanged: (Bool) -> Void = { _ in }
    var maximumLength: Int? = nil
    var accessibilityName = "Your answer"
    var showsChoices = false
    var onToggleChoices: (() -> Void)? = nil
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSend: Bool {
        enabled && canSubmit && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let onToggleChoices {
                Button(action: onToggleChoices) {
                    Image(systemName: showsChoices ? "keyboard" : "rectangle.grid.1x2")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(MonsterPalette.text)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 48)
                        .background {
                            Circle().fill(.white)
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.07), radius: 12, y: 4)
                        }
                }
                .buttonStyle(MonsterReplyPressStyle())
                .accessibilityLabel(showsChoices ? "Type an answer" : "Show answer choices")
                .disabled(!enabled)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.85)))
            }
            inputSurface
        }
        .animation(reduceMotion ? nil : MonsterChatMotion.panel, value: onToggleChoices != nil)
        .onChange(of: enabled) { _, value in
            if !value { focused = false }
        }
        .onChange(of: canSubmit) { _, value in
            if !value { focused = false }
        }
        .onChange(of: showsChoices) { _, shown in
            if onToggleChoices != nil { focused = !shown }
        }
        .onChange(of: onToggleChoices != nil) { _, available in
            if available && showsChoices { focused = false }
        }
        .onChange(of: focused) { _, value in onFocusChanged(value) }
    }

    private var inputSurface: some View {
        HStack(alignment: .bottom, spacing: 4) {
            TextField(placeholder, text: $draft, axis: .vertical)
                .font(.body)
                .foregroundStyle(MonsterPalette.text)
                .tint(MonsterPalette.text)
                .lineLimit(1...5)
                .submitLabel(.send)
                .focused($focused)
                .disabled(!enabled)
                .padding(.leading, 16).padding(.vertical, 13)
                .accessibilityLabel(accessibilityName)
                .onChange(of: draft) { _, value in
                    if let maximumLength, value.utf16.count > maximumLength {
                        var bounded = value
                        while bounded.utf16.count > maximumLength { bounded.removeLast() }
                        draft = bounded
                    }
                }
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(canSend ? .white : MonsterPalette.textDim.opacity(0.65))
                    .frame(width: 32, height: 32)
                    .background(canSend ? .black : MonsterPalette.surface, in: Circle())
                    .scaleEffect(canSend || reduceMotion ? 1 : 0.92)
                    .frame(width: 44, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MonsterReplyPressStyle())
            .disabled(!canSend)
            .accessibilityLabel(maximumLength == nil ? "Send answer" : "Send question")
            .padding(.trailing, 2)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous)
            .strokeBorder(MonsterPalette.text.opacity(0.035), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 5)
        .animation(reduceMotion ? nil : MonsterChatMotion.feedback, value: canSend)
    }

    private func send() {
        guard canSend else { return }
        focused = false
        onSend()
    }
}
