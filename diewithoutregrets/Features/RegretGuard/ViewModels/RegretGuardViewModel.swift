//
//  RegretGuardViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

class RegretGuardViewModel: ObservableObject {
    @Published var showInstructions = false
    @Published var showEditRegret = false
    @Published var selectedApp: RegretApp?
    
    var apps: [RegretApp] {
        RegretApp.sampleApps
    }
    
    func selectApp(_ app: RegretApp) {
        selectedApp = app
        showInstructions = true
    }
}
