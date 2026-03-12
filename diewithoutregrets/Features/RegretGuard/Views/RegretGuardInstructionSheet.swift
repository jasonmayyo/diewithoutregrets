import SwiftUI
import AVKit

struct RegretGuardInstructionSheet: View {
    @Environment(\.dismiss) var dismiss
    let app: RegretApp
    @State private var showMoreSteps = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Setup \(app.name)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                    
                    Text("Watch the tutorial — it stays on screen when you leave the app.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 28)
                .padding(.bottom, 16)
                
                PiPVideoPlayer(videoName: "shortcut-setup-tutorial", videoExtension: "MP4")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9/16, contentMode: .fit)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 0) {
                    SetupStepRow(
                        number: "1",
                        title: "Get the shortcut",
                        subtitle: "Tap the button below to add the \(app.name) shortcut to your device."
                    )
                    .padding(.top, 20)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showMoreSteps.toggle()
                        }
                    }) {
                        HStack {
                            Text(showMoreSteps ? "Hide steps" : "Show all steps")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                            
                            Image(systemName: showMoreSteps ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        }
                        .padding(.vertical, 12)
                    }
                    
                    if showMoreSteps {
                        VStack(alignment: .leading, spacing: 0) {
                            SetupStepRow(
                                number: "2",
                                title: "Open the Shortcuts app",
                                subtitle: "Go to the Automation tab."
                            )
                            
                            SetupStepRow(
                                number: "3",
                                title: "Create a new Automation",
                                subtitle: "Tap + and select \"App\" as the trigger."
                            )
                            
                            SetupStepRow(
                                number: "4",
                                title: "Choose \(app.name)",
                                subtitle: "Select \"Is Opened\" and set to \"Run Immediately\"."
                            )
                            
                            SetupStepRow(
                                number: "5",
                                title: "Set the action",
                                subtitle: "Choose the dwr. shortcut you just added."
                            )
                            
                            SetupStepRow(
                                number: "6",
                                title: "Done!",
                                subtitle: "Test it by opening \(app.name)."
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 12) {
                    Button(action: {
                        UIApplication.shared.open(app.shortcutLink)
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .medium))
                            Text("Get Shortcut for \(app.name)")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: 0x2BC391))
                        .cornerRadius(14)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 16, weight: .medium))
                            Text("Open Shortcuts App")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: 0x184449))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: 0x184449).opacity(0.08))
                        .cornerRadius(14)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct SetupStepRow: View {
    let number: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Color(hex: 0x184449))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: 0x184449))
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - PiP Video Player

struct PiPVideoPlayer: UIViewControllerRepresentable {
    let videoName: String
    let videoExtension: String
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            print("Video file not found: \(videoName).\(videoExtension)")
            return controller
        }
        
        let player = AVPlayer(url: url)
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        
        player.play()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

#Preview {
    RegretGuardInstructionSheet(app: RegretApp(
        name: "Instagram",
        iconName: "instagram-icon",
        shortcutLink: URL(string: "https://www.icloud.com/shortcuts/your-instagram-shortcut")!
    ))
}
