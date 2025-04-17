//
//  WelcomeView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/03.
//

import SwiftUI
import AVKit

struct WelcomeView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showImage = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: geometry.size.height * 0.01) {
                    // Video player that scales based on device size
                    LoopingVideoPlayer(videoName: "mockupvideo", videoExtension: "mp4")
                        .frame(height: min(570, geometry.size.height * 0.7))
                        .opacity(showImage ? 1 : 0)
                        .offset(y: showImage ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.2), value: showImage)
                        .accessibilityHidden(true)
                    
                    // Spacer to push content up on iPad
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        Spacer().frame(height: 20)
                    }
                    
                    // Welcome Title
                    Text("Welcome to Study Guard")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 38 : 30))
                        .bold()
                        .foregroundColor(Color(hex: 0x184449))
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.4), value: showTitle)
                        .accessibilityLabel("Welcome to StudyGuard")
                    
                    // Welcome Subtitle
                    Text("The only app that forces you to study")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                        .padding(.bottom, geometry.size.height * 0.02)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeInOut(duration: 1).delay(0.6), value: showSubtitle)
                        .accessibilityLabel("Turn idle phone time into productive study sessions")
                    
                    Spacer()
                    
                    // Get Started Button - width limited for iPad
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.nextStep()
                    }, label: {
                        Text("Get Started")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 70 : 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    })
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
                    .accessibilityLabel("Get Started")
                    .accessibilityHint("Tap to begin setting up Regret Guard")
                    .accessibilityAddTraits(.isButton)
                    
                    // Terms of Use and Privacy Policy Links
                    HStack(spacing: 20) {
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .font(.footnote)
                            .foregroundColor(Color(hex: 0x184449))
                        
                        Link("Privacy Policy", destination: URL(string: "https://studyguard.framer.website/legal/privacy-policy")!)
                            .font(.footnote)
                            .foregroundColor(Color(hex: 0x184449))
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 20)
                .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.height * 0.05 : 20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            // Trigger the animations when the view appears
            showImage = true
            showTitle = true
            showSubtitle = true
            showButton = true
        }
        .preferredColorScheme(.light)
    }
}

class PlayerUIView: UIView {
    var playerLayer: AVPlayerLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = self.bounds
    }
}


struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExtension: String
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            print("⚠️ Video file not found: \(videoName).\(videoExtension)")
            return view
        }
        
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        (view as? PlayerUIView)?.playerLayer = playerLayer
        
        // Start playing and add observer for looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        player.play()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure the player layer frame always matches the view's bounds.
        if let layer = (uiView as? PlayerUIView)?.playerLayer {
            layer.frame = uiView.bounds
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(OnboardingViewModel())
}
