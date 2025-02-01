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
    case regretView
    case regretReport
}

// Remove @MainActor and make it synchronous
public final class NavigationModel: ObservableObject {
    public static let shared = NavigationModel()
    
    @Published public var currentDestination: NavigationDestination?
    
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
}
