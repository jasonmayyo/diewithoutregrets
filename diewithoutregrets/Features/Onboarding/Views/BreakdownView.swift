//
//  BreakdownView.swift
//  diewithoutregrets
//
//  Onboarding v2, Phase 2. The reality check: six auto-choreographed screens
//  personalized from the quiz answers. Calculating theater, the 80-dot life
//  drain, the semester chart, the typographic hammer, then the turn: the
//  grid heals and the chart flips as dawn breaks into the daylight Meadow.
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

// MARK: - Life grid data (shared by LifeDrainView and ReclaimView)

private enum LifeGrid {
    struct ObligationGroup {
        let count: Int
        let color: Color
        let caption: String
    }

    static let groups: [ObligationGroup] = [
        .init(count: 27, color: LifeDotsGrid.Palette.sleep, caption: "27 years sleeping"),
        .init(count: 18, color: LifeDotsGrid.Palette.school, caption: "18 years working"),
        .init(count: 7, color: LifeDotsGrid.Palette.commute, caption: "7 years commuting"),
        .init(count: 5, color: LifeDotsGrid.Palette.eating, caption: "5 years cooking and eating"),
        .init(count: 3, color: LifeDotsGrid.Palette.chores, caption: "3 years doing chores"),
    ]

    /// 60 obligation dots; the remaining 20 are free time.
    static let obligationCount = groups.reduce(0) { $0 + $1.count }

    /// The grid exactly as LifeDrainView leaves it: obligations filled, free
    /// time mint, the last `phoneYears` free dots drained ember.
    static func drainedColors(phoneYears: Int) -> [Color] {
        var colors: [Color] = []
        for group in groups {
            colors.append(contentsOf: Array(repeating: group.color, count: group.count))
        }
        let free = OnboardingViewModel.freeYears
        let drained = min(phoneYears, free)
        colors.append(contentsOf: Array(repeating: LifeDotsGrid.Palette.free, count: free - drained))
        colors.append(contentsOf: Array(repeating: LifeDotsGrid.Palette.phone, count: drained))
        return colors
    }

    /// Grid width that fits the vertical budget (10 rows at 7pt spacing have
    /// a fixed height/width ratio) without blowing past the screen width.
    static func width(in size: CGSize, reservedHeight: CGFloat) -> CGFloat {
        let budget = max(150, size.height - reservedHeight)
        return min(size.width - 56, 330, budget / 1.26)
    }
}

// MARK: - Chart data (shared by StudyVsScrollChartView and AfterChartView)

private enum RealityCurves {
    /// Normalized x in [0,1]; y is hours pressure where 1.0 = the chart top
    /// once the phone line has forced the rescale.
    static let study: [CGPoint] = curve([0.16, 0.22, 0.28, 0.33, 0.35, 0.31, 0.27, 0.24, 0.23, 0.28, 0.34])
    static let sleep: [CGPoint] = curve([0.42, 0.41, 0.40, 0.40, 0.39, 0.39, 0.38, 0.39, 0.38, 0.37, 0.36])
    static let phone: [CGPoint] = curve([0.50, 0.62, 0.74, 0.88, 1.02, 1.15, 1.28, 1.42, 1.55, 1.66, 1.78])
    /// Study Guard caps the phone curve at 20% of its old height.
    static let guardLine: [CGPoint] = phone.map { CGPoint(x: $0.x, y: $0.y * 0.2) }

    /// The y-axis compression once the phone line towers over the others.
    static let finalScale: CGFloat = 0.55

    private static func curve(_ ys: [Double]) -> [CGPoint] {
        ys.enumerated().map { index, y in
            CGPoint(x: Double(index) / Double(ys.count - 1), y: y)
        }
    }
}

/// Small floating series label pinned near its curve.
private struct FloatingChartLabel: View {
    let text: String
    let color: Color
    var night = true

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (night ? Color.white.opacity(0.10) : Color.black.opacity(0.05)),
                in: Capsule(style: .continuous)
            )
    }
}

/// Position for a floating label: anchor.x is the x fraction, anchor.y the
/// pre-scale curve value, mapped through the live yScale.
private func chartLabelPosition(anchor: CGPoint,
                                yScale: CGFloat,
                                in size: CGSize,
                                below: Bool = false) -> CGPoint {
    let lineY = size.height - min(1, anchor.y * yScale) * size.height
    let y = lineY + (below ? 20 : -18)
    return CGPoint(x: anchor.x * size.width,
                   y: max(12, min(size.height - 12, y)))
}

/// Week 1 to Finals axis under both semester charts.
private struct ChartXAxis: View {
    var night = true

    var body: some View {
        HStack {
            Text("Week 1")
            Spacer()
            Text("Midterms")
            Spacer()
            Text("Finals")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(night ? OnbNight.textMuted : SGTheme.paperTertiary)
    }
}

// MARK: - 9. Calculating (night, fully automatic, no CTA)

struct CalculatingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var started = false
    @State private var advanced = false
    @State private var pendingAdvance = false
    @State private var pulsing = false
    @State private var statusIndex = 0

    private let statuses = [
        "Analyzing your screen time...",
        "Calculating hours lost...",
        "Mapping your semester...",
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
                        .font(.system(size: 15, weight: .medium))
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

// MARK: - 10. Life drain (night, auto ~20s)

private enum DrainPhase: Int, Comparable {
    case filling, free, drainIntro, drainCount, drainPercent

    static func < (lhs: DrainPhase, rhs: DrainPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct LifeDrainView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var colors = Array(repeating: LifeDotsGrid.Palette.empty,
                                      count: OnboardingViewModel.lifeYears)
    @State private var phase: DrainPhase = .filling
    @State private var obligationCaption = ""
    @State private var showCTA = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Your life in years")
                        .font(SGTheme.display(26))
                        .foregroundColor(OnbNight.textPrimary)
                    Text("Each square is one year")
                        .font(SGTheme.caption)
                        .foregroundColor(OnbNight.textMuted)
                }
                .fadeRise(shown)
                .padding(.top, 16)

                Spacer(minLength: 14)

                LifeDotsGrid(colors: colors)
                    .frame(width: LifeGrid.width(in: geo.size, reservedHeight: 360))
                    .fadeRise(shown, delay: 0.15)

                Spacer(minLength: 14)

                captionArea
                    .frame(height: 118)

                Spacer(minLength: 8)

                OnbCTA(title: "This needs to change", night: true, visible: showCTA) {
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
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(OnbNight.textPrimary)
                    .id(obligationCaption)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))

            case .free:
                VStack(spacing: 4) {
                    Text("\(OnboardingViewModel.freeYears) years")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(SGTheme.mint)
                    Text("of actual free time.")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OnbNight.textSecondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))

            case .drainIntro, .drainCount, .drainPercent:
                VStack(spacing: 4) {
                    Text("Your phone will steal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OnbNight.textPrimary)

                    if phase >= .drainCount {
                        Text("\(viewModel.phoneYears) of them.")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(SGTheme.ember)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    if phase >= .drainPercent {
                        Text("That's \(viewModel.phonePercentOfFree)% of your free time, gone.")
                            .font(SGTheme.body)
                            .foregroundColor(OnbNight.textSecondary)
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .animation(.easeInOut(duration: 0.35), value: phase)
        .animation(.easeInOut(duration: 0.3), value: obligationCaption)
    }

    private func start() {
        guard !started else { return }
        started = true

        let phoneYears = viewModel.phoneYears
        let phonePercent = viewModel.phonePercentOfFree

        if UIAccessibility.isReduceMotionEnabled {
            viewModel.screenAction("obligations_phase_started")
            viewModel.screenAction("free_time_revealed", properties: [
                "free_years": OnboardingViewModel.freeYears,
            ])
            viewModel.screenAction("phone_drain_revealed", properties: [
                "phone_years": phoneYears,
                "phone_percent_of_free": phonePercent,
            ])
            colors = LifeGrid.drainedColors(phoneYears: phoneYears)
            phase = .drainPercent
            showCTA = true
            return
        }

        // Phase 1: obligations fill in groups, caption swapping per group.
        var t = 0.4
        var startIndex = 0
        after(t) { viewModel.screenAction("obligations_phase_started") }
        for group in LifeGrid.groups {
            let firstDot = startIndex
            let groupStart = t
            after(groupStart) {
                obligationCaption = group.caption
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            for i in 0..<group.count {
                after(groupStart + Double(i) * 0.035) {
                    colors[firstDot + i] = group.color
                }
            }
            t = groupStart + Double(group.count) * 0.035 + 0.55
            startIndex += group.count
        }

        // Phase 2: the free 20 pop mint.
        let freeStart = t + 0.35
        after(freeStart) {
            viewModel.screenAction("free_time_revealed", properties: [
                "free_years": OnboardingViewModel.freeYears,
            ])
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            phase = .free
        }
        for i in 0..<OnboardingViewModel.freeYears {
            after(freeStart + 0.2 + Double(i) * 0.05) {
                colors[LifeGrid.obligationCount + i] = LifeDotsGrid.Palette.free
            }
        }

        // Phase 3: the phone drains their years, one dot at a time.
        let drainStart = freeStart + 0.2 + Double(OnboardingViewModel.freeYears) * 0.05 + 2.2
        after(drainStart) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            viewModel.screenAction("phone_drain_revealed", properties: [
                "phone_years": phoneYears,
                "phone_percent_of_free": phonePercent,
            ])
            phase = .drainIntro
        }
        for i in 0..<phoneYears {
            after(drainStart + 0.5 + Double(i) * 0.18) {
                colors[OnboardingViewModel.lifeYears - 1 - i] = LifeDotsGrid.Palette.phone
                if i % 3 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }

        let drainEnd = drainStart + 0.5 + Double(phoneYears) * 0.18
        after(drainEnd + 0.15) { phase = .drainCount }
        after(drainEnd + 1.1) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            phase = .drainPercent
        }
        after(drainEnd + 2.5) { showCTA = true }
    }
}

// MARK: - 11. Study vs scroll chart (night, auto ~14s)

struct StudyVsScrollChartView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var series: [ChartSeries] = [
        ChartSeries(points: RealityCurves.study, color: SGTheme.mint, label: "Study"),
        ChartSeries(points: RealityCurves.sleep, color: Color(hex: 0x7B88FF), label: "Sleep"),
        ChartSeries(points: RealityCurves.phone, color: SGTheme.ember, label: "Phone", glow: true),
    ]
    @State private var yScale: CGFloat = 1
    @State private var showStudyLabel = false
    @State private var showSleepLabel = false
    @State private var showPhoneLabel = false
    @State private var showSubline = false
    @State private var showCTA = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("Who gets your hours?")
                    .font(SGTheme.headline)
                    .foregroundColor(OnbNight.textPrimary)
                Text("Hours per day across your semester")
                    .font(SGTheme.caption)
                    .foregroundColor(OnbNight.textMuted)
            }
            .multilineTextAlignment(.center)
            .fadeRise(shown)
            .padding(.top, 24)
            .padding(.horizontal, 28)

            Spacer(minLength: 20)

            VStack(spacing: 8) {
                ZStack(alignment: .bottom) {
                    OnbAreaChart(series: series, yScale: yScale)
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 1)
                }
                .frame(height: 280)
                .overlay {
                    GeometryReader { geo in
                        if showStudyLabel {
                            FloatingChartLabel(text: "Study", color: SGTheme.mint)
                                .position(chartLabelPosition(anchor: CGPoint(x: 0.4, y: 0.35),
                                                             yScale: yScale, in: geo.size))
                                .transition(.opacity)
                        }
                        if showSleepLabel {
                            FloatingChartLabel(text: "Sleep", color: Color(hex: 0x7B88FF))
                                .position(chartLabelPosition(anchor: CGPoint(x: 0.8, y: 0.40),
                                                             yScale: yScale, in: geo.size))
                                .transition(.opacity)
                        }
                        if showPhoneLabel {
                            FloatingChartLabel(text: "Phone", color: SGTheme.ember)
                                .position(chartLabelPosition(anchor: CGPoint(x: 0.85, y: 1.5),
                                                             yScale: yScale, in: geo.size))
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.4), value: showStudyLabel)
                    .animation(.easeOut(duration: 0.4), value: showSleepLabel)
                    .animation(.easeOut(duration: 0.4), value: showPhoneLabel)
                }
                .fadeRise(shown, delay: 0.15)

                ChartXAxis(night: true)
                    .fadeRise(shown, delay: 0.15)
            }
            .padding(.horizontal, SGTheme.screenPadding)

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                (Text("\(viewModel.phoneMinutesPerDay) minutes. ")
                    .foregroundColor(SGTheme.ember)
                    + Text("Every single day.")
                    .foregroundColor(OnbNight.textPrimary))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .opacity(showSubline ? 1 : 0)
                    .animation(.easeOut(duration: 0.6), value: showSubline)

                Text("Self-reported daily screen time vs typical study hours (Common Sense Media 2023)")
                    .font(.system(size: 11))
                    .foregroundColor(OnbNight.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .opacity(showSubline ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: showSubline)
            }

            Spacer(minLength: 16)

            OnbCTA(title: "Not anymore", night: true, visible: showCTA) {
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

        let phoneMins = viewModel.phoneMinutesPerDay

        if UIAccessibility.isReduceMotionEnabled {
            viewModel.screenAction("phone_line_revealed", properties: ["phone_mins": phoneMins])
            for i in series.indices { series[i].progress = 1 }
            yScale = RealityCurves.finalScale
            showStudyLabel = true
            showSleepLabel = true
            showPhoneLabel = true
            showSubline = true
            showCTA = true
            return
        }

        // The honest lines draw first.
        after(0.9) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 1.6)) { series[0].progress = 1 }
        }
        after(2.3) { showStudyLabel = true }

        after(2.9) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 1.6)) { series[1].progress = 1 }
        }
        after(4.3) { showSleepLabel = true }

        // Then the phone line towers and the whole chart shrinks beneath it.
        after(5.6) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            viewModel.screenAction("phone_line_revealed", properties: ["phone_mins": phoneMins])
            withAnimation(.easeInOut(duration: 2.4)) {
                series[2].progress = 1
                yScale = RealityCurves.finalScale
            }
        }
        after(7.6) { showPhoneLabel = true }

        after(8.6) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSubline = true
        }
        after(9.8) { showCTA = true }
    }
}

// MARK: - 12. Hours lost (night, auto ~12s, pure typography)

struct HoursLostCycleView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var endingIndex: Int?
    @State private var showCTA = false

    private let endings = [
        "of lectures sat through, distracted.",
        "of grades below what you're capable of.",
        "spent watching other people live.",
        "not becoming who you're meant to be.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                (Text("That's ")
                    .foregroundColor(OnbNight.textPrimary)
                    + Text("\(viewModel.phoneYears) years")
                    .foregroundColor(SGTheme.ember))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .fadeRise(shown)

                ZStack {
                    if let index = endingIndex {
                        Text(endings[index])
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
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

            OnbCTA(title: "I want my time back", night: true, visible: showCTA) {
                viewModel.screenAction("continue_tapped", properties: [
                    "ending_index": endingIndex ?? 0,
                    "phone_years_shown": viewModel.phoneYears,
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
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }

        after(0.8 + 2.8 * Double(endings.count - 1) + 1.4) { showCTA = true }
    }
}

// MARK: - 13. Reclaim (the turn: dawn breaks, the grid heals)

struct ReclaimView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var colors: [Color] = []
    @State private var glowing: Set<Int> = []
    @State private var showCTA = false

    /// The grid renders its drained state on the very first frame, before
    /// onAppear has seeded the state array.
    private var displayColors: [Color] {
        colors.isEmpty ? LifeGrid.drainedColors(phoneYears: viewModel.phoneYears) : colors
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                (Text("Study Guard helps you win back ")
                    .foregroundColor(SGTheme.paper)
                    + Text("\(viewModel.reclaimYears) years")
                    .foregroundColor(SGTheme.mintDeep)
                    + Text(" of your life")
                    .foregroundColor(SGTheme.paper))
                    .font(SGTheme.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    // The container's night backdrop takes ~1.2s to fade to
                    // dawn; the dark-ink title waits so it lands with it.
                    .fadeRise(shown, delay: 1.0)

                Spacer(minLength: 18)

                LifeDotsGrid(colors: displayColors, glowing: glowing)
                    .frame(width: LifeGrid.width(in: geo.size, reservedHeight: 360))
                    .fadeRise(shown, delay: 0.15)

                Spacer(minLength: 18)

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

    private func start() {
        guard !started else { return }
        started = true

        let phoneYears = viewModel.phoneYears
        let reclaimYears = min(viewModel.reclaimYears, phoneYears)
        let firstDrained = OnboardingViewModel.lifeYears - phoneYears
        colors = LifeGrid.drainedColors(phoneYears: phoneYears)

        if UIAccessibility.isReduceMotionEnabled {
            for i in 0..<reclaimYears {
                colors[firstDrained + i] = LifeDotsGrid.Palette.free
                glowing.insert(firstDrained + i)
            }
            viewModel.screenAction("reclaim_animation_complete", properties: [
                "years_reclaimed": viewModel.reclaimYears,
            ])
            showCTA = true
            return
        }

        // The ember dots flip back one by one, glowing mint.
        for i in 0..<reclaimYears {
            after(1.4 + Double(i) * 0.18) {
                let index = firstDrained + i
                colors[index] = LifeDotsGrid.Palette.free
                glowing.insert(index)

                if i == 0 || i == reclaimYears - 1 {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } else if i % 3 == 0 {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
        }

        let healEnd = 1.4 + Double(reclaimYears) * 0.18
        after(healEnd + 0.3) {
            SGTheme.successHaptic()
            viewModel.screenAction("reclaim_animation_complete", properties: [
                "years_reclaimed": viewModel.reclaimYears,
            ])
        }
        after(healEnd + 0.9) { showCTA = true }
    }
}

// MARK: - 14. After chart (daylight, auto ~6s)

struct AfterChartView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var shown = false
    @State private var series: [ChartSeries] = [
        ChartSeries(points: RealityCurves.study, color: SGTheme.mintDeep, label: "Study", progress: 1),
        ChartSeries(points: RealityCurves.sleep, color: SGTheme.teal, label: "Sleep", progress: 1),
        ChartSeries(points: RealityCurves.phone, color: SGTheme.ember, label: "Phone", progress: 1, dimmed: true),
        ChartSeries(points: RealityCurves.guardLine, color: SGTheme.mint,
                    label: "Phone (with Study Guard)", glow: true),
    ]
    @State private var showGuardLabel = false
    @State private var showCTA = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Put your hours back where they belong")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(SGTheme.paper)
                Text("Less scrolling. Better grades. More life.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .fadeRise(shown)
            .padding(.top, 24)
            .padding(.horizontal, 28)

            Spacer(minLength: 20)

            VStack(spacing: 8) {
                ZStack(alignment: .bottom) {
                    OnbAreaChart(series: series, yScale: RealityCurves.finalScale)
                    Rectangle()
                        .fill(SGTheme.hairline)
                        .frame(height: 1)
                }
                .frame(height: 260)
                .overlay {
                    GeometryReader { geo in
                        if showGuardLabel {
                            FloatingChartLabel(text: "Phone (with Study Guard)",
                                               color: SGTheme.mintDeep,
                                               night: false)
                                .position(chartLabelPosition(anchor: CGPoint(x: 0.6, y: 0.25),
                                                             yScale: RealityCurves.finalScale,
                                                             in: geo.size,
                                                             below: true))
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.4), value: showGuardLabel)
                }
                .fadeRise(shown, delay: 0.1)

                ChartXAxis(night: false)
                    .fadeRise(shown, delay: 0.1)
            }
            .padding(.horizontal, SGTheme.screenPadding)

            Spacer(minLength: 16)

            legend
                .fadeRise(shown, delay: 0.2)

            Spacer(minLength: 16)

            OnbCTA(title: "Continue", visible: showCTA) {
                viewModel.nextStep()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            shown = true
            start()
        }
    }

    private var legend: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                LegendChip(color: SGTheme.mintDeep, label: "Study")
                LegendChip(color: SGTheme.teal, label: "Sleep")
                LegendChip(color: SGTheme.ember, label: "Phone", dimmed: true)
            }
            LegendChip(color: SGTheme.mint, label: "Phone (with Study Guard)")
        }
        .padding(.horizontal, SGTheme.screenPadding)
    }

    private func start() {
        guard !started else { return }
        started = true

        if UIAccessibility.isReduceMotionEnabled {
            viewModel.screenAction("reclaim_graph_shown")
            series[3].progress = 1
            showGuardLabel = true
            showCTA = true
            return
        }

        // The chart is pre-drawn; the only beat is the Study Guard line.
        after(1.0) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            viewModel.screenAction("reclaim_graph_shown")
            withAnimation(.easeInOut(duration: 1.6)) { series[3].progress = 1 }
        }
        after(2.4) { showGuardLabel = true }
        after(3.2) { showCTA = true }
    }
}

/// Legend pill: colored dot + label on a raised capsule (daylight only).
private struct LegendChip: View {
    let color: Color
    let label: String
    var dimmed = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SGTheme.paper)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(Capsule(style: .continuous).strokeBorder(SGTheme.hairline, lineWidth: 1))
        )
        .opacity(dimmed ? 0.55 : 1)
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

#Preview("Life drain") {
    ZStack {
        NightSkyBackdrop()
        LifeDrainView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("Study vs scroll") {
    ZStack {
        NightSkyBackdrop()
        StudyVsScrollChartView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("Hours lost") {
    ZStack {
        NightSkyBackdrop()
        HoursLostCycleView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("Reclaim") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        ReclaimView()
    }
    .environmentObject(OnboardingViewModel())
}

#Preview("After chart") {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        AfterChartView()
    }
    .environmentObject(OnboardingViewModel())
}
