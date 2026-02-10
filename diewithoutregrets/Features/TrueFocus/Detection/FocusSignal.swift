//
//  FocusSignal.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Foundation
import Vision

// MARK: - Signal Result

/// Result of evaluating a single focus signal.
enum SignalResult {
    /// Signal passes -- user appears to be working for this criterion.
    case pass(reason: String)
    /// Signal fails -- user does not meet this criterion.
    case fail(reason: String)
    /// Signal is not available (e.g. no ARKit). Treated as pass (ignored).
    case notAvailable
}

// MARK: - Frame Data

/// All the data extracted from a single camera frame, passed to each signal for evaluation.
struct FrameData {
    let face: VNFaceObservation?
    let bodyPose: VNHumanBodyPoseObservation?
    let strictness: StrictnessLevel
    /// Scene classification labels with confidence (from VNClassifyImageRequest).
    let sceneLabels: [String: Float]
}

// MARK: - Signal Protocol

/// A single, independent detector that evaluates one aspect of "is the user working?"
protocol FocusSignalProtocol {
    var kind: SignalKind { get }
    func evaluate(frame: FrameData) -> SignalResult
}

// MARK: - Face Presence Signal

/// Checks if a face is detected in the frame.
struct FacePresenceSignal: FocusSignalProtocol {
    let kind = SignalKind.facePresence

    func evaluate(frame: FrameData) -> SignalResult {
        guard frame.face != nil else {
            return .fail(reason: "No face detected")
        }
        return .pass(reason: "Face detected")
    }
}

// MARK: - Posture Signal

/// Checks if shoulders are roughly level (upright posture). Mac only.
struct PostureSignal: FocusSignalProtocol {
    let kind = SignalKind.posture

    func evaluate(frame: FrameData) -> SignalResult {
        guard let body = frame.bodyPose else {
            return .pass(reason: "No body pose (assumed upright)")
        }

        guard let leftShoulder = try? body.recognizedPoint(.leftShoulder),
              let rightShoulder = try? body.recognizedPoint(.rightShoulder),
              leftShoulder.confidence > 0.3, rightShoulder.confidence > 0.3 else {
            return .pass(reason: "Shoulders not visible (assumed upright)")
        }

        let dy = abs(leftShoulder.location.y - rightShoulder.location.y)
        if dy > 0.15 {
            return .fail(reason: String(format: "Not upright (shoulder tilt: %.2f)", dy))
        }

        return .pass(reason: "Upright posture")
    }
}

// MARK: - Head Direction Signal

/// Checks if head yaw is within tolerance (looking roughly forward). Mac only.
struct HeadDirectionSignal: FocusSignalProtocol {
    let kind = SignalKind.headDirection

    func evaluate(frame: FrameData) -> SignalResult {
        guard let face = frame.face else {
            return .fail(reason: "No face for head direction")
        }

        let yaw = face.yaw?.doubleValue ?? 1.0
        let tolerance = frame.strictness.yawTolerance

        if abs(yaw) > tolerance {
            return .fail(reason: String(format: "Head turned (yaw: %.2f, max: %.2f)", yaw, tolerance))
        }

        return .pass(reason: String(format: "Head forward (yaw: %.2f)", yaw))
    }
}

// MARK: - Eye Visibility Signal

/// Checks if both eyes are visible in face landmarks. Mac only.
struct EyeVisibilitySignal: FocusSignalProtocol {
    let kind = SignalKind.eyeVisibility

    func evaluate(frame: FrameData) -> SignalResult {
        guard let face = frame.face else {
            return .fail(reason: "No face for eye check")
        }

        let hasLeftEye = face.landmarks?.leftEye != nil
        let hasRightEye = face.landmarks?.rightEye != nil

        if hasLeftEye && hasRightEye {
            return .pass(reason: "Both eyes visible")
        }
        if hasLeftEye || hasRightEye {
            if frame.strictness == .strict {
                return .fail(reason: "Only one eye visible")
            }
            return .pass(reason: "One eye visible")
        }

        return .fail(reason: "Eyes not visible")
    }
}

// MARK: - Scene Classification Signal

/// Checks if the camera sees a working environment (desk, laptop, notebook, books, etc.)
/// Uses labels from VNClassifyImageRequest.
///
/// Once a workspace is detected, it stays "locked in" for a cooldown period to prevent
/// flickering when the classifier briefly drops confidence between frames.
final class SceneClassificationSignal: FocusSignalProtocol {
    let kind = SignalKind.sceneClassification

    /// Minimum confidence to count as a match. Low threshold because the classifier
    /// fluctuates between frames even when the scene hasn't changed.
    private static let confidenceThreshold: Float = 0.03

    /// Once we detect a workspace, keep it "locked in" for this many evaluation cycles
    /// before requiring re-detection. Prevents flickering.
    private let lockInCycles = 5
    private var cyclesSinceLastDetection = 0
    private var isLockedIn = false

    func reset() {
        cyclesSinceLastDetection = 0
        isLockedIn = false
    }

    /// All keywords for workspace detection (shared between evaluate and static matcher).
    static let workingKeywords: [String] = [
        // Computers & electronics
        "laptop", "notebook", "computer", "desktop", "monitor", "display",
        "screen", "keyboard", "mouse", "trackpad", "tablet", "ipad",
        "machine", "device", "technology", "electronic",
        // Stationery & writing
        "pen", "pencil", "marker", "highlighter", "eraser", "ruler",
        "paper", "document", "binder", "folder", "clipboard",
        "writing", "stationery", "note", "planner", "calendar",
        // Books & reading
        "book", "textbook", "workbook", "reading", "magazine", "journal",
        // Furniture & workspace
        "desk", "table", "office", "workspace", "cubicle", "chair",
        "furniture", "shelf", "cabinet",
        // Lighting & accessories
        "lamp", "desk_lamp", "light",
        // Scene types
        "library", "study", "classroom", "lecture", "school",
        "home_office", "conference", "meeting",
        // Bags & accessories often at a desk
        "backpack", "briefcase", "calculator", "stapler", "tape",
        "headphone", "earphone", "cup", "mug", "coffee", "water_bottle",
    ]

    func evaluate(frame: FrameData) -> SignalResult {
        guard !frame.sceneLabels.isEmpty else {
            // No labels available -- if we're locked in, still pass
            if isLockedIn {
                cyclesSinceLastDetection += 1
                if cyclesSinceLastDetection > lockInCycles {
                    isLockedIn = false
                    return .notAvailable
                }
                return .pass(reason: "Work environment (cached)")
            }
            return .notAvailable
        }

        let matched = Self.matchWorkingLabels(from: frame.sceneLabels)

        if let best = matched.first {
            // Detected -- lock in and reset counter
            isLockedIn = true
            cyclesSinceLastDetection = 0
            return .pass(reason: String(format: "Work environment: %@ (%.0f%%)", best.label, best.confidence * 100))
        }

        // Not detected this frame -- but if we recently detected, keep passing
        if isLockedIn {
            cyclesSinceLastDetection += 1
            if cyclesSinceLastDetection <= lockInCycles {
                return .pass(reason: "Work environment (cached)")
            }
            // Exceeded cooldown -- actually lost the scene
            isLockedIn = false
        }

        // Show top labels in debug for tuning
        let topLabels = frame.sceneLabels
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { String(format: "%@:%.0f%%", $0.key, $0.value * 100) }
            .joined(separator: ", ")

        return .fail(reason: "No work items detected [\(topLabels)]")
    }

    /// Returns matched working-environment labels sorted by confidence (highest first).
    static func matchWorkingLabels(from sceneLabels: [String: Float]) -> [(label: String, confidence: Float)] {
        var matched: [(label: String, confidence: Float)] = []
        for (label, confidence) in sceneLabels {
            let lower = label.lowercased()
            for keyword in workingKeywords {
                if lower.contains(keyword) && confidence > confidenceThreshold {
                    matched.append((label, confidence))
                    break
                }
            }
        }
        return matched.sorted { $0.confidence > $1.confidence }
    }
}
