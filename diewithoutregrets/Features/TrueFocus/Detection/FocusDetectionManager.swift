//
//  FocusDetectionManager.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import AVFoundation
import Combine
import SwiftUI
import Vision

/// Thin coordinator that owns the camera session (or ARKit session in Strict mode),
/// feeds frames to FocusEngine, and publishes state from FocusStateMachine.
///
/// Includes a pre-session setup phase where the user positions their phone
/// until both face and work environment are detected for 5 consecutive seconds.
final class FocusDetectionManager: NSObject, ObservableObject {

    // MARK: - Published state for UI

    @Published var focusState: TrueFocusState = .setup
    @Published var isFocused = false
    @Published var hasCameraPermission = false
    @Published var permissionDenied = false
    @Published var debugReason: String = "Setting up..."

    // MARK: - Setup state (published for UI)

    /// Whether we're still in the setup phase.
    @Published var isInSetup = true
    /// Whether a face is currently detected (for setup checklist).
    @Published var setupFaceDetected = false
    /// Whether a work environment is currently detected (for setup checklist).
    @Published var setupSceneDetected = false
    /// How many consecutive seconds both signals have been passing (0-5).
    @Published var setupHoldProgress: Int = 0
    /// Total seconds needed to complete setup.
    let setupHoldRequired = 5

    // MARK: - Visual feedback

    /// Top scene labels with their match status (true = matched a work keyword, false = not matched).
    @Published var detectedSceneLabels: [(label: String, isWorkMatch: Bool)] = []

    /// Grace seconds remaining (nil if not in grace).
    var graceRemaining: Int? { focusState.graceRemaining }

    // MARK: - Configuration

    let strictness: StrictnessLevel

    var usesARKit: Bool {
        #if os(iOS)
        return strictness.usesGazeTracking && gazeTracker?.isAvailable == true
        #else
        return false
        #endif
    }

    // MARK: - Internal components

    private let engine: FocusEngine
    private let stateMachine: FocusStateMachine

    #if os(iOS)
    private(set) var gazeTracker: GazeTracker?
    #endif

    // MARK: - Camera

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var detectionTimer: Timer?
    private let sessionQueue = DispatchQueue(label: "com.attent.capture")
    private var latestSampleBuffer: CMSampleBuffer?
    private let sampleBufferLock = NSLock()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var captureSessionForPreview: AVCaptureSession? {
        captureSession
    }

    // MARK: - Adaptive polling

    private let workingInterval: TimeInterval = 3.0
    private let alertInterval: TimeInterval = 1.0
    /// During setup, check every second for responsive feedback.
    private let setupInterval: TimeInterval = 1.0

    // MARK: - Scene classification cache

    private var cachedSceneLabels: [String: Float] = [:]
    private var lastSceneClassificationTime: Date = .distantPast
    private let sceneCacheInterval: TimeInterval = 15.0

    // MARK: - Setup tracking

    private var consecutiveSetupPasses = 0

    // MARK: - Init

    init(strictness: StrictnessLevel = .standard) {
        self.strictness = strictness
        self.engine = FocusEngine(strictness: strictness)
        self.stateMachine = FocusStateMachine(graceDuration: strictness.graceDuration)
        super.init()
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        #if os(iOS)
        if strictness.usesGazeTracking {
            let tracker = GazeTracker()
            gazeTracker = tracker
            engine.setGazeTracker(tracker)
            tracker.start()

            if tracker.isAvailable {
                Task { @MainActor in
                    self.hasCameraPermission = true
                    self.startDetectionTimer()
                }
                return
            }
        }
        #endif

        sessionQueue.async { [weak self] in
            self?.setupCamera()
        }
    }

    func stopMonitoring() {
        detectionTimer?.invalidate()
        detectionTimer = nil
        engine.reset()
        debugReason = "Stopped"
        cachedSceneLabels = [:]
        lastSceneClassificationTime = .distantPast
        consecutiveSetupPasses = 0

        #if os(iOS)
        gazeTracker?.stop()
        gazeTracker = nil
        #endif

        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    var displayDebugReason: String {
        if let sec = graceRemaining {
            return "\(debugReason) — Timer stops in \(sec)s"
        }
        return debugReason
    }

    // MARK: - Camera setup

    private func setupCamera() {
        let session = AVCaptureSession()

        session.sessionPreset = .medium

        let camera: AVCaptureDevice?
        #if os(iOS)
        camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        #elseif os(macOS)
        camera = AVCaptureDevice.default(for: .video)
        #else
        camera = nil
        #endif

        guard let camera else {
            Task { @MainActor in self.permissionDenied = true }
            return
        }

        #if os(iOS)
        do {
            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            camera.unlockForConfiguration()
        } catch {
            // Frame-rate lock failed; the session still works at the camera's
            // default rate, so we don't surface to UI. Log to Sentry as info
            // so we know if it's happening on real devices.
            Telemetry.capture(error,
                              tags: ["feature": "true_focus", "operation": "camera_lock"],
                              level: .info)
        }
        #endif

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.hasCameraPermission = granted
                    self?.permissionDenied = !granted
                }
                if granted, let self {
                    self.sessionQueue.async { [weak self] in
                        self?.configureSession(session: session, camera: camera)
                    }
                }
            }
            return
        case .denied, .restricted:
            Task { @MainActor in self.permissionDenied = true }
            return
        @unknown default:
            Task { @MainActor in self.permissionDenied = true }
            return
        }

        Task { @MainActor in self.hasCameraPermission = true }
        configureSession(session: session, camera: camera)
    }

    private func configureSession(session: AVCaptureSession, camera: AVCaptureDevice) {
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) { session.addInput(input) }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: sessionQueue)
            output.alwaysDiscardsLateVideoFrames = true

            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
            }

            captureSession = session
            session.startRunning()

            Task { @MainActor in
                self.startDetectionTimer()
            }
        } catch {
            // configureSession only throws on AVCaptureDeviceInput init —
            // typically a hardware/permission edge case that surfaces to the
            // user as "permission denied". Worth knowing about on real devices.
            Telemetry.capture(error,
                              tags: ["feature": "true_focus", "operation": "configure_session"])
            Task { @MainActor in self.permissionDenied = true }
        }
    }

    // MARK: - Detection loop

    private func startDetectionTimer() {
        scheduleNextCheck()
    }

    private func scheduleNextCheck() {
        detectionTimer?.invalidate()

        let interval: TimeInterval
        switch focusState {
        case .setup:
            interval = setupInterval
        case .working:
            interval = workingInterval
        case .grace, .notWorking:
            interval = alertInterval
        }

        detectionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.captureAndAnalyze()
        }
    }

    private func captureAndAnalyze() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            let image: CGImage?

            #if os(iOS)
            if let tracker = self.gazeTracker, tracker.isAvailable {
                image = tracker.latestCGImage()
            } else {
                image = self.getFrameFromCaptureSession()
            }
            #else
            image = self.getFrameFromCaptureSession()
            #endif

            guard let image else {
                Task { @MainActor in
                    self.handleNoFrame()
                    self.scheduleNextCheck()
                }
                return
            }

            // During setup: always run both face + scene (every 1s for responsive feedback)
            let inSetup: Bool
            Task { @MainActor in }  // just to capture
            inSetup = self.stateMachine.state.isSetup

            let faceRequest = VNDetectFaceLandmarksRequest()
            var requests: [VNRequest] = [faceRequest]

            #if os(macOS)
            let bodyRequest = VNDetectHumanBodyPoseRequest()
            requests.append(bodyRequest)
            #endif

            #if os(iOS)
            let needsSceneRefresh: Bool
            if inSetup {
                // During setup, always run scene classification for responsive checklist
                needsSceneRefresh = true
            } else {
                needsSceneRefresh = Date().timeIntervalSince(self.lastSceneClassificationTime) >= self.sceneCacheInterval
            }
            var classifyRequest: VNClassifyImageRequest?
            if needsSceneRefresh {
                let req = VNClassifyImageRequest()
                classifyRequest = req
                requests.append(req)
            }
            #endif

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform(requests)

                let face = (faceRequest.results as? [VNFaceObservation])?.first

                var body: VNHumanBodyPoseObservation?
                #if os(macOS)
                body = (bodyRequest.results as? [VNHumanBodyPoseObservation])?.first
                #endif

                var sceneLabels: [String: Float]
                #if os(iOS)
                if let classifyRequest, let classifications = classifyRequest.results as? [VNClassificationObservation] {
                    var labels: [String: Float] = [:]
                    for c in classifications where c.confidence > 0.05 {
                        labels[c.identifier] = c.confidence
                    }
                    sceneLabels = labels
                    Task { @MainActor in
                        self.cachedSceneLabels = labels
                        self.lastSceneClassificationTime = Date()
                    }
                } else {
                    sceneLabels = self.cachedSceneLabels
                }
                #else
                sceneLabels = [:]
                #endif

                Task { @MainActor in
                    if self.isInSetup {
                        self.processSetupResult(face: face, sceneLabels: sceneLabels)
                    } else {
                        self.processResult(face: face, body: body, sceneLabels: sceneLabels)
                    }
                    self.scheduleNextCheck()
                }
            } catch {
                // Vision request failed mid-session. We treat it as a missed
                // signal (signalsPass: false) and continue, but capture a
                // sample so we can spot a pattern across users — these
                // failures fire many times per second so we throttle: capture
                // is sampled, breadcrumb is always.
                Telemetry.breadcrumb("Vision request failed: \(error.localizedDescription)",
                                     category: "true_focus",
                                     level: .warning)
                Task { @MainActor in
                    self.debugReason = "Error: \(error.localizedDescription)"
                    if !self.isInSetup {
                        let newState = self.stateMachine.tick(signalsPass: false)
                        self.applyState(newState)
                    }
                    self.scheduleNextCheck()
                }
            }
        }
    }

    private func handleNoFrame() {
        if isInSetup {
            setupFaceDetected = false
            setupSceneDetected = false
            consecutiveSetupPasses = 0
            setupHoldProgress = 0
            debugReason = "Waiting for camera..."
        } else {
            processResult(face: nil, body: nil, sceneLabels: [:])
        }
    }

    // MARK: - Setup processing

    private func processSetupResult(face: VNFaceObservation?, sceneLabels: [String: Float]) {
        let hasFace = face != nil

        // Update visual feedback -- show top labels with match status
        updateVisualLabels(from: sceneLabels)

        // Run scene signal to check for work environment
        let frame = FrameData(
            face: face,
            bodyPose: nil,
            strictness: strictness,
            sceneLabels: sceneLabels
        )
        let sceneResult = SceneClassificationSignal().evaluate(frame: frame)
        let hasScene: Bool
        switch sceneResult {
        case .pass:     hasScene = true
        case .fail:     hasScene = false
        case .notAvailable: hasScene = false
        }

        setupFaceDetected = hasFace
        setupSceneDetected = hasScene

        if hasFace && hasScene {
            consecutiveSetupPasses += 1
            setupHoldProgress = min(consecutiveSetupPasses, setupHoldRequired)

            if consecutiveSetupPasses >= setupHoldRequired {
                // Setup complete -- transition to working
                isInSetup = false
                stateMachine.setupComplete()
                applyState(stateMachine.state)
                debugReason = "Session started"
                return
            }

            debugReason = "Hold steady... \(setupHoldRequired - consecutiveSetupPasses)s"
        } else {
            consecutiveSetupPasses = 0
            setupHoldProgress = 0

            if !hasFace && !hasScene {
                debugReason = "Position your phone to see you and your workspace"
            } else if !hasFace {
                debugReason = "We can see your workspace — now show your face"
            } else {
                debugReason = "We can see you — now include your laptop or notebook"
            }
        }
    }

    // MARK: - Session processing

    private func processResult(face: VNFaceObservation?, body: VNHumanBodyPoseObservation?, sceneLabels: [String: Float]) {
        // Update visual feedback -- show top labels with match status
        updateVisualLabels(from: sceneLabels)

        let result = engine.evaluate(face: face, bodyPose: body, sceneLabels: sceneLabels)

        let newState = stateMachine.tick(signalsPass: result.isWorking)
        debugReason = result.debugSummary

        #if os(iOS)
        if let tracker = gazeTracker, tracker.isAvailable {
            debugReason += " | \(tracker.debugInfo)"
        }
        #endif

        applyState(newState)
    }

    /// Build the label pills: show the top 3 scene labels by confidence,
    /// marking each as green (work match) or red (not a work item).
    private func updateVisualLabels(from sceneLabels: [String: Float]) {
        guard !sceneLabels.isEmpty else { return }

        let matchedSet = Set(
            SceneClassificationSignal.matchWorkingLabels(from: sceneLabels).map { $0.label }
        )

        // Take the top 3 labels by confidence
        let top = sceneLabels
            .sorted { $0.value > $1.value }
            .prefix(3)

        detectedSceneLabels = top.map { (label: $0.key, isWorkMatch: matchedSet.contains($0.key)) }
    }

    private func applyState(_ state: TrueFocusState) {
        focusState = state
        isFocused = state.isWorking
    }

    private func getFrameFromCaptureSession() -> CGImage? {
        sampleBufferLock.lock()
        let buffer = latestSampleBuffer
        sampleBufferLock.unlock()
        guard let buffer else { return nil }
        return sampleBufferToCGImage(buffer)
    }

    private func sampleBufferToCGImage(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FocusDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        sampleBufferLock.lock()
        latestSampleBuffer = sampleBuffer
        sampleBufferLock.unlock()
    }
}
