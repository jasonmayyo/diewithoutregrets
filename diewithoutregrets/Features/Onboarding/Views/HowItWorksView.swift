import SwiftUI
import AVKit

struct HowItWorksView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showVideo = false
    @State private var showTagline = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Study Guard turns your scroll habit into a study habit.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                    Spacer()
                    
                    LoopingVideoPlayer(videoName: "mockupvideo", videoExtension: "mp4")
                        .frame(maxWidth: .infinity)
                        .frame(height: min(500, geometry.size.height * 0.55))
                        .cornerRadius(16)
                        .opacity(showVideo ? 1 : 0)
                        .scaleEffect(showVideo ? 1 : 0.95)
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: showVideo)
                    
                    Spacer()
                    
                    Text("No willpower required.\nThe system does the work.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineSpacing(3)
                        .opacity(showTagline ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: showTagline)
                        .padding(.bottom, 20)
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.0), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showVideo = true
            showTagline = true
            showButton = true
        }
    }
}

#Preview {
    HowItWorksView()
        .environmentObject(OnboardingViewModel())
}
