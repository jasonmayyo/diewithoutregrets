//
//  RegretViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/29.
//

import SwiftUI

class RegretViewModel: ObservableObject {
    @Published var showRegret: Bool = false
    @Published var showFinalMessage: Bool = false
    @Published var currentRegretIndex: Int = 0
    @Published var regretMessage: String = ""
    
    let regrets: [Regret] = Regret.regrets
    
    func updateRegretMessage() {
        guard !regrets.isEmpty else { return }
        regretMessage = regrets[currentRegretIndex].regret
    }
    
    func resetView() {
        showRegret = false
        showFinalMessage = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation {
                self.showRegret = true
                self.updateRegretMessage()
            }
        }
    }
    
    func getNextRegretIndex() -> Int {
        return (currentRegretIndex + 1) % regrets.count
    }
}
