import SwiftUI
import AVFoundation

/// The same bundled demo used by Study Guard's earlier welcome screen.
struct SGV5WelcomeDemoVideo: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SGV5WelcomePlayer(isPlaying: scenePhase == .active && !reduceMotion)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .accessibilityLabel("Study Guard product demo: flashcards unlock your apps")
    }
}

private struct SGV5WelcomePlayer: UIViewRepresentable {
    let isPlaying: Bool
    func makeUIView(context: Context) -> SGV5WelcomePlayerView { SGV5WelcomePlayerView() }
    func updateUIView(_ view: SGV5WelcomePlayerView, context: Context) {
        isPlaying ? view.player?.play() : view.player?.pause()
    }
    static func dismantleUIView(_ view: SGV5WelcomePlayerView, coordinator: ()) {
        view.player?.pause()
        view.player?.removeAllItems()
    }
}

private final class SGV5WelcomePlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    override init(frame: CGRect) {
        super.init(frame: frame)
        guard let url = Bundle.main.url(forResource: "mockupvideo", withExtension: "mp4") else { return }
        let queue = AVQueuePlayer()
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        player = queue
        let videoLayer = layer as! AVPlayerLayer
        videoLayer.player = queue
        videoLayer.videoGravity = .resizeAspect
        backgroundColor = UIColor(SGTheme.ink)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

struct SGV5StudyLevelView: View {
    @ObservedObject var viewModel: SGV5FlowModel

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.goal.progress,
                               onBack: { viewModel.previousPage() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SGV5QuizGhostSpeechBubble(question: "What are you studying for?")
                    Text("YOUR STUDY LEVEL")
                        .font(.caption.weight(.semibold)).tracking(1.2)
                        .foregroundStyle(SGTheme.paperSecondary)
                    VStack(spacing: 10) {
                        ForEach(SGV5V5OnboardingProfile.StudyLevel.allCases) { level in
                            Button {
                                viewModel.v5Profile.studyLevel = level
                                SGTheme.beat()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: level.symbol).frame(width: 24)
                                        .foregroundStyle(SGTheme.mintDeep)
                                    Text(level.title).font(.system(size: 16, weight: .semibold))
                                    Spacer(minLength: 0)
                                    if viewModel.v5Profile.studyLevel == level {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(SGTheme.mintDeep)
                                    }
                                }
                                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                .background(SGTheme.inkRaised, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(viewModel.v5Profile.studyLevel == level ? SGTheme.mintDeep : SGTheme.hairline,
                                            lineWidth: viewModel.v5Profile.studyLevel == level ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(viewModel.v5Profile.studyLevel == level ? .isSelected : [])
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 22)
            }
            SGV5QuizContinueButton(isEnabled: viewModel.v5Profile.canContinue(from: .goal)) {
                viewModel.trackUserInput(screenId: 803, inputType: "study_level",
                                        value: viewModel.v5Profile.studyLevel?.rawValue ?? "")
                viewModel.advanceV5()
            }
            .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper).tint(SGTheme.mintDeep)
    }
}

struct SGV5ExamSubjectView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @FocusState private var subjectFocused: Bool
    private var subject: Binding<String> {
        Binding(get: { viewModel.v5Profile.subject ?? "" },
                set: { viewModel.v5Profile.subject = String($0.prefix(80)) })
    }

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.subject.progress,
                               onBack: { viewModel.previousPage() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SGV5QuizGhostSpeechBubble(question: "Which subject is your next exam for?")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("EXAM SUBJECT")
                            .font(.caption.weight(.semibold)).tracking(1.2)
                            .foregroundStyle(SGTheme.paperSecondary)
                        TextField("e.g. Biology", text: subject)
                            .font(.system(size: 18)).textInputAutocapitalization(.words)
                            .submitLabel(.continue).focused($subjectFocused)
                            .onSubmit { if viewModel.v5Profile.canContinue(from: .subject) { advance() } }
                            .padding(17)
                            .background(SGTheme.inkRaised, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(subjectFocused ? SGTheme.mintDeep : SGTheme.hairline))
                            .accessibilityLabel("Which subject is your next exam for?")
                            .accessibilityIdentifier("onboarding.study.subject")
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 22)
            }
            .scrollDismissesKeyboard(.interactively)
            SGV5QuizContinueButton(isEnabled: viewModel.v5Profile.canContinue(from: .subject), action: advance)
                .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper).tint(SGTheme.mintDeep)
    }

    private func advance() {
        subjectFocused = false
        viewModel.v5Profile.subject = viewModel.v5Profile.studySubject
        viewModel.advanceV5()
    }
}

struct SGV5ExamDateView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @State private var pickedDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.habit.progress,
                               onBack: { viewModel.previousPage() }) {
            ScrollView {
                VStack(spacing: 18) {
                    SGV5QuizGhostSpeechBubble(question: "When is your next exam?")
                    Text("Your \(viewModel.v5Profile.subjectLabel) exam")
                        .font(.system(size: 18, weight: .semibold))
                    DatePicker("Exam date", selection: $pickedDate, in: today..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(SGTheme.mintDeep)
                        .padding(8)
                        .background(SGTheme.inkRaised, in: RoundedRectangle(cornerRadius: 24))
                        .accessibilityIdentifier("onboarding.exam.date")
                    Text("We'll show you how much time your phone could take between now and then.")
                        .font(.subheadline).foregroundStyle(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24).padding(.vertical, 22)
            }
            SGV5QuizContinueButton(text: "Set my exam date") {
                viewModel.v5Profile.examDate = Calendar.current.startOfDay(for: pickedDate)
                viewModel.trackUserInput(screenId: 807, inputType: "days_to_exam",
                                        value: String(viewModel.v5Profile.examDays))
                viewModel.advanceV5()
            }
            .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper)
        .onAppear { pickedDate = max(today, viewModel.v5Profile.examDate ?? pickedDate) }
    }
}

/// OneThing's dot-grid reveal, using the actual days until this exam.
struct SGV5ExamCostView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var dotsShown = false
    @State private var revealedDays = 0.0
    @State private var typedText = ""

    private var profile: SGV5V5OnboardingProfile { viewModel.v5Profile }
    private var phoneDays: Double { Double(profile.phoneHoursBeforeExam) / 24 }
    private var daysLabel: String { phoneDays.formatted(.number.precision(.fractionLength(0...3))) }
    private var animating: Bool { scenePhase == .active && !reduceMotion }
    private let endings = [
        "Just scrolling on your phone.",
        "Not doing the work you're meant to be doing.",
        "Not going over that one section you never understood.",
        "Not doing that past paper you should have done.",
        "Just… scrolling."
    ]

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.lifeCost.progress,
                               onBack: { viewModel.previousPage() }) {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        VStack(spacing: 6) {
                            Text(profile.examDays == 0 ? "Your exam is today." : "\(profile.examDays) \(profile.examDays == 1 ? "day" : "days") until your exam.")
                                .font(.system(size: 22, weight: .bold))
                                .accessibilityAddTraits(.isHeader)
                            Text(profile.examDays == 0 ? "No full days left. Make today count." : "Each dot is one day.")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(SGTheme.paperSecondary)
                            if profile.examDays > 0 {
                                HStack(spacing: 18) {
                                    legend(SGTheme.paper.opacity(0.16), "Time ahead")
                                    legend(SGTheme.emberDeep, "On your phone")
                                }.padding(.top, 4)
                            }
                        }
                        .multilineTextAlignment(.center).padding(.top, 16)

                        if profile.examDays > 0 {
                            SGV5ExamDayGrid(days: profile.examDays, filledDays: revealedDays)
                                .opacity(dotsShown ? 1 : 0).scaleEffect(dotsShown ? 1 : 0.95)
                                .frame(height: max(120, min(310, geometry.size.height - 480)))
                                .padding(.vertical, 18)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(profile.examDays) days until your exam. At \(profile.estimatedDailyHours) hours a day, scrolling takes the equivalent of \(daysLabel) full days. Partially filled dots show part of a day.")
                            VStack(spacing: 4) {
                                Text("At your current pace,")
                                    .font(.system(size: 15)).foregroundStyle(SGTheme.paperSecondary)
                                (Text("\(daysLabel) \(phoneDays == 1 ? "day" : "days")").bold().foregroundColor(SGTheme.emberDeep)
                                 + Text(" will go to your phone."))
                                    .font(.system(size: 17))
                            }
                            .multilineTextAlignment(.center)
                            Spacer(minLength: 24)
                            VStack(spacing: 10) {
                                Text("That's \(profile.phoneHoursBeforeExam) \(profile.phoneHoursBeforeExam == 1 ? "hour" : "hours").")
                                    .font(.system(size: 38, weight: .heavy))
                                    .minimumScaleFactor(0.7).lineLimit(1)
                                Text(typedText.isEmpty ? " " : typedText)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(SGTheme.emberDeep)
                                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
                                    .accessibilityHidden(true)
                            }
                            .multilineTextAlignment(.center)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("That's \(profile.phoneHoursBeforeExam) hours just scrolling on your phone.")
                            Spacer(minLength: 8)
                            Text("Based on your estimate of \(profile.estimatedDailyHours) hours a day.")
                                .font(.system(size: 11)).foregroundStyle(SGTheme.paperSecondary)
                                .multilineTextAlignment(.center).padding(.bottom, 16)
                        } else {
                            Spacer(minLength: 28)
                            Image("sgv5-mascot-teaching").resizable().scaledToFit()
                                .frame(height: 220).blendMode(.multiply).accessibilityHidden(true)
                            Text("Make time for one more review.")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center).padding(.vertical, 24)
                            Spacer(minLength: 28)
                        }
                    }
                    .padding(.horizontal, 28)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
            SGV5QuizContinueButton(text: "I want that time to study") { viewModel.advanceV5() }
                .accessibilityIdentifier("onboarding.examCost.continue")
                .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper)
        .task(id: animating) { await runSequence() }
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(SGTheme.paperSecondary)
        }
    }

    @MainActor private func runSequence() async {
        guard profile.examDays > 0 else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sg-v5-exam-dots") {
            dotsShown = true; revealedDays = phoneDays; typedText = endings[0]
            return
        }
        #endif
        guard animating else {
            dotsShown = true; revealedDays = phoneDays; typedText = endings[0]
            return
        }
        do {
            revealedDays = 0; typedText = ""
            withAnimation(.easeOut(duration: 0.35)) { dotsShown = true }
            try await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeInOut(duration: 1.0)) { revealedDays = phoneDays }
            try await Task.sleep(for: .seconds(1.05))
            for ending in endings {
                typedText = ""
                for character in ending {
                    try Task.checkCancellation()
                    typedText.append(character)
                    try await Task.sleep(for: .milliseconds(32))
                }
                try await Task.sleep(for: .seconds(1.5))
            }
        } catch { /* Navigation and inactive scenes cancel the sequence. */ }
    }
}

/// One rounded dot per calendar day. A partial dot preserves fractional days
/// rather than rounding a few hours up to a whole lost day.
private struct SGV5ExamDayGrid: View, Animatable {
    let days: Int
    var filledDays: Double
    var animatableData: Double {
        get { filledDays }
        set { filledDays = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard days > 0 else { return }
            // Keep OneThing's eight-column rhythm for short horizons, then fit
            // the entire exam horizon into the same space for longer dates.
            let columns = min(days, max(8, Int(ceil(sqrt(Double(days) * size.width / max(1, size.height))))))
            let rows = (days + columns - 1) / columns
            let cell = min((size.width + 7) / CGFloat(columns), (size.height + 7) / CGFloat(rows), 41)
            let gap = min(7, cell * 0.18)
            let side = max(1, cell - gap)
            let startX = (size.width - CGFloat(columns) * cell + gap) / 2
            let startY = (size.height - CGFloat(rows) * cell + gap) / 2
            for index in 0..<days {
                let rect = CGRect(x: startX + CGFloat(index % columns) * cell,
                                  y: startY + CGFloat(index / columns) * cell,
                                  width: side, height: side)
                let path = Path(roundedRect: rect, cornerRadius: min(7, side * 0.2))
                context.fill(path, with: .color(SGTheme.paper.opacity(0.16)))
                let fraction = min(1, max(0, filledDays - Double(index)))
                if fraction > 0 {
                    var fill = context
                    fill.clip(to: path)
                    fill.fill(Path(CGRect(x: rect.minX, y: rect.minY,
                                          width: rect.width * fraction, height: rect.height)),
                              with: .color(SGTheme.emberDeep))
                }
            }
        }
    }
}

/// An automatic, local illustration of notes becoming cards. Continue never
/// waits for the animation; no material is uploaded and no real deck is created.
struct SGV5FlashcardGenerationDemo: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase = 0
    @State private var scanProgress: CGFloat = 0
    @State private var answerShown = false

    private var animating: Bool { scenePhase == .active && !reduceMotion }
    private var cardsReady: Bool { phase == 2 }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                let scale = min(geometry.size.width / 350, geometry.size.height / 460, 1.12)
                illustration
                    .frame(width: 350, height: 460)
                    .scaleEffect(scale)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .padding(.horizontal, 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Biology notes are scanned and turned into flashcards automatically. Example: the nucleus stores DNA and controls the cell.")

            VStack(spacing: 10) {
                Text("Your notes.\nInstant flashcards.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                Text("Less prep. More studying.")
                    .font(.system(size: 16)).foregroundStyle(SGTheme.paperSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24).padding(.bottom, 12)

            SGV5QuizContinueButton { viewModel.advanceV5() }
                .accessibilityIdentifier("onboarding.generation.continue")
                .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper)
        .task(id: animating) { await playDemo() }
    }

    private var illustration: some View {
        ZStack {
            Circle().fill(SGTheme.mint.opacity(0.07))
                .frame(width: 322, height: 322).position(x: 175, y: 234)
            Circle().stroke(SGTheme.mint.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 7]))
                .frame(width: 290, height: 290).position(x: 175, y: 234)

            sourceIcon("doc.text.fill", rotation: -14).position(x: 51, y: 100)
            sourceIcon("play.rectangle.fill", rotation: 12).position(x: 299, y: 121)
            notes.position(x: 175, y: 98)

            ForEach(0..<3) { i in
                Circle().fill(SGTheme.mint.opacity(phase == 1 ? 0.9 : 0.22))
                    .frame(width: 5, height: 5)
                    .offset(y: phase == 1 ? 20 : 0)
                    .position(x: 175, y: CGFloat(197 + i * 15))
            }
            ZStack {
                Circle().fill(SGTheme.mintTint).frame(width: 54, height: 54)
                Circle().stroke(SGTheme.mint.opacity(0.28), lineWidth: 1)
                    .frame(width: phase == 1 ? 70 : 58, height: phase == 1 ? 70 : 58)
                Image(systemName: cardsReady ? "checkmark" : "sparkles")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(SGTheme.mintDeep)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(phase == 1 ? 1.12 : 1)
            .position(x: 175, y: 252)

            Image("sgv5-mascot-teaching").resizable().scaledToFit()
                .frame(width: 117, height: 117).blendMode(.multiply)
                .rotationEffect(.degrees(phase == 1 ? -6 : 0))
                .offset(y: phase == 1 ? -6 : 0)
                .position(x: 286, y: 243)

            Image(systemName: "sparkle").font(.system(size: 18)).foregroundStyle(SGTheme.mintDeep)
                .scaleEffect(cardsReady ? 1 : 0.6).opacity(cardsReady ? 1 : 0.3)
                .position(x: 43, y: 303)
            Image(systemName: "sparkle").font(.system(size: 12)).foregroundStyle(SGTheme.mintDeep)
                .scaleEffect(cardsReady ? 1 : 0.6).opacity(cardsReady ? 1 : 0.3)
                .position(x: 312, y: 410)
            cardStack.position(x: 175, y: 367)
        }
        .allowsHitTesting(false)
    }

    private func sourceIcon(_ symbol: String, rotation: Double) -> some View {
        Image(systemName: symbol).font(.system(size: 22, weight: .medium))
            .foregroundStyle(SGTheme.mintDeep.opacity(0.7))
            .frame(width: 47, height: 53)
            .background(SGTheme.inkRaised, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(SGTheme.hairline))
            .rotationEffect(.degrees(rotation))
            .offset(y: phase == 1 ? -5 : 0)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "doc.text.fill").foregroundStyle(SGTheme.mintDeep)
                Text("Biology.pdf").font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 5)
            ForEach(0..<5) { i in
                Capsule().fill(i == 1 || i == 3 ? SGTheme.mint.opacity(0.35) : SGTheme.paper.opacity(0.10))
                    .frame(width: [120.0, 102, 128, 89, 111][i], height: 5)
            }
        }
        .padding(21).frame(width: 178, height: 170)
        .background(SGTheme.ink, in: RoundedRectangle(cornerRadius: 19))
        .overlay(alignment: .top) {
            if !cardsReady {
                Rectangle().fill(SGTheme.mint.opacity(0.12))
                    .frame(height: 30)
                    .overlay(alignment: .bottom) { Rectangle().fill(SGTheme.mint).frame(height: 2) }
                    .offset(y: 38 + scanProgress * 104)
                    .padding(.horizontal, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(SGTheme.hairline))
        .shadow(color: SGTheme.paper.opacity(0.06), radius: 16, x: 0, y: 8)
        .rotationEffect(.degrees(cardsReady ? -5 : -3))
    }

    private var cardStack: some View {
        ZStack {
            ForEach(0..<2) { i in
                RoundedRectangle(cornerRadius: 22)
                    .fill(i == 0 ? SGTheme.mint.opacity(0.13) : SGTheme.mintTint)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(SGTheme.mint.opacity(0.25)))
                    .frame(width: 244, height: 144)
                    .rotationEffect(.degrees(cardsReady ? (i == 0 ? -9 : 7) : 0))
                    .offset(x: cardsReady ? (i == 0 ? -4 : 5) : 0, y: cardsReady ? (i == 0 ? 8 : 3) : 10)
            }
            ZStack {
                cardFace(answer: false).opacity(answerShown ? 0 : 1)
                cardFace(answer: true).opacity(answerShown ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(answerShown ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(cardsReady ? 1 : 0.86)
            .offset(y: cardsReady ? 0 : -8)
            .opacity(cardsReady ? 1 : 0)
            if !cardsReady {
                Image(systemName: "rectangle.stack").font(.system(size: 32, weight: .light))
                    .foregroundStyle(SGTheme.mintDeep.opacity(0.35))
            }
        }
    }

    private func cardFace(answer: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(answer ? "ANSWER" : "BIOLOGY").tracking(1.3)
                Spacer()
                Image(systemName: answer ? "checkmark.circle.fill" : "sparkles")
            }
            .font(.system(size: 10, weight: .bold)).foregroundStyle(SGTheme.mintDeep)
            Text(answer ? "Stores DNA.\nControls the cell." : "What does the\nnucleus do?")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(23).frame(width: 250, height: 150, alignment: .leading)
        .background(answer ? SGTheme.mintTint : SGTheme.ink, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(SGTheme.mint.opacity(0.4)))
        .shadow(color: SGTheme.mintDeep.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    @MainActor private func playDemo() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sg-v5-scanning") {
            phase = 0; scanProgress = 0.55; answerShown = false
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-sg-v5-generated") {
            phase = 2; answerShown = false
            return
        }
        #endif
        guard animating else { phase = 2; answerShown = false; return }
        do {
            while !Task.isCancelled {
                phase = 0; scanProgress = 0; answerShown = false
                withAnimation(.easeInOut(duration: 1.3)) { scanProgress = 1 }
                try await Task.sleep(for: .seconds(1.35))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = 1 }
                try await Task.sleep(for: .seconds(0.55))
                withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) { phase = 2 }
                try await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeInOut(duration: 0.65)) { answerShown = true }
                try await Task.sleep(for: .seconds(2.6))
                withAnimation(.easeOut(duration: 0.3)) { phase = 0 }
                try await Task.sleep(for: .seconds(0.35))
            }
        } catch { /* SwiftUI cancels on navigation or when the scene becomes inactive. */ }
    }
}
