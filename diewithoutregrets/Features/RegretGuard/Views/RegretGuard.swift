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
        VStack(alignment: .leading) {
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(deckStore.decks) { deck in
                            DeckCardView(deck: deck, isSelected: deckStore.selectedDeck?.id == deck.id) {
                                deckStore.selectDeck(deck)
                                withAnimation {
                                    scrollProxy.scrollTo(deck.id, anchor: .leading)
                                }
                            }
                        }
                        
                    }
                }
            }
        }
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



struct DeckCardView: View {
    let deck: Deck
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Spacer()
                Text(deck.name)
                    .foregroundColor(.black)
                    .bold()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(isSelected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                        .shadow(color: isSelected ? Color.green.opacity(0.8) : Color.clear, radius: 5, x: 0, y: 0)
                        
                    Text(isSelected ? "Active" : "Inactive")
                        .foregroundColor(.black)
                        .font(.caption)
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 10)
                    Image(systemName: "rectangle.on.rectangle")
                        .foregroundColor(Color(hex: 0x184449))
                        .font(.caption)
                    Text("\(deck.cards.count)")
                        .foregroundColor(.black)
                        .font(.caption)
                    
                }
                
                Spacer()
                Text(isSelected ? " " : "Tap to make Active")
                    .foregroundColor(.gray)
                    .font(.caption2)
                    .padding(.bottom,5)
            }
            .frame(width: 280, height: 130)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 5)
                
            )
            
        }.cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 0)
            .padding(.leading)
            .padding(.vertical, 5)
        
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
