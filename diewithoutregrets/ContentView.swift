//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

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
                    // First Tab - Guard
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
                        Label("Study", systemImage: "rectangle.stack.fill")
                    }
                    .tag(1)
                    
                    // Third Tab - Profile
                    NavigationStack {
                        ProfileView()
                            .environmentObject(DeckStore.shared)
                    }
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(2)
                }
                .tint(Color(hex: 0x184449))
                .onChange(of: selectedTab) {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.prepare()
                    generator.impactOccurred()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct ProfileView: View {
    @EnvironmentObject var deckStore: DeckStore
    @State private var showingSettings = false
    @State private var showingFlashcardSettings = false
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @State private var showingPaywall = false
    
    private var totalAvailableCards: Int {
        deckStore.decks.reduce(0) { $0 + $1.cards.count }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats Overview
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        StatItem(title: "Decks", value: "\(deckStore.decks.count)", icon: "rectangle.stack.fill")
                        StatItem(title: "Cards", value: "\(totalAvailableCards)", icon: "doc.text.fill")
                        StatItem(title: "To Unlock", value: useAllCards ? "All" : "\(flashcardCount)", icon: "lock.fill")
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal)
                
                // Study Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Study Settings")
                    
                    Button(action: { showingFlashcardSettings = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Flashcards before unlocking")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: 0x184449))
                                
                                Text(useAllCards ? "All cards" : "\(flashcardCount) cards")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Account Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Account")
                    
                    Button(action: {
                        showingPaywall = true
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Upgrade to Pro")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x3FA4AE), Color(hex: 0x2BC391)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Help Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Help & Legal")
                    
                    VStack(spacing: 2) {
                        LinkMenuItem(icon: "questionmark.circle", title: "FAQs", url: "https://studyguard.framer.website/")
                        LinkMenuItem(icon: "exclamationmark.triangle", title: "Report an Error", url: "https://studyguard.framer.website/support")
                        LinkMenuItem(icon: "doc.text", title: "Terms of Use", url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        LinkMenuItem(icon: "hand.raised", title: "Privacy Policy", url: "https://studyguard.framer.website/legal/privacy-policy")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(hex: 0xF8F9FA))
        .navigationTitle("Profile")
        .sheet(isPresented: $showingFlashcardSettings) {
            FlashcardSettingsSheet(flashcardCount: $flashcardCount, useAllCards: $useAllCards)
                .presentationCornerRadius(30)
                .presentationDetents([.fraction(0.8)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingPaywall) {
                    // Present your PaywallView here
                    PaywallView()
                        .onPurchaseCompleted { customerInfo in
                            // Handle successful purchase if needed
                            showingPaywall = false
                        }
                }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color(hex: 0x184449))
            .padding(.leading, 4)
    }
}

struct LinkMenuItem: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: 0x184449))
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(Color(hex: 0x184449))
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x184449).opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: 0x184449))
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: 0x184449))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account")) {
                    NavigationLink {
                        Text("Account Settings")
                    } label: {
                        Label("Account Settings", systemImage: "person.circle")
                    }
                    
                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }
                
                Section(header: Text("Preferences")) {
                    NavigationLink {
                        Text("Study Settings")
                    } label: {
                        Label("Study Settings", systemImage: "book")
                    }
                    
                    NavigationLink {
                        Text("Appearance")
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                }
                
                Section(header: Text("Support")) {
                    NavigationLink {
                        Text("Help Center")
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink {
                        Text("Contact Us")
                    } label: {
                        Label("Contact Us", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FlashcardSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var flashcardCount: Int
    @Binding var useAllCards: Bool
    
    let options = [3, 5, 10, 15, 20, 25]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.self) { number in
                        Button(action: {
                            flashcardCount = number
                            useAllCards = false
                            dismiss()
                        }) {
                            HStack {
                                Text("\(number) cards")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !useAllCards && flashcardCount == number {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: 0x184449))
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        useAllCards = true
                        dismiss()
                    }) {
                        HStack {
                            Text("All cards")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if useAllCards {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(hex: 0x184449))
                            }
                        }
                    }
                } header: {
                    Text("Select the number of flashcards required to unlock")
                } footer: {
                    Text("If you select more cards than available in a deck, all cards from that deck will be used.")
                }
            }
            .navigationTitle("Flashcard Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(UIScreen.main.bounds.height * 0.6)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ContentView()
        .environmentObject(RegretStore.shared)
        .environmentObject(NavigationModel.shared)
}
