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

    /// Lock/unlock animation states (matching flashcard flow).
    @State private var showLockAnimation = true
    @State private var showUnlockAnimation = false
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

    private let cameraCornerRadius: CGFloat = 28
    private let cameraPadding: CGFloat = 16

    init(durationMinutes: Int, strictness: StrictnessLevel, onEndSession: @escaping () -> Void) {
        self.durationMinutes = durationMinutes
        self.strictness = strictness
        self.onEndSession = onEndSession
        _focusManager = StateObject(wrappedValue: FocusDetectionManager(strictness: strictness))
        _pomodoroTimer = StateObject(wrappedValue: PomodoroTimer(durationMinutes: durationMinutes))
    }

    private var sharedAppName: String? {
        sharedDefaults?.string(forKey: "LastGuardedApp")
    }

    /// v2 = Screen Time engine live; legacy = Shortcuts flow (pre-migration).
    private var isV2: Bool { StudyGuardManager.shared.isSetupComplete }

    var body: some View {
        ZStack {
            SGTheme.ink
                .ignoresSafeArea()

            if sessionCompleted {
                sessionCompleteView
            } else {
                VStack(spacing: 0) {
                    topBar
                    cameraCard
                    bottomContent
                }
            }

            // Lock animation overlay (plays on entry, same as flashcards)
            if showLockAnimation {
                MascotLockOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }

            // Frosted glass intro overlay (shown after lock animation dismisses)
            if showIntroOverlay && !showLockAnimation {
                introOverlay
                    .transition(.opacity)
                    .zIndex(9)
            }

            // Unlock animation overlay (plays on session complete)
            if showUnlockAnimation {
                MascotUnlockOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }

            // v2 invariant: a locked user must always have another unlock
            // path. Camera denied → flashcards, prominently; otherwise a
            // quiet always-available switch while the session hasn't started.
            if isV2, !sessionCompleted, !showLockAnimation,
               focusManager.permissionDenied || showIntroOverlay {
                VStack {
                    Spacer()
                    Button {
                        NavigationModel.shared.unlockMethodOverride = "flashcards"
                    } label: {
                        Text(focusManager.permissionDenied
                             ? "Camera unavailable. Answer flashcards instead"
                             : "Answer flashcards instead")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(focusManager.permissionDenied ? .white : .white.opacity(0.7))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(
                                (focusManager.permissionDenied ? SGTheme.mint : Color.white.opacity(0.08)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
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

            // Show lock animation on entry
            withAnimation(.easeInOut(duration: 0.3)) {
                showLockAnimation = true
            }
            // Dismiss lock animation after 1.5s, then show intro overlay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLockAnimation = false
                }
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

        // Show unlock animation, then transition to complete view
        withAnimation(.easeInOut(duration: 0.3)) {
            showUnlockAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showUnlockAnimation = false
                sessionCompleted = true
            }
        }
    }

    // MARK: - Session complete view

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(workingGreen)

            Text("Session Complete")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text(isV2
                 ? "Your apps are unlocked for the next \(StudyGuardManager.shared.intervalMinutes) minutes of use!"
                 : "You've earned a \(trueFocusBreakDuration)-minute break!")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            if !isV2, let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                Text("\(appName) has been unlocked")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text("\(durationMinutes) minutes of focused work")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            Button {
                onEndSession()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 28))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Frosted glass intro overlay

    private var introOverlay: some View {
        ZStack {
            // Frosted glass background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 28) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "eye.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }

                // Title
                Text("True Focus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                // Message
                VStack(spacing: 12) {
                    Text("\(durationMinutes) \(durationMinutes == 1 ? "minute" : "minutes") of real work to break\nthrough procrastination.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("We'll use your camera to check you're at your workspace. Once verified, your \(durationMinutes)-minute timer starts.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                // Privacy badge
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))

                    Text("100% private. All video is processed on your device.\nWe never store or collect your data.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // Tap to continue
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.4))

                    Text("Tap anywhere to start")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1), in: Circle())
            }

            Spacer()

            // Strictness badge
            HStack(spacing: 4) {
                Image(systemName: strictness.icon)
                    .font(.system(size: 10))
                Text(strictness.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.08), in: Capsule())
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
                    .fill(warningOrange.opacity(0.15))
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
                    .font(.system(size: 96, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 4)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.3), value: sec)
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
    /// Green dot = matched a work keyword. Red dot = not a work item.
    private var inFrameLabel: some View {
        VStack {
            Spacer()
            if !focusManager.detectedSceneLabels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(focusManager.detectedSceneLabels.prefix(3).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.isWorkMatch ? .green : .red)
                                .frame(width: 6, height: 6)
                            Text(item.label.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: 11, weight: .semibold))
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
            return bothGood ? setupReadyColor : setupWaitingColor
        }
        switch focusManager.focusState {
        case .setup:      return setupWaitingColor
        case .working:    return workingGreen
        case .grace:      return warningOrange
        case .notWorking: return notWorkingRed
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("We need to see you and your workspace")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
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
                            .stroke(.white.opacity(0.15), lineWidth: 3)
                            .frame(width: 40, height: 40)

                        Circle()
                            .trim(from: 0, to: CGFloat(focusManager.setupHoldProgress) / CGFloat(focusManager.setupHoldRequired))
                            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: focusManager.setupHoldProgress)

                        Text("\(focusManager.setupHoldRequired - focusManager.setupHoldProgress)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.3), value: focusManager.setupHoldProgress)
                    }

                    Text("Hold steady...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func setupCheckRow(icon: String, label: String, detected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: detected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(detected ? .green : .white.opacity(0.2))

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(detected ? .white : .white.opacity(0.35))

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(detected ? .white.opacity(0.5) : .white.opacity(0.1))
        }
    }

    // MARK: - Session content

    private var sessionContent: some View {
        VStack(spacing: 10) {
            // Timer
            Text(timerFormatted)
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: pomodoroTimer.remainingSeconds)

            // Status
            Text(statusTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(statusTitleColor)

            Text(statusSubtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            // Debug
            Text(focusManager.displayDebugReason)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
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
        case .setup:      return .white.opacity(0.6)
        case .working:    return workingGreen
        case .grace:      return warningOrange
        case .notWorking: return notWorkingRed
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
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.8))

            Text("Camera access required")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Enable camera in Settings to detect when you're working.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
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

    // MARK: - Colors

    private var workingGreen: Color {
        Color(red: 0.22, green: 0.98, blue: 0.62)
    }

    private var notWorkingRed: Color {
        Color(red: 1.0, green: 0.38, blue: 0.42)
    }

    private var warningOrange: Color {
        Color(red: 1.0, green: 0.6, blue: 0.2)
    }

    private var setupWaitingColor: Color {
        Color(red: 0.4, green: 0.4, blue: 0.5)
    }

    private var setupReadyColor: Color {
        Color(red: 0.3, green: 0.7, blue: 1.0)
    }
}

#Preview {
    FocusSessionView(durationMinutes: 5, strictness: .standard, onEndSession: {})
}
