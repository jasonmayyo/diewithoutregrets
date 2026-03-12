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
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showTextField = false
    @State private var showButton = false
    
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("What should we call you?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                    
                    Text("We'll use this to personalise your experience.")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                    
                    TextField("", text: $name)
                        .focused($isNameFieldFocused)
                        .placeholder(when: name.isEmpty) {
                            Text("Enter your name")
                                .foregroundColor(Color(hex: 0x184449).opacity(0.35))
                        }
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: 0x184449))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: 0xF5F7FA))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(name.isEmpty ? Color.gray.opacity(0.2) : Color(hex: 0x184449).opacity(0.3), lineWidth: 1.5)
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
                    
                    Button {
                        onboardingViewModel.userName = name.trimmingCharacters(in: .whitespaces)
                        onboardingViewModel.nextStep()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: 55)
                            .background(canContinue ? Color(hex: 0x184449) : Color(hex: 0x184449).opacity(0.3))
                            .cornerRadius(50)
                    }
                    .disabled(!canContinue)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
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
