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
                    RegretGuard()
                    
                }
            }
        }.preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationModel.shared)
}
