//
//  FaithGuardApp.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI

@main
struct FaithGuardApp: App {
    @StateObject private var navigationModel = NavigationModel.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var bibleVerseStore = BibleVerseStore()
    @StateObject private var bibleDataManager = BibleDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(navigationModel)
                    .environmentObject(bibleVerseStore)
                    .environmentObject(bibleDataManager)
            } else {
                OnboardingView()
                    .environmentObject(bibleVerseStore)
                    .environmentObject(bibleDataManager)
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var showFaithVerseView: Bool = false
}
