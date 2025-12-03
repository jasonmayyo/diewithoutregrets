//
//  FaithGuardIntent.swift
//  RegretGuardIntent
//
//  Created by Jason Mayo on 2025/01/29.
//

import AppIntents
import Foundation
import UIKit

struct FaithGuardIntent: AppIntent {
    static var title: LocalizedStringResource = "Faith Guard"
    
    static var description = IntentDescription(
        "Check if Faith Guard protection is active for this app"
    )
    
    @Parameter(title: "App Name")
    var appName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Active Faith Guard when \(\.$appName) opens")
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let cooldownDuration: TimeInterval = 5 * 60 // 5 minutes
        let currentTime = Date().timeIntervalSince1970
        
        // Use shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.faithguardapp")
        let lastBreakTime = sharedDefaults?.double(forKey: "LastBreakTime") ?? 0
        
        print("FaithGuardIntent: Current time:", currentTime)
        print("FaithGuardIntent: Last break time:", lastBreakTime)
        print("FaithGuardIntent: Time difference:", currentTime - lastBreakTime)
        print("FaithGuardIntent: Cooldown duration:", cooldownDuration)
        
        // Store the app name for later use
        sharedDefaults?.set(appName, forKey: "LastGuardedApp")
        
        // Only check if we're within the cooldown period
        if currentTime - lastBreakTime < cooldownDuration {
            print("FaithGuardIntent: Within cooldown period, skipping break")
            return .result(value: false)
        }
        
        print("FaithGuardIntent: Outside cooldown period, showing FaithVerseView")
        return .result(value: true)
    }
}

// Backward compatibility alias
typealias RegretGuardIntent = FaithGuardIntent
