//
//  NavigationModel.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/31.
//

import Foundation
import SwiftUI

// Define the destination enum
public enum NavigationDestination {
    case faithVerseView
    case faithReport
    
    // Backward compatibility aliases
    static var regretView: NavigationDestination { .faithVerseView }
    static var regretReport: NavigationDestination { .faithReport }
}

// Tab enum for main navigation
public enum AppTab {
    case home
    case bible
    case profile
}

// Remove @MainActor and make it synchronous
public final class NavigationModel: ObservableObject {
    public static let shared = NavigationModel()
    
    @Published public var currentDestination: NavigationDestination?
    @Published public var selectedTab: AppTab = .home
    
    private init() {}
    
    public func navigate(to destination: NavigationDestination) {
        // Ensure we're on the main thread
        if Thread.isMainThread {
            currentDestination = destination
        } else {
            DispatchQueue.main.async {
                self.currentDestination = destination
            }
        }
    }
    
    public func switchToTab(_ tab: AppTab) {
        if Thread.isMainThread {
            selectedTab = tab
        } else {
            DispatchQueue.main.async {
                self.selectedTab = tab
            }
        }
    }
}
