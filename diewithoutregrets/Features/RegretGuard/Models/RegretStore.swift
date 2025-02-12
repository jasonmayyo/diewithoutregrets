//
//  RegretStore.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

class RegretStore: ObservableObject {
    static let shared = RegretStore()
    @Published var regrets: [Regret] = Regret.regrets
    @Published var selectedRegret: Regret?
    
    @Published var currentRegretIndex: Int = 0  // Add this line
        
        func cycleRegret() {
            currentRegretIndex = (currentRegretIndex + 1) % regrets.count
        }
    
    func updateRegret(_ updatedRegret: Regret) {
        if let index = regrets.firstIndex(where: { $0.id == updatedRegret.id }) {
            regrets[index] = updatedRegret
        }
    }
    
    func addRegrets(_ newRegrets: [Regret]) {
        regrets.append(contentsOf: newRegrets)
    }
    
    func selectRegret(_ regret: Regret) {
        selectedRegret = regret
    }
}
