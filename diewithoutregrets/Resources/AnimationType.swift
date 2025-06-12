//
//  AnimationType.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/06/12.
//

import Foundation

enum AnimationType: String, CaseIterable {
    case lockAnimation = "lock"
    case memeVideo = "meme"
    
    var displayName: String {
        switch self {
        case .lockAnimation:
            return "Lock Animation"
        case .memeVideo:
            return "Meme Video"
        }
    }
    
    var description: String {
        switch self {
        case .lockAnimation:
            return "Classic animated lock with colorful background"
        case .memeVideo:
            return "Short meme video to brighten your day"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .lockAnimation:
            return "lock.circle.fill"
        case .memeVideo:
            return "play.circle.fill"
        }
    }
} 
