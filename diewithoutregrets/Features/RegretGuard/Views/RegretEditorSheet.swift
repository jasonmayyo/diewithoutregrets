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
    @State private var editedRegret: String
    let regret: Regret
    
    init(regret: Regret) {
        self.regret = regret
        _editedRegret = State(initialValue: regret.regret)
    }
    
    var body: some View {
        VStack {
            // Top Bar with Cancel and Save Buttons
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.black)
                }
                .accessibilityLabel("Cancel")
                .accessibilityHint("Tap to close the editor without saving")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
                
                Button(action: {
                    let updatedRegret = Regret(id: regret.id, regretPrompt: regret.regretPrompt, regret: editedRegret)
                    regretStore.updateRegret(updatedRegret)
                    dismiss()
                }) {
                    Text("Save")
                        .foregroundColor(Color(hex: 0x184449))
                        .bold()
                }
                .accessibilityLabel("Save")
                .accessibilityHint("Tap to save your changes")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
            
            // Title
            Text("Edit Your Regrets")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)
                .accessibilityLabel("Edit Your Regrets")
            
            // Regret Prompt
            Text(regret.regretPrompt)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.horizontal)
                .accessibilityLabel("Prompt: \(regret.regretPrompt)")
            
            // Regret Editor
            VStack(alignment: .leading) {
                Text("You Said...")
                    .accessibilityLabel("You Said")
                
                TextEditor(text: $editedRegret)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: 0x184449), lineWidth: 1)
                    )
                    .accessibilityLabel("Edit your regret")
                    .accessibilityValue(editedRegret)
                    .accessibilityHint("Tap to edit your regret")
            }
            .padding()
            
            Spacer()
        }
        .padding(.top)
        .preferredColorScheme(.light)
    }
}
