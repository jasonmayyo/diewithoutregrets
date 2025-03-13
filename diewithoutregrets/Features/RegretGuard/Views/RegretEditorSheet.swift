//
//  RegretEditorSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var regretStore: RegretStore
    @State private var editedPrompt: String
    @State private var editedRegret: String
    @State private var editedExplanation: String
    let regret: Regret
    @State private var editedChoices: [String]
    @State private var editedCorrectIndex: Int
    
    init(regret: Regret) {
        self.regret = regret
        _editedPrompt = State(initialValue: regret.regretPrompt)
        _editedRegret = State(initialValue: regret.regret)
        _editedExplanation = State(initialValue: regret.backgroundExplanation)
        _editedChoices = State(initialValue: regret.choices)
        _editedCorrectIndex = State(initialValue: regret.correctAnswerIndex)
    }
    
    var body: some View {
        VStack {
            // Top Bar with Cancel and Save Buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.black)
                
                Spacer()
                
                Button("Save") { saveChanges() }
                    .foregroundColor(Color(hex: 0x184449))
                    .bold()
            }
            .padding()
            
            Text("Edit Flashcard")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Prompt Editor
                    VStack(alignment: .leading) {
                        Text("Question")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $editedPrompt)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: 0x184449), lineWidth: 1)
                            )
                    }
                    
                    // Explanation Editor
                    VStack(alignment: .leading) {
                        Text("Explanation")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $editedExplanation)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: 0x184449), lineWidth: 1)
                            )
                    }
                    
                    // Answer Options
                    VStack(alignment: .leading) {
                        Text("Answer Options")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        ForEach(0..<4, id: \.self) { index in
                            HStack {
                                TextField("Option \(index + 1)", text: $editedChoices[index])
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    editedCorrectIndex = index
                                }) {
                                    Image(systemName: editedCorrectIndex == index ?
                                        "checkmark.circle.fill" : "circle")
                                        .foregroundColor(editedCorrectIndex == index ? .green : .gray)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .padding()
            }
        }
        .preferredColorScheme(.light)
    }
    
    private func saveChanges() {
        let updatedRegret = Regret(
            id: regret.id,
            regretPrompt: editedPrompt,
            regret: editedRegret,
            choices: editedChoices,
            correctAnswerIndex: editedCorrectIndex,
            backgroundExplanation: editedExplanation
        )
        regretStore.updateRegret(updatedRegret)
        dismiss()
    }
}

#Preview {
    RegretEditorSheet(regret: Regret(
        regretPrompt: "Sample Prompt",
        regret: "Sample Response",
        choices: ["Option 1", "Option 2", "Option 3", "Option 4"],
        correctAnswerIndex: 0,
        backgroundExplanation: "Sample explanation"
    ))
    .environmentObject(RegretStore())
}
