//
//  AvgScreenTimeViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

class AvgScreenTimeViewModel: ObservableObject {
    @Published var selectedOption: ScreenTimeOption?
    @Published var canContinue: Bool = false
    
    let screenTimeOptions: [ScreenTimeOption] = [
        ScreenTimeOption(range: "Under 1 hour", hours: 0...1),
        ScreenTimeOption(range: "1-3 hours", hours: 1...3),
        ScreenTimeOption(range: "3-4 hours", hours: 3...4),
        ScreenTimeOption(range: "4-5 hours", hours: 4...5),
        ScreenTimeOption(range: "5-7 hours", hours: 5...6),
        ScreenTimeOption(range: "7+ hours", hours: 7...24)
    ]
    
    let AgeOptions: [ScreenTimeOption] = [
        ScreenTimeOption(range: "Under 14", hours: 0...1),
        ScreenTimeOption(range: "14 - 18", hours: 1...3),
        ScreenTimeOption(range: "19 - 25", hours: 3...4),
        ScreenTimeOption(range: "26 - 34", hours: 4...5),
        ScreenTimeOption(range: "35 - 44", hours: 5...6),
        ScreenTimeOption(range: "45 - 55", hours: 5...6),
        ScreenTimeOption(range: "56 - 65", hours: 5...6),
        ScreenTimeOption(range: "Over 65", hours: 7...24)
    ]
    
    func selectOption(_ option: ScreenTimeOption) {
        selectedOption = option
        canContinue = true
    }
    
    func handleContinue() {
        guard let selected = selectedOption else { return }
        print("Selected screen time: \(selected.range)")
    }
}



