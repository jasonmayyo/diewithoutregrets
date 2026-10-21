// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4FounderStoryView.swift
//  OneThing
//
//  Screen 233 (V4): Founder story — Jason & Jude.
//  Personal connection before paywall.
//

import SwiftUI

struct SGV5V4FounderStoryView: View {
    @ObservedObject var viewModel: SGV5FlowModel

    @State private var showPhoto = false
    @State private var showQuote = false
    @State private var showNames = false
    @State private var showMissionCard = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 20) {
                    founderHeadshot(imageName: "jason1")
                    founderHeadshot(imageName: "jude")
                }
                .opacity(showPhoto ? 1 : 0)
                .scaleEffect(showPhoto ? 1 : 0.8)
                .animation(.easeOut(duration: 0.8), value: showPhoto)

                Spacer().frame(height: 28)

                Text("\"We built One Thing because we\nwere tired of losing our best years\nto a screen. We hope it helps you\nas much as it helped us.\"")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(SGTheme.paper.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
                    .opacity(showQuote ? 1 : 0)
                    .offset(y: showQuote ? 0 : 15)
                    .animation(.easeOut(duration: 0.7), value: showQuote)

                Spacer().frame(height: 20)

                VStack(spacing: 4) {
                    Text("Jason & Jude")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(SGTheme.paper)
                    Text("Co-Founders, One Thing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SGTheme.paper.opacity(0.35))
                }
                .opacity(showNames ? 1 : 0)
                .offset(y: showNames ? 0 : 12)
                .animation(.easeOut(duration: 0.55), value: showNames)

                Spacer()

                missionCard
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .opacity(showMissionCard ? 1 : 0)
                    .offset(y: showMissionCard ? 0 : 18)
                    .animation(.easeOut(duration: 0.55), value: showMissionCard)

                Button(action: {
                    viewModel.trackScreenAction(screenId: viewModel.currentPageIndex, action: "founder_story_continue")
                    viewModel.nextPage()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(SGTheme.paper)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(SGTheme.mint)
                        .cornerRadius(28)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeOut(duration: 0.5), value: showButton)
                .sgV5FloatingCTA()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showPhoto = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showQuote = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showNames = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) { showMissionCard = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) { showButton = true }
        }
    }

    private var missionCard: some View {
        Text("No investors. No other employees. Just us, trying to help people live more and scroll less.")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(SGTheme.paper.opacity(0.72))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SGTheme.paper.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SGTheme.paper.opacity(0.1), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func founderHeadshot(imageName: String) -> some View {
        Image(SGV5Assets.name(imageName))
            .resizable()
            .scaledToFill()
            .frame(width: 130, height: 130)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(SGTheme.paper.opacity(0.1), lineWidth: 1)
            )
    }
}


