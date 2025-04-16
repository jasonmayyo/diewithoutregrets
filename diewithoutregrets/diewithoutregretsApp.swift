//
//  diewithoutregretsApp.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

@main
struct diewithoutregretsApp: App {
    @StateObject private var navigationModel = NavigationModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var regretStore = RegretStore()
    @StateObject private var deckStore = DeckStore.shared
    
    init() {
        Purchases.configure(withAPIKey: "appl_ArMMMNZWiwLJiQVDcmVCwLigzmG")
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(navigationModel)
                    .environmentObject(regretStore)
                    .environmentObject(deckStore)
                    
            } else {
                OnboardingView()
                    .environmentObject(regretStore) 
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var showRegretView: Bool = false
}

