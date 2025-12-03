//
//  WecanhelpView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct WecanhelpView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showGrid = false
    @State private var showButton = false
    
    // Grid configuration - adjusted for smaller blocks
    private let columns = Array(repeating: GridItem(.flexible(minimum: 6, maximum: 8), spacing: 2), count: 30)
    
    // Life visualization calculations
    private var livedMonths: Int {
        let currentAge = parseAge(onboardingViewModel.selectedAge)
        return Int(currentAge * 12)
    }
    
    private var remainingLifeMonths: Int {
        let currentAge = parseAge(onboardingViewModel.selectedAge)
        let remainingYears = max(80.0 - currentAge, 0)
        return Int(remainingYears * 12)
    }
    
    private var phoneMonths: Int {
        let dailyHours = parseScreenTime(onboardingViewModel.screenTime)
        let remainingYears = max(80.0 - parseAge(onboardingViewModel.selectedAge), 0)
        let totalHours = dailyHours * 365 * remainingYears
        return Int((totalHours / (24 * 30)).rounded()) // Approximate months
    }
    
    private var totalLifeMonths: Int {
        return livedMonths + remainingLifeMonths
    }
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 3) {
                // Title with animation
                Text("Your Time Matters to God")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                    .accessibilityLabel("Your time matters to God")
                
                // Subtitle with animation
                Text("Let's help you be more intentional with your screen time. We'll ask you a few questions about your faith journey to personalize your experience.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 40)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                    .accessibilityLabel("Let's help you be more intentional with your screen time. We'll ask you a few questions about your faith journey to personalize your experience. And be closer to god amen.")
                
                // Life visualization grid
                HStack {
                    Spacer()
                    Text("Your Life in months ✝️")
                        .padding(.bottom)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .opacity(showGrid ? 1 : 0)
                        .animation(.easeInOut(duration: 1).delay(0.6), value: showGrid)
                        .accessibilityLabel("Your life in months")
                    Spacer()
                }
                
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<totalLifeMonths, id: \.self) { index in
                        Rectangle()
                            .fill(getBlockColor(for: index))
                            .aspectRatio(1, contentMode: .fill)
                            .cornerRadius(1)
                            .accessibilityLabel(blockAccessibilityLabel(for: index))
                    }
                }
                .padding(.horizontal, 8)
                .opacity(showGrid ? 1 : 0)
                .offset(y: showGrid ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.6), value: showGrid)
                .accessibilityElement(children: .combine)
                
                // Legend
                HStack {
                    Spacer()
                    HStack {
                        Rectangle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text("Lived")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .accessibilityLabel("Lived months")
                    }
                    HStack {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text("Screen time")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .accessibilityLabel("Screen time months")
                    }
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .accessibilityLabel("Remaining months")
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .opacity(showGrid ? 1 : 0)
                .animation(.easeInOut(duration: 1).delay(0.7), value: showGrid)
                .padding(.top)
                .accessibilityElement(children: .combine)
                
                Spacer()
                
                // Next button with animation
                Button(action: {
                    onboardingViewModel.nextStep()
                }) {
                    Text("Next")
                        .foregroundColor(.black)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.white)
                        .cornerRadius(50)
                }
                .padding(.top, 20)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
                .accessibilityLabel("Next")
                .accessibilityHint("Tap to proceed to the next step")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showGrid = true
            showButton = true
        }
    }
    
    private func getBlockColor(for index: Int) -> Color {
        if index < livedMonths {
            return Color.green.opacity(0.8)
        } else if index < livedMonths + phoneMonths {
            return Color.red
        } else {
            return Color.white.opacity(0.2)
        }
    }
    
    private func blockAccessibilityLabel(for index: Int) -> String {
        if index < livedMonths {
            return "Lived month"
        } else if index < livedMonths + phoneMonths {
            return "Screen time month"
        } else {
            return "Remaining month"
        }
    }
    
    // MARK: - Data Parsing
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

#Preview {
    WecanhelpView()
        .environmentObject(OnboardingViewModel())
}
