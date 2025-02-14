//
//  WelcomeView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showImage = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true) // Hide decorative background color
            
            VStack {
                // Welcome Image
                Image("welcomebg")
                    .resizable()
                    .frame(height: 550)
                    .opacity(showImage ? 1 : 0)
                    .offset(y: showImage ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showImage)
                    .accessibilityHidden(true) // Hide decorative image
                
                // Welcome Title
                Text("Welcome to Regret Guard")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showTitle)
                    .accessibilityLabel("Welcome to Regret Guard")
                
                // Welcome Subtitle
                Text("Protect Your Time, Protect Your Goals.")
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.6), value: showSubtitle)
                    .accessibilityLabel("Protect your time, protect your goals")
                
                // Get Started Button
                Button(action: {
                    onboardingViewModel.nextStep()
                }, label: {
                    Text("Get Started")
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 65)
                        .background(Color.white)
                        .cornerRadius(50)
                })
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
                .accessibilityLabel("Get Started")
                .accessibilityHint("Tap to begin setting up Regret Guard")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .onAppear {
            // Trigger the animations when the view appears
            showImage = true
            showTitle = true
            showSubtitle = true
            showButton = true
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(OnboardingViewModel())
}
