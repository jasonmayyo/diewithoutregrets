//
//  AgeSelectView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct AgeSelectView: View {
    @StateObject private var viewModel = AvgScreenTimeViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("How old are you?")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                
                Text("This is so we can estimate the amount of time you would spend on your phone over your life")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.AgeOptions) { option in
                            TimeOptionButton(
                                option: option,
                                isSelected: viewModel.selectedOption == option,
                                action: { viewModel.selectOption(option) }
                            )
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if let selectedAge = viewModel.selectedOption?.range {
        onboardingViewModel.selectedAge = selectedAge
    }
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

#Preview {
    AgeSelectView()
}
