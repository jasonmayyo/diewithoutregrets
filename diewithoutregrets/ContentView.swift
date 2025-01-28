//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RegretReportView()
                .tabItem {
                    Image(systemName: "house.fill")
                }
                .tag(1)
            RegretGuard()
                .tabItem {
                    Image(systemName: "lock.shield.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
