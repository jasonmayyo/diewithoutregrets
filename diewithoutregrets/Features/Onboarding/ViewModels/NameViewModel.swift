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
    @Published var answers: [String] = ["", ""]
    
    func canContinue(for index: Int) -> Bool {
        let answer = answers[index]
        return !answer.isEmpty && answer.count >= 20 && answer.count <= 200
    }
}

struct Question: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let placeholder: String
}
