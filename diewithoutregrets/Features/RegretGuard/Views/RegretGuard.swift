//
//  RegretGuard.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretGuard: View {
    @EnvironmentObject var regretStore: RegretStore
    @StateObject private var viewModel = RegretGuardViewModel()
    @EnvironmentObject var deckStore: DeckStore
    @State private var showNewFlashcardSheet = false
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                // Background image
                Image("dwr-background")
                    .resizable()
                    .frame(height: 160)
                    .edgesIgnoringSafeArea(.all)
                    .accessibilityHidden(true) // Hide decorative background image
                
                VStack {
                    headerSection
                    ScrollView {
                        VStack(alignment: .leading) {
                            deckSelectionSection
                            appRestrictionSection
                        }
                    }
                }
                
                .sheet(isPresented: $viewModel.showInstructions) {
                    if let app = viewModel.selectedApp {
                        RegretGuardInstructionSheet(app: app)
                            .presentationDetents([.large])
                            .presentationCornerRadius(30)
                    }
                }
                .sheet(isPresented: $viewModel.showEditRegret) {
                    if let selectedRegret = regretStore.selectedRegret,
                       let index = regretStore.regrets.firstIndex(where: { $0.id == selectedRegret.id }) {
                        RegretEditorSheet(regret: $regretStore.regrets[index])
                            .presentationDetents([.large])
                            .presentationCornerRadius(30)
                            .environmentObject(regretStore)
                    }
                }
            }
            .preferredColorScheme(.light)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    
    private var headerSection: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Study Guard")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Text("Protect Your Time, Protect Your Goals.")
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal)
    }
    
    private var deckSelectionSection: some View {
        DeckSelectionView()
            
    }
    
    
    private var newDeckButton: some View {
        Button(action: { showNewFlashcardSheet = true }) {
            VStack {
                Image(systemName: "plus")
                    .foregroundColor(.black)
                    .bold()
                Text("New Deck")
                    .foregroundColor(.black)
                    .bold()
            }
            .frame(width: 280, height: 130)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 0)
            
            .padding(.vertical, 5)
        }
    }
    
    
    
    private var appRestrictionSection: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Study-Proof Your Phone")
                        .font(.title3)
                        .bold()
                    Text("Select the apps that may hold you back from your goals.")
                        .font(.caption)
                }
                Spacer()
            }
            .padding(.bottom, 5)
            
            let columns = [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 10)]
            
            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(viewModel.apps) { app in
                    AppRestrictionButton(app: app) {
                        viewModel.selectApp(app)
                    }
                }
            }
            
            HStack {
                Spacer()
                Text("Can't find what you're looking for? We're adding more everyday!")
                    .font(.system(size: 10))
                    .padding(.top, 5)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}
struct DeckSelectionView: View {
    @EnvironmentObject var deckStore: DeckStore
    @State private var showAddDeckSheet = false
    @State private var currentPageIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Deck Cards Carousel
            TabView(selection: $currentPageIndex) {
                ForEach(Array(deckStore.decks.enumerated()), id: \.element.id) { index, deck in
                    DeckCardView(
                        deck: deck,
                        isSelected: deckStore.selectedDeck?.id == deck.id
                    ) {
                        deckStore.selectDeck(deck)
                    }
                    .tag(index)
                }
                
                // Add Deck Button
                Button(action: { showAddDeckSheet = true }) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: 0x3FA4AE).opacity(0.1),
                                            Color(hex: 0x2BC391).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color(hex: 0x184449))
                        }
                        
                        VStack(spacing: 4) {
                            Text("Create New Deck")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: 0x184449))
                            
                            Text("Start organizing your flashcards")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(
                                color: Color.black.opacity(0.08),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .tag(deckStore.decks.count)
            }
            .frame(height: 235)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom Page Indicators
            HStack {
                Spacer()
                ForEach(0..<(deckStore.decks.count + 1), id: \.self) { index in
                    Circle()
                        .fill(index == currentPageIndex ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 5, height: 5)
                }
                Spacer()
            }
            
            // Selected Deck Info
            if let selectedDeck = deckStore.selectedDeck {
                HStack {
                    Text("Active Deck: \(selectedDeck.name)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(selectedDeck.cards.count) cards")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showAddDeckSheet) {
            NewDeckView()
                .presentationDetents([.large])
                .presentationCornerRadius(30)
        }
        .onChange(of: deckStore.decks.count, initial: false) { oldCount, newCount in
            if newCount == 1 && oldCount != 1 && deckStore.selectedDeck == nil {
                deckStore.selectedDeck = deckStore.decks.first
            }
        }
    }
}

struct DeckCardView: View {
    let deck: Deck
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var deckStore: DeckStore
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Premium header with gradient background
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(deck.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text("\(deck.cards.count) flashcards")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    Spacer()
                    
                    // Premium status indicator
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .fill(isSelected ? Color.green : .white.opacity(0.6))
                                .frame(width: 18, height: 18)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text(isSelected ? "ACTIVE" : "INACTIVE")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: isSelected ? [
                            Color(hex: 0x2BC391),
                            Color(hex: 0x3FA4AE)
                        ] : [
                            Color(hex: 0x184449),
                            Color(hex: 0x065961)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Enhanced management button
                NavigationLink(destination: DeckView(deck: Binding(
                    get: { 
                        deckStore.decks.first(where: { $0.id == deck.id }) ?? deck 
                    },
                    set: { newValue in
                        if let index = deckStore.decks.firstIndex(where: { $0.id == deck.id }) {
                            deckStore.decks[index] = newValue
                        }
                    }
                ))) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: deck.cards.isEmpty ? "plus.circle.fill" : "square.and.pencil")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(deck.cards.isEmpty ? "Create Flashcards" : "Manage Flashcards")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: 0x184449))
                            
                            Text(deck.cards.isEmpty ? "Start building your deck" : "Edit and organize cards")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.3))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Activation prompt or active deck explanation
                if !isSelected {
                    Divider()
                        .padding(.horizontal, 24)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: 0x3FA4AE))
                        
                        Text("Tap to activate this deck")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: 0x184449))
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color(hex: 0x3FA4AE))
                            .frame(width: 6, height: 6)
                            .scaleEffect(isSelected ? 0 : 1)
                            .opacity(isSelected ? 0 : 1)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isSelected)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(hex: 0x3FA4AE).opacity(0.04))
                } else {
                    Divider()
                        .padding(.horizontal, 24)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.green)
                        
                        Text("Answer flashcards from this deck to unblock apps.")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: 0x184449).opacity(0.8))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.05))
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? 
                        LinearGradient(
                            colors: [
                                Color(hex: 0x2BC391).opacity(0.6),
                                Color(hex: 0x3FA4AE).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .shadow(
                color: isSelected ? 
                    Color(hex: 0x2BC391).opacity(0.2) : 
                    Color.black.opacity(0.08),
                radius: isSelected ? 16 : 10,
                x: 0,
                y: isSelected ? 6 : 3
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 16) // Increased padding to prevent clipping
    }
}

struct AppRestrictionButton: View {
    let app: RegretApp
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(app.iconName)
                    .resizable()
                    .frame(width: 25, height: 25)
                Text(app.name)
                    .font(.system(size: 14))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.2), radius: 5, x: 2, y: 2)
        }
        .foregroundColor(.black)
    }
}

#Preview {
    RegretGuard()
        .environmentObject(RegretStore.shared)
        .environmentObject(DeckStore.shared)
}
