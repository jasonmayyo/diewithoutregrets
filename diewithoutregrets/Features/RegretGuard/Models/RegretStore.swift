//
//  RegretStore.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

class RegretStore: ObservableObject {
    static let shared = RegretStore()
    
    @Published var regrets: [Regret] {
        didSet {
            saveRegrets()
        }
    }
    @Published var selectedRegret: Regret?
    @Published var currentRegretIndex: Int = 0
    
    public init() {
        // Load saved regrets from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "SavedRegrets"),
           let savedRegrets = try? JSONDecoder().decode([Regret].self, from: data) {
            self.regrets = savedRegrets
        } else {
            self.regrets = []
        }
    }
    
    private func saveRegrets() {
        do {
            let encoded = try JSONEncoder().encode(regrets)
            UserDefaults.standard.set(encoded, forKey: "SavedRegrets")
        } catch {
            print("Error saving regrets: \(error)")
        }
    }
    
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
        saveRegrets()
    }
    
    func selectRegret(_ regret: Regret) {
        selectedRegret = regret
        saveRegrets()
    }
}
