//
//  OnboardingV2Components.swift
//  diewithoutregrets
//
//  Shared building blocks for onboarding v2: the night-sky backdrop, staged
//  entrances, CTA pills, the quiz scaffold with its floating clipboard
//  interviewer, fake notification banners, marquees, the 80-dot life grid
//  and the animated area chart.
//
//  Haptic grammar (OneThing): rigid = lock, soft = gain, light = per-tick,
//  medium = beat, heavy = climax.
//

import SwiftUI
import Lottie

// MARK: - Night palette

/// Surfaces and text for the night-sky screens (villain arc + reality
/// check). Text reads the SGTheme night ramp; the card fills stay local
/// because the navy sky wants slightly stronger washes than the ember
/// night scene.
enum OnbNight {
    static let textPrimary = SGTheme.nightText
    static let textSecondary = SGTheme.nightTextSecondary
    static let textMuted = SGTheme.nightTextTertiary
    static let cardFill = Color.white.opacity(0.08)
    static let cardBorder = Color.white.opacity(0.15)
    static let cardBorderSelected = Color.white.opacity(0.7)
    /// Small circular chips (marquee icons, quiz back button).
    static let chipFill = Color.white.opacity(0.12)
}

/// Dusk sky behind the villain arc: deep blue gradient with the drifting
/// clouds Lottie and a readability vignette. The container crossfades this
/// out at the turn (dawn).
struct NightSkyBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: SGTheme.skyTop, location: 0),
                    .init(color: SGTheme.skyMid, location: 0.55),
                    .init(color: SGTheme.skyDeep, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LottieView {
                try await DotLottieFile.named("Clouds 2")
            }
            .playing(loopMode: .loop)
            .animationSpeed(0.3)
            .configure { $0.contentMode = .scaleAspectFill }
            .opacity(0.35)

            // Bottom vignette so the CTA pills and copy stay readable.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.5),
                    .init(color: SGTheme.skyVignette.opacity(0.85), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Staged entrances

/// OneThing's signature entrance: fade in + rise 20pt after a delay. Drive
/// with a single `shown` flag flipped in onAppear.
struct FadeRise: ViewModifier {
    let shown: Bool
    var delay: Double = 0
    var distance: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : distance)
            .animation(.easeOut(duration: 0.8).delay(delay), value: shown)
    }
}

extension View {
    func fadeRise(_ shown: Bool, delay: Double = 0, distance: CGFloat = 20) -> some View {
        modifier(FadeRise(shown: shown, delay: delay, distance: distance))
    }
}

// MARK: - CTA

/// Full-width onboarding CTA: a thin skin over the ONE app button
/// (SGButton, the chunky ledge capsule). Night screens get the white
/// variant, daylight the mint. Reveal it with `visible` once the screen's
/// choreography lands — the delay IS the pacing.
struct OnbCTA: View {
    let title: String
    var night = false
    var visible = true
    let action: () -> Void

    var body: some View {
        SGButton(title: title, variant: night ? .white : .mint, action: action)
            .padding(.horizontal, SGTheme.screenPadding)
            .fadeRise(visible)
            .allowsHitTesting(visible)
    }
}

// MARK: - Quiz scaffold

/// Question-screen scaffold: space reserved for the floating clipboard
/// mascot (rendered ONCE by the container so it persists across question
/// crossfades), numbered question, then the option list. The back button
/// and progress bar moved into the flow-wide chrome in OnboardingView;
/// `progress` is kept only so quiz call sites stay source-stable until the
/// Phase 5 sweep.
struct QuizScreenContainer<Content: View>: View {
    let number: Int
    let question: String
    let subtitle: String
    let progress: Double
    @ViewBuilder var content: Content

    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Space for the container-level floating clipboard mascot.
            Color.clear.frame(height: 128)

            VStack(spacing: 8) {
                (Text("\(number).  ").foregroundColor(OnbNight.textMuted)
                    + Text(question).foregroundColor(OnbNight.textPrimary))
                    .font(SGTheme.display(22, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(SGTheme.body)
                    .foregroundColor(OnbNight.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 10) {
                    content
                }
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Single-select quiz option: dark card, optional emoji + judgment subtext,
/// radio that fills white with a checkmark. Selection auto-advances via
/// viewModel.selectQuizAnswer — no continue button.
struct QuizOptionRow: View {
    let title: String
    var subtext: String? = nil
    var emoji: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let emoji {
                    Text(emoji).font(SGTheme.display(20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(OnbNight.textPrimary)
                    if let subtext {
                        Text(subtext)
                            .font(SGTheme.caption)
                            .foregroundColor(OnbNight.textSecondary)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.white : Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if selected {
                        Circle().fill(Color.white).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(SGTheme.micro.weight(.bold))
                            .foregroundColor(SGTheme.skyTop)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(OnbNight.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(selected ? OnbNight.cardBorderSelected : OnbNight.cardBorder,
                                          lineWidth: selected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
        .animation(SGTheme.springFast, value: selected)
    }
}

// MARK: - Fake notification banners

struct FakeNotification: Identifiable, Equatable {
    let id = UUID()
    let appName: String
    let icon: String       // SF symbol
    let tint: Color
    let title: String
    let body: String

    static let samples: [FakeNotification] = [
        .init(appName: "Instagram", icon: "camera.fill", tint: Color(hex: 0xE1306C),
              title: "Instagram", body: "Someone liked your photo"),
        .init(appName: "TikTok", icon: "music.note", tint: Color(hex: 0x111111),
              title: "TikTok", body: "New video from a creator you follow"),
        .init(appName: "Snapchat", icon: "bolt.fill", tint: Color(hex: 0xFFFC00),
              title: "Snapchat", body: "You have 3 unopened snaps"),
        .init(appName: "Duolingo", icon: "flame.fill", tint: Color(hex: 0x58CC02),
              title: "Duolingo", body: "Your streak is about to expire"),
        .init(appName: "BeReal", icon: "camera.viewfinder", tint: Color(hex: 0x222222),
              title: "BeReal", body: "Time to BeReal. 2 min left"),
        .init(appName: "YouTube", icon: "play.rectangle.fill", tint: Color(hex: 0xFF0000),
              title: "YouTube", body: "New upload from a channel you watch"),
        .init(appName: "X", icon: "number", tint: Color(hex: 0x111111),
              title: "X", body: "You have 12 new notifications"),
        .init(appName: "Messages", icon: "message.fill", tint: Color(hex: 0x34C759),
              title: "Messages", body: "3 new messages in Group Chat"),
    ]
}

/// The iOS-style banner stack that bombards the mascot on the reveal screen.
/// Spawns a banner every `interval` while `active`, keeping at most 3.
struct NotificationBannerOverlay: View {
    var active: Bool
    var interval: Double = 1.2
    var onSpawn: (() -> Void)? = nil

    @State private var visible: [FakeNotification] = []
    @State private var nextIndex = 0
    /// Invalidates in-flight reschedules: bumping it orphans any pending
    /// spawn closure, so deactivation/teardown actually stops the loop
    /// (and its soft haptic) instead of ticking for the rest of the session.
    @State private var generation = 0

    var body: some View {
        VStack(spacing: 8) {
            ForEach(visible) { note in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(note.tint)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: note.icon)
                                .font(SGTheme.buttonSmall)
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(note.title)
                            .font(SGTheme.caption.weight(.bold))
                            .foregroundColor(.primary)
                        Text(note.body)
                            .font(SGTheme.caption)
                            .foregroundColor(.primary.opacity(0.8))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text("now")
                        .font(SGTheme.micro.weight(.regular))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .onChange(of: active) { _, isActive in
            generation += 1
            if isActive { spawn(generation) }
        }
        .onAppear {
            if active {
                generation += 1
                spawn(generation)
            }
        }
        .onDisappear { generation += 1 }
    }

    private func spawn(_ gen: Int) {
        guard active, gen == generation else { return }
        let note = FakeNotification.samples[nextIndex % FakeNotification.samples.count]
        nextIndex += 1
        withAnimation(SGTheme.springFast) {
            visible.insert(note, at: 0)
            if visible.count > 3 { visible.removeLast() }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        onSpawn?()
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { spawn(gen) }
    }
}

// MARK: - Marquee

/// Infinite horizontal marquee: renders content three times and drifts one
/// set-width on a repeating linear animation, with edge-fade mask.
struct MarqueeRow<Content: View>: View {
    var speed: Double = 30          // points per second
    var reverse = false
    @ViewBuilder var content: Content

    @State private var contentWidth: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let offset = contentWidth > 0
                ? CGFloat(t * speed).truncatingRemainder(dividingBy: contentWidth)
                : 0

            HStack(spacing: 0) {
                marqueeContent
                marqueeContent
                marqueeContent
            }
            .offset(x: (reverse ? offset : -offset) - contentWidth)
            // The tripled strip is thousands of points wide; without this
            // the row reports that width and blows the whole screen layout
            // out sideways. Take the proposed width, let the strip overflow
            // underneath, and clip.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipped()
    }

    private var marqueeContent: some View {
        content
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newValue in
                if contentWidth == 0 { contentWidth = newValue }
            }
    }
}

// MARK: - Life dots grid

/// The choreographed dot grid. Drive it by mutating `colors` — each change
/// animates individually, so screens choreograph drains/heals dot by dot.
/// v3 uses 105 entries at 7 columns (the semester: each row one week).
struct LifeDotsGrid: View {
    var colors: [Color]
    var glowing: Set<Int> = []
    /// 7 for the semester grid (one row = one week); 8 was the v2 life grid.
    var columnCount: Int = 7

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 7), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(0..<colors.count, id: \.self) { index in
                // Squircle day-dots: art, near-circular at grid cell size.
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(colors[index])
                    .aspectRatio(1, contentMode: .fit)
                    .scaleEffect(glowing.contains(index) ? 1.18 : 1)
                    .shadow(color: glowing.contains(index) ? colors[index].opacity(0.8) : .clear,
                            radius: 6)
                    // Fills and drains read as a soft crossfade, not a snap;
                    // only the glow keeps its springy pop.
                    .animation(.easeInOut(duration: 0.6), value: colors[index])
                    .animation(SGTheme.springFast, value: glowing.contains(index))
            }
        }
    }

    /// Standard palette for the grid phases.
    enum Palette {
        static let empty = Color.white.opacity(0.10)
        static let sleep = Color(hex: 0x4A7DFF)
        static let school = Color(hex: 0x6A5CFF)
        static let commute = Color(hex: 0x9B59FF)
        static let eating = Color(hex: 0xC44FD6)
        static let chores = Color(hex: 0xE85B9B)
        static let free = SGTheme.mint
        static let phone = SGTheme.ember
    }
}

// MARK: - Animated area chart

/// One animatable series for OnbAreaChart: normalized points in [0,1] on
/// both axes; `progress` draws the line left→right; `yScale` lets the chart
/// rescale live when a taller series lands (the OneThing "rescale" beat).
struct ChartSeries: Identifiable {
    let id = UUID()
    var points: [CGPoint]        // x ascending in [0,1], y in [0,1] (1 = tallest ever shown)
    var color: Color
    var label: String
    var progress: CGFloat = 0    // 0..1 drawn fraction
    var dimmed = false
    var glow = false
}

private struct ChartLineShape: Shape {
    var points: [CGPoint]
    var progress: CGFloat
    var yScale: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, yScale) }
        set { progress = newValue.first; yScale = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1, progress > 0 else { return path }

        let visible = points.filter { $0.x <= progress }
        guard visible.count > 1 else { return path }

        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * rect.width,
                    y: rect.height - min(1, p.y * yScale) * rect.height)
        }

        path.move(to: map(visible[0]))
        for i in 1..<visible.count {
            let prev = map(visible[i - 1])
            let next = map(visible[i])
            let mid = CGPoint(x: (prev.x + next.x) / 2, y: (prev.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: prev)
            if i == visible.count - 1 {
                path.addLine(to: next)
            }
        }
        return path
    }
}

/// Animated multi-series line chart used by the "who gets your hours"
/// screens. Screens mutate the series array; progress/yScale animate.
struct OnbAreaChart: View {
    var series: [ChartSeries]
    var yScale: CGFloat = 1

    var body: some View {
        ZStack {
            ForEach(series) { s in
                ChartLineShape(points: s.points, progress: s.progress, yScale: yScale)
                    .stroke(s.color.opacity(s.dimmed ? 0.25 : 1),
                            style: StrokeStyle(lineWidth: s.glow ? 4 : 2.5, lineCap: .round))
                    .shadow(color: s.glow ? s.color.opacity(0.7) : .clear, radius: 8)
                    .animation(.easeInOut(duration: 0.6), value: s.dimmed)
            }
        }
    }
}

// MARK: - Trust badge

/// Native trust badge row: laurel stars + user count (no image assets).
struct TrustBadges: View {
    var night = true

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(SGTheme.micro.weight(.regular))
                            .foregroundColor(SGTheme.sun)
                    }
                }
                Text("4.8 rating")
                    .font(SGTheme.micro)
                    .foregroundColor(night ? OnbNight.textSecondary : SGTheme.paperSecondary)
            }

            Rectangle()
                .fill((night ? Color.white : Color.black).opacity(0.15))
                .frame(width: 1, height: 30)

            VStack(spacing: 4) {
                HStack(spacing: -8) {
                    ForEach(1...3, id: \.self) { index in
                        Image("char\(index)")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(night ? SGTheme.skyTop : .white, lineWidth: 1.5))
                    }
                }
                Text("45,000+ students")
                    .font(SGTheme.micro)
                    .foregroundColor(night ? OnbNight.textSecondary : SGTheme.paperSecondary)
            }
        }
    }
}
