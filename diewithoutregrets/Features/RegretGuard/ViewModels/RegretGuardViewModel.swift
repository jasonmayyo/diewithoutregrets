//
//  RegretGuardViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

class RegretGuardViewModel: ObservableObject {
    @Published var showInstructions: Bool = false
    @Published var showEditRegret: Bool = false
    @Published var selectedApp: RegretApp?
    @Published var selectedRegret: Regret?
    
    @Published var regrets: [Regret] = Regret.regrets
    
    let apps = RegretApp.sampleApps
    
    func selectRegret(_ regret: Regret) {
        selectedRegret = regret
        showEditRegret = true
    }
    
    func selectApp(_ app: RegretApp) {
        selectedApp = app
        showInstructions = true
    }
    
    func updateRegret(_ updatedRegret: Regret) {
        if let index = regrets.firstIndex(where: { $0.id == updatedRegret.id }) {
            regrets[index] = updatedRegret
            objectWillChange.send()
        }
    }

}
