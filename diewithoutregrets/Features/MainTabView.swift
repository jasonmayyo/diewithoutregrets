//
//  MainTabView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    @EnvironmentObject var bibleDataManager: BibleDataManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content based on selected tab
            Group {
                switch navigationModel.selectedTab {
                case .home:
                    if navigationModel.currentDestination == .faithVerseView {
                        FaithVerseView()
                    } else {
                        FaithGuard()
                    }
                case .bible:
                    BibleReaderTabView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxHeight: .infinity)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: Binding(
                get: { navigationModel.selectedTab },
                set: { navigationModel.selectedTab = $0 }
            ))
            .background(
                Color(red: 0.08, green: 0.10, blue: 0.14)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        VStack(spacing: 0) {
        
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house.fill",
                    label: "Home",
                    isSelected: selectedTab == .home
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .home
                    }
                }
                
                TabBarButton(
                    icon: "book.fill",
                    label: "Bible",
                    isSelected: selectedTab == .bible
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .bible
                    }
                }
                
                TabBarButton(
                    icon: "person.fill",
                    label: "Profile",
                    isSelected: selectedTab == .profile
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .profile
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(
            Color(red: 0.08, green: 0.10, blue: 0.14)
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.35))
                }
                .frame(height: 32)
                
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainTabView()
        .environmentObject(NavigationModel.shared)
        .environmentObject(BibleVerseStore.shared)
        .environmentObject(BibleDataManager.shared)
}

