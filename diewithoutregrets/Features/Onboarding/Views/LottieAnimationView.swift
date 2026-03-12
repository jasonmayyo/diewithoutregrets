import SwiftUI
import Lottie

struct LottieAnimationRepresentable: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .loop
    var speed: CGFloat = 1.0
    
    func makeUIView(context: Context) -> some UIView {
        let containerView = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        animationView.play()
        return containerView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct DotLottieView: UIViewRepresentable {
    let fileName: String
    var loopMode: LottieLoopMode = .loop
    var speed: CGFloat = 1.0
    
    func makeUIView(context: Context) -> some UIView {
        let containerView = UIView(frame: .zero)
        containerView.backgroundColor = .clear
        
        Task { @MainActor in
            guard let dotLottieFile = try? await DotLottieFile.named(fileName) else { return }
            let animationView = LottieAnimationView(dotLottie: dotLottieFile)
            animationView.loopMode = loopMode
            animationView.animationSpeed = speed
            animationView.contentMode = .scaleAspectFit
            animationView.backgroundColor = .clear
            animationView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(animationView)
            NSLayoutConstraint.activate([
                animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
                animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
            
            animationView.play()
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
