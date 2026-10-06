import SwiftUI
import Lottie

/// A receipt for time already granted. Animation and app navigation never grant
/// time themselves, so leaving halfway through either cannot lose the reward.
struct UnlockSuccessView: View {
    let minutes: Int
    var earnedSeconds: Int? = nil
    var correctCount: Int? = nil
    var totalCount: Int? = nil
    var streak: Int = 0
    var subtitle: String? = nil
    var ctaTitle: String = "Unlock apps"
    var destination: ShieldReturnDestination? = nil
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var unlocked = false
    @State private var openingApp = false
    @State private var showReturnFallback = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Label("SESSION COMPLETE", systemImage: "checkmark.circle.fill")
                        .font(SGTheme.micro)
                        .tracking(2)
                        .foregroundStyle(SGTheme.unlockHighlight)
                        .padding(.top, 22)

                    Spacer(minLength: compact ? 16 : 24)

                    unlockSeal
                        .scaleEffect(compact ? 0.88 : 1)
                        .frame(height: compact ? 144 : 176)

                    Text("You're back in.")
                        .font(SGTheme.stepTitle)
                        .foregroundStyle(.white)
                        .padding(.top, compact ? 4 : 16)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("+\(minutes)")
                            .font(SGTheme.display(compact ? 84 : 100, weight: .heavy))
                            .monospacedDigit()
                        Text("min")
                            .font(SGTheme.display(30, weight: .medium))
                    }
                    .foregroundStyle(SGTheme.unlockHighlight)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(minutes) \(minutes == 1 ? "minute" : "minutes") earned")
                    .padding(.top, 8)

                    Text("Screen time, unlocked.")
                        .font(SGTheme.cardTitle)
                        .foregroundStyle(SGTheme.unlockSecondary)

                    if let subtitle {
                        Text(subtitle)
                            .font(SGTheme.body)
                            .foregroundStyle(SGTheme.unlockSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }

                    if let correctCount, let totalCount {
                        resultCard(correct: correctCount, total: totalCount)
                            .padding(.top, compact ? 20 : 28)
                    }

                    Spacer(minLength: compact ? 16 : 24)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 14)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .background {
            LinearGradient(colors: [SGTheme.unlockTop, SGTheme.unlockBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    RadialGradient(colors: [SGTheme.mint.opacity(0.16), .clear],
                                   center: .init(x: 0.5, y: 0.28), startRadius: 10, endRadius: 300)
                }
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .task {
            guard !appeared else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { appeared = true }
            if reduceMotion { finishUnlockAnimation() }
        }
        .alert("Your apps are unlocked", isPresented: $showReturnFallback) {
            Button("Done", action: onContinue)
        } message: {
            Text("Couldn't open \(destination?.name ?? "the app") automatically. Switch back to it from your Home Screen or app switcher. Your earned time is ready.")
        }
    }

    private var unlockSeal: some View {
        ZStack {
            ForEach(0..<2) { ring in
                Circle()
                    .strokeBorder(SGTheme.unlockHighlight.opacity(0.25), lineWidth: 1)
                    .frame(width: 148, height: 148)
                    .scaleEffect(unlocked && !reduceMotion ? 1.55 + Double(ring) * 0.25 : 1)
                    .opacity(unlocked ? 0 : 1)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(Double(ring) * 0.1), value: unlocked)
            }

            Circle()
                .fill(.white.opacity(0.08))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .frame(width: 154, height: 154)

            Image(systemName: "lock.open.fill")
                .font(SGTheme.display(66, weight: .semibold))
                .foregroundStyle(SGTheme.unlockHighlight)
                .opacity(unlocked || reduceMotion ? 1 : 0)
                .scaleEffect(unlocked || reduceMotion ? 1 : 0.85)

            if !reduceMotion {
                UnlockLottie(onFinished: finishUnlockAnimation)
                    .frame(width: 280, height: 210)
                    .opacity(unlocked ? 0 : 1)
            }
        }
        .frame(height: 176)
        .accessibilityHidden(true)
    }

    private func resultCard(correct: Int, total: Int) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                stat("\(correct) / \(total)", label: "Correct answers", icon: "checkmark.circle")
                if streak > 0 {
                    Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 36)
                    stat("\(streak) \(streak == 1 ? "day" : "days")", label: "Study streak", icon: "flame")
                }
            }
            if let earnedSeconds, earnedSeconds < minutes * 60 {
                Text("\(QV2EarnedChip.label(seconds: earnedSeconds)) earned, rounded up to \(minutes) min")
                    .font(SGTheme.caption)
                    .foregroundStyle(SGTheme.unlockSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: SGTheme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: SGTheme.cardRadius)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    private func stat(_ value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Label(value, systemImage: icon)
                .font(SGTheme.display(20, weight: .semibold))
                .foregroundStyle(SGTheme.unlockHighlight)
            Text(label)
                .font(SGTheme.caption)
                .foregroundStyle(SGTheme.unlockSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 14) {
            SGButton(title: destination.map { "Back to \($0.name)" } ?? ctaTitle,
                     icon: destination == nil ? "lock.open.fill" : "arrow.up.forward.app.fill",
                     variant: .white, loading: openingApp, action: continueToApp)

            if destination != nil {
                Button("Stay in Study Guard", action: onContinue)
                    .font(SGTheme.buttonSmall)
                    .foregroundStyle(SGTheme.unlockSecondary)
                    .frame(minHeight: 44)
                    .disabled(openingApp)
            } else {
                Text("Your apps are ready to use again.")
                    .font(SGTheme.caption)
                    .foregroundStyle(SGTheme.unlockSecondary)
                    .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func finishUnlockAnimation() {
        guard !unlocked else { return }
        SGTheme.successHaptic()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { unlocked = true }
    }

    private func continueToApp() {
        guard !openingApp else { return }
        guard let destination else { onContinue(); return }
        openingApp = true
        UIApplication.shared.open(destination.url, options: [:]) { opened in
            openingApp = false
            if opened { onContinue() } else { showReturnFallback = true }
        }
    }
}

/// Play the opening portion of the existing Lock.lottie once. The final
/// open-lock glyph takes over as the source animation fades its last frame.
private struct UnlockLottie: UIViewRepresentable {
    let onFinished: () -> Void

    final class Coordinator {
        var load: Task<Void, Never>?
        var animation: LottieAnimationView?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let coordinator = context.coordinator
        coordinator.load = Task { @MainActor in
            guard let file = try? await DotLottieFile.named("Lock") else {
                if !Task.isCancelled { onFinished() }
                return
            }
            guard !Task.isCancelled else { return }
            let animation = LottieAnimationView(dotLottie: file)
            coordinator.animation = animation
            animation.contentMode = .scaleAspectFit
            animation.backgroundBehavior = .pauseAndRestore
            animation.animationSpeed = 0.85
            animation.translatesAutoresizingMaskIntoConstraints = false
            animation.setValueProvider(ColorValueProvider(LottieColor(r: 0.77, g: 0.96, b: 0.84, a: 1)),
                                       keypath: AnimationKeypath(keypath: "**.Color"))
            container.addSubview(animation)
            NSLayoutConstraint.activate([
                animation.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                animation.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                animation.topAnchor.constraint(equalTo: container.topAnchor),
                animation.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            animation.play(fromFrame: 90, toFrame: 116, loopMode: .playOnce) { finished in
                if finished { onFinished() }
            }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.load?.cancel()
        coordinator.animation?.stop()
    }
}

#Preview("Earned time · Instagram") {
    UnlockSuccessView(minutes: 3, earnedSeconds: 150, correctCount: 5, totalCount: 6, streak: 3,
                      destination: .app(bundleIdentifier: "com.burbn.instagram"), onContinue: {})
}

#Preview("Earned time · short quiz") {
    UnlockSuccessView(minutes: 1, earnedSeconds: 30, correctCount: 1, totalCount: 4, onContinue: {})
}
