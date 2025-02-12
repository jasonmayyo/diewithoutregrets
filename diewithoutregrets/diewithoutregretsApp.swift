//
//  diewithoutregretsApp.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI

@main
struct diewithoutregretsApp: App {
    @StateObject private var navigationModel = NavigationModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var regretStore = RegretStore()
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(navigationModel)
                    .environmentObject(regretStore)
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

