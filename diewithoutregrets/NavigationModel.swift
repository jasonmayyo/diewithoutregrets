import Foundation
import SwiftUI

// Define the destination enum
public enum NavigationDestination {
    case regretView
    case regretReport
}

public final class NavigationModel: ObservableObject {
    public static let shared = NavigationModel()
    
    @Published public var currentDestination: NavigationDestination?
    @Published public var showBuyBackOffer: Bool = false
    @Published public var hasPendingBuyBackOffer: Bool = false
    
    private init() {
        print("[NavigationModel] Initialized")
    }
    
    public func navigate(to destination: NavigationDestination) {
        print("[NavigationModel] Navigate to: \(destination)")
        if Thread.isMainThread {
            currentDestination = destination
        } else {
            DispatchQueue.main.async {
                self.currentDestination = destination
            }
        }
    }

    public func presentBuyBackOffer() {
        print("[NavigationModel] presentBuyBackOffer called, current value: \(showBuyBackOffer)")
        if Thread.isMainThread {
            self.showBuyBackOffer = true
            print("[NavigationModel] showBuyBackOffer set to true")
        } else {
            DispatchQueue.main.async {
                self.showBuyBackOffer = true
                print("[NavigationModel] showBuyBackOffer set to true (async)")
            }
        }
    }

    public func dismissCurrentModal() {
        print("[NavigationModel] dismissCurrentModal called")
        if Thread.isMainThread {
            self.showBuyBackOffer = false
        } else {
            DispatchQueue.main.async {
                self.showBuyBackOffer = false
            }
        }
    }
}
