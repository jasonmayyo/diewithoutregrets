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
                .accessibilityHidden(true)
            
            VStack {
                // Welcome Image
                Image("welcomebg")
                    .resizable()
                    .frame(height: 550)
                    .opacity(showImage ? 1 : 0)
                    .offset(y: showImage ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showImage)
                    .accessibilityHidden(true)
                
                // Welcome Title
                Text("Welcome to Faith Guard.")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showTitle)
                    .accessibilityLabel("Welcome to Faith Guard")
                
                // Welcome Subtitle
                Text("Guard Your Heart with Scripture")
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 40)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.6), value: showSubtitle)
                    .accessibilityLabel("Guard your heart with Scripture")
                
                // Get Started Button
                Button(action: {
                    onboardingViewModel.nextStep()
                }, label: {
                    Text("Get Started")
                        .foregroundColor(.black)
                        .font(.headline)
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
                .accessibilityHint("Tap to begin setting up Faith Guard")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .onAppear {
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
