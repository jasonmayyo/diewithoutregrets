//
//  ColorExtension.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/06/12.
//

import SwiftUI

// Extension for hex color support (from your previous code)
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}
