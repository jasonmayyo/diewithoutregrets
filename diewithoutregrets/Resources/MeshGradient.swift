//
//  MeshGradient.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct MeshGradient: View {
    @State private var pulseWidth: CGFloat = 10
    
    var body: some View {
        ZStack {
            // Full-screen edge effect
            Rectangle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: 0x8B0000), // Dark Red
                            Color(hex: 0xB22222), //
                            Color(hex: 0x8B0000)  // Dark Red for smooth transition
                        ]),
                        center: .center
                    ),
                    lineWidth: pulseWidth
                )
                .cornerRadius(50)
                .blur(radius: 10)
                .animation(
                    Animation.easeInOut(duration: 3)
                        .repeatForever(autoreverses: true),
                    value: pulseWidth
                )
                .ignoresSafeArea()
        }
        .compositingGroup()
        .onAppear {
            pulseWidth = 20 // Expands and contracts
        }
    }
}

#Preview {
    MeshGradient()
}
