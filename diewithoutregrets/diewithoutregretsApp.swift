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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationModel)
        }
    }
}

class AppState: ObservableObject {
    @Published var showRegretView: Bool = false
}

