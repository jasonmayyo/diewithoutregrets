//
//  RegretGuard.swift
//  diewithoutregrets
//
//  The Guard tab — Meadow home. A fixed (non-scrolling) layout: the giant
//  time-left numeral owns the white canvas, the mascot loops on the hill
//  crest, and every control lives in liquid-glass containers on the grass.
//  Five visual states: notSetUp / metering / locked / disabled, plus the
//  reauth banner.
//

import SwiftUI
import FamilyControls
import Lottie

struct RegretGuard: View {
    @EnvironmentObject var deckStore: DeckStore
    @ObservedObject private var guardManager = StudyGuardManager.shared
    @StateObject private var countdown = CountdownReplayModel()
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("focusDuration") private var focusDuration: Int = 5

    // Checklist action sheets
    @State private var showChecklistNewDeck = false
    @State private var showChecklistAutoGenerate = false

    // Guarded apps editing + first-run setup chaining
    @State private var showGuardedAppsPicker = false
    @State private var showLockedEditAlert = false
    @State private var showSetupIntervalSheet = false
    @State private var pendingSetupInterval = false
    @State private var showSetupErrorAlert = false
    @State private var setupErrorMessage = ""
    @State private var setupErrorIsAuth = false
    @State private var pendingSetupError: StudyGuardManager.SetupError?

    // Settings entry points
    @State private var showIntervalSheet = false
    @State private var showEmergencySheet = false
    @State private var showDeckPicker = false

    // Lock reveal sequence — when the user comes home to find their time
    // spent, the story plays in order: (1) the countdown replays down to 0,
    // (2) the monster stamps the screen locked, (3) the locked home state
    // settles in. `lockRevealed` gates the locked UI so nothing leaks
    // before the stamp; it's persisted per budget grant so the show plays
    // exactly once per lock.
    @State private var showLockWipe = false
    @State private var showLockStamp = false
    @State private var lockStampScheduled = false
    @State private var lockRevealed = false
    /// Shared with RegretView: the quiz replays the stamp only when this
    /// grant's reveal was never seen.
    static let lockRevealStampKey = "sg_lockRevealShownForGrant"

    /// The apps are locked and the reveal has played — the home is the dark
    /// lock-out scene instead of the daylight meadow.
    private var isLockedHome: Bool {
        guardManager.state == .locked && lockRevealed
    }

    // Ripple tuner (Debug → Meadow dot ripple). Defaults match MeadowDotRipple.
    @AppStorage("sgRippleSagitta") private var rippleSagitta: Double = 32
    @AppStorage("sgRippleApexInset") private var rippleApexInset: Double = 94
    @AppStorage("sgRippleShiftY") private var rippleShiftY: Double = 0
    /// "dots" (MeadowDotRipple) or "clouds" (Clouds.lottie) — switchable
    /// from Debug → Home backdrop while we decide.
    @AppStorage("sgHomeBackdrop") private var homeBackdrop: String = "dots"

    /// Global Y of the meadow's top edge, measured so the ripple's base arc
    /// can be pinned to the real hill line.
    @State private var meadowTopY: CGFloat = 0

    var body: some View {
        attachModals(mainContent)
    }

    private var mainContent: some View {
        ZStack {
            if isLockedHome {
                // The lock-out home — a completely different scene from the
                // daylight meadow.
                LockedHomeView(
                    emergencyUnlocksRemaining: guardManager.emergencyUnlocksRemaining,
                    deck: deckStore.selectedDeck ?? deckStore.decks.first,
                    onStudy: {
                        // Leave the night scene through the unlock wipe: the
                        // root swaps to the quiz while the screen is covered.
                        NavigationModel.shared.wipeTo(.unlock) {
                            NavigationModel.shared.navigate(to: .regretView)
                        }
                    },
                    onEmergency: { showEmergencySheet = true },
                    onDeckTap: { showDeckPicker = true }
                )
                .transition(.opacity)
            } else {
                meadowHome
            }

            // Stage 2 of the lock reveal: the monster stamps the screen
            // locked. When it finishes, the dark locked home is already set
            // underneath and the overlay fades away.
            if showLockStamp {
                MascotLockOverlay(
                    subtitle: "Study to win your apps back.",
                    background: LockedHomeView.night,
                    onDark: true,
                    startDelay: 0.45,
                    usesExitMask: false
                ) {
                    NavigationModel.shared.isLockStampPlaying = false
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLockStamp = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }

            // Stage 1½: the corner wipe — white leads, ember covers — that
            // carries the screen from the dead 0m readout into the stamp.
            if showLockWipe {
                SGCornerWipe(
                    preset: .lock,
                    onCovered: {
                        // Screen is fully covered: swap the locked scene in
                        // and mount the stamp so the retract reveals it.
                        lockRevealed = true
                        showLockStamp = true
                    },
                    onFinished: {
                        showLockWipe = false
                    }
                )
                .zIndex(3)
            }
        }
        .onAppear {
            // If this lock's reveal already played, land directly on the
            // locked home — the show runs once per budget grant.
            if guardManager.state == .locked, lockRevealShownForCurrentGrant {
                lockRevealed = true
            }
            NavigationModel.shared.isLockedHomeShowing = isLockedHome
            countdown.onSettled = { minutes in
                scheduleLockRevealIfNeeded(settledMinutes: minutes)
            }
            // Visible first: replays only play while Home is on screen.
            countdown.setVisible(true)
            guardManager.refresh()
            syncCountdown()
        }
        // The tab bar reads this to flip between its daylight and night
        // (smoked-glass) looks in step with the scene swap.
        .onChange(of: isLockedHome) { _, showing in
            NavigationModel.shared.isLockedHomeShowing = showing
        }
        .onDisappear {
            countdown.setVisible(false)
        }
        .onChange(of: guardManager.usedMinutes) { _, _ in syncCountdown() }
        .onChange(of: guardManager.totalMinutes) { _, _ in syncCountdown() }
        .onChange(of: guardManager.state) { _, newState in
            if newState != .locked {
                // Unlocked (or paused): arm the show for the next lock.
                showLockWipe = false
                showLockStamp = false
                lockStampScheduled = false
                lockRevealed = false
                NavigationModel.shared.isLockStampPlaying = false
            }
            syncCountdown()
        }
    }

    /// The daylight meadow home (all states except the revealed lock-out).
    private var meadowHome: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            // Backdrop behind the whole screen — either the dot ripple
            // anchored to the measured hill line (dots below it hide under
            // the green hill, so crests rise out of the grass) or the
            // drifting Clouds Lottie. Debug → Home backdrop switches them.
            if homeBackdrop == "clouds" {
                ZStack {
                    LottieView {
                        try await DotLottieFile.named("Clouds")
                    }
                    .playing(loopMode: .loop)
                    .animationSpeed(0.4)
                    .configure { $0.contentMode = .scaleAspectFill }

                    // Sky deepens toward the horizon, like dusk settling in
                    // behind the hill.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: SGTheme.skyMid.opacity(0.35), location: 0.55),
                            .init(color: SGTheme.skyDeep.opacity(0.8), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            } else if meadowTopY > 0 {
                MeadowDotRipple(
                    hillApexY: meadowTopY + CGFloat(rippleApexInset),
                    sagitta: CGFloat(rippleSagitta),
                    shiftY: CGFloat(rippleShiftY)
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // White canvas — the readout centered in the open air above
                // the meadow. Spans from the PHYSICAL top of the screen
                // (ignoresSafeArea below) so the hero sits exactly midway
                // between the top edge and the monster.
                VStack(spacing: 20) {
                    Spacer(minLength: 24)

                    hero

                    if guardManager.needsReauth {
                        reauthBanner
                            .padding(.horizontal, SGTheme.screenPadding)
                    }

                    MigrationCard()
                        .padding(.horizontal, SGTheme.screenPadding)

                    if !checklistAllCompleted {
                        OnboardingChecklistCard(
                            onSetupGuard: { openGuardedAppsEditor() },
                            onCreateDeck: {
                                Analytics.capture("checklist_step_tapped", properties: ["step": "create_deck"])
                                showChecklistNewDeck = true
                            },
                            onGenerateCards: {
                                Analytics.capture("checklist_step_tapped", properties: ["step": "generate_cards"])
                                if deckStore.decks.isEmpty {
                                    let newDeck = Deck(name: "My First Deck")
                                    deckStore.addDeck(newDeck)
                                    deckStore.selectDeck(newDeck)
                                }
                                showChecklistAutoGenerate = true
                            }
                        )
                        .padding(.horizontal, SGTheme.screenPadding)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Capped bottom spacer: the hero hangs a fixed gap above
                    // the mascot instead of floating at the midpoint.
                    Spacer(minLength: 0)
                        .frame(maxHeight: 56)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)

                meadow
                    .background(
                        GeometryReader { proxy in
                            let top = proxy.frame(in: .global).minY
                            Color.clear
                                .onAppear { meadowTopY = top }
                                .onChange(of: top) { _, newTop in meadowTopY = newTop }
                        }
                    )
            }
            .animation(.easeInOut(duration: 0.4), value: checklistAllCompleted)
        }
    }

    /// Modal stack — attached to the body so both the meadow and lock-out
    /// homes can present from it.
    private func attachModals<Content: View>(_ content: Content) -> some View {
        content
        .sheet(isPresented: $showGuardedAppsPicker, onDismiss: {
            if pendingSetupInterval {
                pendingSetupInterval = false
                showSetupIntervalSheet = true
            }
        }) {
            GuardedAppsPickerSheet(onSaved: { result in
                if case .saved = result, guardManager.state == .notSetUp {
                    pendingSetupInterval = true
                }
            })
        }
        .sheet(isPresented: $showSetupIntervalSheet, onDismiss: {
            if let error = pendingSetupError {
                pendingSetupError = nil
                presentSetupError(error)
            }
        }) {
            UsageIntervalSheet(isSetupMode: true, onConfirm: {
                if case .failure(let error) = guardManager.completeSetup() {
                    pendingSetupError = error
                }
                showSetupIntervalSheet = false
            })
        }
        .sheet(isPresented: $showIntervalSheet) {
            UsageIntervalSheet()
        }
        .sheet(isPresented: $showEmergencySheet) {
            EmergencyUnlockSheet {}
        }
        .sheet(isPresented: $showDeckPicker) {
            DeckPickerSheet()
                .environmentObject(deckStore)
        }
        .alert("Apps are locked", isPresented: $showLockedEditAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unlock your apps first to edit which ones are guarded.")
        }
        .alert("Couldn't start Study Guard", isPresented: $showSetupErrorAlert) {
            if setupErrorIsAuth {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(setupErrorMessage)
        }
        .sheet(isPresented: $showChecklistNewDeck) {
            NewDeckView()
                .presentationDetents([.large])
                .sgSheetChrome()
        }
        .sheet(isPresented: $showChecklistAutoGenerate) {
            if let selectedDeck = deckStore.selectedDeck,
               let index = deckStore.decks.firstIndex(where: { $0.id == selectedDeck.id }) {
                AutoGenerateFlashcardsSheet(deck: $deckStore.decks[index])
                    .sgSheetChrome()
                    .environmentObject(deckStore)
            } else if !deckStore.decks.isEmpty {
                AutoGenerateFlashcardsSheet(deck: $deckStore.decks[0])
                    .sgSheetChrome()
                    .environmentObject(deckStore)
            }
        }
    }

    // MARK: - Hero

    /// One pose per story beat: content while there's still time on the
    /// clock, head-down disappointment at the "caught you" reveal, clipboard
    /// out once the way forward is answering flashcards, teaching during
    /// setup, and idle napping when he's off duty.
    private var mascotPose: MascotPose {
        switch guardManager.state {
        case .metering:
            return .idle
        case .locked:
            // Only rendered pre-reveal: he's still staring at the phone
            // while the checkpoint replay rolls the minutes to 0. The
            // revealed lock-out (LockedHomeView) has its own angry mascot.
            return .lookingDown
        case .notSetUp:
            return .teaching
        case .disabled:
            return .idle
        }
    }

    /// Hero text colors — near-black ink on the white canvas, white over the
    /// clouds backdrop's blue sky.
    private var heroPrimary: Color {
        homeBackdrop == "clouds" ? .white : SGTheme.paper
    }
    private var heroSecondary: Color {
        homeBackdrop == "clouds" ? .white.opacity(0.75) : SGTheme.paperSecondary
    }

    /// The white-canvas readout — the number IS the screen, with its label
    /// underneath (mockup order: "15m" over "screen time left").
    private var hero: some View {
        VStack(spacing: 14) {
            switch guardManager.state {
            case .metering:
                heroNumeral(dimmed: false)
                SGMicroLabel(text: "Screen time left", color: heroSecondary)

            case .locked:
                // Only the pre-reveal beat renders here: the minutes they
                // were spending run dry ON SCREEN (checkpoint replay rolls
                // to 0). Once the wipe + stamp play, the whole home swaps to
                // LockedHomeView.
                heroNumeral(dimmed: false)
                SGMicroLabel(text: "Screen time left", color: heroSecondary)

            case .notSetUp:
                SGMicroLabel(text: "Meet your guard", color: heroSecondary)
                Text("Your monster is ready")
                    .font(SGTheme.display(30))
                    .foregroundColor(heroPrimary)
                Text("Pick your distracting apps. When your scroll time runs out, he locks them until you study.")
                    .font(SGTheme.body)
                    .foregroundColor(heroSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)

            case .disabled:
                heroNumeral(dimmed: true)
                SGMicroLabel(text: "Guard paused", color: heroSecondary)
                Text("Your apps are free. He's just napping.")
                    .font(SGTheme.body)
                    .foregroundColor(heroSecondary)
            }
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .animation(SGTheme.spring, value: guardManager.state)
        // Locked reveal: swap from the settled 0m numeral to "He caught you
        // scrolling" as the stamp overlay fades out.
        .animation(SGTheme.spring, value: lockRevealed)
    }

    /// "2h 14m" — giant black digits (plain SF, not rounded), smaller
    /// muted units.
    private func heroNumeral(dimmed: Bool) -> some View {
        let hours = countdown.displayMinutes / 60
        let minutes = countdown.displayMinutes % 60

        // Thin space between digits and unit — a full space reads as a gap
        // at this size, none at all lets the glyphs collide.
        var readout = Text(verbatim: "")
        if hours > 0 {
            readout = readout
                + Text("\(hours)").font(SGTheme.heroDigit)
                + Text("\u{2009}h").font(SGTheme.heroUnit).foregroundColor(heroSecondary)
                + Text(verbatim: " ")
        }
        readout = readout
            + Text("\(minutes)").font(SGTheme.heroDigit)
            + Text("\u{2009}m").font(SGTheme.heroUnit).foregroundColor(heroSecondary)

        return ZStack(alignment: .topTrailing) {
            readout
                .foregroundColor(heroPrimary)
                .contentTransition(.numericText(countsDown: true))
                .opacity(dimmed ? 0.35 : 1)
                .scaleEffect(countdown.isRolling ? 1.08 : 1)

            if let delta = countdown.delta {
                CountdownDeltaLabel(event: delta)
                    .offset(x: 58, y: -18)
                    .id(delta.id)
            }
        }
    }

    // MARK: - Meadow

    /// The green ground pinned to the bottom: the mascot loops on the crest,
    /// every control sits below him in liquid-glass containers, and the
    /// floating tab bar (safeAreaInset in ContentView) hovers over the base.
    private var meadow: some View {
        VStack(spacing: 12) {
            meadowControls
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 160)
        // The floating tab bar's safeAreaInset doesn't reach TabView pages,
        // so clear it explicitly.
        .padding(.bottom, SGTheme.tabBarClearance)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                MeadowHill()
                    .fill(homeBackdrop == "clouds" ? SGTheme.meadowGradientDeep : SGTheme.meadowGradient)
                    .shadow(color: homeBackdrop == "clouds" ? Color.black.opacity(0.16) : SGTheme.mint.opacity(0.28),
                            radius: 24, y: -8)

                // Sunlit rim along the crest — separates the grass from the
                // blue sky when the clouds backdrop is on.
                if homeBackdrop == "clouds" {
                    MeadowCrest()
                        .stroke(Color.white.opacity(0.55), lineWidth: 2.5)
                        .blur(radius: 0.5)
                }
            }
            .padding(.top, 92)
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            MascotView(pose: mascotPose, loops: nil)
                .frame(width: 148, height: 148)
                .padding(.top, 0)
        }
        .animation(SGTheme.spring, value: guardManager.state)
    }

    @ViewBuilder
    private var meadowControls: some View {
        switch guardManager.state {
        case .metering:
            meteringControls

        case .locked:
            // Only reachable pre-reveal (the roll to 0 is still playing, or
            // the wipe is about to land) — keep the metering layout so the
            // lock doesn't leak early. The revealed lock-out lives in
            // LockedHomeView.
            meteringControls

        case .notSetUp:
            SGButton(title: "Turn on Study Guard", icon: "shield.fill", variant: .white) {
                openGuardedAppsEditor()
            }

        case .disabled:
            SGButton(title: "Resume guarding", icon: "play.fill", variant: .white) {
                _ = guardManager.setGuardEnabled(true)
            }
        }
    }

    /// Pills + active deck shown while metering (and while the lock reveal
    /// is still playing).
    @ViewBuilder
    private var meteringControls: some View {
        HStack(spacing: 10) {
            GlassPill(
                text: SGContract.isSelectionEmpty(guardManager.selection)
                    ? "Pick apps"
                    : "\(SGContract.tokenCount(guardManager.selection)) apps",
                icon: "apps.iphone"
            ) {
                openGuardedAppsEditor()
            }
            GlassPill(text: "\(guardManager.intervalMinutes)m", icon: "timer") {
                showIntervalSheet = true
            }
            // No "Earn time" here: while metering the quiz can't grant
            // anything (it dead-ends on "already unlocked"). The locked
            // state owns the earn CTA.
        }
        activeDeckCard
    }

    /// The big white card showing the active deck. Tapping opens the deck
    /// picker sheet (switch the active deck, or dive into editing one).
    @ViewBuilder
    private var activeDeckCard: some View {
        let deck = deckStore.selectedDeck ?? deckStore.decks.first

        if let deck {
            Button {
                showDeckPicker = true
            } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        SGMicroLabel(text: "Active deck", color: SGTheme.mintDeep)
                        Text(deck.name)
                            .font(SGTheme.display(22))
                            .foregroundColor(SGTheme.paper)
                            .lineLimit(1)
                        Text(deck.cards.count == 1
                             ? "1 card. Answering it unlocks your apps"
                             : "\(deck.cards.count) cards. Answering them unlocks your apps")
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(SGTheme.rowLabel)
                        .foregroundColor(SGTheme.paperTertiary)
                }
                .padding(SGTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .meadowCard(in: RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(SGPressStyle())
        } else {
            Button {
                showChecklistNewDeck = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(SGTheme.display(20, weight: .semibold))
                        .foregroundColor(SGTheme.mintDeep)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Create your first deck")
                            .font(SGTheme.cardTitle)
                            .foregroundColor(SGTheme.paper)
                        Text("You'll answer these cards to unlock your apps")
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)
                    }
                    Spacer()
                }
                .padding(SGTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .meadowCard(in: RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous))
            }
            .buttonStyle(SGPressStyle())
        }
    }

    private var reauthBanner: some View {
        SGCard {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(SGTheme.ember)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Screen Time access was revoked")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                    Text("Study Guard is paused until you re-enable it.")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                }
                Spacer()
                Button("Re-enable") {
                    reenableAfterRevocation()
                }
                .font(SGTheme.rowLabel)
                .foregroundColor(SGTheme.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(SGTheme.ember, in: Capsule(style: .continuous))
            }
        }
    }

    private func reenableAfterRevocation() {
        Task { @MainActor in
            let approved = await guardManager.requestAuthorization()
            if approved {
                if case .failure(let error) = guardManager.completeSetup() {
                    presentSetupError(error)
                }
            } else {
                presentSetupError(.notAuthorized)
            }
        }
    }

    private func syncCountdown() {
        let remaining = max(0, guardManager.totalMinutes - guardManager.usedMinutes)
        countdown.sync(remainingMinutes: remaining, grantStamp: currentGrantStamp)
    }

    // MARK: - Lock reveal sequence

    private var currentGrantStamp: Double {
        SGContract.sharedDefaults?.double(forKey: SGContract.Keys.budgetGrantedAt) ?? 0
    }

    private var lockRevealShownForCurrentGrant: Bool {
        UserDefaults.standard.double(forKey: Self.lockRevealStampKey) == currentGrantStamp
    }

    /// Countdown settle hook: when the readout lands on 0 while locked (the
    /// roll only plays while Home is on screen), hold the zero for a beat,
    /// then stamp. Persisted per grant so re-visits skip straight to the
    /// locked home.
    private func scheduleLockRevealIfNeeded(settledMinutes: Int) {
        guard settledMinutes == 0,
              guardManager.state == .locked,
              !lockRevealed, !showLockWipe, !showLockStamp, !lockStampScheduled
        else { return }

        if lockRevealShownForCurrentGrant {
            lockRevealed = true
            return
        }

        lockStampScheduled = true
        UserDefaults.standard.set(currentGrantStamp, forKey: Self.lockRevealStampKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            lockStampScheduled = false
            guard guardManager.state == .locked, !lockRevealed else { return }
            NavigationModel.shared.isLockStampPlaying = true
            showLockWipe = true
        }
    }

    private var checklistAllCompleted: Bool {
        guardManager.isSetupComplete
            && !deckStore.decks.isEmpty
            && deckStore.decks.contains { !$0.cards.isEmpty }
    }

    private func openGuardedAppsEditor() {
        if guardManager.state == .locked {
            showLockedEditAlert = true
        } else {
            showGuardedAppsPicker = true
        }
    }

    private func presentSetupError(_ error: StudyGuardManager.SetupError) {
        switch error {
        case .notAuthorized:
            setupErrorMessage = "Study Guard needs Screen Time access to lock your apps. Tap Open Settings, allow Screen Time for this app, then try again."
            setupErrorIsAuth = true
        case .emptySelection:
            setupErrorMessage = "Pick at least one app to guard, then try again."
            setupErrorIsAuth = false
        case .monitoringFailed:
            setupErrorMessage = "Something went wrong starting the guard. Please try again."
            setupErrorIsAuth = false
        }
        showSetupErrorAlert = true
    }
}

// MARK: - Deck picker sheet

/// Opened from the home active-deck card: pick which deck unlocks the apps,
/// or step into a deck to edit its cards.
struct DeckPickerSheet: View {
    @EnvironmentObject var deckStore: DeckStore
    @Environment(\.dismiss) private var dismiss
    @State private var showNewDeck = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SGSheetHeader(
                    title: "Active deck",
                    subtitle: "Answering cards from the active deck unlocks your apps.",
                    onClose: { dismiss() }
                )
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(deckStore.decks) { deck in
                            deckRow(deck)
                        }

                        Button {
                            showNewDeck = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(SGTheme.mint.opacity(0.12))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "plus")
                                        .font(SGTheme.caption.weight(.bold))
                                        .foregroundColor(SGTheme.mintDeep)
                                }
                                Text("Create new deck")
                                    .font(SGTheme.cardTitle)
                                    .foregroundColor(SGTheme.paper)
                                Spacer()
                            }
                            .padding(.horizontal, SGTheme.cardPadding)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                                    .fill(SGTheme.inkRaised)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.bottom, SGTheme.screenPadding)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(SGTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNewDeck) {
                NewDeckView()
                    .presentationDetents([.large])
                    .sgSheetChrome()
            }
        }
        .presentationDetents([.large])
        .sgSheetChrome()
    }

    private func deckRow(_ deck: Deck) -> some View {
        let isActive = deckStore.selectedDeck?.id == deck.id
        return HStack(spacing: 12) {
            // Tap the row to make this deck active.
            Button {
                if !isActive {
                    Analytics.deckSelected(name: deck.name, cardCount: deck.cards.count)
                    deckStore.selectDeck(deck)
                    SGTheme.tapHaptic()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isActive ? SGTheme.mint.opacity(0.15) : SGTheme.glaze(0.06))
                            .frame(width: 30, height: 30)
                        if isActive {
                            Image(systemName: "checkmark")
                                .font(SGTheme.micro.weight(.bold))
                                .foregroundColor(SGTheme.mintDeep)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.name)
                            .font(SGTheme.cardTitle)
                            .foregroundColor(SGTheme.paper)
                            .lineLimit(1)
                        Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)
                    }

                    Spacer()

                    if isActive {
                        SGMicroLabel(text: "Active", color: SGTheme.mintDeep)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Edit the deck's cards.
            if let index = deckStore.decks.firstIndex(where: { $0.id == deck.id }) {
                NavigationLink {
                    DeckView(deck: $deckStore.decks[index])
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(SGTheme.buttonSmall)
                        .foregroundColor(SGTheme.mintDeep)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(SGTheme.glaze(0.05)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SGTheme.cardPadding)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                        .strokeBorder(isActive ? SGTheme.mint.opacity(0.5) : SGTheme.hairline,
                                      lineWidth: isActive ? 1.5 : 1)
                )
        )
        .animation(SGTheme.springFast, value: isActive)
    }
}

// MARK: - Meadow parts

/// Animated dot field for the white canvas above the meadow. Wave crests
/// ripple UPWARD from the hill line as half-circle rings concentric with the
/// hill's curve — the ripple centre sits far below the crest (at the centre
/// of the circle the hill arc belongs to), so every crest travels parallel
/// to the grass. Adapted from One Thing's DotGridRippleView: pure SwiftUI
/// Canvas + TimelineView, no assets. Dots stretch into radially-oriented
/// dashes as a crest passes, and dissolve with height so the hero numeral
/// stays clean.
struct MeadowDotRipple: View {
    /// Absolute Y of the hill crest apex in this view's own space. When set
    /// (the Guard home measures the real meadow position) the ripple's base
    /// arc sits exactly on the hill line; dots below it hide under the
    /// green hill, so crests visibly rise out of the grass.
    var hillApexY: CGFloat? = nil
    /// Fallback when hillApexY isn't provided: apex sits this far past the
    /// view's own bottom edge. Smaller/negative raises the base line.
    var hillApexInset: CGFloat = 94
    /// How strongly the base line curves (arc sagitta): 32 matches
    /// MeadowHill; smaller = flatter, larger = rounder.
    var sagitta: CGFloat = 32
    /// Translates the ENTIRE dot field down by this many px — use to open a
    /// gap at the top of the screen so the field starts lower.
    var shiftY: CGFloat = 0

    // Tunables — tweak freely to taste.
    var spacing: CGFloat = 18
    var dotSize: CGFloat = 2.6
    var maxStretch: CGFloat = 5
    var wavelength: CGFloat = 240      // px between radial wave crests
    var speed: Double = 1.1            // radial wave drift
    var ringSpeed: CGFloat = 60        // crest travel, px/s
    var ringPeriod: CGFloat = 340      // px between launched crests
    var ringSpread: CGFloat = 34
    var intensity: Double = 0.14
    /// Dots are strongest at the hill line and soften as they rise. Large
    /// enough that the field stays visible all the way past the status bar.
    var fadeDistance: CGFloat = 1200
    var dotColor: Color = SGTheme.mint

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    draw(context, size: size, t: 0)
                }
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        draw(context, size: size, t: t)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ context: GraphicsContext, size: CGSize, t: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }

        var context = context
        context.translateBy(x: 0, y: shiftY)

        // Reconstruct the circle the hill's quad-curve crest approximates:
        // default sagitta 32 = edge height (34) minus apex height (~2) of
        // MeadowHill.
        let halfW = size.width / 2
        let s = max(1, sagitta)
        let hillRadius = (halfW * halfW + s * s) / (2 * s)
        let cx = size.width / 2
        let cy = (hillApexY ?? size.height + hillApexInset) + hillRadius

        let stretchScale = maxStretch * (1.0 + intensity * 1.3)
        let peakBoost = 1.0 + intensity * 0.9
        let ringPos = CGFloat(t) * ringSpeed

        let cols = Int(size.width / spacing) + 2
        let rows = Int(size.height / spacing) + 2

        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * spacing
                let y = CGFloat(row) * spacing
                let dx = x - cx
                let dy = y - cy
                let dist = sqrt(dx * dx + dy * dy)

                // Height above the grass, measured along the hill's own arc.
                let aboveHill = dist - hillRadius
                let f = max(0, min(1, 1 - aboveHill / fadeDistance))
                let strength = Double(f * f * (3 - 2 * f)) // smoothstep fade
                if strength < 0.02 { continue }

                let base = sin(Double(dist / wavelength) - t * speed)

                var m = (dist - ringPos).truncatingRemainder(dividingBy: ringPeriod)
                if m < 0 { m += ringPeriod }
                let dRing = min(m, ringPeriod - m)
                let ring = exp(-(dRing * dRing) / (2 * ringSpread * ringSpread))

                var amp = base * 0.35 + Double(ring)
                amp = max(0, min(1, amp))

                // Every dot stays visible at rest; the wave only ADDS
                // brightness and stretches it into a dash.
                let opacity = min(0.9, (0.16 + amp * 0.5 * peakBoost) * strength)

                let length = dotSize + CGFloat(amp) * stretchScale * CGFloat(strength)
                let rect = CGRect(x: -dotSize / 2, y: -length / 2, width: dotSize, height: length)
                let path = Capsule().path(in: rect)

                var cellContext = context
                cellContext.translateBy(x: x, y: y)
                cellContext.rotate(by: .radians(atan2(dy, dx) - .pi / 2)) // long axis points up the arc
                cellContext.fill(path, with: .color(dotColor.opacity(opacity)))
            }
        }
    }
}

/// Just the crest curve of MeadowHill (no sides/bottom) — stroked as a rim
/// highlight over the clouds backdrop.
struct MeadowCrest: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 34))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 34),
            control: CGPoint(x: rect.midX, y: rect.minY - 30)
        )
        return p
    }
}

/// The green ground the mascot stands on — gentle curved crest.
struct MeadowHill: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + 34))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + 34),
            control: CGPoint(x: rect.midX, y: rect.minY - 30)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Frosted-white surface for controls sitting on the meadow — solid enough
/// for dark ink text to stay readable over any backdrop.
private extension View {
    func meadowCard(in shape: some InsettableShape) -> some View {
        background(
            shape.fill(.white.opacity(0.94))
                .sgShadow(SGTheme.shadowCard)
        )
    }
}

/// White pill on the meadow: dark label, deep-green icon.
/// (MeadowCTA was replaced by SGButton .white in the Phase 2 migration.)
private struct GlassPill: View {
    let text: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(SGTheme.caption.weight(.semibold))
                        .foregroundColor(SGTheme.mintDeep)
                }
                Text(text)
                    .font(SGTheme.rowLabel)
                    .foregroundColor(SGTheme.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .meadowCard(in: Capsule(style: .continuous))
        }
        .buttonStyle(SGPressStyle())
    }
}

// MARK: - Lock-out home

/// The home while the apps are locked — One Thing's home language turned
/// into a red alert: the night canvas, the alarm dot ripple radiating from
/// the monster at the centre of the screen, and one path forward stacked at
/// the bottom (active deck first, the unlock CTA beneath it). Revealed by
/// the corner wipe + lock stamp the moment screen time runs out.
struct LockedHomeView: View {
    let emergencyUnlocksRemaining: Int
    let deck: Deck?
    var onStudy: () -> Void = {}
    var onEmergency: () -> Void = {}
    var onDeckTap: () -> Void = {}

    /// The night scene token (SGTheme) — shared with the lock wipe's final
    /// band and the stamp overlay's background so the whole reveal reads as
    /// one continuous scene.
    static let night = SGTheme.night

    /// Measured centre of the mascot (global coords). The ripple locks to
    /// it so every crest radiates from him, wherever the layout puts him.
    @State private var mascotCenter: CGPoint? = nil

    var body: some View {
        ZStack {
            Self.night.ignoresSafeArea()

            // The red dot storm — One Thing's home-screen ripple, radiating
            // from the monster. Full-bleed so crests run out past the safe
            // areas and under the floating glass dock.
            SGDotGridRipple(centerPoint: mascotCenter)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // Alarm bloom behind the monster — the scene's light source.
            // Values come from SGLockScene, shared with the lock stamp, so
            // the overlay crossfades into this scene pixel-for-pixel.
            RadialGradient(colors: [SGLockScene.accent.opacity(SGLockScene.bloomOpacity), .clear],
                           center: SGLockScene.bloomCenter,
                           startRadius: SGLockScene.bloomStartRadius,
                           endRadius: SGLockScene.bloomEndRadius)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    SGMicroLabel(text: "Time's up", color: SGLockScene.accent)
                    Text("He caught you scrolling")
                        .font(SGTheme.stepTitle)
                        .foregroundColor(SGTheme.nightText)
                        .multilineTextAlignment(.center)
                    Text("Your screen time is spent. Answer your flashcards to win your apps back.")
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.nightTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300)
                }
                .padding(.horizontal, SGTheme.screenPadding)

                Spacer(minLength: 20)

                // The monster in the eye of the storm. His measured centre
                // feeds the ripple above.
                AngryMascotImage()
                    .frame(width: 200, height: 200)
                    .shadow(color: SGLockScene.accent.opacity(0.45), radius: 36, y: 12)
                    .background(
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .global)
                            Color.clear
                                .onAppear {
                                    mascotCenter = CGPoint(x: frame.midX, y: frame.midY)
                                }
                                .onChange(of: frame) { _, newFrame in
                                    mascotCenter = CGPoint(x: newFrame.midX, y: newFrame.midY)
                                }
                        }
                    )

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    if let deck {
                        deckCard(deck)
                    }

                    SGButton(title: "Study to unlock",
                             icon: "rectangle.stack.fill",
                             variant: .alarm,
                             action: onStudy)

                    if emergencyUnlocksRemaining > 0 {
                        Button(action: onEmergency) {
                            Text("Emergency unlock (\(emergencyUnlocksRemaining) left)")
                                .font(SGTheme.caption)
                                .foregroundColor(SGTheme.nightTextTertiary)
                                .underline()
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.bottom, SGTheme.tabBarClearance)
            }
        }
    }

    /// The active deck on smoked glass, so the storm stays visible through
    /// every surface on this screen.
    private func deckCard(_ deck: Deck) -> some View {
        Button(action: onDeckTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    SGMicroLabel(text: "Active deck", color: SGLockScene.accent)
                    Text(deck.name)
                        .font(SGTheme.display(20))
                        .foregroundColor(SGTheme.nightText)
                        .lineLimit(1)
                    Text(deck.cards.count == 1
                         ? "1 card. Answering it unlocks your apps"
                         : "\(deck.cards.count) cards. Answering them unlocks your apps")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.nightTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(SGTheme.rowLabel)
                    .foregroundColor(SGTheme.nightTextTertiary)
            }
            .padding(SGTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sgGlassBackground(in: RoundedRectangle(cornerRadius: SGTheme.cardRadius,
                                                    style: .continuous),
                               onDark: true)
        }
        .buttonStyle(SGPressStyle())
    }
}

#Preview("Locked home") {
    LockedHomeView(
        emergencyUnlocksRemaining: 3,
        deck: Deck(name: "Biology 101")
    )
}

#Preview("Empty / not set up") {
    RegretGuard()
        .environmentObject(DeckStore.shared)
}

#if DEBUG
#Preview("Metering") {
    SGPreviewHarness.seed(.metering)
    return RegretGuard()
        .environmentObject(DeckStore.shared)
}

#Preview("Locked") {
    SGPreviewHarness.seed(.locked)
    return RegretGuard()
        .environmentObject(DeckStore.shared)
}
#endif
