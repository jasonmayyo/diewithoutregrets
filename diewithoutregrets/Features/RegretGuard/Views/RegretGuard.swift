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
                    .padding(.vertical, 5)
                    .tag(index)
                }
                
                // Add Deck Button
                Button(action: { showAddDeckSheet = true }) {
                    VStack(spacing: 15) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 40))
                        Text("Create New Deck")
                            .bold()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 0)
                    .padding(.horizontal)
                }
                .foregroundColor(Color(hex: 0x184449))
                .tag(deckStore.decks.count)
            }
            .frame(height: 160)
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
    }
}

struct DeckCardView: View {
    let deck: Deck
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deck.name)
                            .font(.headline)
                            .bold()
                            .lineLimit(1)
                        
                        Text("\(deck.cards.count) flashcards")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    
                    // Status indicator
                    VStack {
                        Circle()
                            .fill(isSelected ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 14, height: 14)
                        Text(isSelected ? "Active" : "Inactive")
                            .font(.caption2)
                            .foregroundColor(isSelected ? .green : .gray)
                    }
                }
                
                Spacer()
                
                // Preview of first few cards if available
                if !deck.cards.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(deck.cards.prefix(3).enumerated()), id: \.element.id) { index, card in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: 0x184449).opacity(0.1))
                                    .frame(width: 60, height: 40)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(Color(hex: 0x184449))
                                    )
                            }
                            
                            if deck.cards.count > 3 {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: 0x184449).opacity(0.1))
                                    .frame(width: 60, height: 40)
                                    .overlay(
                                        Text("+\(deck.cards.count - 3)")
                                            .font(.caption)
                                            .foregroundColor(Color(hex: 0x184449))
                                    )
                            }
                        }
                    }
                    .padding(.top, 5)
                } else {
                    Text("No cards yet - tap to add")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                }
                
                if !isSelected {
                    Text("Tap to activate")
                        .font(.caption)
                        .foregroundColor(Color(hex: 0x184449))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
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
