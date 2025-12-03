//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    @EnvironmentObject var bibleDataManager: BibleDataManager
    
    var body: some View {
        MainTabView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationModel.shared)
        .environmentObject(BibleVerseStore())
        .environmentObject(BibleDataManager.shared)
}
