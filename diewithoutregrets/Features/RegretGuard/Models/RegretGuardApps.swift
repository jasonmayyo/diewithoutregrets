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

/// How a card asks for its answer in the quiz.
enum AnswerMode: String, Codable, Equatable {
    /// Tap one of several options (the original card type).
    case choices
    /// Type the answer from memory. The card stores the correct answer as
    /// its single choice, so every legacy surface still finds it at
    /// `choices[correctAnswerIndex]`.
    case typed
}

struct Regret: Identifiable, Codable, Equatable {
    let id: UUID
    var regretPrompt: String
    var regret: String
    let createdAt: Date
    var choices: [String]
    var correctAnswerIndex: Int
    var backgroundExplanation: String
    var answerMode: AnswerMode

    /// The canonical correct answer text, valid for both modes.
    var correctAnswer: String {
        choices.indices.contains(correctAnswerIndex) ? choices[correctAnswerIndex] : ""
    }

    init(id: UUID = UUID(),
         regretPrompt: String,
         regret: String,
         createdAt: Date = Date(),
         choices: [String],
         correctAnswerIndex: Int,
         backgroundExplanation: String,
         answerMode: AnswerMode = .choices) {
        self.id = id
        self.regretPrompt = regretPrompt
        self.regret = regret
        self.createdAt = createdAt
        self.choices = choices
        self.correctAnswerIndex = correctAnswerIndex
        self.backgroundExplanation = backgroundExplanation
        self.answerMode = answerMode
    }

    // Cards persisted before answerMode existed decode as .choices.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        regretPrompt = try c.decode(String.self, forKey: .regretPrompt)
        regret = try c.decode(String.self, forKey: .regret)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        choices = try c.decode([String].self, forKey: .choices)
        correctAnswerIndex = try c.decode(Int.self, forKey: .correctAnswerIndex)
        backgroundExplanation = try c.decode(String.self, forKey: .backgroundExplanation)
        answerMode = try c.decodeIfPresent(AnswerMode.self, forKey: .answerMode) ?? .choices
    }
}

/// Grading for typed answers: strict equality after normalization. The quiz
/// gates real screen time, so no fuzzy matching — but nobody should fail on
/// casing, accents, stray spaces, smart quotes or a trailing period.
enum AnswerGrading {
    static func matches(_ input: String, _ expected: String) -> Bool {
        let a = normalize(input)
        return !a.isEmpty && a == normalize(expected)
    }

    static func normalize(_ s: String) -> String {
        var t = s
            .replacingOccurrences(of: "[\u{2018}\u{2019}\u{02BC}]", with: "'", options: .regularExpression)
            .replacingOccurrences(of: "[\u{201C}\u{201D}]", with: "\"", options: .regularExpression)
            .replacingOccurrences(of: "[\u{2013}\u{2014}]", with: "-", options: .regularExpression)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
        // Collapse all whitespace runs (including pasted newlines) to single spaces.
        t = t.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // A single trailing sentence mark never fails a card.
        while let last = t.last, ".?!".contains(last) {
            t.removeLast()
        }
        return t.trimmingCharacters(in: .whitespaces)
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
