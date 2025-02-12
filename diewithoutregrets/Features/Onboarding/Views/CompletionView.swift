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
    @EnvironmentObject var regretStore: RegretStore
    
    // Animation states
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showHandButton = false
    @State private var showTapText = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
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
                    
                    Text("Remember, every moment spent mindfully\nis a moment lived without regrets.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                }
                
                Spacer()
                
                ZStack {
                    // Confetti Particles
                    ForEach(particles) { particle in
                        ConfettiParticle(particle: particle)
                    }
                    
                    // Shaking Hand Button
                    Button(action: {
                        triggerConfetti()
                    }) {
                        Text("🤝")
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
                }
                
                HStack {
                    Text("Tap To Continue")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                        .opacity(showTapText ? 1 : 0)
                        .offset(y: showTapText ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.8), value: showTapText)
                }
                
                Spacer()
            }
            .opacity(isFading ? 0 : 1)
            .scaleEffect(isFading ? 1.2 : 1)
            .animation(.easeInOut(duration: 0.4), value: isFading)
            .padding()
        }
        .onAppear {
            // Trigger entry animations
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                   // Add user's regrets to the store
                   for i in 0..<onboardingViewModel.regretAnswers.count {
                       let newRegret = Regret(
                           regretPrompt: onboardingViewModel.regretPrompts[i],
                           regret: onboardingViewModel.regretAnswers[i]
                       )
                       regretStore.regrets.append(newRegret)
                       print(regretStore.regrets)
                   }
                   
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
        Text("🤝")
            .font(.system(size: 48)) // Increased from 40 to 48
            .scaleEffect(isActive ? particle.scale : 1)
            .offset(x: isActive ? particle.x : 0,
                    y: isActive ? particle.y : 0)
            .rotationEffect(.degrees(isActive ? particle.rotation : 0))
            .opacity(isActive ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) { // Faster animation
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
        let distance = Double.random(in: 80...250) // Reduced distance
        let radians = angle * .pi / 180
        
        self.x = CGFloat(distance * cos(radians))
        self.y = CGFloat(-distance * sin(radians))
        self.scale = Double.random(in: 0.8...1.5) // Reduced scale variation
        self.rotation = Double.random(in: -45...45) // DRAMATICALLY reduced rotation range
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


/* Debugging Completion View
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
 
 
 Button(action: {
 onboardingViewModel.completeOnboarding()
 }, label: {
 Text("Begin")
 .foregroundColor(.black)
 .padding()
 .frame(maxWidth: .infinity)
 .frame(height: 70)
 .background(Color.white)
 .cornerRadius(50)
 })
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
 
 */
