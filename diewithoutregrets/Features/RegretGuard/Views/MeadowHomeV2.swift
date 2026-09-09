//
//  MeadowHomeV2.swift
//  diewithoutregrets
//
//  Home redesign, screenshot-matched to the approved reference: title +
//  streak pinned at the top, the animated clouds sky behind the mascot on
//  the illustrated grass hill (meadow-grass asset, transparent sky), the
//  giant outlined time-left readout over its progress bar, then the live
//  guard setup: stat cards (screen time used, guarded apps, per-unlock
//  interval), the active deck card, and the locked-apps chips. Everything
//  below the hero reads real engine state; taps route to the same sheets
//  RegretGuard already owns. The palette stays local to this file until
//  the direction is locked, then it graduates into SGTheme.
//

import SwiftUI
import FamilyControls
import DeviceActivity
import Lottie

extension DeviceActivityReport.Context {
    /// Must match the context declared in StudyGuardReport's
    /// TopOffendersReport scene — the system pairs them by raw value.
    static let topOffenders = Self("Top Offenders")
}

// MARK: - Palette (screenshot-matched)

private enum MH {
    static let sky = Color(hex: 0x82C9EC)
    static let ink = Color(hex: 0x1C1C1C)             // title, big percent
    static let cardFill = Color.black.opacity(0.14)   // stat + offender slabs
    static let track = Color.black.opacity(0.16)      // progress track
    static let fill = Color(hex: 0xDCF9CB)            // progress fill
    static let label = Color.white.opacity(0.85)      // card captions

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Screen

struct MeadowHomeV2: View {
    @ObservedObject private var guardManager = StudyGuardManager.shared
    /// RegretGuard's countdown replay model — the same engine the legacy
    /// home used: syncs to the guard's remaining minutes, rolls the readout
    /// when a checkpoint replays, and fires the lock reveal on settle.
    @ObservedObject var countdown: CountdownReplayModel
    @ObservedObject private var deckStore = DeckStore.shared

    // Taps route into RegretGuard's existing sheet/alert stack (deck
    // picker, guarded-apps editor with its locked-edit alert, interval
    // sheet, new-deck flow) — no duplicated presentation logic here.
    var onDeckTap: () -> Void = {}
    var onCreateDeck: () -> Void = {}
    var onAppsTap: () -> Void = {}
    var onIntervalTap: () -> Void = {}

    /// The real streak ledger (QV2Streak, written at each quiz grant).
    /// current() reads 0 once a missed day breaks the chain; computed per
    /// render so returning from a winning quiz always shows the new count.
    private var streak: Int { QV2Streak.current() }

    /// "1h 5m" / "47m" — the minutes the guard actually has on the clock.
    /// Minutes are the app's real currency (flashcards buy 10-15m grants),
    /// so the hero shows time, not a percentage.
    private var timeLeftText: String {
        let left = max(0, countdown.displayMinutes)
        return left >= 60 ? "\(left / 60)h \(left % 60)m" : "\(left)m"
    }

    /// Fraction of the granted budget still unspent, for the progress bar.
    private var timeLeftFraction: Double {
        guard guardManager.totalMinutes > 0 else { return 1 }
        return max(0, min(1, Double(countdown.displayMinutes) / Double(guardManager.totalMinutes)))
    }

    private var screenTimeText: String {
        let used = max(0, guardManager.usedMinutes)
        return used >= 60 ? "\(used / 60)h \(used % 60)m" : "\(used)m"
    }

    private var guardedCount: Int {
        SGContract.tokenCount(guardManager.selection)
    }

    private var activeDeck: Deck? {
        deckStore.selectedDeck ?? deckStore.decks.first
    }

    private static var windowTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 59
    }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.top, 2)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Reserved for the FIXED mascot overlaid below —
                        // he stays put while the content scrolls under him.
                        Color.clear.frame(height: mascotReserve)

                        percentBlock

                        progressBar
                            .padding(.horizontal, SGTheme.screenPadding)
                            .padding(.top, 16)

                        statCards
                            .padding(.horizontal, SGTheme.screenPadding)
                            .padding(.top, 16)

                        deckSection
                            .padding(.horizontal, SGTheme.screenPadding)
                            .padding(.top, 20)

                        appsSection
                            .padding(.horizontal, SGTheme.screenPadding)
                            .padding(.top, 16)

                        if guardManager.isSetupComplete {
                            topOffendersSection
                                .padding(.horizontal, SGTheme.screenPadding)
                                .padding(.top, 16)
                        }

                        Color.clear.frame(height: SGTheme.tabBarClearance + 12)
                    }
                }
                #if DEBUG
                // Screenshot harness: open the page pre-scrolled to the end.
                .defaultScrollAnchor(
                    ProcessInfo.processInfo.arguments.contains("-sg-scroll-bottom")
                        ? .bottom : .top
                )
                #endif
                // Scrolled content dissolves just above the minutes' rest
                // position instead of sliding through the mascot.
                .mask(scrollFade)
                .overlay(alignment: .top) {
                    mascot
                        .padding(.top, 36)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Height reserved at the top of the scroll content for the fixed
    /// mascot: top gap + frame + gap to the readout.
    private let mascotReserve: CGFloat = 215

    /// Opaque below the minutes' rest position, dissolving to clear over
    /// the band just above it (under the mascot's feet).
    private var scrollFade: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.62),
                    .init(color: .black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: mascotReserve - 6)
            Color.black
        }
    }

    // MARK: Backdrop

    /// Sky + drifting clouds behind everything; the illustrated grass hill
    /// (transparent sky in the asset) rides over the clouds and under the
    /// content.
    private var backdrop: some View {
        ZStack {
            MH.sky.ignoresSafeArea()

            LottieView {
                try await DotLottieFile.named("Clouds")
            }
            .playing(loopMode: .loop)
            .animationSpeed(0.4)
            .configure { $0.contentMode = .scaleAspectFill }
            .ignoresSafeArea()

            // Oversized and bottom-pinned: scaling the art up ~20% raises
            // the hill crest, trading sky for land.
            GeometryReader { geo in
                Image("meadow-grass")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height * 1.2)
                    // Crest tuned to cross the mascot's middle: half of him
                    // in the sky, half on the grass.
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.43)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            // Thin outline (vs the percent's chunky one) — enough for the
            // sticker read without going bubble-letter.
            OutlinedText(text: "STUDY GUARD", size: 30, outlineWidth: 1.6)

            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image("sticker-fire")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    OutlinedText(text: "\(streak)", size: 17, outlineWidth: 1.4)
                }
            }
        }
    }

    // MARK: Mascot

    /// Under 60% of the budget left, he's caught doomscrolling — the
    /// looking-down-at-phone loop replaces the content idle bounce.
    private var isDoomscrolling: Bool {
        timeLeftFraction < 0.6
    }

    private var mascot: some View {
        // The stacked white shadows trace the character's silhouette into
        // the same sticker outline the icon set wears, lifting him off the
        // busy meadow. Each pose is split into char + shadow Lotties (the
        // outline would trace a baked ground shadow into a white puddle),
        // so the ground shadow renders untouched underneath.
        ZStack {
            LottieAnimationRepresentable(
                animationName: isDoomscrolling ? "2_Looking down_shadow" : "1_idle_shadow",
                loopMode: .loop,
                speed: 1.0
            )
            .frame(width: 165, height: 165)
            // Dropped so the ground shadow peeks out below his feet
            // instead of hiding entirely behind the body.
            .offset(y: 10)
            .id("mascot-shadow-\(isDoomscrolling)")

            LottieAnimationRepresentable(
                animationName: isDoomscrolling ? "2_Looking down_char" : "1_idle_char",
                loopMode: .loop,
                speed: 1.0
            )
            .frame(width: 165, height: 165)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .white, radius: 0.8)
            .shadow(color: .black.opacity(0.15), radius: 12, y: 5)
            .id("mascot-char-\(isDoomscrolling)")
        }
        .animation(.easeInOut(duration: 0.25), value: isDoomscrolling)
    }

    // MARK: Percent + progress

    private var percentBlock: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                OutlinedText(text: timeLeftText, size: 72, fill: .white, outline: .clear)
                    .scaleEffect(countdown.isRolling ? 1.06 : 1)
                    .animation(SGTheme.springFast, value: countdown.isRolling)

                // "−5" / "+15" drifting off the readout on budget events.
                if let delta = countdown.delta {
                    CountdownDeltaLabel(event: delta)
                        .offset(x: 54, y: -20)
                        .id(delta.id)
                }
            }

            Text("screen time left")
                .font(MH.font(14, .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(MH.track)
                Capsule(style: .continuous)
                    .fill(MH.fill)
                    .frame(width: max(14, proxy.size.width * timeLeftFraction))
                    .padding(2)
            }
            .animation(SGTheme.spring, value: timeLeftFraction)
        }
        .frame(height: 16)
    }

    // MARK: Stat cards

    private var statCards: some View {
        HStack(spacing: 12) {
            statCard(icon: "sticker-skull", value: screenTimeText, label: "Screen Time")
            statCard(icon: "sticker-iphone", value: "\(guardedCount)", label: "Guarded Apps",
                     action: onAppsTap)
            statCard(icon: "sticker-stopwatch", value: "\(guardManager.intervalMinutes)m",
                     label: "Per Unlock", action: onIntervalTap)
        }
    }

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String,
                          action: (() -> Void)? = nil) -> some View {
        let body = VStack(spacing: 4) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

            Text(value)
                .font(MH.font(18, .black))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MH.font(11, .bold))
                .foregroundColor(MH.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MH.cardFill)
        )

        if let action {
            Button(action: action) { body }
                .buttonStyle(SGPressStyle())
        } else {
            body
        }
    }

    // MARK: Active deck

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Active Deck")

            Button(action: activeDeck == nil ? onCreateDeck : onDeckTap) {
                HStack(spacing: 12) {
                    Image("sticker-books")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)

                    if let deck = activeDeck {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(deck.name)
                                .font(MH.font(15, .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(deck.cards.count == 1
                                 ? "1 card. Answering it unlocks your apps"
                                 : "\(deck.cards.count) cards. Answering them unlocks your apps")
                                .font(MH.font(11, .semibold))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Create your first deck")
                                .font(MH.font(15, .bold))
                                .foregroundColor(.white)
                            Text("You'll answer these cards to unlock your apps")
                                .font(MH.font(11, .semibold))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }

                    Spacer()

                    Image(systemName: activeDeck == nil ? "plus" : "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(MH.cardFill)
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(SGPressStyle())
        }
    }

    // MARK: Locked apps

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Guarded Apps")

            Button(action: onAppsTap) {
                Group {
                    if guardedCount == 0 {
                        HStack(spacing: 12) {
                            Image("sticker-lock")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Pick apps to guard")
                                    .font(MH.font(15, .bold))
                                    .foregroundColor(.white)
                                Text("They lock when your screen time runs out")
                                    .font(MH.font(11, .semibold))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        appChips
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(MH.cardFill)
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(SGPressStyle())
        }
    }

    /// Real token chips (FamilyControls renders each app's own icon+name)
    /// — the actual apps the shield locks, not stand-ins.
    private var appChips: some View {
        let maxChips = 6
        let apps = Array(guardManager.selection.applicationTokens)
        let categories = Array(guardManager.selection.categoryTokens)
        let visibleApps = Array(apps.prefix(maxChips))
        let visibleCategories = Array(categories.prefix(max(0, maxChips - visibleApps.count)))
        let overflow = guardedCount - visibleApps.count - visibleCategories.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8, alignment: .leading)],
                         alignment: .leading, spacing: 8) {
            ForEach(visibleApps, id: \.self) { token in
                appChip { Label(token) }
            }
            ForEach(visibleCategories, id: \.self) { token in
                appChip { Label(token) }
            }
            if overflow > 0 {
                appChip { Text("+\(overflow) more") }
            }
        }
    }

    private func appChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(MH.font(12, .bold))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(.white.opacity(0.16)))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(MH.font(18, .black))
            .foregroundColor(.white)
    }

    // MARK: Top offenders

    /// Today's most-used apps, rendered by the StudyGuardReport extension
    /// (per-app usage is only readable inside a DeviceActivityReport
    /// scene; the app process never sees the numbers). The extension draws
    /// transparent rows styled for this slab; the report loads
    /// asynchronously, so the slab sits empty for a beat on first scroll.
    /// Renders nothing in the Simulator — Screen Time data needs hardware.
    private var topOffendersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Top Offenders")

            DeviceActivityReport(.topOffenders, filter: topOffendersFilter)
                .frame(height: 318)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(MH.cardFill)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var topOffendersFilter: DeviceActivityFilter {
        let day = Calendar.current.dateInterval(of: .day, for: Date())
            ?? DateInterval(start: Date(), end: Date())
        return DeviceActivityFilter(
            segment: .daily(during: day),
            devices: .init([.iPhone])
        )
    }
}

// MARK: - Outlined display text

/// Chunky black display text with the white sticker outline from the
/// reference — eight offset white copies underneath fake a smooth stroke
/// (SwiftUI has no first-class text stroke).
private struct OutlinedText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .black
    var fill: Color = MH.ink
    var outline: Color = .white
    var outlineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = CGFloat(i) * .pi / 4
                styled(Text(text))
                    .foregroundColor(outline)
                    .offset(x: cos(angle) * outlineWidth,
                            y: sin(angle) * outlineWidth)
            }
            styled(Text(text))
                .foregroundColor(fill)
        }
    }

    /// Shared per-copy styling — numericText so countdown rolls morph
    /// digit-by-digit on every layer of the fake stroke at once.
    private func styled(_ text: Text) -> some View {
        text
            .font(MH.font(size, weight))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
    }
}

#Preview("Meadow home v2") {
    MeadowHomeV2(countdown: CountdownReplayModel())
}
