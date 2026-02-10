//
//  GazeSignal.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Foundation

#if os(iOS)
import ARKit
import Combine
import SceneKit
import SwiftUI

/// ARKit-based gaze tracking signal for Strict mode on iPhone.
/// Uses ARFaceAnchor.lookAtPoint to determine if the user is looking toward the screen.
/// Also provides the AR camera preview and captured pixel buffers for Vision analysis.
final class GazeTracker: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var isLookingAtScreen = true
    @Published private(set) var isAvailable = false
    @Published private(set) var debugInfo = ""

    /// The ARSCNView that renders the front camera feed. Use this as the camera preview.
    let sceneView: ARSCNView = {
        let view = ARSCNView()
        view.automaticallyUpdatesLighting = false
        view.scene = SCNScene()
        // Remove any AR overlays -- we just want the camera feed
        view.rendersContinuously = true
        return view
    }()

    /// Latest pixel buffer from ARKit for Vision analysis.
    private(set) var latestPixelBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()

    /// How far off-axis the gaze can be (in meters at face distance).
    private let gazeThreshold: Float = 0.08

    var isRunning: Bool { sceneView.session.configuration != nil }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            isAvailable = false
            debugInfo = "ARKit face tracking not available"
            return
        }

        isAvailable = true
        sceneView.session.delegate = self
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = false
        sceneView.session.run(config)
        debugInfo = "Gaze tracking active"
    }

    func stop() {
        sceneView.session.pause()
        debugInfo = "Gaze tracking stopped"
    }

    /// Get the latest captured frame as a CGImage for Vision processing.
    func latestCGImage() -> CGImage? {
        bufferLock.lock()
        let pb = latestPixelBuffer
        bufferLock.unlock()
        guard let pb else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pb)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Store the pixel buffer for Vision analysis
        bufferLock.lock()
        latestPixelBuffer = frame.capturedImage
        bufferLock.unlock()

        // Process face anchors for gaze
        guard let faceAnchor = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }

        let lookAt = faceAnchor.lookAtPoint
        // lookAtPoint is in face-local coordinates.
        // x = horizontal offset, y = vertical offset from face center.
        // z < 0 = looking toward camera/screen.
        let offsetFromCenter = hypot(lookAt.x, lookAt.y)
        let lookingForward = lookAt.z < 0

        let isOnScreen = lookingForward && offsetFromCenter < gazeThreshold

        Task { @MainActor in
            self.isLookingAtScreen = isOnScreen
            self.debugInfo = String(format: "Gaze: x=%.3f y=%.3f z=%.3f %@",
                                    lookAt.x, lookAt.y, lookAt.z,
                                    isOnScreen ? "ON" : "OFF")
        }
    }
}

// MARK: - SwiftUI wrapper for ARSCNView

/// A SwiftUI view that wraps the GazeTracker's ARSCNView to show the front camera feed.
struct ARCameraPreviewView: UIViewRepresentable {
    let sceneView: ARSCNView

    func makeUIView(context: Context) -> ARSCNView {
        sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No updates needed -- ARKit drives the view
    }
}

// MARK: - GazeSignal

/// Signal wrapper for gaze tracking. Queries the GazeTracker for current state.
struct GazeSignal: FocusSignalProtocol {
    let kind = SignalKind.gaze
    let tracker: GazeTracker

    func evaluate(frame: FrameData) -> SignalResult {
        guard tracker.isAvailable else {
            return .notAvailable
        }
        if tracker.isLookingAtScreen {
            return .pass(reason: "Looking at screen")
        } else {
            return .fail(reason: "Not looking at screen")
        }
    }
}

#endif
