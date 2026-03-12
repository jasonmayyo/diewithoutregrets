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
    
    @State private var showTitle = false
    @State private var showOptions = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("How old are you?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                        .padding(.bottom, 16)
                    
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.AgeOptions.enumerated()), id: \.element.id) { index, option in
                            Button(action: {
                                viewModel.selectOption(option)
                            }) {
                                HStack {
                                    Text(option.range)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(viewModel.selectedOption == option ? Color(hex: 0x184449) : Color(hex: 0x184449).opacity(0.7))
                                    
                                    Spacer()
                                    
                                    Image(systemName: viewModel.selectedOption == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(viewModel.selectedOption == option ? Color(hex: 0x184449) : Color.gray.opacity(0.3))
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(viewModel.selectedOption == option ? Color(hex: 0x184449).opacity(0.08) : Color(hex: 0xF5F7FA))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(viewModel.selectedOption == option ? Color(hex: 0x184449).opacity(0.3) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .opacity(showOptions ? 1 : 0)
                            .offset(y: showOptions ? 0 : 15)
                            .animation(.easeOut(duration: 0.6).delay(0.4 + Double(index) * 0.06), value: showOptions)
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
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: 55)
                            .background(viewModel.canContinue ? Color(hex: 0x184449) : Color(hex: 0x184449).opacity(0.3))
                            .cornerRadius(50)
                    }
                    .disabled(!viewModel.canContinue)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showOptions = true
            showButton = true
        }
    }
}

#Preview {
    AgeSelectView()
        .environmentObject(OnboardingViewModel())
}
