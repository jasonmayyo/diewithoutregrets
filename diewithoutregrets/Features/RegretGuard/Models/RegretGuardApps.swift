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

struct Regret: Identifiable {
    let id: UUID
    let regretPrompt: String
    var regret: String // Mark as `var` to allow modification
    static let regrets: [Regret] = []
    // Custom initializer
    init(id: UUID = UUID(), regretPrompt: String, regret: String) {
        self.id = id
        self.regretPrompt = regretPrompt
        self.regret = regret
    }
}

// Add the sample data extension
extension RegretApp {
    static let sampleApps: [RegretApp] = [
        RegretApp(
            name: "Instagram",
            iconName: "instagram-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b02dc82b30d24fd6bf688e1bc323d392")!
        ),
        RegretApp(
            name: "YouTube",
            iconName: "youtube-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/60b648c638524630b3a733a004159a3e")!
        ),
        RegretApp(
            name: "TikTok",
            iconName: "tiktok-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/3a93b551732745cd857b4a830a0287ef")!
        ),
        RegretApp(
            name: "Facebook",
            iconName: "facebook-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/00ac004a93224ea78dd6c8627b7e2ccf")!
        ),
        RegretApp(
            name: "Snapchat",
            iconName: "snapchat-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/db9ad920d0a84d69aef10a9c9874ff42")!
        ),
        RegretApp(
            name: "Twitter (X)",
            iconName: "twitter-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/562c86386e44438580003de9c1057071")!
        ),
        RegretApp(
            name: "Reddit",
            iconName: "reddit-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b736ac777fca4ee799d4573eff769657")!
        ),
        RegretApp(
            name: "Netflix",
            iconName: "netflix-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/da0786ff8ea944aebaaaa82b0ff11dc4")!
        ),
        RegretApp(
            name: "BeReal",
            iconName: "bereal-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/f4efae1b20294e358407f29b2e624a23")!
        ),
        RegretApp(
            name: "Threads",
            iconName: "threads-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/41a6f82163e5463898af33ed3e7c5253")!
        ),
        RegretApp(
            name: "Safari",
            iconName: "safari-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b1074252da6148eda199e73109e7b0bc")!
        ),
    ]
}
