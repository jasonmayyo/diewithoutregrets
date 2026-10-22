import SwiftUI

/// Screen 18: a visual story from a first deck to exam day.
/// Chapter selection explores the story; the CTA is available immediately.
struct SGV5V4PersonalizedPlanView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var chapter = 0
    @State private var hovering = false

    private var profile: SGV5V5OnboardingProfile { viewModel.v5Profile }
    private let assets = ["sgv5-journey-start", "sgv5-journey-rhythm", "sgv5-journey-exam"]
    private let labels = ["Start", "Build", "Exam day"]
    private let symbols = ["doc.text.fill", "bolt.fill", "flag.checkered"]
    private let headings = ["One small start.", "Study. Unlock. Repeat.", "Walk in more prepared."]
    private let eyebrows = ["TODAY", "YOUR NEW RHYTHM", "EXAM DAY"]
    private let imageDescriptions = [
        "A student opens their notes at a desk as the Study Guard mascot offers a first stack of flashcards.",
        "The same student practices flashcards with the Study Guard mascot cheering them on.",
        "The student and the Study Guard mascot walk toward the exam room, ready for the next chapter."
    ]

    private var examCountdown: String {
        switch profile.examDays {
        case 0: return "Your exam is today"
        case 1: return "1 day to your exam"
        default: return "\(profile.examDays) days to your exam"
        }
    }

    private func caption(for index: Int) -> String {
        switch index {
        case 0: return "Turn your \(profile.subjectLabel) notes into your first deck."
        case 1: return "Answer \(profile.studyCardCount) cards correctly. Earn 5 minutes to scroll."
        default: return "Little sessions now. More \(profile.subjectLabel) behind you."
        }
    }

    private func badge(for index: Int) -> String {
        switch index {
        case 0: return "Your notes → flashcards"
        case 1: return "\(profile.studyCardCount) correct → 5 min"
        default: return "One session at a time"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let artworkHeight = min(320, max(235, geometry.size.height * 0.39))
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        TabView(selection: $chapter) {
                            ForEach(0..<3, id: \.self) { index in
                                artwork(index, height: artworkHeight)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: artworkHeight + 28)
                        .accessibilityIdentifier("onboarding.journey.scenes")

                        VStack(spacing: 8) {
                            Text(eyebrows[chapter])
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(SGTheme.mintDeep)
                            Text(headings[chapter])
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .tracking(-0.6)
                                .foregroundStyle(SGTheme.paper)
                                .accessibilityAddTraits(.isHeader)
                            Text(caption(for: chapter))
                                .font(.system(size: 15))
                                .foregroundStyle(SGTheme.paperSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("onboarding.journey.caption")

                        chapterNavigation
                            .padding(.horizontal, 32)
                        Text("Tap a stop or swipe to explore")
                            .font(.system(size: 11))
                            .foregroundStyle(SGTheme.paperTertiary)
                            .padding(.top, -8)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
                }
                VStack(spacing: 12) {
                    Text(profile.studyRuleSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SGTheme.mintDeep)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboarding.plan.studyRule")
                    SGV5QuizContinueButton(text: "Let's start my journey", isEnabled: profile.isReady) {
                        viewModel.advanceV5()
                    }
                    .accessibilityIdentifier("onboarding.plan.continue")
                }
                .padding(.top, 8)
                .sgV5FloatingCTA()
            }
            .background(SGTheme.ink)
        }
        .onAppear {
            hovering = true
            #if DEBUG
            // Keep existing screenshot arguments, now mapped to story chapters.
            if ProcessInfo.processInfo.arguments.contains("-sg-v5-plan-middle") { chapter = 1 }
            if ProcessInfo.processInfo.arguments.contains("-sg-v5-plan-end") { chapter = 2 }
            #endif
        }
        .onChange(of: chapter) { _, selected in
            SGV5Haptics.play(selected == 2 ? .success : .selection)
            viewModel.trackScreenAction(screenId: 816, action: "journey_chapter_viewed",
                                       properties: ["chapter": selected + 1])
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text(examCountdown)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SGTheme.mintDeep)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(SGTheme.mintTint, in: Capsule())
            Text("Your next chapter.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-1)
                .foregroundStyle(SGTheme.paper)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 24)
    }

    private func artwork(_ index: Int, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(index == 1 ? Color(hex: 0xF0ECFA) : SGTheme.mintTint)
                .frame(width: height * 0.9, height: height * 0.83)
                .rotationEffect(.degrees(index == 1 ? 7 : -7))
                .offset(y: -6)
            Image(assets[index])
                .resizable().scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .padding(.horizontal, 12)
                .offset(y: hovering && !reduceMotion && scenePhase == .active ? -3 : 3)
                .animation(reduceMotion || scenePhase != .active ? nil : .easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: hovering)
                .accessibilityLabel(imageDescriptions[index])
            VStack {
                HStack {
                    Text(String(format: "%02d / 03", index + 1))
                        .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                        .tracking(1)
                        .foregroundStyle(SGTheme.paperTertiary)
                    Spacer()
                    Image(systemName: "sparkle")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(SGTheme.mintDeep.opacity(0.65))
                }
                Spacer()
                Label(badge(for: index), systemImage: symbols[index])
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SGTheme.mintDeep)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(SGTheme.ink, in: Capsule())
                    .overlay(Capsule().stroke(SGTheme.mintSoft.opacity(0.5), lineWidth: 1))
                    .shadow(color: SGTheme.paper.opacity(0.06), radius: 10, y: 5)
                    .rotationEffect(.degrees(index == 1 ? 2 : -2))
            }
            .padding(.horizontal, 36)
        }
        .padding(.bottom, 7)
    }

    private var chapterNavigation: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                if index > 0 {
                    Capsule()
                        .fill(index <= chapter ? SGTheme.mint : SGTheme.inkHigh)
                        .frame(maxWidth: .infinity).frame(height: 3)
                        .padding(.top, 20)
                }
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { chapter = index }
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: symbols[index])
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(index <= chapter ? SGTheme.ink : SGTheme.paperTertiary)
                            .frame(width: 42, height: 42)
                            .background(index <= chapter ? SGTheme.mintDeep : SGTheme.inkHigh, in: Circle())
                            .overlay(Circle().stroke(index == chapter ? SGTheme.mintSoft : .clear, lineWidth: 3).padding(-4))
                        Text(labels[index])
                            .font(.system(size: 11, weight: index == chapter ? .bold : .medium))
                            .foregroundStyle(index == chapter ? SGTheme.paper : SGTheme.paperSecondary)
                    }
                    .frame(width: 68)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chapter \(index + 1): \(labels[index])")
                .accessibilityAddTraits(index == chapter ? .isSelected : [])
                .accessibilityIdentifier("onboarding.journey.chapter\(index + 1)")
            }
        }
    }
}
