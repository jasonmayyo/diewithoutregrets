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
    
    // State variables to control the opacity and offset of each element
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showOptions = false
    @State private var showButton = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 3) {
                // Title with animation
                Text("How old are you?")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                
                // Subtitle with animation
                Text("This is so we can estimate the amount of time you would spend on your phone over your life")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                
                // ScrollView with options
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.AgeOptions) { option in
                            TimeOptionButton(
                                option: option,
                                isSelected: viewModel.selectedOption == option,
                                action: { viewModel.selectOption(option) }
                            )
                            .opacity(showOptions ? 1 : 0)
                            .offset(y: showOptions ? 0 : 20)
                            .animation(.easeInOut(duration: 1).delay(0.6 + Double(viewModel.AgeOptions.firstIndex(of: option)!) * 0.1), value: showOptions)
                        }
                    }
                }
                
                Spacer()
                
                // Continue button with animation
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
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
            }
            .padding()
        }
        .onAppear {
            // Trigger the animations when the view appears
            showTitle = true
            showSubtitle = true
            showOptions = true
            showButton = true
        }
    }
}

#Preview {
    AgeSelectView()
        .environmentObject(OnboardingViewModel())
}
