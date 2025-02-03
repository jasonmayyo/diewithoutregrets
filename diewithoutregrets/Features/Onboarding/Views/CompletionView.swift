//
//  CompletionView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Debug Information")
                        .font(.title)
                        .foregroundColor(.white)
                        .bold()
                    
                    Group {
                        InfoRow(title: "Name", value: onboardingViewModel.userName)
                        InfoRow(title: "Age", value: onboardingViewModel.selectedAge)
                        InfoRow(title: "Daily Screen Time", value: onboardingViewModel.screenTime)
                        
                        Text("Regret Questions:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Question 1:")
                                .foregroundColor(.white.opacity(0.7))
                            Text(onboardingViewModel.regretAnswers[0])
                                .foregroundColor(.white)
                                .padding(.bottom)
                            
                            Text("Question 2:")
                                .foregroundColor(.white.opacity(0.7))
                            Text(onboardingViewModel.regretAnswers[1])
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    CompletionView()
        .environmentObject(OnboardingViewModel())
}
