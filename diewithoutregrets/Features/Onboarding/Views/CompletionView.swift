//
//  CompletionView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var isConfettiActive = false
    @State private var isFading = false
    @State private var particles: [Particle] = []
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    
    // Animation states
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showHandButton = false
    @State private var showTapText = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            // Main Content
            VStack(spacing: 10) {
                VStack(spacing: 10) {
                    Text("You're Ready to Begin!")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                        .accessibilityLabel("You're ready to begin!")
                    
                    Text("Remember, every moment spent in His word\nis a moment closer to His purpose for you.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                        .accessibilityLabel("Remember, every moment spent in His word is a moment closer to His purpose for you.")
                }
                
                Spacer()
                
                ZStack {
                    // Confetti Particles
                    ForEach(particles) { particle in
                        ConfettiParticle(particle: particle)
                            .accessibilityHidden(true)
                    }
                    
                    // Cross Button
                    Button(action: {
                        triggerConfetti()
                    }) {
                        Text("✝️")
                            .font(.system(size: 50))
                            .padding(30)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                            .shadow(radius: 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isConfettiActive)
                    .opacity(showHandButton ? 1 : 0)
                    .offset(y: showHandButton ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.6), value: showHandButton)
                    .accessibilityLabel("Tap to celebrate")
                    .accessibilityHint("Tap the cross button to continue")
                    .accessibilityAddTraits(.isButton)
                }
                
                HStack {
                    Text("Tap To Continue")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                        .opacity(showTapText ? 1 : 0)
                        .offset(y: showTapText ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.8), value: showTapText)
                        .accessibilityLabel("Tap to continue")
                }
                
                Spacer()
            }
            .opacity(isFading ? 0 : 1)
            .scaleEffect(isFading ? 1.2 : 1)
            .animation(.easeInOut(duration: 0.4), value: isFading)
            .padding()
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showHandButton = true
            showTapText = true
        }
    }
    
    private func triggerConfetti() {
        guard !isConfettiActive else { return }
        isConfettiActive = true
        generateParticles()
        
        // Confetti animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isFading = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Add user's verses to the store (already handled in onboarding view model)
            hasCompletedOnboarding = true
        }
    }
    
    private func generateParticles() {
        particles = (0..<15).map { _ in
            Particle()
        }
    }
}

struct ConfettiParticle: View {
    let particle: Particle
    @State private var isActive = false
    
    var body: some View {
        Text("✝️")
            .font(.system(size: 48))
            .scaleEffect(isActive ? particle.scale : 1)
            .offset(x: isActive ? particle.x : 0,
                    y: isActive ? particle.y : 0)
            .rotationEffect(.degrees(isActive ? particle.rotation : 0))
            .opacity(isActive ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    self.isActive = true
                }
            }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let scale: Double
    let rotation: Double
    
    init() {
        let angle = Double.random(in: 0..<360)
        let distance = Double.random(in: 80...250)
        let radians = angle * .pi / 180
        
        self.x = CGFloat(distance * cos(radians))
        self.y = CGFloat(-distance * sin(radians))
        self.scale = Double.random(in: 0.8...1.5)
        self.rotation = Double.random(in: -45...45)
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
        .environmentObject(BibleVerseStore())
}
