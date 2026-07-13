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

        // v2 kill switch (defense in depth): the distributed iCloud shortcuts
        // are supposed to branch on RegretGuardIntent's result before calling
        // this, but their internals aren't verifiable — never force the quiz
        // once Screen Time setup is complete. (openAppWhenRun still opens the
        // app; that part can't be prevented.)
        let sharedDefaults = UserDefaults(suiteName: SGContract.appGroupID)
        if sharedDefaults?.bool(forKey: SGContract.Keys.setupComplete) == true {
            return .result(value: false)
        }

        NavigationModel.shared.navigate(to: .regretView)
        return .result(value: true)
    }
}
