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
        ZStack {
            VStack {
                LoopingVideoPlayer(videoName: "mockupvideo", videoExtension: "mp4")
                                    .frame(height: 570)
                                    .opacity(showImage ? 1 : 0)
                                    .offset(y: showImage ? 0 : 20)
                                    .animation(.easeInOut(duration: 1).delay(0.2), value: showImage)
                                    .accessibilityHidden(true)
                // Welcome Title
                Text("Welcome to Study Guard")
                    .font(.title)
                    .bold()
                    .foregroundColor(Color(hex: 0x184449))
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showTitle)
                    .accessibilityLabel("Welcome to StudyGuard")
                
                // Welcome Subtitle
                Text("The only app that forces you to study")
                    .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                    .padding(.bottom, 40)
                    .font(.callout)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.6), value: showSubtitle)
                    .accessibilityLabel("Turn idle phone time into productive study sessions")
                
                // Get Started Button
                Button(action: {
                    onboardingViewModel.triggerHapticFeedback()
                    onboardingViewModel.nextStep()
                }, label: {
                    Text("Get Started")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: 0x184449))
                        .cornerRadius(50)
                })
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
                .accessibilityLabel("Get Started")
                .accessibilityHint("Tap to begin setting up Regret Guard")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
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
