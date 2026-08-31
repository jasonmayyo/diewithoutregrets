//
//  OnboardingV4Steps.swift
//  diewithoutregrets
//
//  The steps added by onboarding v4 ("Ace the Semester", Rocapine
//  problem-first): name capture, the symptom check, the mid-quiz
//  testimonial, the preparedness baseline, the reality-check Screen Time
//  ask, the live flashcard demo (the aha moment), the commitment unlock
//  rule, the plan-building loader and the personalized plan reveal.
//
//  The exam-date question lives in OnboardingV3NewSteps.swift (upgraded in
//  place); the diagnosis screens live in BreakdownView.swift.
//

import SwiftUI
import FamilyControls

// MARK: - quizName

/// Quiz question 1 (night): first name. Powers the plan reveal's
/// "Jason, here's how you ace Nov 4." Skippable — the copy degrades
/// gracefully without it.
struct QuizNameView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Space for the container-level floating clipboard mascot.
            Color.clear.frame(height: 128)

            VStack(spacing: 8) {
                (Text("1.  ").foregroundColor(OnbNight.textMuted)
                    + Text("What should we call you?").foregroundColor(OnbNight.textPrimary))
                    .font(SGTheme.display(22, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("Your plan is going to have your name on it.")
                    .font(SGTheme.body)
                    .foregroundColor(OnbNight.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)

            TextField("", text: $draft, prompt: Text("First name").foregroundColor(OnbNight.textMuted))
                .font(SGTheme.display(20, weight: .semibold))
                .foregroundColor(OnbNight.textPrimary)
                .tint(.white)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(advance)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                        .fill(OnbNight.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                                .strokeBorder(focused ? OnbNight.cardBorderSelected : OnbNight.cardBorder,
                                              lineWidth: focused ? 1.5 : 1)
                        )
                )
                .padding(.horizontal, SGTheme.screenPadding)

            Spacer()

            OnbCTA(title: draft.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip" : "Continue",
                   night: true) {
                advance()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            draft = viewModel.firstName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
        }
    }

    private func advance() {
        viewModel.firstName = draft.trimmingCharacters(in: .whitespaces)
        focused = false
        viewModel.nextStep()
    }
}

// MARK: - quizSymptoms

/// Quiz question 6 (night): the symptom check, multi-select. Pure
/// identification — every row is a pain the plan reveal maps a feature to.
struct QuizSymptomsView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let options = [
        "My grades are slipping",
        "I cram at 2am the night before",
        "I can't focus for 10 minutes",
        "I scroll even during class",
        "I keep promising myself I'll stop",
    ]

    var body: some View {
        VStack(spacing: 0) {
            QuizScreenContainer(
                number: 6,
                question: "Any of this sound familiar?",
                subtitle: "Pick everything that's true. No one's judging.",
                progress: OnboardingStep.quizSymptoms.quizProgress
            ) {
                ForEach(options, id: \.self) { option in
                    QuizOptionRow(
                        title: option,
                        selected: viewModel.symptoms.contains(option)
                    ) {
                        SGTheme.tapHaptic()
                        if viewModel.symptoms.contains(option) {
                            viewModel.symptoms.remove(option)
                        } else {
                            viewModel.symptoms.insert(option)
                        }
                    }
                }
            }

            OnbCTA(title: viewModel.symptoms.isEmpty ? "Not really" : "That's me",
                   night: true) {
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
    }
}

// MARK: - quizTestimonial

/// The mid-quiz testimonial drop-in (Quittr beat): legitimacy from a user,
/// not a proof screen, landed while they're still opening up.
struct QuizTestimonialView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(SGTheme.body)
                            .foregroundColor(SGTheme.sun)
                    }
                }
                .fadeRise(shown, delay: 0.1)

                Text("\u{201C}I answered the questions the same way you just did. One semester later I went from cramming at 2am to actually walking into exams ready.\u{201D}")
                    .font(SGTheme.display(22, weight: .semibold))
                    .foregroundColor(OnbNight.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .fadeRise(shown, delay: 0.3)

                HStack(spacing: 8) {
                    Image("char2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Maya, 2nd year")
                        .font(SGTheme.caption)
                        .foregroundColor(OnbNight.textSecondary)
                }
                .fadeRise(shown, delay: 0.5)
            }
            .padding(.horizontal, SGTheme.screenPadding + 8)

            Spacer()

            OnbCTA(title: "Keep going", night: true, visible: shown) {
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear { shown = true }
    }
}

// MARK: - quizPreparedness

/// Quiz question 8 (night): the baseline. Feeds the verdict's kicker line
/// and the plan's intensity.
struct QuizPreparednessView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    private let options: [(title: String, emoji: String)] = [
        ("Way behind", "😰"),
        ("A bit behind", "😬"),
        ("On track", "🙂"),
        ("Ahead of the game", "😎"),
    ]

    @State private var answered = false

    var body: some View {
        QuizScreenContainer(
            number: 8,
            question: "Honestly, how ready are you?",
            subtitle: "For the exam you just told us about.",
            progress: OnboardingStep.quizPreparedness.quizProgress
        ) {
            ForEach(options, id: \.title) { option in
                QuizOptionRow(
                    title: option.title,
                    emoji: option.emoji,
                    selected: viewModel.preparedness == option.title
                ) {
                    guard !answered else { return }
                    answered = true
                    viewModel.selectQuizAnswer {
                        viewModel.preparedness = option.title
                    }
                }
            }
        }
    }
}

// MARK: - realityCheck

/// The confrontation permission ask (night): most people guess low — see
/// the real number. Grant unlocks the real-usage verdict row; "use my
/// estimate" and denial both advance, the self-reported math carries the
/// diagnosis either way.
struct RealityCheckView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false
    @State private var isRequesting = false
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Text("You guessed \(viewModel.screenTime.isEmpty ? "your screen time" : viewModel.screenTime.lowercased()).")
                    .font(SGTheme.stepTitle)
                    .foregroundColor(OnbNight.textPrimary)
                    .fadeRise(shown, delay: 0.1)

                Text("Most people guess about 40% low.\nYour iPhone knows the real number.")
                    .font(SGTheme.display(22, weight: .semibold))
                    .foregroundColor(OnbNight.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .fadeRise(shown, delay: 0.5)

                Text("iOS will ask with a system dialog. Your usage stays on your device. We never see it.")
                    .font(SGTheme.body)
                    .foregroundColor(OnbNight.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .fadeRise(shown, delay: 0.9)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, SGTheme.screenPadding + 8)

            Spacer()

            SGButton(title: "Show my real screen time",
                     variant: .white,
                     enabled: !isRequesting,
                     loading: isRequesting) {
                requestAccess()
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .fadeRise(shown, delay: 1.2)

            // Night text button: SGButton's .text variant is dark-on-light
            // and vanishes against the night sky.
            Button {
                guard !isRequesting, !didFinish else { return }
                didFinish = true
                viewModel.screenAction("reality_check_skipped")
                viewModel.nextStep()
            } label: {
                Text("Use my estimate")
                    .font(SGTheme.rowLabel)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SGPressStyle())
            .padding(.top, 2)
            .padding(.bottom, 10)
            .fadeRise(shown, delay: 1.3)
        }
        .onAppear {
            shown = true
            // Hand the exam date to the report extension now, so the
            // verdict's real-usage row can do its days-lost math. This is
            // the only data that crosses INTO the report sandbox.
            if let examDate = viewModel.examDate {
                SGContract.sharedDefaults?.set(examDate.timeIntervalSince1970,
                                               forKey: SGContract.Keys.onboardingExamDate)
            } else {
                SGContract.sharedDefaults?.removeObject(forKey: SGContract.Keys.onboardingExamDate)
            }
        }
    }

    private func requestAccess() {
        guard !isRequesting, !didFinish else { return }
        isRequesting = true

        Task { @MainActor in
            let ok = await StudyGuardManager.shared.requestAuthorization()
            Analytics.capture("screen_time_auth_result", properties: [
                "granted": ok,
                "surface": "onboarding_diagnosis",
            ])
            isRequesting = false
            didFinish = true
            viewModel.authorizedInQuiz = ok

            if ok {
                SGTheme.successHaptic()
            }
            // Denial never blocks — the estimate carries the verdict.
            viewModel.nextStep()
        }
    }
}

// MARK: - tryIt

/// The aha moment, inside the onboarding (daylight): answer one real
/// flashcard and watch the coins bank real screen time. This screen IS the
/// product demo — it replaces the science/mechanic/no-willpower explainers.
struct TryItDemoView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let question = "Mitochondria are the ___ of the cell"
    private let choices = ["bouncer", "powerhouse", "landlord"]
    private let correctIndex = 1

    @State private var shown = false
    @State private var selected: Int?
    @State private var revealed = false
    @State private var missed: Int?
    @State private var earnedSeconds = 0
    @State private var coinsBanked = 0
    @State private var coins: [QV2CoinModel] = []
    @State private var chipFrame: CGRect = .zero
    @State private var ctaFrame: CGRect = .zero
    @State private var showOutro = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SGMicroLabel(text: "Try it")
                Spacer()
                QV2EarnedChip(seconds: earnedSeconds, bump: coinsBanked)
                    .background(QV2GlobalFrameReader { chipFrame = $0 })
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 12)
            .fadeRise(shown, delay: 0.1)

            Text("This is how you'll open Instagram.")
                .font(SGTheme.stepTitle)
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 14)
                .fadeRise(shown, delay: 0.2)

            Text(question)
                .font(SGTheme.display(21, weight: .semibold))
                .foregroundColor(SGTheme.paper)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 26)
                .fadeRise(shown, delay: 0.35)

            VStack(spacing: 12) {
                ForEach(choices.indices, id: \.self) { idx in
                    Button {
                        tapTile(idx)
                    } label: {
                        Text(choices[idx])
                            .font(QV2.font(19, .medium))
                            .foregroundColor(tileStyle(idx).label)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                    }
                    .buttonStyle(QV2ChunkyStyle(
                        fill: tileStyle(idx).fill,
                        edge: tileStyle(idx).border,
                        depth: 2.5,
                        radius: 13,
                        bordered: true
                    ))
                    .disabled(revealed)
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 22)
            .fadeRise(shown, delay: 0.5)

            Spacer()

            ZStack(alignment: .bottom) {
                if showOutro {
                    VStack(spacing: 14) {
                        Text("Every correct card earns you \(StudyGuardManager.shared.perCardSeconds) seconds of your apps. No willpower needed. The lock does the work.")
                            .font(SGTheme.body)
                            .foregroundColor(SGTheme.paperSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, SGTheme.screenPadding + 8)

                        OnbCTA(title: "I like this deal") {
                            viewModel.nextStep()
                        }
                    }
                    .transition(.opacity)
                } else {
                    QV2CTAButton(title: "CHECK", enabled: selected != nil, action: commit)
                        .background(QV2GlobalFrameReader { ctaFrame = $0 })
                        .padding(.horizontal, SGTheme.screenPadding)
                }
            }
            .padding(.bottom, 12)
            .animation(SGTheme.springFast, value: showOutro)
        }
        .overlay {
            QV2CoinFlightOverlay(
                coins: coins,
                spawnFrame: ctaFrame,
                targetFrame: chipFrame,
                onLand: bankCoin
            )
        }
        .onAppear { shown = true }
    }

    private func tileStyle(_ idx: Int) -> (fill: Color, border: Color, label: Color) {
        if revealed {
            if idx == correctIndex { return (QV2.greenPanel, QV2.greenTileBorder, QV2.greenDeep) }
            return (.white, QV2.tileBorder, QV2.text)
        }
        if missed == idx { return (QV2.redPanel, QV2.redTileBorder, QV2.redDeep) }
        if selected == idx { return (QV2.blueTint, QV2.blueBorder, QV2.blue) }
        return (.white, QV2.tileBorder, QV2.text)
    }

    private func tapTile(_ idx: Int) {
        guard !revealed, selected != idx else { return }
        QuizHaptics.selectTick()
        withAnimation(SGTheme.springFast) {
            selected = idx
            missed = nil
        }
    }

    private func commit() {
        guard !revealed, let answer = selected else { return }
        if answer == correctIndex {
            revealed = true
            QuizHaptics.correctBurst()
            viewModel.screenAction("demo_card_correct")
            spawnFlock()
        } else {
            QuizHaptics.wrongBuzz()
            withAnimation(SGTheme.springFast) {
                missed = answer
                selected = nil
            }
        }
    }

    private func spawnFlock() {
        let perCard = StudyGuardManager.shared.perCardSeconds
        if reduceMotion {
            earnedSeconds = perCard
            coinsBanked += 1
            showOutro = true
            return
        }
        coins = QV2CoinModel.flock(of: 5, serial: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(SGTheme.springFast) { showOutro = true }
        }
    }

    private func bankCoin(_ coin: QV2CoinModel) {
        guard coins.contains(where: { $0.id == coin.id }) else { return }
        QuizHaptics.coinLand(progress: Double(coin.index + 1) / Double(coin.flockSize))
        let perCard = StudyGuardManager.shared.perCardSeconds
        let base = perCard / coin.flockSize
        let value = coin.index == coin.flockSize - 1 ? perCard - base * (coin.flockSize - 1) : base
        withAnimation(SGTheme.springPop) {
            earnedSeconds += value
            coinsBanked += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            coins.removeAll { $0.id == coin.id }
        }
    }
}

// MARK: - commitment

/// The unlock rule (daylight): how many flashcards per unlock. Writes the
/// REAL setting the quiz engine reads — this is the Rocapine commitment
/// block doubling as configuration.
struct CommitmentView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false

    private let options = [5, 10, 20]
    private let recommended = 10

    @State private var shown = false
    @State private var picked = 10

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                SGMicroLabel(text: "Your unlock rule")
                Text("How hard should Instagram be to open?")
                    .font(SGTheme.stepTitle)
                    .foregroundColor(SGTheme.paper)
                Text("Locked apps only open after flashcards. Each correct card earns \(StudyGuardManager.shared.perCardSeconds) seconds of screen time.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 20)
            .fadeRise(shown, delay: 0.1)

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { count in
                    optionCard(count)
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .fadeRise(shown, delay: 0.3)

            Spacer()

            OnbCTA(title: "Lock it in", visible: shown) {
                viewModel.commitCardCount = picked
                flashcardCount = picked
                useAllCards = false
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            shown = true
            picked = viewModel.commitCardCount
        }
    }

    private func optionCard(_ count: Int) -> some View {
        let minutes = StudyGuardManager.shared.earnedMinutes(forCardCount: count)
        let isPicked = picked == count
        return Button {
            SGTheme.tapHaptic()
            withAnimation(SGTheme.springFast) { picked = count }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(count) flashcards")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                    Text("Earns \(minutes) minutes of your apps")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                }

                Spacer()

                if count == recommended {
                    Text("RECOMMENDED")
                        .font(SGTheme.micro.weight(.heavy))
                        .foregroundColor(SGTheme.mintDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(SGTheme.mintTint))
                }

                ZStack {
                    Circle()
                        .strokeBorder(isPicked ? SGTheme.mint : SGTheme.hairline, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isPicked {
                        Circle().fill(SGTheme.mint).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(SGTheme.micro.weight(.bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(isPicked ? SGTheme.mint.opacity(0.6) : SGTheme.hairline,
                                          lineWidth: isPicked ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
    }
}

// MARK: - planBuilding

/// The final loader (daylight): the plan assembles from THEIR answers.
/// Rocapine rule: the loader must visibly use what they told us.
struct PlanBuildingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var started = false
    @State private var advanced = false
    @State private var pendingAdvance = false
    @State private var pulsing = false
    @State private var statusIndex = 0

    private var statuses: [String] {
        [
            "Locking in your \(viewModel.commitCardCount)-card unlock rule...",
            viewModel.examDateLabel.map { "Mapping your \(viewModel.effectiveDaysToExam) days to \($0)..." }
                ?? "Mapping your next \(viewModel.effectiveDaysToExam) days...",
            "Placing your first milestone...",
            viewModel.firstName.isEmpty ? "Writing your plan..." : "Writing \(viewModel.firstName)'s plan...",
        ]
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 44) {
                ZStack {
                    Circle()
                        .stroke(SGTheme.mint, lineWidth: 1.5)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulsing ? 1.6 : 1)
                        .opacity(pulsing ? 0 : 0.5)

                    MascotView(pose: .clipboard, loops: nil)
                        .frame(width: 110, height: 110)
                        .shadow(color: SGTheme.mint.opacity(0.35), radius: 22)
                }

                ZStack {
                    Text(statuses[statusIndex])
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .id(statusIndex)
                        .transition(.push(from: .bottom))
                }
                .frame(height: 24)
                .animation(.easeInOut(duration: 0.35), value: statusIndex)
            }
        }
        .onAppear { start() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && pendingAdvance {
                pendingAdvance = false
                advance()
            }
        }
    }

    private func start() {
        guard !started else { return }
        started = true

        if UIAccessibility.isReduceMotionEnabled {
            statusIndex = statuses.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { advance() }
            return
        }

        withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
            pulsing = true
        }

        for i in 1..<statuses.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 * Double(i)) {
                statusIndex = i
                SGTheme.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.9) { advance() }
    }

    private func advance() {
        guard !advanced else { return }
        guard scenePhase == .active else {
            pendingAdvance = true
            return
        }
        advanced = true
        viewModel.screenAction("plan_building_complete")
        viewModel.nextStep()
    }
}

// MARK: - planReveal

/// The key conversion screen (daylight): the personalized plan, delivered
/// before the ask. Every row traces back to an answer they gave.
struct PlanRevealView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var shown = false

    private var headline: String {
        let ace = viewModel.examDateLabel.map { "ace \($0)" } ?? "ace this semester"
        return viewModel.firstName.isEmpty
            ? "Here's how you \(ace)."
            : "\(viewModel.firstName), here's how you \(ace)."
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                SGMicroLabel(text: "Your plan is ready")
                Text(headline)
                    .font(SGTheme.stepTitle)
                    .foregroundColor(SGTheme.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 20)
            .fadeRise(shown, delay: 0.1)

            VStack(spacing: 0) {
                planRow(icon: "target", label: "Goal",
                        value: "Walk in ready", index: 0)
                planRow(icon: "iphone.slash", label: "The stakes",
                        value: "Your phone is set to eat \(viewModel.phoneDaysToExam) of your \(viewModel.effectiveDaysToExam) days",
                        index: 1)
                planRow(icon: "rectangle.on.rectangle", label: "Your rule",
                        value: "\(viewModel.commitCardCount) flashcards = \(StudyGuardManager.shared.earnedMinutes(forCardCount: viewModel.commitCardCount)) min of your apps",
                        index: 2)
                planRow(icon: "square.and.arrow.up", label: "Day 1",
                        value: "Upload your study notes", index: 3)
                planRow(icon: "flame", label: "First milestone",
                        value: "A 7-day streak", index: 4)
                planRow(icon: "graduationcap", label: viewModel.examDateLabel.map { "By \($0)" } ?? "By exam season",
                        value: "+\(viewModel.studyHoursToExam) hours of studying reclaimed",
                        index: 5, last: true)
            }
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
            )
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 22)
            .fadeRise(shown, delay: 0.3)

            Spacer()

            OnbCTA(title: "Unlock my plan", visible: shown) {
                viewModel.screenAction("plan_revealed", properties: [
                    "card_count": viewModel.commitCardCount,
                    "days_to_exam": viewModel.daysToExam as Any,
                    "has_name": !viewModel.firstName.isEmpty,
                ])
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear { shown = true }
    }

    private func planRow(icon: String, label: String, value: String,
                         index: Int, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(SGTheme.body.weight(.semibold))
                    .foregroundColor(SGTheme.mintDeep)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(SGTheme.micro.weight(.heavy))
                        .foregroundColor(SGTheme.paperTertiary)
                        .textCase(.uppercase)
                    Text(value)
                        .font(SGTheme.rowLabel)
                        .foregroundColor(SGTheme.paper)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            if !last {
                Divider().overlay(SGTheme.hairline).padding(.leading, 54)
            }
        }
        .fadeRise(shown, delay: 0.4 + Double(index) * 0.12)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("quizName") {
    ZStack {
        NightSkyBackdrop()
        QuizNameView().environmentObject(OnboardingViewModel())
    }
}

#Preview("quizSymptoms") {
    ZStack {
        NightSkyBackdrop()
        QuizSymptomsView().environmentObject(OnboardingViewModel())
    }
}

#Preview("testimonial") {
    ZStack {
        NightSkyBackdrop()
        QuizTestimonialView().environmentObject(OnboardingViewModel())
    }
}

#Preview("realityCheck") {
    ZStack {
        NightSkyBackdrop()
        RealityCheckView().environmentObject(OnboardingViewModel())
    }
}

#Preview("tryIt") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        TryItDemoView().environmentObject(OnboardingViewModel())
    }
}

#Preview("commitment") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        CommitmentView().environmentObject(OnboardingViewModel())
    }
}

#Preview("planReveal") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        PlanRevealView().environmentObject(OnboardingViewModel())
    }
}
#endif
