//
//  MemeVideoView.swift
//  diewithoutregrets
//
//  Created by Assistant on 2025/01/14.
//

import SwiftUI
import AVKit
import AVFoundation

struct MemeVideoView: View {
    @State private var player: AVPlayer?
    @State private var videoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background color similar to lock animation
            Color.white.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .opacity(videoOpacity)
                    .onAppear {
                        // Fade in the video over 0.5 seconds
                        withAnimation(.easeInOut(duration: 0.3)) {
                            videoOpacity = 1.0
                        }
                    }.ignoresSafeArea()
            } else {
                // Fallback loading state
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Loading...")
                        .font(.headline)
                        .padding(.top, 16)
                }
                .opacity(videoOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        videoOpacity = 1.0
                    }
                }
            }
        }
        .onAppear {
            setupVideoPlayer()
        }
        .onDisappear {
            cleanupVideoPlayer()
        }
    }
    
    private func setupVideoPlayer() {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        guard let videoURL = Bundle.main.url(forResource: "dog-side-eye", withExtension: "mp4") else {
            print("Could not find dog-side-eye.mp4 in bundle")
            return
        }
        
        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // Configure player for our needs
        newPlayer.isMuted = false // Enable video sound
        newPlayer.volume = 1.0 // Set volume to maximum
        newPlayer.actionAtItemEnd = .none
        
        // Set up notification for when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            // Loop the video
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        self.player = newPlayer
        
        // Start playing after a short delay to allow fade-in to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            newPlayer.play()
        }
    }
    
    private func cleanupVideoPlayer() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}

struct MemeVideoView_Previews: PreviewProvider {
    static var previews: some View {
        MemeVideoView()
    }
} 
