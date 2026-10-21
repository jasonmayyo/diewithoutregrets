// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4ScienceBackedView.swift
//  OneThing
//
//  Screen 225 (V4): Science-backed credibility screen.
//  Introduces the One Thing Method as science-backed before the feature walkthrough.
//

import SwiftUI

struct SGV5V4ScienceBackedView: View {
    @ObservedObject var viewModel: SGV5FlowModel

    @State private var showGhost = false
    @State private var showHeadline = false
    @State private var showDivider = false
    @State private var showLogos = false
    @State private var showFootnote = false
    @State private var showButton = false
    @State private var glowPulse = false

    private let goldAccent = SGTheme.mint

    /// Harvard, UCL, ScienceDirect (Elsevier “E”) — same slot size, no chrome.
    private let institutionIconNames = ["Harvard", "ucl", "sciencedirect"]
    private let institutionIconSlot: CGFloat = 80

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .onAppear { startSequence() }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            SGTheme.ink
                .ignoresSafeArea()

            // Subtle warm radial glow behind the ghost
            RadialGradient(
                colors: [
                    goldAccent.opacity(glowPulse ? 0.06 : 0.03),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: glowPulse)
        }
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(spacing: 0) {
            Spacer()

            floatingGhostHeader
                .padding(.bottom, 28)

            // Headline
            VStack(spacing: 12) {
                Text("Study Guard Method")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)

                Text("Built on proven science, grounded in behavioral research from the world's leading institutions.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SGTheme.paper.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            .opacity(showHeadline ? 1 : 0)
            .offset(y: showHeadline ? 0 : 15)
            .animation(.easeOut(duration: 0.7), value: showHeadline)

            Spacer().frame(height: 36)

            // Divider line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, goldAccent.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 48)
                .opacity(showDivider ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: showDivider)

            Spacer().frame(height: 28)

            // Research footnote
            Text("Based on research in habit formation,\ndigital wellness & behavioral psychology")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(SGTheme.paper.opacity(0.25))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .opacity(showFootnote ? 1 : 0)
                .animation(.easeOut(duration: 0.5), value: showFootnote)

            Spacer().frame(height: 28)

            institutionLogosRow
                .padding(.horizontal, 24)
                .opacity(showLogos ? 1 : 0)
                .offset(y: showLogos ? 0 : 12)
                .animation(.easeOut(duration: 0.7), value: showLogos)

            Spacer()

            // CTA
            SGV5QuizContinueButton {
                viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "science_continue_tapped")
                viewModel.nextPage()
            }
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
            .animation(.easeOut(duration: 0.5), value: showButton)
            .sgV5FloatingCTA()
        }
    }

    // MARK: - Floating ghost (ghost-science)

    private var floatingGhostHeader: some View {
        SGV5FloatingGhostScienceImage()
            .opacity(showGhost ? 1 : 0)
            .scaleEffect(showGhost ? 1 : 0.75)
            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: showGhost)
            .frame(height: 160)
    }

    // MARK: - Institution marks (static row)

    private var institutionLogosRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(institutionIconNames.enumerated()), id: \.offset) { _, name in
                Image(SGV5Assets.name(name))
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: institutionIconSlot, height: institutionIconSlot)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Animation Sequence

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showGhost = true
            glowPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showHeadline = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showDivider = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showFootnote = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            showLogos = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showButton = true
        }
    }
}

// MARK: - Floating ghost-science

private struct SGV5FloatingGhostScienceImage: View {
    @State private var floating = false

    private let baseHeight: CGFloat = 150

    var body: some View {
        Image(SGV5Assets.name("ghost-science"))
            .resizable()
            .scaledToFit()
            .blendMode(.multiply)
            .frame(height: baseHeight)
            .offset(y: floating ? -7 : 7)
            .animation(
                .easeInOut(duration: 2.6).repeatForever(autoreverses: true),
                value: floating
            )
            .onAppear { floating = true }
    }
}


