//
//  StrictnessLevel.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Foundation

/// The three strictness levels for focus detection.
/// Each level controls grace duration and (on Mac) how tight the head direction check is.
enum StrictnessLevel: String, CaseIterable, Identifiable, Codable {
    case relaxed
    case standard
    case strict

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed:  return "Relaxed"
        case .standard: return "Standard"
        case .strict:   return "Strict"
        }
    }

    var description: String {
        switch self {
        case .relaxed:  return "Face + desk/laptop in view"
        case .standard: return "Face + desk/laptop in view"
        case .strict:   return "Face + desk/laptop + gaze"
        }
    }

    var icon: String {
        switch self {
        case .relaxed:  return "gauge.low"
        case .standard: return "gauge.medium"
        case .strict:   return "gauge.high"
        }
    }

    // MARK: - Grace period (seconds before timer pauses)

    var graceDuration: Int {
        switch self {
        case .relaxed:  return 45
        case .standard: return 20
        case .strict:   return 10
        }
    }

    // MARK: - Head direction yaw tolerance (Mac only)

    var yawTolerance: Double {
        switch self {
        case .relaxed:  return 0.7
        case .standard: return 0.5
        case .strict:   return 0.3
        }
    }

    // MARK: - Required signals per platform

    /// iPhone: person present + working scene (laptop/notebook/desk visible).
    var iPhoneSignals: Set<SignalKind> {
        return [.facePresence, .sceneClassification]
    }

    /// Mac: face pointing roughly at camera.
    var macSignals: Set<SignalKind> {
        switch self {
        case .relaxed:
            return [.facePresence, .headDirection]
        case .standard:
            return [.facePresence, .headDirection, .eyeVisibility]
        case .strict:
            return [.facePresence, .headDirection, .eyeVisibility, .posture]
        }
    }

    /// Returns the right signal set for the current platform.
    var requiredSignals: Set<SignalKind> {
        #if os(iOS)
        return iPhoneSignals
        #else
        return macSignals
        #endif
    }

    /// On iPhone in Strict mode, gaze tracking supplements scene detection.
    var usesGazeTracking: Bool {
        self == .strict
    }
}

/// Identifies each type of signal the engine can evaluate.
enum SignalKind: String, Hashable {
    case facePresence
    case sceneClassification
    case headDirection
    case eyeVisibility
    case posture
    case gaze
}
