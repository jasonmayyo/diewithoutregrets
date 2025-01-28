//
//  RegretGuardViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

class RegretGuardViewModel: ObservableObject {
    @Published var showInstructions: Bool = false
    @Published var selectedApp: RegretApp?
    
    let apps = RegretApp.sampleApps
    
    func selectApp(_ app: RegretApp) {
        selectedApp = app
        showInstructions = true
    }
}
