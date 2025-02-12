//
//  BreakdownView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct BreakdownView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // State variables to control the opacity and offset of each element
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showTabView = false
    @State private var showButton = false
    
    // MARK: - Calculated Values
    private var lifetimeYears: Int {
        calculateLifetimeYears()
    }
    
    private var annualDays: Int {
        calculateAnnualDays()
    }
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 3) {
                // Title with animation
                Text("Here is the deal, \(onboardingViewModel.userName)!")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                
                // Subtitle with animation
                Text("Based on what you have told us, we estimate you will spend...")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                
                Spacer()
                
                // TabView with animation
                TabView {
                    // Lifetime Estimate
                    VStack(alignment: .center, spacing: 0) {
                        Text("\(lifetimeYears.formattedWithCommas) YEARS")
                            .font(.system(size: 72, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                        
                        Text("ON YOUR PHONE!")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0)
                    }
                    .background(Color(hex: 0x184449))
                    
                    // Annual Estimate
                    VStack {
                        Text("\(annualDays.formattedWithCommas) DAYS")
                            .font(.system(size: 72, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 10, x: 0, y: 0)
                        
                        Text("THIS YEAR ALONE!")
                            .font(.system(size: 38, weight: .black))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: .white.opacity(0.3), radius: 5, x: 0, y: 0)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
                .opacity(showTabView ? 1 : 0)
                .offset(y: showTabView ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.6), value: showTabView)
                
                Spacer()
                
                // Next button with animation
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
            showTabView = true
            showButton = true
        }
    }
    
    // MARK: - Calculation Methods
    private func calculateLifetimeYears() -> Int {
        let lifeExpectancy = 80.0
        let currentAge = parseAge(onboardingViewModel.selectedAge)
        let remainingYears = max(lifeExpectancy - currentAge, 0)
        let dailyHours = parseScreenTime(onboardingViewModel.screenTime)
        
        let totalHours = dailyHours * 365 * remainingYears
        let totalYears = totalHours / (24 * 365)
        return Int(totalYears.rounded())
    }
    
    private func calculateAnnualDays() -> Int {
        let dailyHours = parseScreenTime(onboardingViewModel.screenTime)
        let annualHours = dailyHours * 365
        return Int((annualHours / 24).rounded())
    }
    
    private func parseAge(_ ageRange: String) -> Double {
        let components = ageRange.components(separatedBy: "-")
            .compactMap { Double($0.filter { $0.isNumber }) }
        guard components.count == 2 else { return 30 }
        return (components[0] + components[1]) / 2
    }
    
    private func parseScreenTime(_ screenTime: String) -> Double {
        let components = screenTime.components(separatedBy: "-")
            .compactMap { Double($0.filter { $0.isNumber }) }
        guard components.count == 2 else { return 5 }
        return (components[0] + components[1]) / 2
    }
}

// MARK: - Formatting Extension
extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    BreakdownView()
        .environmentObject(OnboardingViewModel())
}
