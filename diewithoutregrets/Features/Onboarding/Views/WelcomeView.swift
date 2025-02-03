//
//  WelcomeView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            VStack {
                Spacer()
                Text("Welcome to Regret Guard")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                Text("Protect Your Time, Protect Your Goals.")
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                
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
            }.padding()
            
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(OnboardingViewModel())
}
