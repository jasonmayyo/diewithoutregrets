//
//  OpenGuardIntent.swift
//  OpenGuardIntent
//
//  Created by Jason Mayo on 2025/01/30.
//

import AppIntents

struct OpenFaithGuardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Faith Guard"
    static let description = IntentDescription("Opens the Faith Guard app")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        print("OpenFaithGuardIntent: Attempting to perform")
        NavigationModel.shared.navigate(to: .regretView)
        return .result(value: true)
    }
}

// Backward compatibility alias
typealias OpenGuardIntent = OpenFaithGuardIntent
