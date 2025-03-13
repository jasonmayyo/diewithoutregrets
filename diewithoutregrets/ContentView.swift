//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var navigationModel: NavigationModel
    
    var body: some View {
        
        Group {
            if navigationModel.currentDestination == .regretView {
                RegretView()
                    .environmentObject(DeckStore.shared) 
                    .environmentObject(RegretStore.shared)
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        RegretGuard()
                            .environmentObject(DeckStore.shared)
                    }
                    .tabItem {
                        Label("Guard", systemImage: "shield.lefthalf.filled")
                    }
                    .tag(0)
                    
                    // Second Tab - Decks
                    NavigationStack {
                        DeckListView()
                            .environmentObject(DeckStore.shared)
                    }
                    .tabItem {
                        Label("Decks", systemImage: "square.stack.3d.up")
                    }
                    .tag(1)
                }
            }
            
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .environmentObject(RegretStore.shared)
        .environmentObject(NavigationModel.shared)
}
