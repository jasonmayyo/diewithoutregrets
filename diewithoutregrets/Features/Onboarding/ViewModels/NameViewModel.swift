//
//  NameViewModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

class NameViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var canContinue: Bool = false
    
    func handleNameChange(_ newName: String) {
        name = newName
        canContinue = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func handleContinue() {
        guard !name.isEmpty else { return }
        // Handle the name submission (e.g., save to UserDefaults, send to API, etc.)
        print("Submitted name: \(name)")
    }
}

class RegretQuestionViewModel: ObservableObject {
    @Published var regrets: [Regret] = [
        Regret(
            regretPrompt: "",
            regret: "",
            choices: [
                "",
                "",
                "",
                ""
            ],
            correctAnswerIndex: 0,
            backgroundExplanation: ""
            
        ),
    ]
    
    func canContinue(for index: Int) -> Bool {
        !regrets[index].regretPrompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        !regrets[index].regret.trimmingCharacters(in: .whitespaces).isEmpty
    }
}


struct Question: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let placeholder: String
}
