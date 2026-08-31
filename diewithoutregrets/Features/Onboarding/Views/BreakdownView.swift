//
//  BreakdownView.swift
//  diewithoutregrets
//
//  Onboarding v4, Phase 2 — the diagnosis: auto-choreographed screens
//  personalized from the quiz answers, every number scaled to THEIR exam
//  countdown. Calculating theater, the exam verdict (the dependency-score
//  peak, with the real-usage report row when Screen Time was authorized at
//  the reality check), then the turn: half the drained days heal to study
//  days as dawn breaks into the Meadow.
//

import SwiftUI
import DeviceActivity

// MARK: - Shared choreography helpers

/// Timeline beat: run an action after a delay on the main queue.
private func after(_ delay: Double, _ action: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
}

/// Blur 6 -> 0 plus fade, the reveal used by the typographic endings.
private struct BlurFadeModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity)
    }
}

private extension AnyTransition {
    static var onbBlurFade: AnyTransition {
        .modifier(
            active: BlurFadeModifier(blur: 6, opacity: 0),
            identity: BlurFadeModifier(blur: 0, opacity: 1)
        )
    }
}

// MARK: - Countdown grid data (shared by ExamVerdictView and TheImagineView)

/// One square per day until the exam. Long countdowns cap the grid at 105
/// squares (15 rows) and scale the drained share proportionally so the
/// visual ratio stays honest.
enum CountdownGrid {
    static let maxDots = 105

    static func dayCount(_ vm: OnboardingViewModel) -> Int {
        min(vm.effectiveDaysToExam, maxDots)
    }

    /// The phone's share of the (possibly capped) grid, at least 1 dot.
    static func drainedCount(_ vm: OnboardingViewModel) -> Int {
        let dots = dayCount(vm)
        let scaled = Double(vm.phoneDaysToExam) * Double(dots) / Double(vm.effectiveDaysToExam)
        return min(max(1, Int(scaled.rounded())), dots)
    }

    /// The grid exactly as ExamVerdictView leaves it: countdown mint, the
    /// last `drained` dots ember.
    static func drainedColors(_ vm: OnboardingViewModel) -> [Color] {
        let dots = dayCount(vm)
        let drained = drainedCount(vm)
        return Array(repeating: LifeDotsGrid.Palette.free, count: dots - drained)
            + Array(repeating: LifeDotsGrid.Palette.phone, count: drained)
    }

    /// Grid width that fits the vertical budget for however many week-rows
    /// this countdown needs, without blowing past the screen.
    static func width(_ vm: OnboardingViewModel, in size: CGSize, reservedHeight: CGFloat) -> CGFloat {
        let rows = max(1, Int((Double(dayCount(vm)) / 7.0).rounded(.up)))
        let budget = max(170, size.height - reservedHeight)
        return min(size.width - 56, 330, budget * 7 / CGFloat(rows))
    }
}

// MARK: - Calculating (night, fully automatic, no CTA)

struct CalculatingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var started = false
    @State private var advanced = false
    @State private var pendingAdvance = false
    @State private var pulsing = false
    @State private var statusIndex = 0

    /// Rocapine rule: the loader must visibly use the answers given.
    private var statuses: [String] {
        [
            "Reading your answers...",
            viewModel.examDateLabel.map { "Counting the days to \($0)..." }
                ?? "Mapping your deadline season...",
            viewModel.authorizedInQuiz
                ? "Reading your real screen time..."
                : "Measuring what your phone takes...",
            "Preparing your verdict...",
        ]
    }

    var body: some View {
        ZStack {
            Color.clear

            VStack(spacing: 44) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
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
                        .foregroundColor(OnbNight.textSecondary)
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
            after(1.2) { advance() }
            return
        }

        withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
            pulsing = true
        }

        for i in 1..<statuses.count {
            after(0.9 * Double(i)) {
                statusIndex = i
                SGTheme.tick()
            }
        }

        after(3.9) { advance() }
    }

    private func advance() {
        guard !advanced else { return }
        guard scenePhase == .active else {
            pendingAdvance = true
            return
        }
        advanced = true
        viewModel.screenAction("calculating_complete")
        viewModel.nextStep()
    }
}

// MARK: - Exam verdict (night, the dependency-score peak)

private enum VerdictPhase: Int, Comparable {
    case filling, counted, drainIntro, drainCount, drainKicker

    static func < (lhs: VerdictPhase, rhs: VerdictPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The diagnosis: one square per day until THEIR exam, then the phone eats
/// its share, ember, from the bottom. When Screen Time was authorized at
/// the reality check, a report row renders their REAL average underneath —
/// computed inside the report sandbox, never readable by the app.
struct ExamVerdictView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var colors: [Color] = []
    @State private var phase: VerdictPhase = .filling
    @State private var showCTA = false

    private var headerLine: String {
        viewModel.hasExams ? "days until your exam" : "days of deadline season"
    }

    private var kickerLine: String {
        switch viewModel.preparedness {
        case "Way behind", "A bit behind":
            return "Whole days, staring at a screen. And you said you're already behind."
        default:
            return "Whole days, staring at a screen. \(viewModel.phonePctOfCountdown)% of your countdown. Gone."
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("\(viewModel.effectiveDaysToExam) \(headerLine)")
                        .font(SGTheme.stepTitle)
                        .foregroundColor(OnbNight.textPrimary)
                    Text("Each square is one of them.")
                        .font(SGTheme.caption)
                        .foregroundColor(OnbNight.textMuted)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fadeRise(shown)
                .padding(.top, 16)

                Spacer(minLength: 14)

                LifeDotsGrid(colors: displayColors)
                    .frame(width: CountdownGrid.width(viewModel, in: geo.size,
                                                     reservedHeight: viewModel.authorizedInQuiz ? 400 : 340))
                    .fadeRise(shown, delay: 0.15)

                Spacer(minLength: 14)

                captionArea
                    .frame(height: 124)

                if viewModel.authorizedInQuiz {
                    // The real number, rendered by the report extension.
                    // Renders nothing until iOS hands the data over (and
                    // never in the Simulator) — the row just stays blank.
                    DeviceActivityReport(
                        DeviceActivityReport.Context("onboardingDiagnosis"),
                        filter: realUsageFilter
                    )
                    .frame(height: 56)
                    .padding(.horizontal, SGTheme.screenPadding)
                    .opacity(phase >= .drainCount ? 1 : 0)
                    .animation(.easeIn(duration: 0.6), value: phase >= .drainCount)
                }

                Spacer(minLength: 8)

                OnbCTA(title: "This has to change", night: true, visible: showCTA) {
                    viewModel.nextStep()
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            shown = true
            start()
        }
    }

    /// The grid renders on the very first frame, before onAppear seeds it.
    private var displayColors: [Color] {
        colors.isEmpty
            ? Array(repeating: LifeDotsGrid.Palette.empty, count: CountdownGrid.dayCount(viewModel))
            : colors
    }

    /// Last 7 full days of usage, all apps: enough for a trustworthy daily
    /// average without waiting on a long query.
    private var realUsageFilter: DeviceActivityFilter {
        let now = Date()
        let start = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        )
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: now)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private var captionArea: some View {
        ZStack {
            switch phase {
            case .filling, .counted:
                VStack(spacing: 4) {
                    Text("\(viewModel.effectiveDaysToExam) days")
                        .font(SGTheme.display(44, weight: .heavy))
                        .foregroundColor(SGTheme.mint)
                    Text("That's all you've got.")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(OnbNight.textSecondary)
                }
                .opacity(phase >= .counted ? 1 : 0)
                .transition(.onbBlurFade)

            case .drainIntro, .drainCount, .drainKicker:
                VStack(spacing: 4) {
                    Text("Your phone is set to eat")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(OnbNight.textPrimary)

                    if phase >= .drainCount {
                        Text("\(viewModel.phoneDaysToExam) of them.")
                            .font(SGTheme.display(44, weight: .heavy))
                            .foregroundColor(SGTheme.ember)
                            .transition(.onbBlurFade)
                    }

                    if phase >= .drainKicker {
                        Text(kickerLine)
                            .font(SGTheme.body)
                            .foregroundColor(OnbNight.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .transition(.onbBlurFade)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.55), value: phase)
    }

    private func start() {
        guard !started else { return }
        started = true

        let dots = CountdownGrid.dayCount(viewModel)
        let drained = CountdownGrid.drainedCount(viewModel)
        colors = Array(repeating: LifeDotsGrid.Palette.empty, count: dots)

        if UIAccessibility.isReduceMotionEnabled {
            colors = CountdownGrid.drainedColors(viewModel)
            phase = .drainKicker
            emitVerdictAnalytics()
            showCTA = true
            return
        }

        // Phase 1: the countdown fills mint, fast — these days are theirs.
        for i in 0..<dots {
            after(0.7 + Double(i) * 0.03) {
                colors[i] = LifeDotsGrid.Palette.free
            }
        }
        let filled = 0.7 + Double(dots) * 0.03
        after(filled + 0.2) {
            SGTheme.gain()
            phase = .counted
        }

        // Phase 2: the phone eats its share, one day at a time.
        let drainStart = filled + 2.6
        after(drainStart) {
            SGTheme.climax()
            phase = .drainIntro
        }
        for i in 0..<drained {
            after(drainStart + 0.6 + Double(i) * 0.14) {
                colors[dots - 1 - i] = LifeDotsGrid.Palette.phone
                if i % 4 == 0 {
                    SGTheme.tick()
                }
            }
        }

        let drainEnd = drainStart + 0.6 + Double(drained) * 0.14
        after(drainEnd + 0.3) { phase = .drainCount }
        after(drainEnd + 1.6) {
            SGTheme.climax()
            phase = .drainKicker
            emitVerdictAnalytics()
        }
        after(drainEnd + 3.0) { showCTA = true }
    }

    private func emitVerdictAnalytics() {
        viewModel.screenAction("exam_verdict_revealed", properties: [
            "days_to_exam": viewModel.effectiveDaysToExam,
            "phone_days": viewModel.phoneDaysToExam,
            "phone_percent": viewModel.phonePctOfCountdown,
            "real_usage_row": viewModel.authorizedInQuiz,
        ])
    }
}

// MARK: - The imagine (the turn: dawn breaks, half the days heal)

/// The user's frame, verbatim: "imagine if just half of those were spent
/// studying." The verdict's drained grid carries over and half the ember
/// days flip mint one by one as dawn breaks; the study-hours stats land as
/// it heals.
struct TheImagineView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var colors: [Color] = []
    @State private var glowing: Set<Int> = []
    @State private var statBeats = 0
    @State private var showCTA = false

    /// The grid renders its drained state on the very first frame, before
    /// onAppear has seeded the state array.
    private var displayColors: [Color] {
        colors.isEmpty ? CountdownGrid.drainedColors(viewModel) : colors
    }

    private var finalsPrepEquiv: Int {
        max(1, Int((Double(viewModel.studyHoursToExam) / 40).rounded()))
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                (Text("Imagine if just ")
                    .foregroundColor(SGTheme.paper)
                    + Text("half")
                    .foregroundColor(SGTheme.mintDeep)
                    + Text(" of those days went to studying.")
                    .foregroundColor(SGTheme.paper))
                    .font(SGTheme.stepTitle)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    // The container's night backdrop takes ~1.2s to fade to
                    // dawn; the dark-ink title waits so it lands with it.
                    .fadeRise(shown, delay: 1.0)

                Spacer(minLength: 16)

                LifeDotsGrid(colors: displayColors, glowing: glowing)
                    .frame(width: CountdownGrid.width(viewModel, in: geo.size, reservedHeight: 420))
                    .fadeRise(shown, delay: 0.15)

                Spacer(minLength: 16)

                statsArea
                    .frame(height: 130)

                Spacer(minLength: 10)

                OnbCTA(title: "Let's do this", visible: showCTA) {
                    viewModel.nextStep()
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            shown = true
            start()
        }
    }

    private var statsArea: some View {
        VStack(spacing: 8) {
            Text(viewModel.examDateLabel.map { "+\(viewModel.studyHoursToExam) hours of studying before \($0)." }
                ?? "+\(viewModel.studyHoursToExam) hours of studying reclaimed.")
                .font(SGTheme.display(22, weight: .heavy))
                .foregroundColor(SGTheme.mintDeep)
                .fadeRise(statBeats >= 1)

            Text("That's more prep than \(finalsPrepEquiv) finals need. Without giving up your phone.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .fadeRise(statBeats >= 2)

            Text("Study Guard makes it automatic.\nScroll time in, study time out.")
                .font(SGTheme.rowLabel)
                .foregroundColor(SGTheme.mintDeep)
                .fadeRise(statBeats >= 3)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 30)
    }

    private func start() {
        guard !started else { return }
        started = true

        let dots = CountdownGrid.dayCount(viewModel)
        let drained = CountdownGrid.drainedCount(viewModel)
        let reclaim = max(1, drained / 2)
        let firstDrained = dots - drained
        colors = CountdownGrid.drainedColors(viewModel)

        if UIAccessibility.isReduceMotionEnabled {
            for i in 0..<reclaim {
                colors[firstDrained + i] = LifeDotsGrid.Palette.free
                glowing.insert(firstDrained + i)
            }
            statBeats = 3
            viewModel.screenAction("imagine_animation_complete", properties: [
                "days_reclaimed": viewModel.reclaimDaysToExam,
                "study_hours_to_exam": viewModel.studyHoursToExam,
            ])
            showCTA = true
            return
        }

        // Half the ember days flip back one by one, glowing mint.
        for i in 0..<reclaim {
            after(1.4 + Double(i) * 0.14) {
                let index = firstDrained + i
                colors[index] = LifeDotsGrid.Palette.free
                glowing.insert(index)

                if i == 0 || i == reclaim - 1 {
                    SGTheme.climax()
                } else if i % 3 == 0 {
                    SGTheme.beat()
                }
            }
        }

        // The stats land as the heal settles.
        let healEnd = 1.4 + Double(reclaim) * 0.14
        after(healEnd + 0.3) {
            SGTheme.successHaptic()
            statBeats = 1
            viewModel.screenAction("imagine_animation_complete", properties: [
                "days_reclaimed": viewModel.reclaimDaysToExam,
                "study_hours_to_exam": viewModel.studyHoursToExam,
            ])
        }
        after(healEnd + 1.2) { statBeats = 2 }
        after(healEnd + 2.1) { statBeats = 3 }
        after(healEnd + 2.7) { showCTA = true }
    }
}

// MARK: - Previews

#Preview("Calculating") {
    ZStack {
        NightSkyBackdrop()
        CalculatingView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("Exam verdict") {
    ZStack {
        NightSkyBackdrop()
        ExamVerdictView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("The imagine") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        TheImagineView()
    }
    .environmentObject(OnboardingViewModel())
}
