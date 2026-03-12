import SwiftUI

struct TheHookView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showHeadline = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("welcome-image-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.15), location: 0),
                        .init(color: Color.black.opacity(0.55), location: 0.55),
                        .init(color: Color.black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    Text("You already know something needs to change.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 30)
                        .animation(.easeOut(duration: 1.0).delay(0.6), value: showHeadline)
                    
                    Spacer()
                        .frame(height: 60)
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
                    }) {
                        Text("I'm ready")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: 0x184449))
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.5 : .infinity)
                            .frame(height: 55)
                            .background(Color.white)
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.4), value: showButton)
                    
                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Link("Privacy Policy", destination: URL(string: "https://studyguard.framer.website/legal/privacy-policy")!)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            showHeadline = true
            showButton = true
        }
    }
}

#Preview {
    TheHookView()
        .environmentObject(OnboardingViewModel())
}
