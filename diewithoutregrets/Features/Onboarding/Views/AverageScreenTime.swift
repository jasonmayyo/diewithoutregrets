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
    
    // State variables to control the opacity and offset of each element
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showOptions = false
    @State private var showButton = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 2) {
                // Title with animation
                Text("What is your average screen time right now?")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                
                // Subtitle with animation
                Text("Just an estimate, does not have to be exact")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                
                // ScrollView with options
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.screenTimeOptions) { option in
                            TimeOptionButton(
                                option: option,
                                isSelected: viewModel.selectedOption == option,
                                action: { viewModel.selectOption(option) }
                            )
                            .opacity(showOptions ? 1 : 0)
                            .offset(y: showOptions ? 0 : 20)
                            .animation(.easeInOut(duration: 1).delay(0.6 + Double(viewModel.screenTimeOptions.firstIndex(of: option)!) * 0.1), value: showOptions)
                        }
                    }
                }
                
                Spacer()
                
                // Continue button with animation
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
        .environmentObject(OnboardingViewModel())
}
