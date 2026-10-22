// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  QuizComponents.swift
//  OneThing
//
//  Reusable components for quiz/question screens in onboarding
//

import SwiftUI
import Lottie

// MARK: - Floating Ghost Mascot

struct SGV5FloatingGhostView: View {
    /// Shared size used by the persistent question-screen ghost so the mascot and
    /// the space reserved for it (`SGV5QuizGhostPlaceholder`) always stay in sync.
    static let questionSize: CGFloat = 100

    var imageName: String = "ghost-clipboard"
    var size: CGFloat = 100
    /// Vertical float distance in each direction. Smaller is a gentler bob.
    var floatAmplitude: CGFloat = 6
    /// Seconds for one half of the bob. Longer is slower and calmer.
    var floatDuration: Double = 2.4

    @State private var floating = false

    /// Map the old static asset name to its animated Lottie equivalent. The quiz
    /// screens use the default, so questions show the clipboard ghost.
    private var lottieName: String {
        switch imageName {
        case "tired-ghost":    return "2_Looking down"
        case "ghost-clipboard": return "3_clipboard"
        default:                return "3_clipboard"
        }
    }

    var body: some View {
        LottieView(animation: .named(lottieName))
            .playing(loopMode: .loop)
            .frame(width: size, height: size)
            .shadow(color: SGTheme.paper.opacity(0.15), radius: 16, x: 0, y: 8)
            .offset(y: floating ? -floatAmplitude : floatAmplitude)
            .animation(
                .easeInOut(duration: floatDuration).repeatForever(autoreverses: true),
                value: floating
            )
            .onAppear { floating = true }
    }
}

// MARK: - Ghost Placeholder

/// Reserves the vertical space taken up by the persistent ghost mascot that
/// `OnboardingContainerView` renders on top of the question screens. The ghost
/// lives in the container (not inside each question view) so it stays put and
/// keeps floating while the question content swaps, instead of fading out and
/// back in on every new question.
struct SGV5QuizGhostPlaceholder: View {
    var body: some View {
        Color.clear
            .frame(height: SGV5FloatingGhostView.questionSize)
            .allowsHitTesting(false)
    }
}

// MARK: - Progress Bar (matches the flashcard quiz)

struct SGV5QuizProgressBar: View {
    let progress: Double // 0.0 to 1.0
    var accessibilityTitle = "Onboarding progress"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: CGFloat {
        progress.isFinite ? CGFloat(min(max(progress, 0), 1)) : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            let fillWidth = geometry.size.width * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(SGTheme.inkHigh)

                if fraction > 0 {
                    Capsule()
                        .fill(SGTheme.mint)
                        .overlay(alignment: .top) {
                            // Same inset shine and 16pt capsule as QV2ProgressBar.
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4.5)
                                .padding(.horizontal, min(8, fillWidth / 2))
                                .padding(.top, 4)
                        }
                        .frame(width: fillWidth)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 16)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
        .accessibilityIdentifier("onboarding.progress")
    }
}

// MARK: - Quiz Header (Question #X)

struct SGV5QuizHeader: View {
    let questionNumber: Int
    
    var body: some View {
        // Empty view - question number now shown inline with question text
        EmptyView()
    }
}

// MARK: - Question Text

struct SGV5QuizQuestionText: View {
    let question: String
    let subtitle: String?
    let questionNumber: Int?
    
    init(question: String, subtitle: String? = nil, questionNumber: Int? = nil) {
        self.question = question
        self.subtitle = subtitle
        self.questionNumber = questionNumber
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Question with optional inline number
            HStack(alignment: .top, spacing: 8){
                if let number = questionNumber {
                    Text("\(number).")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SGTheme.paper.opacity(0.35))
                        .padding(.top, 5)
                }
                
                Text(question)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(SGV5Theme.textPrimary)
            }
            .multilineTextAlignment(.center)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(SGV5Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Speech Bubble (Ghost asks the question)

/// Which edge the speech bubble's tail protrudes from.
enum SGV5QuizSpeechBubbleTailSide {
    case left, top, bottom
}

/// Rounded rectangle with a smooth curved tail drawn as a single continuous
/// path. Mirrors the shape prototyped in `OnboardingStylePreviewView` so the
/// production question header matches that design.
struct SGV5QuizSpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 18
    var tailSide: SGV5QuizSpeechBubbleTailSide = .bottom

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let tail: CGFloat = 10 // how far the tail protrudes

        // Inset the body to make room for the tail
        let body: CGRect
        switch tailSide {
        case .top:
            body = CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
        case .bottom:
            body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        case .left:
            body = CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        }

        var p = Path()

        // Start: top-left corner
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))

        // --- Top edge ---
        if tailSide == .top {
            let tx: CGFloat = body.minX + 28
            p.addLine(to: CGPoint(x: tx, y: body.minY))
            p.addQuadCurve(to: CGPoint(x: tx + 4, y: rect.minY),
                           control: CGPoint(x: tx + 2, y: body.minY))
            p.addQuadCurve(to: CGPoint(x: tx + 16, y: body.minY),
                           control: CGPoint(x: tx + 6, y: body.minY))
        }
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))

        // Top-right corner
        p.addQuadCurve(to: CGPoint(x: body.maxX, y: body.minY + r),
                       control: CGPoint(x: body.maxX, y: body.minY))

        // --- Right edge ---
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))

        // Bottom-right corner
        p.addQuadCurve(to: CGPoint(x: body.maxX - r, y: body.maxY),
                       control: CGPoint(x: body.maxX, y: body.maxY))

        // --- Bottom edge ---
        if tailSide == .bottom {
            let tx: CGFloat = body.minX + 28
            p.addLine(to: CGPoint(x: tx + 16, y: body.maxY))
            p.addQuadCurve(to: CGPoint(x: tx + 4, y: rect.maxY),
                           control: CGPoint(x: tx + 6, y: body.maxY))
            p.addQuadCurve(to: CGPoint(x: tx, y: body.maxY),
                           control: CGPoint(x: tx + 2, y: body.maxY))
        }
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))

        // Bottom-left corner
        p.addQuadCurve(to: CGPoint(x: body.minX, y: body.maxY - r),
                       control: CGPoint(x: body.minX, y: body.maxY))

        // --- Left edge ---
        if tailSide == .left {
            let ty: CGFloat = body.maxY - 20
            p.addLine(to: CGPoint(x: body.minX, y: ty))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: ty - 4),
                           control: CGPoint(x: body.minX, y: ty - 2))
            p.addQuadCurve(to: CGPoint(x: body.minX, y: ty - 16),
                           control: CGPoint(x: body.minX, y: ty - 6))
        }
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))

        // Top-left corner
        p.addQuadCurve(to: CGPoint(x: body.minX + r, y: body.minY),
                       control: CGPoint(x: body.minX, y: body.minY))

        p.closeSubpath()
        return p
    }
}

/// Question-screen header: the ghost mascot on the left "asking" the question
/// through a speech bubble on the right. Replaces the centered ghost + numbered
/// question + subtitle layout.
struct SGV5QuizGhostSpeechBubble: View {
    let question: String
    var ghostSize: CGFloat = 84

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            SGV5FloatingGhostView(size: ghostSize, floatAmplitude: 1.5, floatDuration: 3.4)
                .accessibilityHidden(true)

            Text(question)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(SGV5Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 24)
                .padding(.trailing, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    SGV5QuizSpeechBubbleShape(tailSide: .left)
                        .fill(SGTheme.paper.opacity(0.06))
                )
                .overlay(
                    SGV5QuizSpeechBubbleShape(tailSide: .left)
                        .stroke(SGTheme.paper.opacity(0.10), lineWidth: 0.5)
                )
                .accessibilityAddTraits(.isHeader)
        }
    }
}

// MARK: - Option Button (Single Select) - Clear Dark Card Style

struct SGV5NumberedOptionButton: View {
    let number: Int // Kept for API compatibility but not displayed
    let text: String
    let subtext: String?
    let isSelected: Bool
    let showsSelectionIndicator: Bool
    let action: () -> Void

    init(number: Int, text: String, subtext: String? = nil, isSelected: Bool, showsSelectionIndicator: Bool = true, action: @escaping () -> Void) {
        self.number = number
        self.text = text
        self.subtext = subtext
        self.isSelected = isSelected
        self.showsSelectionIndicator = showsSelectionIndicator
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Text content - left aligned
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SGTheme.paper)
                    
                    if let subtext = subtext {
                        Text(subtext)
                            .font(.system(size: 13))
                            .foregroundColor(SGTheme.paper.opacity(0.6))
                    }
                }
                
                Spacer()

                // Selection indicator - right side
                if showsSelectionIndicator {
                    ZStack {
                        Circle()
                            .stroke(SGTheme.paper.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(SGTheme.mint)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(SGTheme.paper)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                // Solid dark background for visibility on any color
                RoundedRectangle(cornerRadius: 14)
                    .fill(SGTheme.ink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? SGTheme.paper.opacity(0.6) : SGTheme.paper.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGV5ScaleButtonStyle())
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Multi-Select Option Button - Modern Premium Style

struct SGV5MultiSelectOptionButton: View {
    let emoji: String?
    let text: String
    let subtext: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(emoji: String? = nil, text: String, subtext: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.emoji = emoji
        self.text = text
        self.subtext = subtext
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Emoji if present - displayed prominently on left
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 24))
                        .frame(width: 32)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SGTheme.paper)
                    
                    if let subtext = subtext {
                        Text(subtext)
                            .font(.system(size: 13))
                            .foregroundColor(SGTheme.paper.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Checkbox indicator - right side
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(SGTheme.paper.opacity(0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(SGTheme.mint)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(SGTheme.paper)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                // Solid dark background for visibility on any color
                RoundedRectangle(cornerRadius: 14)
                    .fill(SGTheme.ink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? SGTheme.paper.opacity(0.6) : SGTheme.paper.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGV5ScaleButtonStyle())
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Continue Button

struct SGV5QuizContinueButton: View {
    let text: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    init(text: String = "Continue", isEnabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.text = text
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            SGV5Haptics.play(.tap)
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(SGTheme.paper) }
                Text(text)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(SGTheme.paper)
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity, minHeight: SGV5Theme.buttonHeight)
            .background(SGTheme.mint, in: Capsule())
            .shadow(color: SGTheme.paper.opacity(0.10), radius: 8, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Skip Button

struct SGV5SkipButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Skip")
                .font(.subheadline)
                .foregroundColor(SGV5Theme.textSecondary)
        }
    }
}

// MARK: - Back Button (matches old onboarding style)

struct SGV5QuizBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.backward")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SGTheme.paper)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SGTheme.paper.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(SGTheme.paper.opacity(0.22), lineWidth: 0.8)
                )
        }
    }
}

// MARK: - Quiz Screen Container

struct SGV5QuizScreenContainer<Content: View>: View {
    let progress: Double
    let showBackButton: Bool
    let onBack: (() -> Void)?
    let useGlassEffect: Bool  // Whether to use glass effect (for liquid background)
    let content: Content
    
    init(
        progress: Double,
        showBackButton: Bool = true,
        onBack: (() -> Void)? = nil,
        useGlassEffect: Bool = true,  // Default to glass effect for liquid background
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.showBackButton = showBackButton
        self.onBack = onBack
        self.useGlassEffect = useGlassEffect
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Transparent background - liquid wave is rendered by OnboardingContainerView
            Color.clear
            
            VStack(spacing: 0) {
                // Top bar with back button and flashcard-style progress.
                HStack(alignment: .center, spacing: 12) {
                    if showBackButton, let onBack = onBack {
                        SGV5QuizBackButton(action: onBack)
                    } else {
                        Spacer()
                            .frame(width: 32)
                    }
                    
                    SGV5QuizProgressBar(progress: progress)
                }
                .frame(height: 32)
                .padding(.leading, 16)
                .padding(.trailing, 24)
                .padding(.top, 8)
                
                // Main content
                content
            }
        }
    }
}

// MARK: - Previews








// MARK: - Floating CTA

// Shared treatment for onboarding call-to-action buttons. The CTA floats above
// the content: a full-width pill lifted off the side edges and raised above the
// home indicator, with no scrim behind it.
//
// Usage: apply to the CTA (a single button, or a VStack of button + skip) in
// place of its trailing `.padding(.horizontal, _).padding(.bottom, _)`:
//
//     myContinueButton
//         .sgV5FloatingCTA()

extension View {
    /// Floats a bottom CTA above the content.
    /// - Parameters:
    ///   - background: retained for call-site compatibility; no longer drawn.
    ///   - horizontal: side inset for the pill (keeps it lifted off the edges).
    ///   - bottom: gap below the pill, above the home indicator.
    func sgV5FloatingCTA(
        background: Color = SGV5Theme.floatingCTABackground,
        horizontal: CGFloat = 24,
        bottom: CGFloat = 24
    ) -> some View {
        modifier(SGV5FloatingCTAModifier(horizontal: horizontal, bottom: bottom))
    }
}

struct SGV5FloatingCTAModifier: ViewModifier {
    let horizontal: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontal)
            .padding(.bottom, bottom)
    }
}
