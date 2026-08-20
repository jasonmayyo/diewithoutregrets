//
//  QuizV2Kit.swift
//  diewithoutregrets
//
//  Shared design language for the blocking-flow redesign: the palette
//  (Meadow tokens aliased from SGTheme), the 3D chunky button, the stat
//  card, and the redesigned quiz-failure ending. The legacy quiz
//  components in QuizKit.swift stay untouched (RegretView still uses
//  them).
//

import SwiftUI

// MARK: - Palette (Meadow tokens, via SGTheme)

enum QV2 {
    static let canvas = SGTheme.ink
    static let text = SGTheme.paper
    static let textSecondary = SGTheme.paperSecondary
    static let chrome = SGTheme.paperDisabled          // close button, disabled CTA text
    static let track = SGTheme.inkHigh                 // progress track, disabled CTA fill
    static let tileBorder = SGTheme.inkHigh
    static let rule = SGTheme.whiteDeep                // dashed word underlines
    static let blankRule = SGTheme.paperTertiary       // solid blank line

    static let green = SGTheme.mint                    // CTA face, filled answer word
    static let greenDeep = SGTheme.mintDeep            // CTA ledge, panel text
    static let greenPanel = SGTheme.mintTint           // feedback panel + correct tile fill
    static let greenTileBorder = SGTheme.mintSoft

    static let blue = SGTheme.teal                     // selected tile text
    static let blueTint = Color(hex: 0xE7F4F5)         // selected tile fill (teal tint)
    static let blueBorder = Color(hex: 0x9FD2D8)       // selected tile border (teal soft)

    static let orange = SGTheme.amber                  // correct-reveal progress fill

    static let red = SGTheme.ember                     // wrong CTA face
    static let redDeep = SGTheme.emberDeep             // wrong panel text, CTA ledge
    static let redPanel = SGTheme.emberTint            // wrong feedback panel + tile fill
    static let redTileBorder = SGTheme.emberSoft
    static let redWash = SGTheme.emberTint             // failure sunburst base
    static let redWashRay = Color(hex: 0xFFE1D4)       // failure sunburst rays

    static let cream = Color(hex: 0xFAE8CD)           // streak sunburst base
    static let creamRay = Color(hex: 0xF6DDBB)        // streak sunburst rays
    static let creamDeep = Color(hex: 0xF2D8AF)       // streak circles, close button
    static let cardOrange = SGTheme.amber             // streak encouragement card
    static let cardOrangeGlow = SGTheme.ember         // glow behind the card flame

    static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 3D press style (face slides down onto its ledge)

struct QV2ChunkyStyle: ButtonStyle {
    let fill: Color
    let edge: Color
    var depth: CGFloat = 4
    var radius: CGFloat = 14
    var bordered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        configuration.label
            .background(shape.fill(fill))
            .overlay {
                if bordered {
                    shape.strokeBorder(edge, lineWidth: 2)
                }
            }
            .offset(y: configuration.isPressed ? depth : 0)
            .background(shape.fill(edge).offset(y: depth))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - CTA button

struct QV2CTAButton: View {
    enum Variant { case green, red, white }

    let title: String
    var variant: Variant = .green
    var enabled: Bool = true
    let action: () -> Void

    private var face: Color {
        switch variant {
        case .green: return QV2.green
        case .red: return QV2.red
        case .white: return .white
        }
    }

    private var ledge: Color {
        switch variant {
        case .green: return QV2.greenDeep
        case .red: return QV2.redDeep
        case .white: return QV2.track
        }
    }

    private var label: Color {
        variant == .white ? QV2.text : .white
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(QV2.font(16, .bold))
                .tracking(1.7)
                .foregroundColor(enabled ? label : QV2.chrome)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(QV2ChunkyStyle(
            fill: enabled ? face : QV2.track,
            edge: enabled ? ledge : QV2.track,
            depth: enabled ? 4 : 0,
            bordered: variant == .white
        ))
        .disabled(!enabled)
    }
}

// MARK: - Stat card (bordered, colored header band, big value)

struct QV2StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(QV2.font(12, .bold))
                .tracking(1.2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(color)

            HStack(spacing: 7) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(value)
                    .font(QV2.font(22, .bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color, lineWidth: 2.5)
        )
    }
}

// MARK: - Sunburst backdrop (rays from behind the mascot)

/// The celebration-poster backdrop: alternating wedge rays radiating from a
/// point behind the mascot, a soft glow at the center, slow rotation.
/// Tint it per mood (red for failure, green for celebration).
struct QV2SunburstBackground: View {
    let base: Color
    let ray: Color
    var glow: Color = Color.white.opacity(0.4)
    /// Where the rays converge, as a fraction of the screen.
    var center: UnitPoint = UnitPoint(x: 0.5, y: 0.32)
    var rayCount: Int = 12

    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width * center.x,
                            y: geo.size.height * center.y)
            let span = max(geo.size.width, geo.size.height) * 3.2

            ZStack {
                base

                QV2RaysShape(rayCount: rayCount)
                    .fill(ray)
                    .frame(width: span, height: span)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .position(c)

                RadialGradient(
                    colors: [glow, .clear],
                    center: center,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.7
                )
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 45).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

private struct QV2RaysShape: Shape {
    let rayCount: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height)
        let step = Double.pi * 2 / Double(rayCount)
        // Ray and gap take equal halves of each step.
        let half = step / 4
        for i in 0..<rayCount {
            let a = Double(i) * step
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + Foundation.cos(a - half) * r,
                                  y: c.y + Foundation.sin(a - half) * r))
            p.addLine(to: CGPoint(x: c.x + Foundation.cos(a + half) * r,
                                  y: c.y + Foundation.sin(a + half) * r))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - Failure ending

/// The run is sealed: not every card was right. Same three ways forward as
/// the legacy QuizFailureView, restyled as a lesson-results screen.
struct QuizV2FailureView: View {
    let correctCount: Int
    let totalCount: Int
    let emergencyUnlocksRemaining: Int
    let onRetry: () -> Void
    let onEmergency: () -> Void
    let onGiveUp: () -> Void

    var body: some View {
        ZStack {
            QV2SunburstBackground(base: QV2.redWash, ray: QV2.redWashRay)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                MascotView(pose: .lookingDown, loops: 2)
                    .frame(width: 150, height: 150)

                Text("Not quite.")
                    .font(QV2.font(30, .bold))
                    .foregroundColor(QV2.text)
                    .padding(.top, 20)

                Text("You got \(correctCount) of \(totalCount). Your apps stay locked until every card is right.")
                    .font(QV2.font(17, .medium))
                    .foregroundColor(QV2.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 12)

                HStack(spacing: 12) {
                    QV2StatCard(
                        label: "SCORE",
                        value: "\(correctCount) / \(totalCount)",
                        icon: "sticker-target",
                        color: QV2.red
                    )
                    QV2StatCard(
                        label: "YOUR APPS",
                        value: "Locked",
                        icon: "sticker-lock",
                        color: QV2.orange
                    )
                }
                .padding(.top, 28)
                .padding(.horizontal, 12)

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    QV2CTAButton(title: "RETRY QUESTIONS", action: onRetry)

                    if emergencyUnlocksRemaining > 0 {
                        QV2CTAButton(
                            title: "EMERGENCY UNLOCK (\(emergencyUnlocksRemaining) LEFT)",
                            variant: .white,
                            action: onEmergency
                        )
                    }

                    Button(action: onGiveUp) {
                        Text("GIVE UP FOR NOW")
                            .font(QV2.font(15, .bold))
                            .tracking(1.4)
                            .foregroundColor(QV2.redDeep)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SGPressStyle())
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Previews

#Preview("Quiz v2 failure") {
    QuizV2FailureView(
        correctCount: 1,
        totalCount: 3,
        emergencyUnlocksRemaining: 3,
        onRetry: {},
        onEmergency: {},
        onGiveUp: {}
    )
}
