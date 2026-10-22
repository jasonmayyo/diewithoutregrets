// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
import SwiftUI

enum SGV5PostPurchaseStyle {
    static let primary = SGTheme.paper
    static let secondary = SGTheme.paperSecondary
    static let accent = SGTheme.mintDeep
    static let surface = SGTheme.ink
    static let raised = SGTheme.inkRaised
    static let border = SGTheme.paper.opacity(0.08)
    static let cardCornerRadius: CGFloat = 52
    static let screenIDs = [601, 602, 606, 604]
}

/// Lives outside the changing card so the atmosphere and mascot stay continuous.
struct SGV5PostPurchaseBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var startedAt = Date()

    var body: some View {
        let isReduced = reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isReduced || scenePhase != .active)) { timeline in
            let time = isReduced ? 0 : timeline.date.timeIntervalSince(startedAt)
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    SGTheme.inkRaised
                    Canvas { context, size in
                        drawHaze(in: &context, size: size, time: time)
                    }
                    let compact = geometry.size.height < 700 || typeSize.isAccessibilitySize
                    let heroHeight: CGFloat = compact ? 144 : 224
                    let scale = min((geometry.size.width - 24) / 360, heroHeight / 252)
                    let heroOffset = max(compact ? 32 : 16,
                                         geometry.safeAreaInsets.top + 8
                                         + SGV5PostPurchaseOrbitSample.shieldRadius * scale - heroHeight / 2)
                    SGV5PostPurchaseOrbitHero(time: time)
                        .frame(width: 360, height: 252)
                        .scaleEffect(scale)
                        .frame(width: geometry.size.width, height: heroHeight)
                        .padding(.top, geometry.safeAreaInsets.top)
                        // Keep the whole shield below the top safe area, with breathing room.
                        .offset(y: -geometry.safeAreaInsets.top + heroOffset)
                }
                .ignoresSafeArea()
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func drawHaze(in context: inout GraphicsContext, size: CGSize, time: Double) {
        // Overlapping soft fields move slowly, like diffuse light through smoke.
        // Brighter sage light extends behind the card so its dark surface reads clearly.
        let fields: [(x: Double, y: Double, radius: Double, color: Color)] = [
            (0.12 + sin(time * 0.19) * 0.16, 0.11 + cos(time * 0.15) * 0.025,
             0.85, Color(red: 0.58, green: 0.53, blue: 0.43).opacity(0.40)),
            (0.88 + cos(time * 0.16) * 0.14, 0.17 + sin(time * 0.18) * 0.04,
             0.90, Color(red: 0.45, green: 0.64, blue: 0.53).opacity(0.48)),
            (0.48 + sin(time * 0.12) * 0.20, 0.02 + cos(time * 0.13) * 0.04,
             0.65, SGTheme.paperSecondary.opacity(0.24)),
            (0.05 + sin(time * 0.11) * 0.08, 0.34,
             1.05, Color(red: 0.62, green: 0.78, blue: 0.65).opacity(0.48)),
            (0.96 + cos(time * 0.09) * 0.06, 0.65,
             1.10, Color(red: 0.47, green: 0.69, blue: 0.56).opacity(0.44)),
            (0.24 + sin(time * 0.13) * 0.10, 0.96,
             0.85, Color(red: 0.62, green: 0.59, blue: 0.47).opacity(0.34))
        ]
        for field in fields {
            let center = CGPoint(x: size.width * field.x, y: size.height * field.y)
            let radius = size.width * field.radius
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(stops: [
                            .init(color: field.color, location: 0),
                            .init(color: field.color.opacity(0.45), location: 0.40),
                            .init(color: .clear, location: 1)
                         ]), center: center, startRadius: 0, endRadius: radius))
        }
    }
}

// BEGIN ORBIT GEOMETRY
/// The icon's entire tile always stays outside the shield, even during a collision.
struct SGV5PostPurchaseOrbitSample {
    let angle: Double
    let x: Double
    let y: Double
    let size: Double
    let depth: Double
    let impact: Double
    let ripple: Double?

    static let shieldRadius = 66.0
    static let orbitRadius = 116.0

    static func make(index: Int, count: Int, time: Double) -> Self {
        let angle = Double(index) / Double(count) * .pi * 2 + time * 0.18 - 0.3
        let depth = (sin(angle) + 1) / 2
        let size = 42 * (0.70 + depth * 0.30)
        let cycle = Double(count) * 2.6
        let phase = ((time - Double(index) * 2.6).truncatingRemainder(dividingBy: cycle) + cycle)
            .truncatingRemainder(dividingBy: cycle)
        let pull = phase < 1.6 ? pow(sin(.pi * phase / 1.6), 4) : 0
        let rebound = phase > 0.8 && phase < 1.6 ? sin(.pi * (phase - 0.8) / 0.8) * 8 : 0
        // The half-diagonal covers the rotating square icon, not just its centre.
        let contactRadius = shieldRadius + size / sqrt(2) + 4
        let outerRadius = max(orbitRadius, contactRadius + 6)
        let distance = outerRadius - (outerRadius - contactRadius) * pull + rebound
        let impact = phase < 1.6 ? exp(-pow((phase - 0.8) / 0.16, 2)) : 0
        let ripple = phase >= 0.8 && phase < 1.5 ? (phase - 0.8) / 0.7 : nil
        return Self(angle: angle, x: cos(angle) * distance, y: sin(angle) * distance,
                    size: size, depth: depth, impact: impact, ripple: ripple)
    }
}
// END ORBIT GEOMETRY

private struct SGV5PostPurchaseOrbitHero: View {
    let time: Double
    private let icons = ["instagram", "youtube", "whatsapp", "tiktok", "spotify",
                         "facebook", "snapchat", "slack", "pinterest"]
    private var samples: [SGV5PostPurchaseOrbitSample] {
        icons.indices.map { SGV5PostPurchaseOrbitSample.make(index: $0, count: icons.count, time: time) }
    }

    var body: some View {
        let states = samples
        let impact = states.map(\.impact).max() ?? 0
        ZStack {
            Circle()
                .stroke(SGTheme.paper.opacity(0.07), lineWidth: 0.7)
                .frame(width: SGV5PostPurchaseOrbitSample.orbitRadius * 2,
                       height: SGV5PostPurchaseOrbitSample.orbitRadius * 2)
                .zIndex(-2)
            ForEach(icons.indices, id: \.self) { index in
                let state = states[index]
                icon(named: icons[index], side: state.size)
                    .rotationEffect(.degrees(sin(time * 0.55 + Double(index)) * 9))
                    .rotation3DEffect(.degrees(cos(state.angle) * 12), axis: (x: 0, y: 1, z: 0))
                    .opacity(0.50 + state.depth * 0.50)
                    .shadow(color: SGTheme.ink.opacity(0.45), radius: 5, y: 4)
                    .offset(x: state.x, y: state.y)
                    .zIndex(state.depth < 0.5 ? -1 : 3)
            }
            shield(impact: impact)
                .zIndex(0)
            Image("sgv5-mascot-reading")
                .resizable().scaledToFit()
                .frame(width: 144, height: 144)
                .scaleEffect(1 + sin(time * 0.7) * 0.018)
                .offset(y: -2 + sin(time * 0.7) * 2)
                .shadow(color: SGV5PostPurchaseStyle.accent.opacity(0.12), radius: 14)
                .zIndex(1)
            Image("sgv5-app-logo")
                .resizable().scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SGTheme.paper.opacity(0.20), lineWidth: 0.8))
                .shadow(color: SGTheme.ink.opacity(0.45), radius: 5, y: 3)
                .offset(y: SGV5PostPurchaseOrbitSample.shieldRadius)
                .zIndex(2)
            ForEach(icons.indices, id: \.self) { index in
                impactRipple(states[index])
                    .zIndex(2)
            }
        }
        .frame(width: 360, height: 252)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func shield(impact: Double) -> some View {
        ZStack {
            Circle()
                .stroke(SGV5PostPurchaseStyle.accent.opacity(0.10 + impact * 0.13), lineWidth: 9)
                .blur(radius: 10)
            Circle()
                .fill(RadialGradient(colors: [SGTheme.paper.opacity(0.035), SGV5PostPurchaseStyle.accent.opacity(0.055),
                                              SGV5PostPurchaseStyle.accent.opacity(0.13)],
                                     center: .init(x: 0.35, y: 0.2), startRadius: 3, endRadius: 100))
            Circle()
                .stroke(AngularGradient(colors: [SGTheme.paper.opacity(0.55), SGV5PostPurchaseStyle.accent.opacity(0.20),
                                                 SGTheme.paper.opacity(0.08), SGV5PostPurchaseStyle.accent.opacity(0.55),
                                                 SGTheme.paper.opacity(0.55)], center: .center,
                                        angle: .degrees(time * 7)), lineWidth: 1)
            Circle().trim(from: 0.05, to: 0.21)
                .stroke(SGTheme.paper.opacity(0.42), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .padding(4)
                .rotationEffect(.degrees(-100 + sin(time * 0.2) * 18))
        }
        .frame(width: SGV5PostPurchaseOrbitSample.shieldRadius * 2,
               height: SGV5PostPurchaseOrbitSample.shieldRadius * 2)
    }

    @ViewBuilder
    private func impactRipple(_ state: SGV5PostPurchaseOrbitSample) -> some View {
        if let progress = state.ripple {
            Circle()
                .stroke(SGV5PostPurchaseStyle.accent.opacity((1 - progress) * 0.55), lineWidth: 1)
                .frame(width: 8 + progress * 30, height: 8 + progress * 30)
                .offset(x: cos(state.angle) * SGV5PostPurchaseOrbitSample.shieldRadius,
                        y: sin(state.angle) * SGV5PostPurchaseOrbitSample.shieldRadius)
        }
        Circle().trim(from: 0, to: 0.09)
            .stroke(SGV5PostPurchaseStyle.accent.opacity(state.impact * 0.9),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: SGV5PostPurchaseOrbitSample.shieldRadius * 2,
               height: SGV5PostPurchaseOrbitSample.shieldRadius * 2)
            .rotationEffect(.radians(state.angle - .pi * 0.09))
            .shadow(color: SGV5PostPurchaseStyle.accent.opacity(state.impact * 0.7), radius: 5)
    }

    @ViewBuilder
    private func icon(named name: String, side: Double) -> some View {
        if name == "pinterest" {
            // This supplied icon includes a matte; crop it within the display tile.
            Image(SGV5Assets.name("post-orbit-" + name)).resizable().scaledToFill()
                .frame(width: side, height: side).scaleEffect(1.45)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.28))
        } else {
            Image(SGV5Assets.name("post-orbit-" + name)).resizable().scaledToFit()
                .frame(width: side, height: side)
        }
    }
}

struct SGV5PostPurchaseCard<Content: View>: View {
    @ObservedObject var viewModel: SGV5FlowModel
    let screenID: Int
    let title: String
    let subtitle: String
    let buttonTitle: String
    var isBusy = false
    var footnote: String? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    let action: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var steps: [Int] { viewModel.activeFlowOrder.filter(SGV5PostPurchaseStyle.screenIDs.contains) }
    private var position: Int { steps.firstIndex(of: screenID) ?? 0 }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700 || typeSize.isAccessibilitySize
            VStack(spacing: 0) {
                Spacer(minLength: 0).frame(height: compact ? 144 : 190)
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button { viewModel.previousPage() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(SGV5PostPurchaseStyle.primary.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(SGV5PostPurchaseStyle.raised, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Previous setup step")
                        .hiddenWhen(position == 0)
                        SGV5QuizProgressBar(
                            progress: Double(position + 1) / Double(max(steps.count, 1)),
                            accessibilityTitle: "Setup step \(position + 1) of \(steps.count)"
                        )
                        Text("\(position + 1) / \(steps.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(SGV5PostPurchaseStyle.secondary)
                            .frame(width: 44)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)
                    .disabled(isBusy)
                    .modifier(SGV5PostPurchaseEntrance(isVisible: hasAppeared, reduceMotion: reduceMotion, delay: 0.06))

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compact ? 18 : 24) {
                            VStack(spacing: 12) {
                                Text(title)
                                    .font(.system(size: compact ? titleSize * 0.875 : titleSize, weight: .bold, design: .default))
                                    .tracking(-1.1)
                                    .foregroundStyle(SGV5PostPurchaseStyle.primary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                                    .modifier(SGV5PostPurchaseEntrance(isVisible: hasAppeared, reduceMotion: reduceMotion, delay: 0.12))
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(SGV5PostPurchaseStyle.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                                    .modifier(SGV5PostPurchaseEntrance(isVisible: hasAppeared, reduceMotion: reduceMotion, delay: 0.20))
                            }.padding(.horizontal, 12)
                            content
                                .modifier(SGV5PostPurchaseEntrance(isVisible: hasAppeared, reduceMotion: reduceMotion, delay: 0.28))
                        }
                        .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 20)
                        .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 12) {
                        if let secondaryTitle, let secondaryAction {
                            Button(secondaryTitle) {
                                SGV5Haptics.play(.selection)
                                secondaryAction()
                            }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(SGV5PostPurchaseStyle.secondary)
                                .frame(minHeight: 44)
                                .disabled(isBusy)
                        } else if let footnote {
                            Text(footnote).font(.system(size: 11))
                                .foregroundStyle(SGV5PostPurchaseStyle.secondary)
                                .multilineTextAlignment(.center)
                        }
                        SGV5QuizContinueButton(text: isBusy ? "One moment…" : buttonTitle,
                                               isLoading: isBusy, action: action)
                            .accessibilityIdentifier("onboarding.setup.continue")
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                    .modifier(SGV5PostPurchaseEntrance(isVisible: hasAppeared, reduceMotion: reduceMotion, delay: 0.38))
                }
                .background(SGV5PostPurchaseStyle.surface, in: RoundedRectangle(cornerRadius: SGV5PostPurchaseStyle.cardCornerRadius, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: SGV5PostPurchaseStyle.cardCornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [SGV5PostPurchaseStyle.accent.opacity(0.58),
                                                      SGV5PostPurchaseStyle.accent.opacity(0.28),
                                                      Color(red: 0.68, green: 0.64, blue: 0.49).opacity(0.34)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(-8)
                        .blur(radius: 26)
                }
                .overlay(RoundedRectangle(cornerRadius: SGV5PostPurchaseStyle.cardCornerRadius, style: .continuous).strokeBorder(
                    LinearGradient(colors: [SGTheme.paper.opacity(0.24), SGV5PostPurchaseStyle.accent.opacity(0.16),
                                            SGTheme.paper.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                .shadow(color: SGTheme.ink.opacity(0.30), radius: 12, y: 8)
                .modifier(SGV5PostPurchaseEntrance(isVisible: hasAppeared, reduceMotion: reduceMotion, delay: 0, distance: 30))
                .padding(.horizontal, 10)
                .padding(.bottom, 12)

            }
        }
        .task(id: screenID) {
            hasAppeared = false
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
            }
            hasAppeared = true
        }
    }
}

private struct SGV5PostPurchaseEntrance: ViewModifier {
    let isVisible: Bool
    let reduceMotion: Bool
    let delay: Double
    var distance: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : distance)
            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.86).delay(delay), value: isVisible)
    }
}

private extension View {
    func hiddenWhen(_ hidden: Bool) -> some View {
        opacity(hidden ? 0 : 1).allowsHitTesting(!hidden).accessibilityHidden(hidden)
    }
}

struct SGV5PostPurchaseFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 19, weight: .medium))
                .foregroundStyle(SGV5PostPurchaseStyle.accent)
                .frame(width: 42, height: 42)
                .background(SGV5PostPurchaseStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(SGV5PostPurchaseStyle.primary)
                Text(detail).font(.system(size: 12)).foregroundStyle(SGV5PostPurchaseStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(14)
            .background(SGV5PostPurchaseStyle.raised, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(SGV5PostPurchaseStyle.accent.opacity(0.08)))
    }
}

struct SGV5PostPurchaseHabitIllustration: View {
    var body: some View {
        ZStack {
            Circle().fill(SGV5PostPurchaseStyle.accent.opacity(0.055)).frame(width: 222, height: 222)
            RoundedRectangle(cornerRadius: 25).fill(SGTheme.inkRaised)
                .frame(width: 165, height: 180).rotationEffect(.degrees(-12)).offset(x: -23, y: 4)
            VStack(spacing: 14) {
                Image("sgv5-mascot-reading").resizable().scaledToFit().frame(width: 110, height: 110)
                Text("Your studies first")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(SGV5PostPurchaseStyle.primary)
                Label("Then, time to scroll", systemImage: "lock.open.fill")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(SGV5PostPurchaseStyle.accent)
            }
            .frame(width: 180, height: 200)
            .background(SGV5PostPurchaseStyle.raised, in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(SGV5PostPurchaseStyle.accent.opacity(0.12)))
            .shadow(color: SGTheme.ink.opacity(0.3), radius: 15, y: 10)
            .rotationEffect(.degrees(5)).offset(x: 12)
        }.frame(height: 235).accessibilityHidden(true)
    }
}

struct SGV5PostPurchasePermissionIllustration: View {
    var notifications = false

    var body: some View {
        ZStack {
            Circle().fill(SGV5PostPurchaseStyle.accent.opacity(0.04)).frame(width: 132, height: 132)
            Circle().strokeBorder(SGV5PostPurchaseStyle.accent.opacity(0.08), lineWidth: 1).frame(width: 112, height: 112)
            RoundedRectangle(cornerRadius: 30)
                .fill(LinearGradient(colors: [SGTheme.inkRaised, SGTheme.inkRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 84, height: 84).rotationEffect(.degrees(-9))
                .shadow(color: SGTheme.ink.opacity(0.35), radius: 20, y: 12)
            Image(systemName: notifications ? "bell.badge.fill" : "hourglass")
                .font(.system(size: 38, weight: .medium))
                .symbolRenderingMode(.hierarchical).foregroundStyle(SGV5PostPurchaseStyle.accent)
        }.frame(height: 136).accessibilityHidden(true)
    }
}

struct SGV5PostPurchaseNotificationStack: View {
    var compact = false
    private let messages = [
        ("Your flashcards are waiting", "A quick review before your next scroll.", "now"),
        ("You earned this", "Your apps are ready when you are.", "2m"),
        ("Small steps. Real progress.", "Make a little room for your studies today.", "8m")
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<(compact ? 2 : 3), id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    Image("sgv5-app-logo").resizable().scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(messages[index].0).font(.system(size: 12, weight: .semibold)).foregroundStyle(SGV5PostPurchaseStyle.primary)
                        Text(messages[index].1).font(.system(size: 11)).foregroundStyle(SGV5PostPurchaseStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text(messages[index].2).font(.system(size: 9)).foregroundStyle(SGV5PostPurchaseStyle.secondary)
                }
                .padding(13)
                .background(SGV5PostPurchaseStyle.raised, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(SGV5PostPurchaseStyle.primary.opacity(0.06)))
                .rotationEffect(.degrees(index == 1 ? 1.5 : -1))
            }
        }.padding(.vertical, 8).accessibilityElement(children: .ignore).accessibilityLabel("Example Study Guard study reminders and app-unlock notifications")
    }
}

struct SGV5PostPurchaseAppsIllustration: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 15) {
                appTile("play.rectangle.fill", color: Color(red: 0.55, green: 0.45, blue: 0.38), angle: -10)
                appTile("bubble.left.and.bubble.right.fill", color: Color(red: 0.39, green: 0.52, blue: 0.45), angle: 5)
                appTile("safari.fill", color: SGTheme.paperSecondary, angle: 12)
            }
            Image(systemName: "lock.shield.fill").font(.system(size: 36, weight: .light))
                .foregroundStyle(SGV5PostPurchaseStyle.accent.opacity(0.7))
        }.padding(.vertical, 18).accessibilityHidden(true)
    }

    private func appTile(_ symbol: String, color: Color, angle: Double) -> some View {
        Image(systemName: symbol).font(.system(size: 27, weight: .medium)).foregroundStyle(SGTheme.paper)
            .frame(width: 65, height: 65)
            .background(LinearGradient(colors: [color.opacity(0.65), color], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: color.opacity(0.24), radius: 10, y: 9)
            .rotationEffect(.degrees(angle))
    }
}
