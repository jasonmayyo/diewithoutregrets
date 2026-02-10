//
//  AppURLHelper.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2026/02/10.
//

import Foundation

/// Shared helper for resolving app URL schemes.
/// Used by both RegretView (flashcard unlock) and FocusSessionView (True Focus unlock).
struct AppURLHelper {
    static func url(for appName: String) -> URL {
        let scheme = urlScheme(for: appName)
        return URL(string: scheme) ?? URL(string: "instagram://") ?? URL(string: "https://instagram.com") ?? URL(fileURLWithPath: "/")
    }

    static func urlScheme(for appName: String) -> String {
        switch appName.lowercased() {
        case "instagram": return "instagram://"
        case "youtube": return "youtube://"
        case "tiktok": return "tiktok://"
        case "threads": return "threads://"
        case "snapchat": return "snapchat://"
        case "netflix": return "netflix://"
        case "facebook": return "facebook://"
        case "bereal": return "bereal://"
        case "reddit": return "reddit://"
        case "x": return "x://"
        case "safari": return "https://google.com"
        case "clash royale": return "clashroyale://"
        default: return "instagram://"
        }
    }
}
