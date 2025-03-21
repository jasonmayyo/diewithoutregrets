import SwiftUI

struct LockView: View {
    // State for vertical offset of the lock
    @State private var lockOffset: CGFloat = 0
    // State for the scale of the red circle background
    @State private var redCircleScale: CGFloat = 0.1
    // State for the rotation angle of the lock (starting at 30° for a "tilted" position)
    @State private var lockRotation: Double = 30
    
    // Array of red colors from light to dark
    private let redColors: [Color] = [
        Color(red: 1.0, green: 0.8, blue: 0.8),  // Lightest red
        Color(red: 1.0, green: 0.6, blue: 0.6),
        Color(red: 1.0, green: 0.4, blue: 0.4),
        Color(red: 0.9, green: 0.2, blue: 0.2),
        Color(red: 0.8, green: 0.1, blue: 0.1),
        Color(red: 0.7, green: 0.0, blue: 0.0),  // Darkest red
    ]
    
    var body: some View {
        ZStack {
            // Base background (white)
            Color.white.ignoresSafeArea()
            
            // Stacked circles with different red shades
            ForEach(0..<redColors.count, id: \.self) { index in
                Circle()
                    .fill(redColors[index])
                    .frame(width: 150, height: 150)
                    .scaleEffect(redCircleScale * (1.0 - (Double(index) * 0.15)))
                    .ignoresSafeArea()
            }
            
            // The lock icon in the center.
            Image(systemName: "lock.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.white)  // White lock for better visibility on red background
                .offset(y: lockOffset)
                .rotationEffect(.degrees(lockRotation))
        }
        .onAppear {
            // Animate the red circle expansion quickly.
            withAnimation(.easeOut(duration: 0.5)) {
                redCircleScale = 10.0  // Scale up to fill the screen.
            }
            // Animate the lock dropping while rotating to flat.
            withAnimation(.easeInOut(duration: 0.6)) {
                lockOffset = 20    // Move lock down 20 points.
                lockRotation = 0   // Rotate to flat (0°).
            }
            // Bounce the lock back up using a spring effect.
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.6)) {
                lockOffset = 0     // Return lock to original vertical position.
            }
        }
    }
}

struct LockView_Previews: PreviewProvider {
    static var previews: some View {
        LockView()
    }
}
