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
    
    // State variables to control the opacity and offset of each element
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showTextField = false
    @State private var showButton = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true) // Hide decorative background color
            
            VStack(alignment: .leading, spacing: 3) {
                // Title with animation
                Text("What should we call you?")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                    .accessibilityLabel("What should we call you?")
                
                // Subtitle with animation
                Text("What's your name? Or what's the name your mom calls you when she is mad at you?")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                    .accessibilityLabel("What's your name? Or what's the name your mom calls you when she is mad at you?")
                
                // Custom TextField with animation
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
                .opacity(showTextField ? 1 : 0)
                .offset(y: showTextField ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.6), value: showTextField)
                .accessibilityLabel("Enter your name")
                .accessibilityHint("Type your name in this field")
                .accessibilityValue(viewModel.name.isEmpty ? "Empty" : viewModel.name)
                
                Spacer()
                
                // Continue button with animation
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
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
                .accessibilityLabel("Continue")
                .accessibilityHint("Tap to proceed to the next step")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .onAppear {
            // Trigger the animations when the view appears
            showTitle = true
            showSubtitle = true
            showTextField = true
            showButton = true
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
