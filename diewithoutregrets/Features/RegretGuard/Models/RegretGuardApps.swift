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
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/171e3ff340c34abfad727e84cd68799e")!
        ),
        RegretApp(
            name: "YouTube",
            iconName: "youtube-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/171e3ff340c34abfad727e84cd68799e")!
        )
    ]
}


extension Regret {
    static let regrets: [Regret] = [
        Regret (regretPrompt: "Imagine you’re 80, looking back on your life. What are the things you’d most regret not doing? What dreams did you leave behind? What opportunities did you waste?", regret: "Not starting the business I've always wanted"),
        Regret (regretPrompt: "Regret prompt number 2?", regret: "this is my second regret hehehe hghogogogog")
    ]
}
