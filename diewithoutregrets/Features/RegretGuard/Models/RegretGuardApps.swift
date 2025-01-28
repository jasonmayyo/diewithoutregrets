//
//  RegretGuardApps.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretApp: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let shortcutLink: URL
}

// Add the sample data extension
extension RegretApp {
    static let sampleApps: [RegretApp] = [
        RegretApp(
            name: "Instagram",
            iconName: "instagram-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/your-instagram-shortcut")!
        ),
        RegretApp(
            name: "YouTube",
            iconName: "youtube-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/your-youtube-shortcut")!
        )
    ]
}
