//
//  NameView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct NameView: View {
    @StateObject private var viewModel = NameViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("What should we call you?")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                
                Text("What's your name ? or what's the name your mom calls you when she is mad at you?")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                
                // Custom TextField
                TextField("", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.handleNameChange($0) }
                ))
                .placeholder(when: viewModel.name.isEmpty) {
                    Text("Enter your name")
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.leading, 20)
                }
                .textFieldStyle(CustomTextFieldStyle())
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                
                Spacer()
                
                Button(action: {
                    onboardingViewModel.userName = viewModel.name
    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.white)
                        .cornerRadius(50)
                }
                .disabled(!viewModel.canContinue)
                .buttonStyle(DisabledOpacityButtonStyle())
            }
            .padding()
        }
    }
}

// Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 50)
                    .fill(Color.white.opacity(0.2))
            )
    }
}

// Custom View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    NameView()
        .environmentObject(OnboardingViewModel())
}
