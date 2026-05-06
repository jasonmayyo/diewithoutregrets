import SwiftUI
import PostHog

struct CompletionView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false
    @State private var showConfetti = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
                    .zIndex(1)
            }
            
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundColor(Color(hex: 0x184449))
                    .opacity(showIcon ? 1 : 0)
                    .scaleEffect(showIcon ? 1 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showIcon)
                
                Text("You just took\nthe hardest step.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: 0x184449))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.4), value: showTitle)
                
                Text("Most people never do.\nLet's make it count, \(onboardingViewModel.userName).")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 15)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: showSubtitle)
                
                Spacer()
                
                Button(action: {
                    Analytics.capture("onboarding_completed", properties: [
                        "user_name": onboardingViewModel.userName,
                        "selected_age": onboardingViewModel.selectedAge,
                        "screen_time": onboardingViewModel.screenTime,
                        "deck_name": onboardingViewModel.newDeckName,
                        "flashcards_created": onboardingViewModel.regretEntries.count,
                        "selected_apps_count": onboardingViewModel.selectedApps.count,
                        "selected_apps": onboardingViewModel.selectedApps.map { $0.name },
                        "feelings": Array(onboardingViewModel.selectedFeelings).sorted(),
                        "obstacles": Array(onboardingViewModel.selectedObstacles).sorted()
                    ])

                    AdsTracker.trackCompleteRegistration()

                    hasCompletedOnboarding = true
                    onboardingViewModel.triggerHapticFeedback()
                }) {
                    Text("Let's go")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: 0x184449))
                        .cornerRadius(50)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: showButton)
                .padding(.horizontal, 24)
                .padding(.bottom)
            }
            .padding()
        }
        .onAppear {
            showIcon = true
            showTitle = true
            showSubtitle = true
            showButton = true
            withAnimation(.easeOut(duration: 0.5)) {
                showConfetti = true
            }
        }
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let colors: [Color] = [
        Color(hex: 0x184449),
        Color(hex: 0x184449).opacity(0.6),
        Color(hex: 0x3FA4AE),
        Color(hex: 0x64FFDA),
        Color(hex: 0x184449).opacity(0.3)
    ]
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                RoundedRectangle(cornerRadius: 2)
                    .fill(particle.color)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(particle.rotation))
                    .scaleEffect(particle.scale)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onAppear { createParticles() }
        .onReceive(timer) { _ in updateParticles() }
    }
    
    private func createParticles() {
        particles = (0..<40).map { _ in
            ConfettiParticle(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 3,
                color: colors.randomElement() ?? Color(hex: 0x184449),
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
                particles[i].vy += 0.5
                particles[i].rotation += particles[i].vr
                particles[i].scale *= 0.99
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
