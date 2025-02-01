//
//  OpenGuardIntent.swift
//  OpenGuardIntent
//
//  Created by Jason Mayo on 2025/01/30.
//

import AppIntents

struct OpenGuardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Regret Guard"
    static let description = IntentDescription("Opens the Die Without Regrets app")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        print("OpenAppIntent: Attempting to perform")
        NavigationModel.shared.navigate(to: .regretView)
        return .result(value: true)
    }
}
