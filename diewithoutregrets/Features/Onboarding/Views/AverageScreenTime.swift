//
//  AverageScreenTime.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct AverageScreenTime: View {
    @StateObject private var viewModel = AvgScreenTimeViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("What is your average screen time right now?")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                
                Text("Just an estimate, does not have to be exact")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.screenTimeOptions) { option in
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
                    if let selectedTime = viewModel.selectedOption?.range {
        onboardingViewModel.screenTime = selectedTime
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

struct TimeOptionButton: View {
    let option: ScreenTimeOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(option.range)
                    .foregroundColor(isSelected ? .black : .white)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white : Color.white.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

struct DisabledOpacityButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(.easeInOut, value: isEnabled)
    }
}

#Preview {
    AverageScreenTime()
}
