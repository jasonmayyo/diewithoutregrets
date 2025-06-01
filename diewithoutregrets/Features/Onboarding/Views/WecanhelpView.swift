//
//  WecanhelpView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct WecanhelpView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        // Main text
                        Text("What do you hate to learn?")
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                        Text("We will help you learn and memorise the things you can't be bothered to learn")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.skipToCompletion()
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white.opacity(0.1))
                            )
                    }
                    .padding(.trailing)
                }
                .padding(.top)
                
                Spacer()
                
                // Deck name field
                VStack(alignment: .leading, spacing: 10) {
                    Text("Give your deck a name:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("My First Deck", text: $onboardingViewModel.newDeckName)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: 0x065961), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue Button
                Button(action: {
                    onboardingViewModel.triggerHapticFeedback()
                    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(.white)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom)
            }
        }
    }
}

#Preview {
    WecanhelpView()
        .environmentObject(OnboardingViewModel())
}
