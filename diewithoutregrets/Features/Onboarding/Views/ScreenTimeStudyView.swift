import SwiftUI

struct ScreenTimeStudyView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showAnimation = false
    @State private var showLabel = false
    @State private var showHeadline = false
    @State private var showSource = false
    @State private var showSubtext = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    DotLottieView(fileName: "hourglass", speed: 0.8)
                        .frame(height: min(200, geometry.size.height * 0.25))
                        .frame(maxWidth: .infinity)
                        .opacity(showAnimation ? 1 : 0)
                        .scaleEffect(showAnimation ? 1 : 0.85)
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: showAnimation)
                        .padding(.top, 10)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    Text("The research is clear.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .opacity(showLabel ? 1 : 0)
                        .offset(y: showLabel ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: showLabel)
                        .padding(.bottom, 16)
                    
                    Text("The average student spends over 7 hours a day on their phone.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(4)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.6), value: showHeadline)
                        .padding(.bottom, 16)
                    
                    HStack(spacing: 10) {
                        Image("common-sense-media-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 22)
                        
                        Text("Common Sense Media, 2023")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                    }
                    .opacity(showSource ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.9), value: showSource)
                    .padding(.bottom, 24)
                    
                    Text("That's more time than they spend in class and studying combined.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                        .lineSpacing(3)
                        .opacity(showSubtext ? 1 : 0)
                        .offset(y: showSubtext ? 0 : 15)
                        .animation(.easeOut(duration: 0.8).delay(1.2), value: showSubtext)
                    
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
                    }) {
                        Text("How much time do I spend?")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.5 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.6), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showAnimation = true
            showLabel = true
            showHeadline = true
            showSource = true
            showSubtext = true
            showButton = true
        }
    }
}

#Preview {
    ScreenTimeStudyView()
        .environmentObject(OnboardingViewModel())
}
