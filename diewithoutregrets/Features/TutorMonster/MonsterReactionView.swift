import SwiftUI
import AVFoundation

/// Comment-sized media sits directly below the spoken line, without a second
/// bubble. Reserve its final size before decoding to keep the transcript steady.
struct MonsterReactionView: View {
    let reaction: MonsterReaction
    let playbackEnabled: Bool
    let viewportHeight: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mediaFrame = CGRect.null
    @State private var appeared = false
    @State private var paused = false

    private var isPlaybackVisible: Bool {
        playbackEnabled && appeared && scenePhase == .active && !reduceMotion &&
            mediaFrame.maxY > 0 && mediaFrame.minY < viewportHeight
    }

    var body: some View {
        Group {
            if reaction.isAnimated && !reduceMotion {
                Button { paused.toggle() } label: {
                    media.overlay(alignment: .bottomLeading) {
                        Text(paused ? "GIF · Paused" : "GIF")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 3))
                            .padding(5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reaction.accessibilityLabel)
                .accessibilityValue(paused ? "Animation paused" : "Animated reaction")
                .accessibilityHint(paused ? "Double tap to play" : "Double tap to pause")
            } else {
                media.accessibilityHidden(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(reaction.accessibilityLabel)
                    .accessibilityAddTraits(.isImage)
            }
        }
        .frame(width: 136, height: 136 / reaction.aspectRatio)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        // Keep the frame, not an intersection captured before the scroll view
        // measures its height. A short, stationary transcript may never scroll.
        .onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: .named("monsterTranscript"))
        } action: { mediaFrame = $0 }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    private var media: some View {
        ZStack {
            if let poster = MonsterReactionPosters.image(for: reaction) {
                Image(uiImage: poster).resizable().scaledToFit()
            }
            if reaction.isAnimated, !reduceMotion,
               let url = reaction.resourceURL(extension: "mp4") {
                MonsterReactionLoop(url: url, isActive: isPlaybackVisible, isPlaying: !paused)
            }
        }
        .frame(width: 136, height: 136 / reaction.aspectRatio)
        .accessibilityHidden(true)
    }
}

private enum MonsterReactionPosters {
    static let cache = NSCache<NSString, UIImage>()
    static func image(for reaction: MonsterReaction) -> UIImage? {
        let key = reaction.rawValue as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let url = reaction.resourceURL(extension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

private struct MonsterReactionLoop: UIViewRepresentable {
    let url: URL
    let isActive: Bool
    let isPlaying: Bool

    func makeUIView(context: Context) -> ReactionPlayerView { ReactionPlayerView() }
    func updateUIView(_ view: ReactionPlayerView, context: Context) {
        view.update(url: url, isActive: isActive, isPlaying: isPlaying)
    }
    static func dismantleUIView(_ view: ReactionPlayerView, coordinator: ()) { view.stop() }

    final class ReactionPlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        func update(url: URL, isActive: Bool, isPlaying: Bool) {
            // Offscreen rows have a poster but allocate no video decoder.
            guard isActive else { stop(); return }
            // A deliberate pause holds the current frame until it leaves view.
            guard isPlaying else { player?.pause(); return }
            if currentURL != url || player == nil {
                stop()
                let player = AVQueuePlayer()
                player.isMuted = true
                player.volume = 0
                player.preventsDisplaySleepDuringVideoPlayback = false
                let item = AVPlayerItem(url: url)
                looper = AVPlayerLooper(player: player, templateItem: item)
                self.player = player
                currentURL = url
                playerLayer.videoGravity = .resizeAspect
                playerLayer.player = player
                backgroundColor = .clear
                isUserInteractionEnabled = false
            }
            player?.play()
        }

        func stop() {
            player?.pause()
            looper?.disableLooping()
            player?.removeAllItems()
            playerLayer.player = nil
            looper = nil
            player = nil
            currentURL = nil
        }
    }
}
