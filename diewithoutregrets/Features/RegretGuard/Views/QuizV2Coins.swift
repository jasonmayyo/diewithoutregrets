//
//  QuizV2Coins.swift
//  diewithoutregrets
//
//  The earn moment of the blocking-flow redesign: every correct CHECK
//  bursts a flock of time-coins (hourglass stickers) out of the button,
//  then arcs them one by one into the earned-time chip beside the
//  progress bar. Each coin banks with an escalating haptic tick, pulses
//  the chip, and rolls the numeral up.
//
//  Pure choreography: QuizV2View spawns the flock and owns the displayed
//  total. Nothing here touches the quiz machine or the grant.
//
//  Flight is the two-curve trick: x and y are separate offsets driven by
//  separate withAnimation transactions (x eases out while y eases in), so
//  two straight-line moves compose into a swoop that bows outward and
//  funnels vertically into the chip.
//

import SwiftUI

// MARK: - Coin model

/// One coin of a burst flock. All randomness is rolled at spawn so the
/// flight is deterministic once airborne.
struct QV2CoinModel: Identifiable {
    let id: Int
    /// Position in the flock; drives the collect stagger and haptic ramp.
    let index: Int
    let flockSize: Int
    /// The card this flock was earned on. Stragglers can bank while the
    /// next card is already up; the tag keeps them from touching that
    /// card's progress gate.
    let cardIndex: Int
    /// Where the burst throws this coin, relative to the spawn point.
    let scatter: CGSize
    /// Resting tilt after the burst (degrees).
    let spin: Double
    /// Tilt it straightens to over the collect flight (degrees).
    let spinTravel: Double
    /// Seconds from spawn until this coin leaves for the chip.
    let collectDelay: Double

    /// Roll one burst flock. `serial` keeps ids unique across bursts.
    static func flock(of size: Int, serial: Int, cardIndex: Int = 0) -> [QV2CoinModel] {
        (0..<size).map { i in
            QV2CoinModel(
                id: serial * 100 + i,
                index: i,
                flockSize: size,
                cardIndex: cardIndex,
                scatter: CGSize(width: .random(in: -76...76), height: .random(in: -54 ... -10)),
                spin: .random(in: -26...26),
                spinTravel: .random(in: -16...16),
                collectDelay: 0.42 + Double(i) * 0.085
            )
        }
    }
}

// MARK: - Earned-time chip

/// The header counter the coins fly into: hourglass + screen time earned
/// this run. Pulses and flashes amber every time a coin banks.
struct QV2EarnedChip: View {
    let seconds: Int
    /// Cumulative banked count; each change plays one pulse.
    let bump: Int

    @State private var scale: CGFloat = 1
    @State private var flash = false
    /// Coins bank faster than one pulse plays; the generation invalidates
    /// a superseded pulse's settle timers so each bank reads as its own pop.
    @State private var pulseGeneration = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            Image("sticker-hourglass")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(Self.label(seconds: seconds))
                .font(QV2.font(16, .bold))
                .monospacedDigit()
                .foregroundColor(flash ? QV2.orange : QV2.text)
                .contentTransition(.numericText(countsDown: false))
        }
        .padding(.leading, 9)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white))
        .overlay(Capsule().strokeBorder(flash ? QV2.orange : QV2.tileBorder, lineWidth: 2))
        .scaleEffect(scale)
        .onChange(of: bump) { _, _ in pulse() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Self.spokenLabel(seconds: seconds)) earned")
    }

    /// Compact time label: "45s", "1m 30s", "5m".
    static func label(seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    static func spokenLabel(seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) seconds" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m) minutes" : "\(m) minutes \(s) seconds"
    }

    private func pulse() {
        guard !reduceMotion else { return }
        pulseGeneration += 1
        let generation = pulseGeneration

        // Snap back to rest so back-to-back banks each get a visible pop
        // (a same-value write would otherwise animate nothing).
        var restart = Transaction()
        restart.disablesAnimations = true
        withTransaction(restart) { scale = 1 }

        withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) {
            scale = 1.18
            flash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard generation == pulseGeneration else { return }
            withAnimation(SGTheme.springFast) { scale = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard generation == pulseGeneration else { return }
            withAnimation(.easeOut(duration: 0.25)) { flash = false }
        }
    }
}

// MARK: - Global frame reader

/// The RegretGuard measurement idiom, packaged: reads a view's global
/// frame into state via .background. Consumers no-op while the frame is
/// still .zero.
struct QV2GlobalFrameReader: View {
    let onChange: (CGRect) -> Void

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear
                .onAppear { onChange(frame) }
                .onChange(of: frame) { _, newFrame in onChange(newFrame) }
        }
    }
}

// MARK: - Flight overlay

/// Full-bleed, hit-transparent layer the coins fly across. Frames arrive
/// in global coordinates (from QV2GlobalFrameReader) and are converted to
/// the overlay's space here; unmeasured frames fall back to sensible
/// screen fractions so the flight never targets the origin.
struct QV2CoinFlightOverlay: View {
    let coins: [QV2CoinModel]
    /// Global frame of the CHECK button the flock erupts from.
    let spawnFrame: CGRect
    /// Global frame of the earned-time chip the flock funnels into.
    let targetFrame: CGRect
    let onLand: (QV2CoinModel) -> Void

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let spawn = spawnFrame.isEmpty
                ? CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.8)
                : CGPoint(x: spawnFrame.midX - origin.x, y: spawnFrame.midY - origin.y)
            let target = targetFrame.isEmpty
                ? CGPoint(x: geo.size.width - 56, y: 40)
                : CGPoint(x: targetFrame.midX - origin.x, y: targetFrame.midY - origin.y)

            ZStack {
                ForEach(coins) { coin in
                    QV2FlyingCoin(coin: coin, spawn: spawn, target: target, onLand: onLand)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - One coin

private struct QV2FlyingCoin: View {
    let coin: QV2CoinModel
    let spawn: CGPoint
    let target: CGPoint
    let onLand: (QV2CoinModel) -> Void

    /// Burst: popped out of the button to its scatter slot.
    @State private var popped = false
    /// Collect: airborne toward the chip, one flag per axis so each can
    /// carry its own curve (see file header).
    @State private var flyX = false
    @State private var flyY = false
    /// Banked: shrink-and-vanish into the chip.
    @State private var banked = false

    private let flightTime = 0.5

    var body: some View {
        Image("sticker-hourglass")
            .resizable()
            .scaledToFit()
            .frame(width: 33, height: 33)
            .rotationEffect(.degrees(flyX ? coin.spinTravel : coin.spin))
            .scaleEffect(banked ? 0.2 : (flyX ? 0.78 : (popped ? 1 : 0.1)))
            .opacity(banked ? 0 : (popped ? 1 : 0))
            .offset(x: flyX ? target.x - spawn.x : (popped ? coin.scatter.width : 0))
            .offset(y: flyY ? target.y - spawn.y : (popped ? coin.scatter.height : 0))
            .position(spawn)
            .onAppear(perform: fly)
    }

    private func fly() {
        withAnimation(SGTheme.springPop) { popped = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + coin.collectDelay) {
            withAnimation(.easeOut(duration: flightTime)) { flyX = true }
            withAnimation(.easeIn(duration: flightTime)) { flyY = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + coin.collectDelay + flightTime) {
            onLand(coin)
            withAnimation(.easeOut(duration: 0.16)) { banked = true }
        }
    }
}

// MARK: - Previews

#if DEBUG
/// Standalone playground: tap CHECK to fire a flock at the chip. Same
/// spawn/bank flow as QuizV2View, minus the quiz machine.
private struct QV2CoinPlayground: View {
    @State private var coins: [QV2CoinModel] = []
    @State private var seconds = 0
    @State private var banked = 0
    @State private var chipFrame: CGRect = .zero
    @State private var ctaFrame: CGRect = .zero
    @State private var serial = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            QV2.canvas.ignoresSafeArea()

            VStack {
                HStack(spacing: 16) {
                    Image(systemName: "xmark")
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundColor(QV2.chrome)
                        .frame(width: 44, height: 44)
                    Capsule().fill(QV2.track).frame(height: 16)
                    QV2EarnedChip(seconds: seconds, bump: banked)
                        .background(QV2GlobalFrameReader { chipFrame = $0 })
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                Spacer()
            }

            QV2CTAButton(title: "CHECK") { burst() }
                .background(QV2GlobalFrameReader { ctaFrame = $0 })
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .overlay {
            QV2CoinFlightOverlay(
                coins: coins,
                spawnFrame: ctaFrame,
                targetFrame: chipFrame
            ) { coin in
                QuizHaptics.coinLand(progress: Double(coin.index + 1) / Double(coin.flockSize))
                withAnimation(SGTheme.springPop) {
                    seconds += SGContract.defaultPerCardSeconds / coin.flockSize
                    banked += 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    coins.removeAll { $0.id == coin.id }
                }
            }
        }
    }

    private func burst() {
        serial += 1
        coins.append(contentsOf: QV2CoinModel.flock(of: 5, serial: serial))
    }
}

#Preview("Coin collect playground") {
    QV2CoinPlayground()
}
#endif
