//
//  LoopingVideoPlayer.swift
//  diewithoutregrets
//
//  Shared looping video player (paywall + how-it-works mockup video).
//  Extracted from the retired WelcomeView.
//

import SwiftUI
import AVKit

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
