//
//  AutoGenerateFlashcardSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/03/14.
//

import SwiftUI

struct AutoGenerateFlashcardsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var deck: Deck
    @State private var inputText: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack {
                Text("Paste flashcards text below")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $inputText)
                    .frame(height: 300)
                    .border(Color.gray, width: 1)
                    .padding()
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.bottom)
                }
                
                Button("Generate Flashcards") {
                    let newFlashcards = parseRegrets(from: inputText)
                    if newFlashcards.isEmpty {
                        errorMessage = "No valid flashcards were found. Please check your format."
                    } else {
                        deck.cards.append(contentsOf: newFlashcards)
                        dismiss()
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Auto Generate Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Parsing Helpers
    
    func parseRegrets(from input: String) -> [Regret] {
        var regrets: [Regret] = []
        // Split the input by occurrences of "Regret(" (ignoring any empty segments)
        let blocks = input.components(separatedBy: "Regret(").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for block in blocks {
            // Attempt to extract each field using regex.
            guard let prompt = extractField("regretPrompt", from: block),
                  let regretText = extractField("regret", from: block),
                  let explanation = extractField("backgroundExplanation", from: block),
                  let correctAnswerIndexStr = extractField("correctAnswerIndex", from: block),
                  let correctAnswerIndex = Int(correctAnswerIndexStr),
                  let choices = extractChoices(from: block)
            else { continue }
            
            let newRegret = Regret(
                regretPrompt: prompt,
                regret: regretText,
                choices: choices,
                correctAnswerIndex: correctAnswerIndex,
                backgroundExplanation: explanation
            )
            regrets.append(newRegret)
        }
        return regrets
    }
    
    func extractField(_ field: String, from text: String) -> String? {
        // First, try to match a quoted value, e.g. regretPrompt: "some text"
        let quotedPattern = "\(field):\\s*\"([^\"]+)\""
        if let result = matchRegex(quotedPattern, in: text) {
            return result
        }
        
        // If the field is correctAnswerIndex, try an unquoted pattern
        if field == "correctAnswerIndex" {
            let numberPattern = "\(field):\\s*([0-9]+)"
            return matchRegex(numberPattern, in: text)
        }
        
        return nil
    }

    func matchRegex(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsText = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if let match = results.first, match.numberOfRanges > 1 {
            return nsText.substring(with: match.range(at: 1))
        }
        return nil
    }

    
    func extractChoices(from text: String) -> [String]? {
        // Matches the choices array block: choices: [ "Option 1", "Option 2", ... ]
        let pattern = "choices:\\s*\\[([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsText = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if let match = results.first, match.numberOfRanges > 1 {
            let choicesContent = nsText.substring(with: match.range(at: 1))
            // Now extract each quoted option.
            let choicePattern = "\"([^\"]+)\""
            guard let choiceRegex = try? NSRegularExpression(pattern: choicePattern, options: []) else { return nil }
            let choiceMatches = choiceRegex.matches(in: choicesContent, options: [], range: NSRange(location: 0, length: (choicesContent as NSString).length))
            var choices: [String] = []
            for choiceMatch in choiceMatches {
                if choiceMatch.numberOfRanges > 1 {
                    let choice = (choicesContent as NSString).substring(with: choiceMatch.range(at: 1))
                    choices.append(choice)
                }
            }
            return choices
        }
        return nil
    }
}
