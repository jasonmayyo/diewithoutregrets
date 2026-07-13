//
//  MascotView.swift
//  diewithoutregrets
//
//  The Study Guard monster. Wraps the bundled Lottie set with a pose enum;
//  plays a limited number of loops then holds the last frame (battery +
//  fatigue), and falls back to the PNG stills under Reduce Motion.
//

import SwiftUI
import Lottie

enum MascotPose: String {
    /// Content, gently bouncing — home while metering, celebrations.
    case idle = "1_idle"
    /// Head down, disappointed — locked states, empty states.
    case lookingDown = "2_Looking down"
    /// Taking notes — decks, checklists, setup steps.
    case clipboard = "3_clipboard"
    /// At the whiteboard — practice, AI generation, how-it-works.
    case teaching = "4_teaching"

    /// Matching PNG still bundled alongside the Lottie JSON.
    var stillName: String { rawValue }
}

struct MascotView: View {
    let pose: MascotPose
    /// Loops before holding the last frame. Nil = loop forever.
    var loops: Int? = 3
    var speed: CGFloat = 1.0
    /// Bump to replay the animation from frame 0 without changing pose —
    /// e.g. the clipboard monster jotting a note each time an answer is picked.
    var replayKey: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                still
            } else {
                LottieAnimationRepresentable(
                    animationName: pose.rawValue,
                    loopMode: loops.map { LottieLoopMode.repeat(Float($0)) } ?? .loop,
                    speed: speed
                )
                // LottieAnimationRepresentable.updateUIView is a no-op —
                // identity change is what makes pose switching (and replay) work.
                .id("\(pose.rawValue)#\(replayKey)")
            }
        }
        .accessibilityHidden(true)
    }

    private var still: some View {
        Group {
            if let image = UIImage(named: pose.stillName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

/// The static angry mascot (asset catalog) — shield still + lock overlay.
struct AngryMascotImage: View {
    var body: some View {
        Image("angry-instagram")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
