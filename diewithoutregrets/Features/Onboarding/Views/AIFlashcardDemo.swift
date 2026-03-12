import SwiftUI

struct AIFlashcardDemo: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showImage = false
    @State private var showBullets = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("No Work. No Scroll.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                    Spacer()
                    
                    Image("verified-focus-image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .opacity(showImage ? 1 : 0)
                        .scaleEffect(showImage ? 1 : 0.95)
                        .animation(.easeOut(duration: 0.8).delay(0.6), value: showImage)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 14) {
                        VerifiedFocusBulletRow(icon: "eye.slash.fill", text: "No more lying to yourself about \"studying\"")
                        VerifiedFocusBulletRow(icon: "timer", text: "Walk away? The timer stops. No free passes.")
                        VerifiedFocusBulletRow(icon: "checkmark.shield.fill", text: "Only real focus counts. Every minute earned.")
                    }
                    .opacity(showBullets ? 1 : 0)
                    .offset(y: showBullets ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.0), value: showBullets)
                    .padding(.bottom, 24)
                    
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.5 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.3), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showImage = true
            showBullets = true
            showButton = true
        }
    }
}

struct VerifiedFocusBulletRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: 0x184449).opacity(0.7))
        }
    }
}

#Preview {
    AIFlashcardDemo()
        .environmentObject(OnboardingViewModel())
}
