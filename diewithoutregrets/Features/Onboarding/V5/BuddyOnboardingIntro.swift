import SwiftUI

/// Two short visual pages introduce guarding and studying to unlock.
struct BuddyHowItWorksView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    let step: SGV5V5OnboardingStep
    @Environment(\.scenePhase) private var scenePhase

    private var isGuard: Bool { step == .howGuard }
    private let pose: MascotPose = .lookingDown

    var body: some View {
        SGV5QuizScreenContainer(progress: step.progress, onBack: { viewModel.previousPage() }) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 12)
                        if isGuard {
                            VStack(spacing: 12) {
                                mascot
                                    .frame(height: min(360, max(220, geometry.size.height * 0.58)))
                                HStack(spacing: 18) {
                                    appIcon("social-instagram", name: "Instagram")
                                    appIcon("social-tiktok", name: "TikTok")
                                    appIcon("social-youtube", name: "YouTube")
                                }
                            }
                            .modifier(MonsterMessageArrival())
                        }
                        VStack(spacing: 12) {
                            Text(isGuard ? "Block the scroll." : "Get past your\nstudy buddy to scroll.")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(SGTheme.paper)
                            Text(isGuard ? "Choose the apps that distract you." : "Answer flashcards before you scroll.")
                                .font(.title3).foregroundStyle(SGTheme.paperSecondary)
                        }
                        .multilineTextAlignment(.center)
                        if !isGuard {
                            BuddyUnlockChatDemo(viewportHeight: geometry.size.height)
                                .frame(maxWidth: 380)
                        }
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    .padding(.horizontal, 24)
                }
                .coordinateSpace(name: "monsterTranscript")
            }
            SGV5QuizContinueButton(text: "Continue") { viewModel.nextPage() }
                .sgV5FloatingCTA()
        }
    }

    @ViewBuilder private var mascot: some View {
        if scenePhase == .active {
            // The original bundled animations; MascotView handles Reduce Motion.
            MascotView(pose: pose, loops: nil)
        } else {
            Image(pose.stillName).resizable().scaledToFit().accessibilityHidden(true)
        }
    }

    private func appIcon(_ asset: String, name: String) -> some View {
        Image(asset).resizable().scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SGTheme.paper)
                    .padding(6).background(MonsterPalette.bg, in: Circle())
                    .offset(x: 5, y: 5)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("\(name), guarded")
    }
}

/// Scripted product preview only; never starts a session or grants screen time.
private struct BuddyUnlockChatDemo: View {
    let viewportHeight: CGFloat
    @StateObject private var presenter = MonsterTranscriptPresenter()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messages: [MonsterMessage] = [
        .monster("Well well well."),
        .monster("Look who has come to scroll when their bio exam is only 3 days away."),
        .monster("Not on my watch. Answer these 3 questions before you scroll.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonsterAvatarHeader(persona: .diva)
            Rectangle().fill(MonsterPalette.hairline).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                // The user's uploaded JPG is already bundled as this reaction.
                // Show it first, with no GIF badge or fabricated animation.
                MonsterReactionView(reaction: .holdingItIn,
                                    playbackEnabled: scenePhase == .active,
                                    viewportHeight: viewportHeight)
                    .modifier(MonsterMessageArrival())
                ForEach(messages.prefix(presenter.revealed)) { message in
                    if let text = message.text {
                        MonsterTextBubble(text: text, sender: message.sender)
                            .modifier(MonsterMessageArrival())
                    }
                }
                if presenter.isTyping { MonsterTypingIndicator(name: MonsterPersona.diva.name) }
            }
            .frame(maxWidth: .infinity, minHeight: 370, alignment: .topLeading)
        }
        .padding(16)
        .background(MonsterPalette.bg, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(MonsterPalette.hairline))
        .task(id: scenePhase == .active ? (reduceMotion ? 2 : 1) : 0) {
            guard scenePhase == .active else { presenter.pause(); return }
            guard !reduceMotion else { presenter.restoreHistory(messages); return }
            presenter.update(messages: messages, isVisible: true)
        }
        .onDisappear { presenter.pause() }
    }
}

/// A transparent projection from a self-reported range, before exam details exist.
struct BuddyPhoneTimeCostView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0.0
    private var profile: SGV5V5OnboardingProfile { viewModel.v5Profile }
    private var displayedHours: Int { Int((Double(profile.yearlyPhoneHours) * revealed).rounded()) }

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.phoneTimeCost.progress,
                               onBack: { viewModel.previousPage() }) {
            ScrollView {
                VStack(spacing: 18) {
                    Text(profile.phoneEstimateIsExample ? "LET’S PUT IT IN PERSPECTIVE" : "AT THIS PACE…")
                        .font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(SGTheme.paperSecondary)
                    VStack(spacing: 2) {
                        Text(displayedHours.formatted()).monospacedDigit()
                            .font(.system(size: 68, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("hours a year on your phone.").font(.title3)
                    }.foregroundStyle(SGTheme.paper)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(profile.yearlyPhoneHours) hours a year on your phone")
                    Text(profile.phoneEstimateExplanation)
                        .font(.caption).foregroundStyle(SGTheme.paperSecondary)
                    yearGrid
                    Text("That’s \(profile.yearlyPhoneDays.formatted(.number.precision(.fractionLength(1)))) full days.")
                        .font(.title2.weight(.bold)).foregroundStyle(.orange)
                    Text("Take back the scrolling you don’t want.")
                        .font(.title3.weight(.semibold)).foregroundStyle(SGTheme.paper)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.vertical, 24)
            }
            SGV5QuizContinueButton(text: "Let’s make that time count") { viewModel.nextPage() }
                .sgV5FloatingCTA()
        }
        .task(id: scenePhase == .active && !reduceMotion) {
            guard scenePhase == .active, !reduceMotion else { revealed = 1; return }
            revealed = 0
            for tick in 1...45 {
                do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
                revealed = Double(tick) / 45
            }
        }
    }

    private var yearGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 30), spacing: 4) {
                ForEach(0..<365) { index in
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 3).fill(SGTheme.paper.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Rectangle().fill(.orange)
                                    .frame(width: geometry.size.width * min(1, max(0, profile.yearlyPhoneDays * revealed - Double(index))))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }.aspectRatio(1, contentMode: .fit)
                }
            }.accessibilityHidden(true)
            Text("One dot = one day. Orange = phone time.")
                .font(.caption).foregroundStyle(SGTheme.paperSecondary)
        }
    }
}
