//
//  RegretGuardApps.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct Deck: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var cards: [Regret]
    var createdAt: Date
    
    init(id: UUID = UUID(), name: String, cards: [Regret] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.cards = cards
        self.createdAt = createdAt
    }
}

struct Regret: Identifiable, Codable, Equatable {
    let id: UUID
    var regretPrompt: String
    var regret: String
    let createdAt: Date
    var choices: [String]
    var correctAnswerIndex: Int
    var backgroundExplanation: String  // Add this new property
    
    init(id: UUID = UUID(),
         regretPrompt: String,
         regret: String,
         createdAt: Date = Date(),
         choices: [String],
         correctAnswerIndex: Int,
         backgroundExplanation: String) {  // Update initializer
        self.id = id
        self.regretPrompt = regretPrompt
        self.regret = regret
        self.createdAt = createdAt
        self.choices = choices
        self.correctAnswerIndex = correctAnswerIndex
        self.backgroundExplanation = backgroundExplanation
    }
}

extension Regret {
    static let regrets: [Regret] = [
        Regret(
            regretPrompt: "Not spending enough time with family",
            regret: "Not spending enough time with the people I love",
            choices: ["Option 1", "Option 2", "Option 3", "Option 4"],
            correctAnswerIndex: 0,
            backgroundExplanation: "Studies show people who prioritize family time report higher life satisfaction and lower end-of-life regrets."
        ),
        // Add other entries with background explanations
    ]
}
