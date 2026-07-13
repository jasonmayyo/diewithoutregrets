//
//  RegretGuardIntent.swift
//  RegretGuardIntent
//
//  Created by Jason Mayo on 2025/01/29.
//

import AppIntents
import Foundation
import UIKit

struct RegretGuardIntent: AppIntent {
    static var title: LocalizedStringResource = "Regret Guard"
    
    static var description = IntentDescription(
        "Check if a Regret Guard has been placed on this app"
    )
    
    @Parameter(title: "App Name")
    var appName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Active Regret Guard when \(\.$appName) opens")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let currentTime = Date().timeIntervalSince1970

        // Use shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")

        // v2 kill switch: once Screen Time setup is complete, the old Shortcut
        // automations become silent no-ops (returning false means the shortcut
        // never calls OpenGuardIntent). Counted so analytics can watch the
        // automation tail before the targets are removed in 3.0.
        if sharedDefaults?.bool(forKey: SGContract.Keys.setupComplete) == true {
            let fires = (sharedDefaults?.integer(forKey: SGContract.Keys.legacyIntentFireCount) ?? 0) + 1
            sharedDefaults?.set(fires, forKey: SGContract.Keys.legacyIntentFireCount)
            sharedDefaults?.synchronize()
            print("RegretGuardIntent: v2 active, legacy automation no-op (fire #\(fires))")
            return .result(value: false)
        }
        let lastBreakTime = sharedDefaults?.double(forKey: "LastBreakTime") ?? 0
        
        // Read the user's chosen break duration (in minutes), default to 5 if not set
        let breakDurationMinutes = sharedDefaults?.integer(forKey: "BreakDurationMinutes")
        let cooldownDuration: TimeInterval = TimeInterval((breakDurationMinutes ?? 5) > 0 ? (breakDurationMinutes ?? 5) : 5) * 60
        
        print("RegretGuardIntent: Current time:", currentTime)
        print("RegretGuardIntent: Last break time:", lastBreakTime)
        print("RegretGuardIntent: Time difference:", currentTime - lastBreakTime)
        print("RegretGuardIntent: Cooldown duration:", cooldownDuration)
        
        // Store the app name for later use
        sharedDefaults?.set(appName, forKey: "LastGuardedApp")
        
        // Only check if we're within the cooldown period
        if currentTime - lastBreakTime < cooldownDuration {
            print("RegretGuardIntent: Within cooldown period, skipping break")
            return .result(value: false)
        }
        
        print("RegretGuardIntent: Outside cooldown period, showing RegretView")
        return .result(value: true)
    }
}
