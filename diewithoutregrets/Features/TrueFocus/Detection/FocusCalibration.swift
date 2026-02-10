//
//  FocusCalibration.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Foundation

/// Calibration data for focus detection. Records baseline face position and size
/// so we can detect "working zone" and stability.
struct FocusCalibration: Codable {
    /// Face center in normalized Vision coords (0-1, origin bottom-left).
    let faceCenterX: Double
    let faceCenterY: Double
    /// Face bounding box area (width * height) in normalized coords.
    let faceArea: Double
    /// Timestamp when calibrated.
    let calibratedAt: Date
}

// MARK: - Persistence

private let calibrationKey = "Attent.focusCalibration"

func loadFocusCalibration() -> FocusCalibration? {
    guard let data = UserDefaults.standard.data(forKey: calibrationKey) else { return nil }
    return try? JSONDecoder().decode(FocusCalibration.self, from: data)
}

func saveFocusCalibration(_ calibration: FocusCalibration) {
    let data = (try? JSONEncoder().encode(calibration)) ?? Data()
    UserDefaults.standard.set(data, forKey: calibrationKey)
}

func clearFocusCalibration() {
    UserDefaults.standard.removeObject(forKey: calibrationKey)
}
