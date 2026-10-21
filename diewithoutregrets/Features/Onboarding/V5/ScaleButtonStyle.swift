// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5ScaleButtonStyle.swift
//  OneThing
//
//  Created by Jason Mayo on 2025/06/27.
//

import SwiftUI

// MARK: - Scale Button Style
struct SGV5ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

