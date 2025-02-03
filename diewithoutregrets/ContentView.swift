//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    
    var body: some View {
        NavigationStack {
            Group {
                if navigationModel.currentDestination == .regretView {
                    RegretView()
                } else {
                    ZStack {
                        // Blurred background
                        Color.clear
                            .background(.ultraThinMaterial)
                            .ignoresSafeArea()
                        
                        TabView {
                            RegretGuard()
                                .tabItem {
                                    Image(systemName: "house.fill")
                                        
                                    Text("Home")
                                }
                            
                            dwrLockView()
                                .tabItem {
                                    Image(systemName: "lock.rectangle.stack.fill")
                                        
                                    Text("Locks")
                                }
                        }
                        .tint(Color(hex: 0x184449))
                        .background(Color.clear)
                        .glassBackground()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}


extension View {
    func glassBackground() -> some View {
        self.onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationModel.shared)
}
