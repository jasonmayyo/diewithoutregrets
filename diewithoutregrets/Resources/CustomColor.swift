//
//  CustomColor.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}


// Example Useage
// Color(hex: 0x184449)
