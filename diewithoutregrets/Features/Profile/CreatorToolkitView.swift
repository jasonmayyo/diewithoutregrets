//
//  CreatorToolkitView.swift
//  diewithoutregrets
//
//  Demo controls for creators filming the app. Ships in TestFlight builds
//  (Profile tab, Creator section) so nobody has to spend ten real minutes
//  scrolling to capture a lock: every tool jumps straight to a state or
//  moment. App Store installs never see the entry point (AppEnvironment
//  gate in ProfileView), and the engine helpers behind these buttons are
//  called from nowhere else.
//
//  Staging model: the tools write the same app-group truth the engine
//  uses (never a parallel fake state), then land the user on the Guard
//  tab so the home plays its normal choreography over that truth. The
//  lock reveal is armed or skipped through RegretGuard.lockRevealStampKey,
//  and the countdown story through CountdownReplayModel's truth keys.
//

import SwiftUI

struct CreatorToolkitView: View {
    @ObservedObject private var studyGuard = StudyGuardManager.shared
    @ObservedObject private var navigationModel = NavigationModel.shared
    @AppStorage("sgHomeBackdrop") private var homeBackdrop: String = "dots"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var streak = QV2Streak.current()
    @State private var showResetConfirm = false
    @State private var showOnboardingConfirm = false
    @State private var engineStateExpanded = false

    /// The lock/time/flow tools only make sense with the Screen Time
    /// engine live. Setup and disabled states get the hint card instead.
    private var engineLive: Bool {
        studyGuard.state == .metering || studyGuard.state == .locked
    }

    private var remainingMinutes: Int {
        max(0, studyGuard.totalMinutes - studyGuard.usedMinutes)
    }

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                SGScreenHeader(eyebrow: "Creator tools", title: "Toolkit")

                ScrollView {
                    VStack(alignment: .leading, spacing: SGTheme.sectionSpacing) {
                        introCard

                        if engineLive {
                            lockSection
                            timeSection
                            flowSection
                        } else {
                            setupHintCard
                        }

                        streakSection
                        scenerySection
                        engineSection
                    }
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.top, 14)
                    .padding(.bottom, SGTheme.tabBarClearance)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            studyGuard.refresh()
            streak = QV2Streak.current()
        }
        .confirmationDialog("Reset the Study Guard engine?",
                            isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) {
                studyGuard.debugResetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears setup, guarded apps, budgets and shields. You will run Screen Time setup again from the Guard tab.")
        }
        .confirmationDialog("Replay onboarding?",
                            isPresented: $showOnboardingConfirm,
                            titleVisibility: .visible) {
            Button("Replay onboarding") {
                hasCompletedOnboarding = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app returns to the new user flow immediately. Finish it to come back here.")
        }
    }

    // MARK: - Intro

    private var introCard: some View {
        HStack(spacing: 12) {
            MascotView(pose: .teaching)
                .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 5) {
                SGMicroLabel(text: "For filming", color: SGTheme.mintDeep)
                Text("Skip the waiting")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Text("Stage locks, timers and animations instantly instead of scrolling for ten real minutes.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, SGTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(SGTheme.mint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .strokeBorder(SGTheme.mint.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var setupHintCard: some View {
        SGCard(shadowed: false, dashed: SGTheme.mint) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Engine not running")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Text("Finish Screen Time setup on the Guard tab first. The lock and timer tools drive the real engine, so they need it live.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Lock and unlock

    private var lockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Lock and unlock")

            SGButton(title: "Lock with the full sequence",
                     assetIcon: "sticker-lock",
                     variant: .ember,
                     enabled: studyGuard.state == .metering) {
                playLockSequence()
            }

            SGButton(title: "Lock instantly",
                     variant: .ghost,
                     enabled: studyGuard.state == .metering) {
                lockInstantly()
            }

            SGButton(title: "Unlock and refill time",
                     assetIcon: "sticker-unlock",
                     variant: .mint) {
                unlockNow()
            }

            Text("The full sequence plays on the Guard tab: the countdown rolls to zero, the lock stamps shut and the meadow goes dark. Unlocking counts the fresh minutes back up.")
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Screen time

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Screen time")

            SGCard(shadowed: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image("sticker-timer")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("\(remainingMinutes) of \(studyGuard.totalMinutes) min left")
                            .font(SGTheme.cardTitle)
                            .monospacedDigit()
                            .foregroundColor(SGTheme.paper)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        timeChip(1)
                        timeChip(2)
                        timeChip(5)
                        timeChip(studyGuard.totalMinutes, label: "Full")
                    }

                    Text("Below 60 percent of the budget the mascot switches to his doomscrolling pose. The countdown rolls to the new value next time the Guard tab appears.")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .disabled(studyGuard.state != .metering)
        .opacity(studyGuard.state == .metering ? 1 : 0.5)
    }

    private func timeChip(_ minutes: Int, label: String? = nil) -> some View {
        let selected = remainingMinutes == min(minutes, studyGuard.totalMinutes)
        return Button {
            studyGuard.creatorSetRemaining(minutes: minutes)
            navigationModel.requestedTab = 0
        } label: {
            Text(label ?? "\(minutes) min")
                .font(SGTheme.buttonSmall)
                .foregroundColor(selected ? SGTheme.mintDeep : SGTheme.paper)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(selected ? SGTheme.mint.opacity(0.13) : SGTheme.ink)
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? SGTheme.mint : SGTheme.hairline,
                                lineWidth: selected ? 1.5 : 1)
                        )
                )
        }
        .buttonStyle(SGPressStyle())
    }

    // MARK: - Unlock flows

    private var flowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Unlock flows")

            SGListRow(title: "Open the flashcard quiz",
                      subtitle: "Locks first if needed, then enters the quiz",
                      assetIcon: "sticker-books") {
                openUnlockFlow("flashcards")
            }

            SGListRow(title: "Open True Focus",
                      subtitle: "Locks first if needed, then starts a session",
                      assetIcon: "sticker-eye") {
                openUnlockFlow("trueFocus")
            }

            Text("Finishing either flow earns a real unlock, so the celebration, streak and refill all play exactly as users see them.")
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Streak")

            SGCard(shadowed: false) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image("sticker-fire")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                            .font(SGTheme.cardTitle)
                            .monospacedDigit()
                            .foregroundColor(SGTheme.paper)
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        ForEach([0, 5, 25, 100], id: \.self) { value in
                            streakChip(value)
                        }
                    }

                    Text("Sets the flame counter on the home screen and the number the streak poster rolls to after a win.")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func streakChip(_ value: Int) -> some View {
        let selected = streak == value
        return Button {
            QV2Streak.creatorSet(value)
            streak = QV2Streak.current()
            SGTheme.tapHaptic()
        } label: {
            Text("\(value)")
                .font(SGTheme.buttonSmall)
                .monospacedDigit()
                .foregroundColor(selected ? SGTheme.mintDeep : SGTheme.paper)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(selected ? SGTheme.mint.opacity(0.13) : SGTheme.ink)
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? SGTheme.mint : SGTheme.hairline,
                                lineWidth: selected ? 1.5 : 1)
                        )
                )
        }
        .buttonStyle(SGPressStyle())
    }

    // MARK: - Scenery

    private var scenerySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Home scenery")

            HStack(spacing: 10) {
                SGOptionTile(title: "Dot ripple",
                             icon: "sticker-target",
                             selected: homeBackdrop == "dots") {
                    homeBackdrop = "dots"
                    SGTheme.tapHaptic()
                }
                SGOptionTile(title: "Clouds",
                             icon: "sticker-sun",
                             selected: homeBackdrop == "clouds") {
                    homeBackdrop = "clouds"
                    SGTheme.tapHaptic()
                }
            }
        }
    }

    // MARK: - Engine

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Engine")

            SGListRow(title: "Engine state",
                      subtitle: engineStateExpanded ? nil : "The raw numbers behind the guard",
                      assetIcon: "sticker-info",
                      trailingIcon: engineStateExpanded ? "chevron.up" : "chevron.down") {
                withAnimation(SGTheme.springFast) { engineStateExpanded.toggle() }
            }

            if engineStateExpanded {
                SGCard(shadowed: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(studyGuard.debugStateDump(), id: \.0) { row in
                            dumpRow(row.0, row.1)
                        }
                    }
                }
            }

            SGListRow(title: "Replay onboarding",
                      subtitle: "Back to the full new user flow",
                      assetIcon: "sticker-rocket") {
                showOnboardingConfirm = true
            }

            SGButton(title: "Reset Study Guard engine",
                     variant: .ember,
                     enabled: studyGuard.isSetupComplete) {
                showResetConfirm = true
            }
        }
    }

    private func dumpRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(SGTheme.paperSecondary)
                .frame(width: 148, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(SGTheme.paper)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Staging actions

    private var grantStamp: Double {
        SGContract.sharedDefaults?.double(forKey: SGContract.Keys.budgetGrantedAt) ?? 0
    }

    /// The whole show: arm the reveal for this grant, force the real lock,
    /// land on the Guard tab. The countdown rolls to zero, the lock stamps
    /// shut and the night home fades up.
    private func playLockSequence() {
        UserDefaults.standard.removeObject(forKey: RegretGuard.lockRevealStampKey)
        studyGuard.debugForceLock()
        navigationModel.requestedTab = 0
    }

    /// Straight to the night home: reveal marked seen and the countdown
    /// truth pre-settled at zero so nothing rolls on the way in.
    private func lockInstantly() {
        UserDefaults.standard.set(grantStamp, forKey: RegretGuard.lockRevealStampKey)
        UserDefaults.standard.set(0, forKey: CountdownReplayModel.lastShownKey)
        UserDefaults.standard.set(grantStamp, forKey: CountdownReplayModel.lastStampKey)
        studyGuard.debugForceLock()
        navigationModel.requestedTab = 0
    }

    /// Fresh budget through the real grant path: shields clear and the
    /// meadow counts the new minutes up from zero.
    private func unlockNow() {
        studyGuard.grantFreshBudget(reason: .debug)
        navigationModel.requestedTab = 0
    }

    /// Enter an unlock flow the way a locked user does, through the scene
    /// fade. Forces a quiet lock first when needed (the reveal is marked
    /// seen so the stamp does not replay under the flow).
    private func openUnlockFlow(_ method: String) {
        if studyGuard.state != .locked {
            UserDefaults.standard.set(grantStamp, forKey: RegretGuard.lockRevealStampKey)
            studyGuard.debugForceLock()
        }
        navigationModel.unlockMethodOverride = method
        navigationModel.requestedTab = 0
        navigationModel.wipeTo(.unlock) {
            navigationModel.navigate(to: .regretView)
        }
    }
}

#Preview {
    NavigationStack {
        CreatorToolkitView()
    }
}
