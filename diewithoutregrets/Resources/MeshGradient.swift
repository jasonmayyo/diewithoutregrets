//
//  MeshGradient.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct MeshGradient: View {
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            AngularGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0x184449),  // Dark teal
                    Color(hex: 0x1B3F34),  // Deep forest green
                    Color(hex: 0x1EDAA0),  // Bright teal
                    Color(hex: 0x90EE90),  // Light green
                    Color(hex: 0x00FF00)   // Neon green
                ]),
                center: .center,
                angle: .degrees(animateGradient ? 360 : 0)
            )
            .blur(radius: 40)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x1EDAA0).opacity(0.7),  // Bright teal
                        Color(hex: 0xADFF2F).opacity(0.4)   // Green-yellow
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.softLight)
            )
            .animation(
                Animation.easeInOut(duration: 6)  // Faster animation
                    .repeatForever(autoreverses: false),
                value: animateGradient
            )
            .onAppear {
                animateGradient = true
            }
        }
    }
}

#Preview {
    MeshGradient()
}
