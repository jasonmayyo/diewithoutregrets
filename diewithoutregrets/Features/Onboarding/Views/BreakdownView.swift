//
//  BreakdownView.swift
//  diewithoutregrets
//
//  Onboarding v3, Phase 2 — the semester receipt: auto-choreographed
//  screens personalized from the quiz answers, every number scaled to the
//  student's 15-week semester. Calculating theater, the 105-day semester
//  drain, the typographic hammer, then the turn: half the drained days heal
//  to study days as dawn breaks into the Meadow.
//

import SwiftUI

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

// MARK: - Semester grid data (shared by SemesterDrainView and TheImagineView)

private enum SemesterGrid {
    struct ObligationGroup {
        let count: Int
        let color: Color
        let caption: String
    }

    static let groups: [ObligationGroup] = [
        .init(count: OnboardingViewModel.sleepDays,
              color: LifeDotsGrid.Palette.sleep,
              caption: "\(OnboardingViewModel.sleepDays) days asleep"),
        .init(count: OnboardingViewModel.classDays,
              color: LifeDotsGrid.Palette.school,
              caption: "\(OnboardingViewModel.classDays) days in class"),
        .init(count: OnboardingViewModel.choresDays,
              color: LifeDotsGrid.Palette.eating,
              caption: "\(OnboardingViewModel.choresDays) days eating, commuting, chores"),
    ]

    /// 68 obligation dots; the remaining 37 are actually theirs.
    static let obligationCount = groups.reduce(0) { $0 + $1.count }

    /// The grid exactly as SemesterDrainView leaves it: obligations filled,
    /// free days mint, the last `phoneDays` free dots drained ember.
    static func drainedColors(phoneDays: Int) -> [Color] {
        var colors: [Color] = []
        for group in groups {
            colors.append(contentsOf: Array(repeating: group.color, count: group.count))
        }
        let free = OnboardingViewModel.freeDays
        let drained = min(phoneDays, free)
        colors.append(contentsOf: Array(repeating: LifeDotsGrid.Palette.free, count: free - drained))
        colors.append(contentsOf: Array(repeating: LifeDotsGrid.Palette.phone, count: drained))
        return colors
    }

    /// Grid width that fits the vertical budget (15 week-rows at 7pt
    /// spacing are ~2.2× taller than wide) without blowing past the screen.
    static func width(in size: CGSize, reservedHeight: CGFloat) -> CGFloat {
        let budget = max(170, size.height - reservedHeight)
        return min(size.width - 56, 330, budget / 2.2)
    }
}

// MARK: - 11. Calculating (night, fully automatic, no CTA)

struct CalculatingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var started = false
    @State private var advanced = false
    @State private var pendingAdvance = false
    @State private var pulsing = false
    @State private var statusIndex = 0

    private let statuses = [
        "Reading your answers...",
        "Mapping your semester...",
        "Counting the days your phone takes...",
        "Preparing your reality check...",
    ]

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

// MARK: - 12. Semester drain (night, auto ~28s, unhurried)

private enum DrainPhase: Int, Comparable {
    case filling, free, drainIntro, drainCount, drainPercent

    static func < (lhs: DrainPhase, rhs: DrainPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// "Your semester in days" — 105 squares, one per day, a week per row.
/// Obligations fill, the free 37 pop mint, then the phone drains its share
/// ember from the bottom-right. Deliberately unhurried: every caption gets
/// long enough on screen to actually be read, and each dot crossfades in
/// softly instead of snapping.
struct SemesterDrainView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var colors = Array(repeating: LifeDotsGrid.Palette.empty,
                                      count: OnboardingViewModel.semesterDays)
    @State private var phase: DrainPhase = .filling
    @State private var obligationCaption = ""
    @State private var showCTA = false

    // Pacing knobs. The whole show reads at these speeds; slow them
    // together, not individually.
    private let fillPerDot = 0.06       // obligation fill
    private let groupHold = 1.5         // pause after each caption's group
    private let freePerDot = 0.06       // mint pop
    private let freeHold = 3.4          // let "actually yours" land
    private let drainPerDot = 0.16      // ember drain
    private let captionFade = 0.55      // caption crossfade duration

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Your semester in days")
                        .font(SGTheme.stepTitle)
                        .foregroundColor(OnbNight.textPrimary)
                    Text("15 weeks. 105 days. Each square is one.")
                        .font(SGTheme.caption)
                        .foregroundColor(OnbNight.textMuted)
                }
                .fadeRise(shown)
                .padding(.top, 16)

                Spacer(minLength: 14)

                LifeDotsGrid(colors: colors)
                    .frame(width: SemesterGrid.width(in: geo.size, reservedHeight: 340))
                    .fadeRise(shown, delay: 0.15)

                Spacer(minLength: 14)

                captionArea
                    .frame(height: 118)

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

    private var captionArea: some View {
        ZStack {
            switch phase {
            case .filling:
                Text(obligationCaption)
                    .font(SGTheme.display(26))
                    .foregroundColor(OnbNight.textPrimary)
                    .id(obligationCaption)
                    .transition(.onbBlurFade)

            case .free:
                VStack(spacing: 4) {
                    Text("\(OnboardingViewModel.freeDays) days")
                        .font(SGTheme.display(44, weight: .heavy))
                        .foregroundColor(SGTheme.mint)
                    Text("left. Actually yours.")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(OnbNight.textSecondary)
                }
                .transition(.onbBlurFade)

            case .drainIntro, .drainCount, .drainPercent:
                VStack(spacing: 4) {
                    Text("This semester, your phone will take")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(OnbNight.textPrimary)

                    if phase >= .drainCount {
                        Text("\(viewModel.phoneDays) of them.")
                            .font(SGTheme.display(44, weight: .heavy))
                            .foregroundColor(SGTheme.ember)
                            .transition(.onbBlurFade)
                    }

                    if phase >= .drainPercent {
                        Text("Whole days, staring at a screen. \(viewModel.phonePctOfFree)% of your free time. Gone.")
                            .font(SGTheme.body)
                            .foregroundColor(OnbNight.textSecondary)
                            .transition(.opacity)
                    }
                }
                .transition(.onbBlurFade)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: captionFade), value: phase)
        .animation(.easeInOut(duration: captionFade), value: obligationCaption)
    }

    private func start() {
        guard !started else { return }
        started = true

        let phoneDays = viewModel.phoneDays
        let phonePercent = viewModel.phonePctOfFree

        if UIAccessibility.isReduceMotionEnabled {
            viewModel.screenAction("obligations_phase_started")
            viewModel.screenAction("free_time_revealed", properties: [
                "free_days": OnboardingViewModel.freeDays,
            ])
            viewModel.screenAction("phone_drain_revealed", properties: [
                "phone_days": phoneDays,
                "phone_percent_of_free": phonePercent,
            ])
            colors = SemesterGrid.drainedColors(phoneDays: phoneDays)
            phase = .drainPercent
            showCTA = true
            return
        }

        // Phase 1: obligations fill in groups, caption swapping per group.
        // Each caption holds long enough to read before the next arrives.
        var t = 0.7
        var startIndex = 0
        after(t) { viewModel.screenAction("obligations_phase_started") }
        for group in SemesterGrid.groups {
            let firstDot = startIndex
            let groupStart = t
            after(groupStart) {
                obligationCaption = group.caption
                SGTheme.tick()
            }
            for i in 0..<group.count {
                after(groupStart + 0.35 + Double(i) * fillPerDot) {
                    colors[firstDot + i] = group.color
                }
            }
            t = groupStart + 0.35 + Double(group.count) * fillPerDot + groupHold
            startIndex += group.count
        }

        // Phase 2: the free 37 pop mint, then breathe.
        let freeStart = t + 0.3
        after(freeStart) {
            viewModel.screenAction("free_time_revealed", properties: [
                "free_days": OnboardingViewModel.freeDays,
            ])
            SGTheme.gain()
            phase = .free
        }
        for i in 0..<OnboardingViewModel.freeDays {
            after(freeStart + 0.3 + Double(i) * freePerDot) {
                colors[SemesterGrid.obligationCount + i] = LifeDotsGrid.Palette.free
            }
        }

        // Phase 3: the phone drains their days, one dot at a time.
        let drainStart = freeStart + 0.3 + Double(OnboardingViewModel.freeDays) * freePerDot + freeHold
        after(drainStart) {
            SGTheme.climax()
            viewModel.screenAction("phone_drain_revealed", properties: [
                "phone_days": phoneDays,
                "phone_percent_of_free": phonePercent,
            ])
            phase = .drainIntro
        }
        for i in 0..<phoneDays {
            after(drainStart + 0.6 + Double(i) * drainPerDot) {
                colors[OnboardingViewModel.semesterDays - 1 - i] = LifeDotsGrid.Palette.phone
                if i % 4 == 0 {
                    SGTheme.tick()
                }
            }
        }

        let drainEnd = drainStart + 0.6 + Double(phoneDays) * drainPerDot
        after(drainEnd + 0.3) { phase = .drainCount }
        after(drainEnd + 1.6) {
            SGTheme.climax()
            phase = .drainPercent
        }
        after(drainEnd + 3.0) { showCTA = true }
    }
}

// MARK: - 13. Days lost (night, auto ~12s, pure typography)

struct DaysLostCycleView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var endingIndex: Int?
    @State private var showCTA = false

    private let endings = [
        "while the exam gets closer either way.",
        "while your grades sit below what you're capable of.",
        "watching other people live their lives.",
        "and next semester, it happens again.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                (Text("\(viewModel.phoneDays) days")
                    .foregroundColor(SGTheme.ember)
                    + Text(" of this semester,\nspent scrolling")
                    .foregroundColor(OnbNight.textPrimary))
                    .font(SGTheme.stepTitle)
                    .fadeRise(shown)

                ZStack {
                    if let index = endingIndex {
                        Text(endings[index])
                            .font(SGTheme.display(22, weight: .semibold))
                            .foregroundColor(OnbNight.textMuted)
                            .id(index)
                            .transition(.onbBlurFade)
                    }
                }
                .frame(height: 84)
                .animation(.easeInOut(duration: 0.9), value: endingIndex)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer()

            OnbCTA(title: "I want those days back", night: true, visible: showCTA) {
                viewModel.screenAction("continue_tapped", properties: [
                    "ending_index": endingIndex ?? 0,
                    "phone_days_shown": viewModel.phoneDays,
                ])
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            shown = true
            start()
        }
    }

    private func start() {
        guard !started else { return }
        started = true

        if UIAccessibility.isReduceMotionEnabled {
            endingIndex = endings.count - 1
            showCTA = true
            return
        }

        for i in 0..<endings.count {
            after(0.8 + 2.8 * Double(i)) {
                endingIndex = i
                if i == endings.count - 1 {
                    SGTheme.climax()
                } else {
                    SGTheme.tick()
                }
            }
        }

        after(0.8 + 2.8 * Double(endings.count - 1) + 1.4) { showCTA = true }
    }
}

// MARK: - 14. The imagine (the turn: dawn breaks, half the days heal)

/// The user's frame, verbatim: "imagine if just half of those were spent
/// studying." The drained grid carries over and half the ember days flip
/// mint one by one as dawn breaks; the study-hours stats land as it heals.
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
        colors.isEmpty ? SemesterGrid.drainedColors(phoneDays: viewModel.phoneDays) : colors
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
                    .frame(width: SemesterGrid.width(in: geo.size, reservedHeight: 420))
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
            Text("+\(viewModel.halfStudyHours) hours of studying this semester.")
                .font(SGTheme.display(22, weight: .heavy))
                .foregroundColor(SGTheme.mintDeep)
                .fadeRise(statBeats >= 1)

            Text("That's more prep than \(viewModel.finalsPrepEquiv) finals need. Without giving up your phone.")
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

        let phoneDays = viewModel.phoneDays
        let reclaimDays = min(viewModel.reclaimDays, phoneDays)
        let firstDrained = OnboardingViewModel.semesterDays - phoneDays
        colors = SemesterGrid.drainedColors(phoneDays: phoneDays)

        if UIAccessibility.isReduceMotionEnabled {
            for i in 0..<reclaimDays {
                colors[firstDrained + i] = LifeDotsGrid.Palette.free
                glowing.insert(firstDrained + i)
            }
            statBeats = 3
            viewModel.screenAction("imagine_animation_complete", properties: [
                "days_reclaimed": reclaimDays,
                "half_study_hours": viewModel.halfStudyHours,
            ])
            showCTA = true
            return
        }

        // Half the ember days flip back one by one, glowing mint.
        for i in 0..<reclaimDays {
            after(1.4 + Double(i) * 0.14) {
                let index = firstDrained + i
                colors[index] = LifeDotsGrid.Palette.free
                glowing.insert(index)

                if i == 0 || i == reclaimDays - 1 {
                    SGTheme.climax()
                } else if i % 3 == 0 {
                    SGTheme.beat()
                }
            }
        }

        // The stats land as the heal settles.
        let healEnd = 1.4 + Double(reclaimDays) * 0.14
        after(healEnd + 0.3) {
            SGTheme.successHaptic()
            statBeats = 1
            viewModel.screenAction("imagine_animation_complete", properties: [
                "days_reclaimed": reclaimDays,
                "half_study_hours": viewModel.halfStudyHours,
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

#Preview("Semester drain") {
    ZStack {
        NightSkyBackdrop()
        SemesterDrainView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("Days lost") {
    ZStack {
        NightSkyBackdrop()
        DaysLostCycleView()
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
