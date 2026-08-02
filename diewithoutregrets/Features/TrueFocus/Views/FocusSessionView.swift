//
//  FocusSessionView.swift
//  diewithoutregrets
//
//  Adapted from Attent by Jason Mayo on 2026/02/10.
//

import SwiftUI

struct FocusSessionView: View {
    let durationMinutes: Int
    let strictness: StrictnessLevel
    let onEndSession: () -> Void

    @StateObject private var focusManager: FocusDetectionManager
    @StateObject private var pomodoroTimer: PomodoroTimer

    /// Shared UserDefaults for communicating with the Shortcut.
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")

    @AppStorage("trueFocusBreakDuration") private var trueFocusBreakDuration: Int = 30

    /// Drives the animated gradient rotation on the border.
    @State private var borderRotation: Double = 0
    @State private var sessionCompleted = false

    /// Lock animation state (matching flashcard flow): the stamp plays once
    /// per lock. Decided at INIT so a user who already saw it (home reveal,
    /// or a method switch mid-flow) never gets a second slam — and the
    /// overlay never mounts-then-vanishes with orphaned haptics.
    @State private var showLockAnimation: Bool
    /// Frosted glass intro overlay -- dismissed on tap.
    @State private var showIntroOverlay = true

    /// Wall-clock when the user entered the focus screen — used to compute
    /// total time including setup phase.
    @State private var sessionStartTime: Date = Date()
    /// Whether we've already emitted `focus_session_started` (after setup
    /// completes the timer actually starts running).
    @State private var didTrackSessionStart = false
    /// Have we asked for camera permission yet? Tracks first transition only
    /// so we don't double-send the permission event.
    @State private var didTrackCameraPermission = false

    private let cameraCornerRadius: CGFloat = SGTheme.sheetRadius
    private let cameraPadding: CGFloat = 16

    init(durationMinutes: Int, strictness: StrictnessLevel, onEndSession: @escaping () -> Void) {
        self.durationMinutes = durationMinutes
        self.strictness = strictness
        self.onEndSession = onEndSession
        _focusManager = StateObject(wrappedValue: FocusDetectionManager(strictness: strictness))
        _pomodoroTimer = StateObject(wrappedValue: PomodoroTimer(durationMinutes: durationMinutes))
        _showLockAnimation = State(initialValue: !Self.stampSeen())
    }

    /// Same once-per-lock bookkeeping as the flashcard quiz (keyed to the
    /// current budget grant). Legacy flow (stamp == 0) stamps every time.
    private static func stampSeen() -> Bool {
        let stamp = SGContract.sharedDefaults?.double(forKey: SGContract.Keys.budgetGrantedAt) ?? 0
        return stamp != 0
            && UserDefaults.standard.double(forKey: RegretGuard.lockRevealStampKey) == stamp
    }

    private func markStampSeen() {
        let stamp = SGContract.sharedDefaults?.double(forKey: SGContract.Keys.budgetGrantedAt) ?? 0
        guard stamp != 0 else { return }
        UserDefaults.standard.set(stamp, forKey: RegretGuard.lockRevealStampKey)
    }

    private var sharedAppName: String? {
        sharedDefaults?.string(forKey: "LastGuardedApp")
    }

    /// v2 = Screen Time engine live; legacy = Shortcuts flow (pre-migration).
    private var isV2: Bool { StudyGuardManager.shared.isSetupComplete }

    /// Minutes of app time this session earns — the v2 engine's budget
    /// interval, or the legacy Shortcuts break duration.
    private var grantedBreakMinutes: Int {
        isV2 ? StudyGuardManager.shared.intervalMinutes : trueFocusBreakDuration
    }

    var body: some View {
        ZStack {
            SGTheme.ink
                .ignoresSafeArea()

            if sessionCompleted {
                // The one canonical celebration — the same circle-reveal,
                // count-up, and confetti the flashcard flow lands on.
                UnlockCelebrationView(
                    minutes: grantedBreakMinutes,
                    ctaTitle: "Start my \(grantedBreakMinutes) minutes",
                    subtitle: "Focus held the whole way. He's impressed.",
                    onStart: onEndSession
                )
                .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    topBar
                    cameraCard
                    bottomContent
                }
            }

            // Lock animation overlay (plays on entry, same as flashcards).
            // The stamp runs on the night canvas and drives its own timing;
            // when the full choreography lands, it hands off by crossfade.
            if showLockAnimation {
                MascotLockOverlay(
                    subtitle: nil,
                    background: SGTheme.night,
                    onDark: true,
                    usesExitMask: false,
                    onFinished: {
                        withAnimation(.easeOut(duration: 0.5)) {
                            showLockAnimation = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }

            // Frosted glass intro overlay (shown after lock animation dismisses)
            if showIntroOverlay && !showLockAnimation {
                introOverlay
                    .transition(.opacity)
                    .zIndex(9)
            }

            // v2 invariant: a locked user must always have another unlock
            // path. Camera denied → flashcards, prominently; otherwise a
            // quiet always-available switch while the session hasn't started.
            if isV2, !sessionCompleted, !showLockAnimation,
               focusManager.permissionDenied || showIntroOverlay {
                VStack {
                    Spacer()
                    // Denied → the mint primary (this is now the only way
                    // out); otherwise a quiet ghost pill.
                    SGButton(
                        title: focusManager.permissionDenied
                            ? "Camera unavailable. Answer flashcards instead"
                            : "Answer flashcards instead",
                        variant: focusManager.permissionDenied ? .mint : .ghost,
                        fullWidth: false
                    ) {
                        NavigationModel.shared.unlockMethodOverride = "flashcards"
                    }
                    .padding(.bottom, 24)
                }
                .zIndex(11)
            }
        }
        .onAppear {
            sessionStartTime = Date()
            Analytics.focusSessionEntered(
                durationMinutes: durationMinutes,
                strictness: "\(strictness)"
            )
            Telemetry.breadcrumb("Focus session entered", category: "true_focus",
                                 data: ["duration_minutes": durationMinutes,
                                        "strictness": "\(strictness)"])

            // The lock stamp shows on cold entry only (once per lock) and
            // dismisses itself via onFinished — no kill timer, so the
            // choreography never truncates.
            if showLockAnimation {
                markStampSeen()
            }
            startBorderAnimation()
        }
        .onDisappear {
            // If the user hit X (or otherwise dismissed) before the session
            // completed, treat it as abandoned. `sessionCompleted` is true
            // only when the pomodoro timer hit zero and the success view is
            // already showing.
            if !sessionCompleted {
                let focusedSecondsCompleted = (durationMinutes * 60) - pomodoroTimer.remainingSeconds
                let totalSeconds = max(durationMinutes * 60, 1)
                Analytics.focusSessionAbandoned(
                    durationMinutes: durationMinutes,
                    strictness: "\(strictness)",
                    focusedSecondsCompleted: focusedSecondsCompleted,
                    completionPct: Double(focusedSecondsCompleted) / Double(totalSeconds),
                    wasInSetup: focusManager.isInSetup
                )
            }
            focusManager.stopMonitoring()
            pomodoroTimer.stop()
        }
        .onChange(of: focusManager.hasCameraPermission) { _, granted in
            if granted && !didTrackCameraPermission {
                didTrackCameraPermission = true
                Analytics.focusCameraPermission(granted: true)
            }
        }
        .onChange(of: focusManager.permissionDenied) { _, denied in
            if denied && !didTrackCameraPermission {
                didTrackCameraPermission = true
                Analytics.focusCameraPermission(granted: false)
            }
        }
        .onChange(of: focusManager.isInSetup) { _, inSetup in
            if !inSetup {
                pomodoroTimer.setFocused(true)
                pomodoroTimer.start()

                if !didTrackSessionStart {
                    didTrackSessionStart = true
                    Analytics.focusSessionStarted(
                        durationMinutes: durationMinutes,
                        strictness: "\(strictness)",
                        setupSec: Date().timeIntervalSince(sessionStartTime)
                    )
                }
            }
        }
        .onChange(of: focusManager.isFocused) { _, focused in
            pomodoroTimer.setFocused(focused)
        }
        .onChange(of: pomodoroTimer.isComplete) { _, complete in
            if complete {
                handleSessionComplete()
            }
        }
    }

    // MARK: - Session completion (Shortcuts-based unlock)

    private func handleSessionComplete() {
        focusManager.stopMonitoring()

        Analytics.focusSessionCompleted(
            durationMinutes: durationMinutes,
            strictness: "\(strictness)",
            breakDurationMinutes: trueFocusBreakDuration,
            appName: sharedAppName,
            wallClockSec: Date().timeIntervalSince(sessionStartTime)
        )

        if isV2 {
            // Grant synchronously the moment the session is earned — never
            // inside an animation delay (a background/kill mid-animation
            // would eat the earned unlock).
            StudyGuardManager.shared.grantFreshBudget(reason: .focusSession)
        } else {
            // Legacy Shortcuts flow — unchanged until the user migrates.
            let currentTime = Date().timeIntervalSince1970
            sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
            sharedDefaults?.set(true, forKey: "UserAllowedBreak")
            sharedDefaults?.set(trueFocusBreakDuration, forKey: "BreakDurationMinutes")
            sharedDefaults?.synchronize()

            // Deep-link back to the blocked app
            if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                UIApplication.shared.open(getAppURL(for: appName), options: [:])
            }
        }

        // Land directly on the canonical celebration — it drives its own
        // circle reveal, count-up, and confetti.
        withAnimation(.easeInOut(duration: 0.3)) {
            sessionCompleted = true
        }
    }

    // MARK: - Frosted glass intro overlay

    private var introOverlay: some View {
        ZStack {
            // Frosted glass over the light canvas — dark text, mint accent.
            SGTheme.ink.opacity(0.55)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 28) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(SGTheme.mintTint)
                        .frame(width: 100, height: 100)

                    Image(systemName: "eye.fill")
                        .font(SGTheme.display(40, weight: .regular))
                        .foregroundStyle(SGTheme.mint)
                }

                // Title
                Text("True Focus")
                    .font(SGTheme.stepTitle)
                    .foregroundStyle(SGTheme.paper)

                // Message
                VStack(spacing: 12) {
                    Text("\(durationMinutes) \(durationMinutes == 1 ? "minute" : "minutes") of real work to break\nthrough procrastination.")
                        .font(SGTheme.cardTitle)
                        .foregroundStyle(SGTheme.paper.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("We'll use your camera to check you're at your workspace. Once verified, your \(durationMinutes)-minute timer starts.")
                        .font(SGTheme.body)
                        .foregroundStyle(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                // Privacy badge
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(SGTheme.body)
                        .foregroundStyle(SGTheme.mintDeep)

                    Text("100% private. All video is processed on your device.\nWe never store or collect your data.")
                        .font(SGTheme.caption)
                        .foregroundStyle(SGTheme.paperSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: SGTheme.tileRadius)
                        .fill(SGTheme.glaze(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: SGTheme.tileRadius)
                                .stroke(SGTheme.hairline, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // Tap to continue
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(SGTheme.display(20, weight: .regular))
                        .foregroundStyle(SGTheme.paperTertiary)

                    Text("Tap anywhere to start")
                        .font(SGTheme.rowLabel)
                        .foregroundStyle(SGTheme.paperTertiary)
                }
                .padding(.bottom, 50)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showIntroOverlay = false
            }
            // Start camera monitoring after intro is dismissed
            focusManager.startMonitoring()
        }
    }

    private func startBorderAnimation() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            borderRotation = 360
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            // Close
            Button {
                onEndSession()
            } label: {
                Image(systemName: "xmark")
                    .font(SGTheme.rowLabel)
                    .foregroundStyle(SGTheme.paperSecondary)
                    .frame(width: 32, height: 32)
                    .background(SGTheme.glaze(0.06), in: Circle())
            }

            Spacer()

            // Strictness badge
            HStack(spacing: 4) {
                Image(systemName: strictness.icon)
                    .font(SGTheme.caption)
                Text(strictness.displayName)
                    .font(SGTheme.caption)
            }
            .foregroundStyle(SGTheme.paperSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(SGTheme.glaze(0.06), in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Camera card with Siri-like animated border

    private var cameraCard: some View {
        ZStack {
            // Animated gradient border (Siri-like glow)
            RoundedRectangle(cornerRadius: cameraCornerRadius + 4)
                .fill(
                    AngularGradient(
                        colors: borderGradientColors,
                        center: .center,
                        angle: .degrees(borderRotation)
                    )
                )
                .blur(radius: 12)
                .padding(cameraPadding - 8)

            // Solid border ring
            RoundedRectangle(cornerRadius: cameraCornerRadius + 2)
                .strokeBorder(
                    AngularGradient(
                        colors: borderGradientColors,
                        center: .center,
                        angle: .degrees(borderRotation)
                    ),
                    lineWidth: 3
                )
                .padding(cameraPadding - 2)

            // Camera preview
            cameraPreview
                .clipShape(RoundedRectangle(cornerRadius: cameraCornerRadius))
                .padding(cameraPadding)

            // Warning tint
            if case .grace = focusManager.focusState {
                RoundedRectangle(cornerRadius: cameraCornerRadius)
                    .fill(SGTheme.amber.opacity(0.15))
                    .padding(cameraPadding)
                    .allowsHitTesting(false)
            }

            // In-frame label (what's detected)
            if !focusManager.isInSetup {
                inFrameLabel
            }

            // Grace countdown
            if let sec = focusManager.graceRemaining, sec <= 10, sec > 0 {
                Text("\(sec)")
                    .font(SGTheme.heroDigit)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .sgShadow(SGTheme.shadowFloat)
                    .contentTransition(.numericText())
                    .animation(SGTheme.springFast, value: sec)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: currentBorderState)
    }

    @ViewBuilder
    private var cameraPreview: some View {
        #if os(iOS)
        if focusManager.usesARKit, let tracker = focusManager.gazeTracker {
            ARCameraPreviewView(sceneView: tracker.sceneView)
        } else {
            CameraPreviewView(session: focusManager.captureSessionForPreview)
        }
        #else
        CameraPreviewView(session: focusManager.captureSessionForPreview)
        #endif
    }

    /// Shows detected items as small pills at the bottom of the camera card.
    /// Mint dot = matched a work keyword. Ember dot = not a work item.
    private var inFrameLabel: some View {
        VStack {
            Spacer()
            if !focusManager.detectedSceneLabels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(focusManager.detectedSceneLabels.prefix(3).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.isWorkMatch ? SGTheme.mint : SGTheme.ember)
                                .frame(width: 6, height: 6)
                            Text(item.label.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(SGTheme.micro)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.5), in: Capsule())
                    }
                }
                .padding(.bottom, cameraPadding + 12)
            }
        }
    }

    // MARK: - Border gradient colors

    private var borderGradientColors: [Color] {
        let base = currentBorderColor
        return [
            base,
            base.opacity(0.6),
            base.opacity(0.2),
            base.opacity(0.6),
            base,
        ]
    }

    private var currentBorderColor: Color {
        if focusManager.isInSetup {
            let bothGood = focusManager.setupFaceDetected && focusManager.setupSceneDetected
            return bothGood ? SGTheme.teal : SGTheme.paperTertiary
        }
        switch focusManager.focusState {
        case .setup:      return SGTheme.paperTertiary
        case .working:    return SGTheme.mint
        case .grace:      return SGTheme.amber
        case .notWorking: return SGTheme.ember
        }
    }

    /// Used for animation value tracking.
    private var currentBorderState: String {
        if focusManager.isInSetup {
            return focusManager.setupFaceDetected && focusManager.setupSceneDetected ? "ready" : "waiting"
        }
        switch focusManager.focusState {
        case .setup:      return "setup"
        case .working:    return "working"
        case .grace:      return "grace"
        case .notWorking: return "notWorking"
        }
    }

    // MARK: - Bottom content

    @ViewBuilder
    private var bottomContent: some View {
        if focusManager.isInSetup {
            setupContent
        } else {
            sessionContent
        }
    }

    // MARK: - Setup content

    private var setupContent: some View {
        VStack(spacing: 20) {
            Text("Position your phone")
                .font(SGTheme.cardTitle)
                .foregroundStyle(SGTheme.paper)

            Text("We need to see you and your workspace")
                .font(SGTheme.rowLabel)
                .foregroundStyle(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                setupCheckRow(icon: "person.fill", label: "You", detected: focusManager.setupFaceDetected)
                setupCheckRow(icon: "laptopcomputer", label: "Laptop or notebook", detected: focusManager.setupSceneDetected)
            }
            .padding(.horizontal, 4)

            if focusManager.setupFaceDetected && focusManager.setupSceneDetected {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(SGTheme.glaze(0.12), lineWidth: 3)
                            .frame(width: 40, height: 40)

                        Circle()
                            .trim(from: 0, to: CGFloat(focusManager.setupHoldProgress) / CGFloat(focusManager.setupHoldRequired))
                            .stroke(SGTheme.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: focusManager.setupHoldProgress)

                        Text("\(focusManager.setupHoldRequired - focusManager.setupHoldProgress)")
                            .font(SGTheme.numeral(16))
                            .foregroundStyle(SGTheme.paper)
                            .contentTransition(.numericText())
                            .animation(SGTheme.springFast, value: focusManager.setupHoldProgress)
                    }

                    Text("Hold steady...")
                        .font(SGTheme.rowLabel)
                        .foregroundStyle(SGTheme.paperSecondary)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius)
                        .stroke(SGTheme.hairline, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func setupCheckRow(icon: String, label: String, detected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: detected ? "checkmark.circle.fill" : "circle")
                .font(SGTheme.display(20, weight: .regular))
                .foregroundStyle(detected ? SGTheme.mint : SGTheme.paper.opacity(0.2))

            Text(label)
                .font(SGTheme.body)
                .foregroundStyle(detected ? SGTheme.paper : SGTheme.paper.opacity(0.4))

            Spacer()

            Image(systemName: icon)
                .font(SGTheme.body)
                .foregroundStyle(detected ? SGTheme.paperSecondary : SGTheme.paper.opacity(0.15))
        }
    }

    // MARK: - Session content

    private var sessionContent: some View {
        VStack(spacing: 10) {
            // Timer
            Text(timerFormatted)
                .font(SGTheme.numeral(44))
                .monospacedDigit()
                .foregroundStyle(SGTheme.paper)
                .contentTransition(.numericText())
                .animation(SGTheme.springFast, value: pomodoroTimer.remainingSeconds)

            // Status
            Text(statusTitle)
                .font(SGTheme.buttonSmall)
                .foregroundStyle(statusTitleColor)

            Text(statusSubtitle)
                .font(SGTheme.caption)
                .foregroundStyle(SGTheme.paperTertiary)

            // Debug
            Text(focusManager.displayDebugReason)
                .font(SGTheme.micro.monospaced())
                .foregroundStyle(SGTheme.paper.opacity(0.25))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var timerFormatted: String {
        let m = pomodoroTimer.remainingSeconds / 60
        let s = pomodoroTimer.remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var statusTitle: String {
        switch focusManager.focusState {
        case .setup:      return "Setting up"
        case .working:    return "Working"
        case .grace:      return "Timer is about to stop"
        case .notWorking: return "Not working"
        }
    }

    private var statusTitleColor: Color {
        switch focusManager.focusState {
        case .setup:      return SGTheme.paperSecondary
        case .working:    return SGTheme.mint
        case .grace:      return SGTheme.amber
        case .notWorking: return SGTheme.ember
        }
    }

    private var statusSubtitle: String {
        switch focusManager.focusState {
        case .setup:      return "Position your phone"
        case .working:    return "At desk, focused on your work"
        case .grace:      return "Come back to keep the timer running"
        case .notWorking: return "Come back to your desk and focus"
        }
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(SGTheme.display(44, weight: .light))
                .foregroundStyle(SGTheme.paper.opacity(0.8))

            Text("Camera access required")
                .font(SGTheme.cardTitle)
                .foregroundStyle(SGTheme.paper)

            Text("Enable camera in Settings to detect when you're working.")
                .font(SGTheme.rowLabel)
                .foregroundStyle(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - URL Helpers

    private func getAppURL(for appName: String) -> URL {
        let scheme = getUrlScheme(for: appName)
        return URL(string: scheme) ?? URL(string: "instagram://") ?? URL(string: "https://instagram.com") ?? URL(fileURLWithPath: "/")
    }

    private func getUrlScheme(for appName: String) -> String {
        switch appName.lowercased() {
        case "instagram": return "instagram://"
        case "youtube": return "youtube://"
        case "tiktok": return "tiktok://"
        case "threads": return "threads://"
        case "snapchat": return "snapchat://"
        case "netflix": return "netflix://"
        case "facebook": return "facebook://"
        case "bereal": return "bereal://"
        case "reddit": return "reddit://"
        case "x": return "x://"
        case "safari": return "https://google.com"
        case "clash royale": return "clashroyale://"
        default: return "instagram://"
        }
    }

}

#Preview {
    FocusSessionView(durationMinutes: 5, strictness: .standard, onEndSession: {})
}
