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
        let cooldownDuration: TimeInterval = 5 * 60 // 5 minutes
        let currentTime = Date().timeIntervalSince1970
        
        // Use shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
        let lastBreakTime = sharedDefaults?.double(forKey: "LastBreakTime") ?? 0
        
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
