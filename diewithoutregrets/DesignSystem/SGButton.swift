//
//  SGButton.swift
//  diewithoutregrets
//
//  THE button. One signature for every primary action in the app: a
//  continuous capsule sitting on a hard darker "ledge" (a zero-radius
//  shadow), whose face physically presses down onto the ledge on touch.
//  Ported from Secure's LessonCTAButton mechanics, tuned for the Meadow
//  (6pt depth, mint/ember ramps).
//
//  Implementation note: the press is driven by ButtonStyle.isPressed on a
//  real Button (not a raw DragGesture), so touch-up-inside semantics,
//  scroll-cancellation, and VoiceOver all behave like a system button.
//
//  Variants: .mint (default primary), .ember (lock-scene CTAs),
//  .alarm (locked-home red-alert CTA), .white (onboarding sky arc),
//  .ghost (secondary, flat), .text (tertiary).
//

import SwiftUI

enum SGButtonVariant {
    case mint
    case ember
    case alarm
    case white
    case ghost
    case text

    var face: Color {
        switch self {
        case .mint: return SGTheme.mint
        case .ember: return SGTheme.ember
        case .alarm: return SGTheme.alarm
        case .white: return .white
        case .ghost, .text: return .clear
        }
    }

    /// The ledge color: the accent's opaque deep partner (a translucent
    /// ledge disappears against the night scenes).
    var ledge: Color {
        switch self {
        case .mint: return SGTheme.mintDeep
        case .ember: return SGTheme.emberDeep
        case .alarm: return SGTheme.alarmDeep
        case .white: return SGTheme.whiteDeep
        case .ghost, .text: return .clear
        }
    }

    var label: Color {
        switch self {
        case .mint, .ember, .alarm: return .white
        case .white: return SGTheme.paper
        case .ghost: return SGTheme.paper
        case .text: return SGTheme.paperSecondary
        }
    }

    /// Chunky variants get the ledge press; flat variants scale.
    var isChunky: Bool {
        switch self {
        case .mint, .ember, .alarm, .white: return true
        case .ghost, .text: return false
        }
    }
}

/// Swallows double-taps so a fast second tap can never skip a step.
/// Hold in @State so it survives view re-inits.
@MainActor
final class SGTapDebouncer {
    private var lastFire: Date = .distantPast
    private let window: TimeInterval

    init(window: TimeInterval = 0.6) {
        self.window = window
    }

    func allow() -> Bool {
        allow(window: window)
    }

    /// Per-call window override — lets one @State debouncer serve buttons
    /// whose pacing differs (the quiz runs a tighter 0.25s window).
    func allow(window: TimeInterval) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastFire) >= window else { return false }
        lastFire = now
        return true
    }
}

struct SGButton: View {
    let title: String
    var icon: String? = nil
    var variant: SGButtonVariant = .mint
    var fullWidth: Bool = true
    var enabled: Bool = true
    /// In-flight state for request-backed actions (restore, permission
    /// prompts): shows a spinner in the icon slot and blocks taps without
    /// the full disabled dim.
    var loading: Bool = false
    /// Debounce window for repeat taps. The 0.6s default suits one-shot
    /// CTAs; rapid-fire surfaces (the quiz) pass a tighter window.
    var debounceWindow: TimeInterval = 0.6
    /// Chunky variants fire SGTheme.beat() on press. Callers whose action
    /// composes its own haptic (the quiz's Check → correctBurst/wrongBuzz)
    /// pass false so one press can never buzz twice.
    var tapHaptic: Bool = true
    let action: () -> Void

    @State private var debouncer = SGTapDebouncer()

    /// Loading blocks interaction like disabled does.
    private var interactive: Bool { enabled && !loading }

    var body: some View {
        switch variant {
        case .mint, .ember, .alarm, .white:
            Button(action: { fire(haptic: true) }) {
                label
            }
            .buttonStyle(SGChunkyStyle(variant: variant, enabled: enabled))
            .disabled(!interactive)

        case .ghost:
            Button(action: { fire(haptic: false) }) {
                label
                    .background(
                        Capsule(style: .continuous)
                            .fill(SGTheme.glaze(0.06))
                            .overlay(Capsule(style: .continuous)
                                .strokeBorder(SGTheme.hairline, lineWidth: 1))
                    )
            }
            .buttonStyle(SGPressStyle()) // provides the press tick
            .opacity(enabled ? 1 : 0.4)
            .disabled(!interactive)

        case .text:
            Button(action: { fire(haptic: false) }) {
                HStack(spacing: 8) {
                    if loading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(variant.label)
                    }
                    Text(title)
                        .font(SGTheme.buttonSmall)
                }
                .foregroundColor(variant.label)
                .padding(.vertical, 12)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .contentShape(Rectangle())
            }
            .buttonStyle(SGPressStyle())
            .opacity(enabled ? 1 : 0.4)
            .disabled(!interactive)
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            if loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(variant.label)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            Text(title)
                .font(SGTheme.button)
        }
        .foregroundColor(variant.label)
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .frame(maxWidth: fullWidth ? .infinity : nil)
    }

    private func fire(haptic: Bool) {
        guard interactive, debouncer.allow() else { return }
        if haptic { SGTheme.beat() }
        action()
    }
}

/// The signature press: the face travels down onto its hard ledge.
private struct SGChunkyStyle: ButtonStyle {
    let variant: SGButtonVariant
    let enabled: Bool

    /// Ledge depth: how far the face travels on press.
    static let depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        configuration.label
            .background(variant.face, in: Capsule(style: .continuous))
            // Flatten first so the hard ledge is cast by the capsule
            // silhouette, not the text glyphs.
            .compositingGroup()
            .offset(y: pressed ? Self.depth : 0)
            .shadow(color: enabled ? variant.ledge : .clear,
                    radius: 0, x: 0,
                    y: pressed ? 2 : Self.depth)
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .animation(.easeInOut(duration: 0.15), value: enabled)
    }
}

#if DEBUG
#Preview("SGButton variants") {
    VStack(spacing: 20) {
        SGButton(title: "Study to unlock", icon: "rectangle.stack.fill") {}
        SGButton(title: "Unlock my apps", variant: .ember) {}
        SGButton(title: "I'm ready", variant: .white) {}
            .padding(12)
            .background(SGTheme.night)
        SGButton(title: "Not now", variant: .ghost) {}
        SGButton(title: "Skip for now", variant: .text) {}
        SGButton(title: "Disabled", enabled: false) {}
    }
    .padding(SGTheme.screenPadding)
    .background(SGTheme.ink)
}
#endif
