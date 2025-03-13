
//
//  UnlockView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/03/12.
//

import SwiftUI

struct UnlockView: View {
    // State for vertical offset of the lock
    @State private var lockOffset: CGFloat = 0
    // State for the scale of the red circle background
    @State private var redCircleScale: CGFloat = 0.1
    // State for the rotation angle of the lock (starting at 30° for a "tilted" position)
    @State private var lockRotation: Double = 30

    var body: some View {
        ZStack {
            // Base background (white)
            Color.white.ignoresSafeArea()
            
            // Expanding red circle background.
            Circle()
                .fill(Color.green)
                .frame(width: 100, height: 100)
                .scaleEffect(redCircleScale)
                .ignoresSafeArea()
            
            // The lock icon in the center.
            Image(systemName: "lock.open.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .offset(y: lockOffset)
                .rotationEffect(.degrees(lockRotation))
        }
        .onAppear {
            // Animate the red circle expansion quickly.
            withAnimation(.easeOut(duration: 0.5)) {
                redCircleScale = 10.0  // Scale up to fill the screen.
            }
            // Animate the lock dropping while rotating to flat.
            withAnimation(.easeInOut(duration: 0.1)) {
                lockOffset = 20    // Move lock down 20 points.
                lockRotation = 0   // Rotate to flat (0°).
            }
            // Bounce the lock back up using a spring effect.
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15).delay(0.15)) {
                lockOffset = 0     // Return lock to original vertical position.
            }
        }
    }
}

struct UnlockView_Previews: PreviewProvider {
    static var previews: some View {
        UnlockView()
    }
}
