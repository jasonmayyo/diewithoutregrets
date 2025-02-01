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
        TabView {
            if navigationModel.currentDestination == .regretView {
                RegretView()
            } else if navigationModel.currentDestination == .regretReport {
                RegretReportView()
            } else {
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
    }
}

