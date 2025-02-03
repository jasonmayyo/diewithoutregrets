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
                    Color(hex: 0x36B8C4),  // Dark teal
                    Color(hex: 0x238A94),  // Deep forest green
                    Color(hex: 0x197C6F),  // Bright teal
                    Color(hex: 0x26B37D),  // Light green
                    Color(hex: 0x34CC92)   // Neon green
                ]),
                center: .center,
                angle: .degrees(animateGradient ? 360 : 0)
            )
            .blur(radius: 40)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x197C6F).opacity(0.7),  // Bright teal
                        Color(hex: 0x26B37D).opacity(0.4)   // Green-yellow
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
