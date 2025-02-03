//
//  BreakdownView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct BreakdownView: View {
    @StateObject private var viewModel = NameViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Here is the deal, \(viewModel.name)!")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                
                Text("Based on what you have told us, we estimate you will spend...")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)

                Spacer()
                
                TabView {
                    VStack(alignment: .center, spacing: 0) {
                        Text("22 YEARS")
                            .font(.system(size: 72, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                        
                        Text("ON YOUR PHONE!")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0)
                    }.background(Color(hex: 0x184449))
                    
                    VStack {
                        Text("122 DAYS")
                            .font(.system(size: 72, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                        
                        Text("THIS YEAR ALONE!")
                            .font(.system(size: 38, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0)
                    }
                }.tabViewStyle(PageTabViewStyle())
                
                
                
                
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
    BreakdownView()
}
