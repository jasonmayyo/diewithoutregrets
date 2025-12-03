//
//  FaithGuardViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

class FaithGuardViewModel: ObservableObject {
    @Published var showInstructions = false
    @Published var showEditVerse = false
    @Published var selectedApp: GuardedApp?
    
    var apps: [GuardedApp] {
        GuardedApp.sampleApps
    }
    
    func selectApp(_ app: GuardedApp) {
        selectedApp = app
        showInstructions = true
    }
}

// Backward compatibility alias
typealias RegretGuardViewModel = FaithGuardViewModel
