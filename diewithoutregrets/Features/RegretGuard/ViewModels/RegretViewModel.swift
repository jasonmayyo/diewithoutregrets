//
//  RegretViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/29.
//

import SwiftUI

class RegretViewModel: ObservableObject {
    @Published var showRegret = false
    @Published var showFinalMessage = false
    @Published var regretMessage = ""
    
    @ObservedObject var regretStore: RegretStore
    
    init(regretStore: RegretStore) {
        self.regretStore = regretStore
    }
    
    func resetView() {
        showRegret = false
        showFinalMessage = false
        updateRegretMessage()
    }
    
    func updateRegretMessage() {
        guard !regretStore.regrets.isEmpty else { return }
        regretMessage = regretStore.regrets[regretStore.currentRegretIndex].regret
    }
    
    func cycleRegret() {
        regretStore.cycleRegret()
        updateRegretMessage()
    }
}
