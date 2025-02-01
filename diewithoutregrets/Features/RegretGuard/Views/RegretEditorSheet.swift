//
//  RegretEditorSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: RegretGuardViewModel // Access the view model
    @State private var editedRegret: String
    
    let regret: Regret
    
    init(regret: Regret) {
        self.regret = regret
        _editedRegret = State(initialValue: regret.regret) // Initialize state with regret
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    dismiss()
                }, label: {
                    Text("Cancel")
                        .foregroundColor(.black)
                })
                Spacer()
                Button(action: {
                    print(editedRegret)
                    print(regret.id)
                    print(regret.regretPrompt)
                    let updatedRegret = Regret(id: regret.id, regretPrompt: regret.regretPrompt, regret: editedRegret)
                    viewModel.updateRegret(updatedRegret) 
                    print(updatedRegret)
                    dismiss()
                }, label: {
                    Text("Save")
                        .foregroundColor(Color(hex: 0x184449))
                        .bold()
                })
            }.padding()
            Text("Edit Your Regrets")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)
            Text(regret.regretPrompt)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.horizontal)
            VStack (alignment: .leading){
                Text("You Said...")
                TextEditor(text: $editedRegret)
                    .frame(height: 150)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: 0x184449), lineWidth: 1)
                    )
            }.padding()
            Spacer()
        }
        .padding(.top)
    }
}

#Preview {
    RegretEditorSheet(regret: Regret(regretPrompt: "this is an example prompt for the preview", regret: "this is an ecxmaple regret for the preview"))
}
