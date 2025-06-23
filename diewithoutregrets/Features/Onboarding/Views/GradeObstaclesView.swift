//
//  GradeObstaclesView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/27.
//

import SwiftUI

struct GradeObstaclesView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var selectedObstacles: Set<String> = []
    
    // State variables to control the opacity and offset of each element
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showOptions = false
    @State private var showButton = false
    
    private let dwrGreen = Color(hex: 0x013B41)
    private let accentColor = Color(hex: 0x065961)
    private let bgColor = Color(.systemGroupedBackground)
    
    private let obstacles = [
        "Procrastination",
        "Poor time management",
        "Lack of motivation",
        "Distractions (social media, phone)",
        "Difficulty understanding material",
        "Test anxiety",
        "Poor study habits",
        "Health issues (sleep, stress)"
    ]
    
    private var canContinue: Bool {
        !selectedObstacles.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(spacing: 5) {
                // Header Text with animation
                Text("What's stopping you from getting good grades?")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                
                // Subtitle with animation
                Text("Select all that apply to you")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                
                // Obstacles List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(obstacles.enumerated()), id: \.element) { index, obstacle in
                            ObstacleSelectionCard(
                                obstacle: obstacle,
                                isSelected: selectedObstacles.contains(obstacle),
                                onTap: {
                                    if selectedObstacles.contains(obstacle) {
                                        selectedObstacles.remove(obstacle)
                                    } else {
                                        selectedObstacles.insert(obstacle)
                                    }
                                }
                            )
                            .opacity(showOptions ? 1 : 0)
                            .offset(y: showOptions ? 0 : 20)
                            .animation(.easeInOut(duration: 1).delay(0.6 + Double(index) * 0.1), value: showOptions)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Continue Button with animation
                Button(action: {
                    // TODO: Save selected obstacles to onboarding view model
                    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canContinue ?
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x3FA4AE),
                                    Color(hex: 0x2BC391)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(
                            color: canContinue ? Color(hex: 0x3FA4AE).opacity(0.3) : Color.clear,
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                }
                .disabled(!canContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
            }
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

struct ObstacleSelectionCard: View {
    let obstacle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    private let dwrGreen = Color(hex: 0x013B41)
    private let accentColor = Color(hex: 0x065961)
    private let bgColor = Color(.systemGroupedBackground)
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(obstacle)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? accentColor : .gray)
                    .font(.title2)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GradeObstaclesView()
        .environmentObject(OnboardingViewModel())
} 
