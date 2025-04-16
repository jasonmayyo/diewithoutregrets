//
//  CompletionView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.

import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var counter: Int = 0
    @State private var showConfetti = false
        @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background color
            Color(hex: 0xF5F7FA)
                .ignoresSafeArea()
            
            if showConfetti {
                            ConfettiView()
                                .transition(.opacity)
                                .zIndex(1)
                        }
            
            VStack(spacing: 25) {
                Spacer()
                
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color(hex: 0x065961))
                
                // Title
                Text("You're all set!")
                    .font(.title2)
                    .bold()
                    .foregroundColor(Color(hex: 0x013B41))
                
                // Description
                Text("Your first flashcard deck '\(onboardingViewModel.newDeckName)' has been created.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: 0x065961))
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Finish Button
                Button(action: {
                    hasCompletedOnboarding = true // This triggers navigation
                    onboardingViewModel.triggerHapticFeedback()
                }) {
                    Text("Finish") // Fixed spelling from "Finnish" to "Finish"
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: 0x184449))
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom)
            }
        }
        .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showConfetti = true
                    }
                }
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let colors: [Color] = [.red, .green, .blue, .yellow, .pink, .orange, .purple]
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Rectangle()
                    .fill(particle.color)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onAppear {
            createParticles()
        }
        .onReceive(timer) { _ in
            updateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<50).map { _ in
            ConfettiParticle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 3,
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360)
            )
        }
    }
    
    private func updateParticles() {
        withAnimation(.linear(duration: 0.1)) {
            particles = particles.filter { $0.isActive }
            particles.indices.forEach { i in
                particles[i].x += particles[i].vx
                particles[i].y += particles[i].vy
                particles[i].vy += 0.5 // Gravity
                particles[i].rotation += particles[i].vr
                particles[i].scale *= 0.99 // Fade out
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double = Double.random(in: -10...10)
    var vy: Double = Double.random(in: -50...(-20))
    var color: Color
    var rotation: Double
    var vr: Double = Double.random(in: -10...10)
    var scale: Double = 1.0
    var isActive: Bool {
        y < UIScreen.main.bounds.height + 100 && scale > 0.1
    }
}

#Preview {
    CompletionView()
        .environmentObject(OnboardingViewModel())
}
