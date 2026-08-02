//
//  HowItWorksView.swift
//  diewithoutregrets
//
//  Onboarding v2 — CoreMechanicView: THE core-mechanic demo. Four beats on
//  a mini meadow stage (giant minutes readout + a lockable app-tile row):
//  time runs out and apps lock, flashcards earn it back, scrolling spends
//  it, studying is the only way back in. Continue advances beat by beat.
//

import SwiftUI

struct CoreMechanicView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    @State private var started = false
    @State private var beat = 1
    @State private var ctaVisible = false

    // Stage state
    @State private var minutes = 15
    @State private var countsDown = true
    @State private var readoutTint: Color = SGTheme.paper
    @State private var locked = [false, false, false, false]
    @State private var showGain = false

    // Companion slot state
    @State private var mascotPose: MascotPose?
    @State private var showAngry = false
    @State private var showFlashcard = false
    @State private var cardFlipped = false

    // Real app icons (shared with OneThing's asset set) so the demo shows
    // the apps students actually lose their time to.
    private let tiles = ["Instagram", "TikTok", "YouTube", "Snapchat"]

    var body: some View {
        VStack(spacing: 0) {
            // Header — swaps per beat with a crossfade.
            VStack(spacing: 8) {
                Text(beatTitle)
                    .font(SGTheme.stepTitle)
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Text(beatSub)
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .frame(minHeight: 116, alignment: .top)
            .id(beat)
            .transition(.opacity)

            Spacer()

            stage
                .padding(.horizontal, SGTheme.screenPadding)

            companionRow
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 18)

            Spacer()

            OnbCTA(title: "Continue", visible: ctaVisible) {
                advance()
            }
            .padding(.bottom, 12)
        }
        .onAppear {
            guard !started else { return }
            started = true
            startBeat(1)
        }
    }

    // MARK: - Stage

    /// The demo stage, stripped of chrome: the giant readout floats on the
    /// open canvas with the four real app icons in a row beneath it. No
    /// card, no hill; the type and icons carry the whole beat.
    private var stage: some View {
        VStack(spacing: 0) {
            Text("\(minutes)m")
                .font(SGTheme.display(68))
                .monospacedDigit()
                .foregroundColor(readoutTint)
                .contentTransition(.numericText(countsDown: countsDown))
                .animation(.easeInOut(duration: 0.35), value: readoutTint)
                .overlay(alignment: .topTrailing) {
                    if showGain {
                        Text("+15m")
                            .font(SGTheme.display(18))
                            .foregroundColor(SGTheme.mintDeep)
                            .offset(x: 44, y: 18)
                            .transition(.asymmetric(
                                insertion: .offset(y: 12).combined(with: .opacity),
                                removal: .offset(y: -16).combined(with: .opacity)
                            ))
                    }
                }

            Text("scroll time left")
                .font(SGTheme.micro)
                .tracking(1.5)
                .foregroundColor(SGTheme.paperTertiary)
                .textCase(.uppercase)
                .padding(.top, 2)

            HStack(spacing: 16) {
                ForEach(tiles.indices, id: \.self) { index in
                    AppDemoTile(imageName: tiles[index],
                                locked: locked[index])
                }
            }
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity)
    }

    /// Beside the stage: the mascot (or the angry still) plus the flashcard
    /// chip during beat 2. Fixed height so beats never shift the layout.
    private var companionRow: some View {
        HStack(spacing: 16) {
            ZStack {
                if let pose = mascotPose {
                    MascotView(pose: pose, loops: nil)
                        .frame(width: 120, height: 120)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                if showAngry {
                    Image("angry-instagram")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .frame(width: 120, height: 120)

            if showFlashcard {
                FlashcardDemoChip(flipped: cardFlipped)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 124)
    }

    // MARK: - Copy

    private var beatTitle: String {
        switch beat {
        case 1: return "When your scroll time runs out, your apps lock."
        case 2: return "Answer your flashcards to earn time back."
        case 3: return "Scrolling spends your balance."
        default: return "Studying is the only way back in."
        }
    }

    private var beatSub: String {
        switch beat {
        case 1: return "Automatically. No snooze, no \u{201C}five more minutes.\u{201D}"
        case 2: return "Answer correctly and your apps open again."
        case 3: return "The only screen time you get is time you earned."
        default: return "Zero willpower needed. It's just how your phone works now."
        }
    }

    // MARK: - Advancement

    private func advance() {
        if beat < 4 {
            viewModel.screenAction("beat_advanced", properties: ["beat": beat])
            withAnimation(.easeInOut(duration: 0.3)) { beat += 1 }
            startBeat(beat)
        } else {
            viewModel.screenAction("mechanic_complete")
            viewModel.nextStep()
        }
    }

    // MARK: - Choreography

    private func startBeat(_ n: Int) {
        ctaVisible = false
        let reduced = UIAccessibility.isReduceMotionEnabled

        switch n {
        case 1: startBeat1(reduced: reduced)
        case 2: startBeat2(reduced: reduced)
        case 3: startBeat3(reduced: reduced)
        default: startBeat4(reduced: reduced)
        }
    }

    /// Beat 1: time drains to zero fast, then the tiles lock one by one and
    /// the mascot looks away.
    private func startBeat1(reduced: Bool) {
        if reduced {
            minutes = 0
            readoutTint = SGTheme.paper
            locked = [true, true, true, true]
            mascotPose = .lookingDown
            ctaVisible = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            tickReadout(to: 0, interval: 0.09, up: false, tint: SGTheme.paper) {
                lockTilesSequentially {
                    withAnimation(SGTheme.spring) { mascotPose = .lookingDown }
                    SGTheme.beat()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { ctaVisible = true }
                    }
                }
            }
        }
    }

    /// Beat 2: the flashcard flips Q to A, the readout climbs back to 15 in
    /// green with a floating gain label, the tiles unlock, mascot takes notes.
    private func startBeat2(reduced: Bool) {
        if reduced {
            showFlashcard = true
            cardFlipped = true
            minutes = 15
            countsDown = false
            readoutTint = SGTheme.mintDeep
            locked = [false, false, false, false]
            mascotPose = .clipboard
            ctaVisible = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(SGTheme.spring) { showFlashcard = true }
            SGTheme.gain()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            cardFlipped = true
            SGTheme.beat()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(SGTheme.springFast) { showGain = true }
            tickReadout(to: 15, interval: 0.08, up: true, tint: SGTheme.mintDeep) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.4)) { showGain = false }
                }
                withAnimation(SGTheme.spring) { locked = [false, false, false, false] }
                SGTheme.successHaptic()
                withAnimation(SGTheme.spring) { mascotPose = .clipboard }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { ctaVisible = true }
                }
            }
        }
    }

    /// Beat 3: scrolling drains the balance in ember while the angry
    /// Instagram still pops in.
    private func startBeat3(reduced: Bool) {
        withAnimation(.easeOut(duration: 0.3)) { showFlashcard = false }
        cardFlipped = false

        if reduced {
            minutes = 8
            countsDown = true
            readoutTint = SGTheme.emberDeep
            mascotPose = nil
            showAngry = true
            ctaVisible = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(SGTheme.spring) {
                mascotPose = nil
                showAngry = true
            }
            SGTheme.beat()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            tickReadout(to: 8, interval: 0.14, up: false, tint: SGTheme.emberDeep) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { ctaVisible = true }
                }
            }
        }
    }

    /// Beat 4: everything settles — angry still gone, mascot idle, readout
    /// back to ink.
    private func startBeat4(reduced: Bool) {
        withAnimation(SGTheme.spring) {
            showAngry = false
            mascotPose = .idle
            readoutTint = SGTheme.paper
        }

        if reduced {
            ctaVisible = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { ctaVisible = true }
        }
    }

    // MARK: - Helpers

    private func tickReadout(to target: Int, interval: Double, up: Bool,
                             tint: Color, completion: @escaping () -> Void) {
        countsDown = !up
        readoutTint = tint

        func step() {
            guard minutes != target else {
                completion()
                return
            }
            withAnimation(.easeInOut(duration: 0.12)) {
                minutes += up ? 1 : -1
            }
            if up {
                SGTheme.tickUpHaptic()
            } else {
                SGTheme.tickDownHaptic()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { step() }
        }
        step()
    }

    private func lockTilesSequentially(completion: @escaping () -> Void) {
        for index in locked.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.24) {
                withAnimation(SGTheme.springFast) { locked[index] = true }
                SGTheme.lock()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(locked.count) * 0.24 + 0.2) {
            completion()
        }
    }
}

// MARK: - Pieces

/// Real app icon tile that grays out under a lock when the balance hits zero.
private struct AppDemoTile: View {
    let imageName: String
    let locked: Bool

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous))
            .grayscale(locked ? 1 : 0)
            .opacity(locked ? 0.55 : 1)
            .overlay {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(SGTheme.display(18))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                }
            }
            .sgShadow(SGTheme.shadowCard)
    }
}

/// The demo flashcard: question on the front, answer on the back, 3D flip.
private struct FlashcardDemoChip: View {
    let flipped: Bool

    var body: some View {
        ZStack {
            side(label: "Q", text: "What powers a cell?",
                 fill: SGTheme.ink, accent: SGTheme.paperTertiary)
                .opacity(flipped ? 0 : 1)

            side(label: "A", text: "Mitochondria",
                 fill: SGTheme.mintTint, accent: SGTheme.mintDeep)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: flipped)
    }

    private func side(label: String, text: String, fill: Color, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(SGTheme.micro)
                .foregroundColor(accent)
            Text(text)
                .font(SGTheme.rowLabel)
                .foregroundColor(SGTheme.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
                .sgShadow(SGTheme.shadowCard)
        )
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        CoreMechanicView()
            .environmentObject(OnboardingViewModel())
    }
}
