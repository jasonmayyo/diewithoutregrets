//
//  NameView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct NameView: View {
    @State private var name = ""
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @FocusState private var isNameFieldFocused: Bool
    
    // Animation states
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showTextField = false
    @State private var showButton = false
    
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("What should we call you?")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                
                // Subtitle
                Text("What's your name? Or what's the name your mom calls you when she is mad at you?")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.9))
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                
                // Text Field
                TextField("", text: $name)
                    .focused($isNameFieldFocused)
                    .placeholder(when: name.isEmpty) {
                        Text("Enter your name")
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 50)
                            .fill(Color.white.opacity(0.2))
                    )
                    .autocorrectionDisabled()
                    .autocapitalization(.words)
                    .submitLabel(.done)
                    .opacity(showTextField ? 1 : 0)
                    .offset(y: showTextField ? 0 : 20)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            isNameFieldFocused = true
                        }
                    }
                
                Spacer()
                
                // Continue Button
                Button {
                    onboardingViewModel.userName = name.trimmingCharacters(in: .whitespaces)
                    onboardingViewModel.nextStep()
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .disabled(!canContinue)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
            }
            .padding()
        }
        .onAppear {
            animateViews()
        }
    }
    
    private func animateViews() {
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            showTitle = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            showSubtitle = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            showTextField = true
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
            showButton = true
        }
    }
}

// Add this extension for placeholder functionality
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
