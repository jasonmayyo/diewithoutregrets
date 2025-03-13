//
//  RegretViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/29.
//

import SwiftUI

class RegretViewModel: ObservableObject {
    @Published var regretStore: RegretStore
    
    init(regretStore: RegretStore) {
        self.regretStore = regretStore
    }
    
    func cycleRegret() {
        regretStore.cycleRegret()
    }
    
    func reset() {
        regretStore.currentRegretIndex = 0
    }
}
