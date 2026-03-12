import SwiftUI

struct StudyGuardReadyView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var isLoading = true
    @State private var progress: CGFloat = 0
    @State private var showCheckmark = false
    @State private var showTitle = false
    @State private var showButton = false
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color(hex: 0x184449).opacity(0.08), lineWidth: 12)
                        .frame(width: 180, height: 180)
                    
                    Circle()
                        .trim(from: 0, to: isLoading ? progress : 1)
                        .stroke(
                            Color(hex: 0x184449),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                    if !isLoading {
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449))
                            .opacity(showCheckmark ? 1 : 0)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                    }
                }
                
                if isLoading {
                    Text("Setting up your Study Guard...")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449))
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 12) {
                        Text("You're all set, \(onboardingViewModel.userName).")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: showTitle)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: 0x184449))
                        .cornerRadius(50)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: showButton)
                .padding(.bottom)
            }
            .padding(.horizontal, 24)
        }
        .onReceive(timer) { _ in
            if isLoading {
                if progress < 1.0 {
                    progress += 0.01
                } else {
                    isLoading = false
                    showCheckmark = true
                    showTitle = true
                    showButton = true
                    timer.upstream.connect().cancel()
                }
            }
        }
    }
}

#Preview {
    StudyGuardReadyView()
        .environmentObject(OnboardingViewModel())
}
