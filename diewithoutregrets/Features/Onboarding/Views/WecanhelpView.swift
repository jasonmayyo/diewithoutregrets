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
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("It’s time to get real...")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                
                Text("In order to help you use your phone more consciously we are going to as you a couple of questions and you should be as honest as possible")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                
                Spacer()
                
                VStack(alignment: .center) {
                    Text("WE CAN HELP")
                        .font(.system(size: 50, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                    
                    Text("CHANGE THAT!")
                        .font(.system(size: 38, weight: .black))
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0)
                }.frame(maxWidth: .infinity)
                
                
                
                
                
                
                Spacer()
                
                Button(action: {
                    onboardingViewModel.nextStep()
                }) {
                    Text("Next")
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.white)
                        .cornerRadius(50)
                }
            }
            .padding()
        }
    }
}

#Preview {
    WecanhelpView()
}
