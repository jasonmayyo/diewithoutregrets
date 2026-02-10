//
//  FocusEngine.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Foundation
import Vision

/// Result of evaluating all signals for a single frame.
struct EngineResult {
    let isWorking: Bool
    let reasons: [String]
    let failReasons: [String]

    var debugSummary: String {
        if isWorking {
            let passReasons = reasons.isEmpty ? "All signals pass" : reasons.joined(separator: ", ")
            return "Working: \(passReasons)"
        } else {
            let failSummary = failReasons.isEmpty ? "Unknown" : failReasons.joined(separator: "; ")
            return "Not working: \(failSummary)"
        }
    }
}

/// Combines multiple focus signals based on the selected strictness level.
///
/// iPhone: face present + working scene (laptop/notebook/desk visible) = working.
/// Mac: face present + looking roughly at camera = working.
final class FocusEngine {
    let strictness: StrictnessLevel

    private let facePresence = FacePresenceSignal()
    private let posture = PostureSignal()
    private let headDirection = HeadDirectionSignal()
    private let eyeVisibility = EyeVisibilitySignal()
    private let sceneClassification = SceneClassificationSignal()

    #if os(iOS)
    private var gazeSignal: GazeSignal?

    func setGazeTracker(_ tracker: GazeTracker) {
        gazeSignal = GazeSignal(tracker: tracker)
    }
    #endif

    init(strictness: StrictnessLevel) {
        self.strictness = strictness
    }

    func evaluate(face: VNFaceObservation?, bodyPose: VNHumanBodyPoseObservation?, sceneLabels: [String: Float] = [:]) -> EngineResult {
        let frame = FrameData(
            face: face,
            bodyPose: bodyPose,
            strictness: strictness,
            sceneLabels: sceneLabels
        )

        let required = strictness.requiredSignals
        var passReasons: [String] = []
        var failReasons: [String] = []
        var allPass = true

        for signalKind in required {
            let result = evaluateSignal(signalKind, frame: frame)
            switch result {
            case .pass(let reason):
                passReasons.append(reason)
            case .fail(let reason):
                failReasons.append(reason)
                allPass = false
            case .notAvailable:
                break
            }
        }

        #if os(iOS)
        if strictness.usesGazeTracking, let gazeSignal = gazeSignal {
            let gazeResult = gazeSignal.evaluate(frame: frame)
            switch gazeResult {
            case .pass(let reason):
                passReasons.append(reason)
            case .fail(let reason):
                failReasons.append(reason)
                allPass = false
            case .notAvailable:
                break
            }
        }
        #endif

        return EngineResult(
            isWorking: allPass,
            reasons: passReasons,
            failReasons: failReasons
        )
    }

    private func evaluateSignal(_ kind: SignalKind, frame: FrameData) -> SignalResult {
        switch kind {
        case .facePresence:         return facePresence.evaluate(frame: frame)
        case .sceneClassification:  return sceneClassification.evaluate(frame: frame)
        case .headDirection:        return headDirection.evaluate(frame: frame)
        case .eyeVisibility:        return eyeVisibility.evaluate(frame: frame)
        case .posture:              return posture.evaluate(frame: frame)
        case .gaze:
            #if os(iOS)
            return gazeSignal?.evaluate(frame: frame) ?? .notAvailable
            #else
            return .notAvailable
            #endif
        }
    }

    func reset() {
        sceneClassification.reset()
    }
}
