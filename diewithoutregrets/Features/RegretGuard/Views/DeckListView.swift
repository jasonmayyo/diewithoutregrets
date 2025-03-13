//
//  DeckListView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/03/13.
//

import SwiftUI

struct DeckListView: View {
    @EnvironmentObject var deckStore: DeckStore
    @State private var showingNewDeckSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background image
                Image("dwr-background")
                    .resizable()
                    .frame(height: 140)
                    .edgesIgnoringSafeArea(.all)
                    .accessibilityHidden(true)
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Decks")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                Text("Feed Your Brain Before Your Feed.")
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack {
                                HStack {
                                    Button(action: { showingNewDeckSheet = true }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(Color(hex: 0x184449).opacity(0.7))
                                            .clipShape(Circle())
                                            .shadow(radius: 5)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 15)
                    }
                    
                    // List of decks
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach($deckStore.decks) { $deck in
                                NavigationLink(destination: DeckView(deck: $deck)) {
                                    HStack () {
                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(deck.name)
                                                .font(.headline)
                                                .foregroundColor(.black)
                                            
                                            HStack (spacing: 3) {
                                                Image(systemName: "rectangle.on.rectangle")
                                                    .foregroundColor(.black)
                                                    .font(.caption)
                                                Text("\(deck.cards.count)")
                                                    .foregroundColor(Color(hex: 0x184449))
                                                    .font(.caption)
                                            }
                                        }
                                        
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top)
                    }
                    .background(Color(.systemGroupedBackground))
                }
                
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingNewDeckSheet) {
                NewDeckView()
            }
        }
        .tint(Color(hex: 0x184449))
        .navigationBarHidden(true)
    }
}

#Preview {
    DeckListView()
        .environmentObject(DeckStore.shared)
}

struct DeckView: View {
    @Binding var deck: Deck
    @State private var showingNewCardSheet = false
    
    var body: some View {
        List {
            ForEach(deck.cards) { card in
                NavigationLink(destination: CardDetailView(card: card)) {
                    VStack(alignment: .leading) {
                        Text(card.regretPrompt)
                            .font(.headline)
                        Text(card.regret)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete(perform: deleteCards)
        }
        .tint(.black)
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewCardSheet = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color(hex: 0x184449))
                }
            }
        }
        .sheet(isPresented: $showingNewCardSheet) {
            NewFlashcardSheet(deck: $deck)
        }
    }
    
    private func deleteCards(at offsets: IndexSet) {
        deck.cards.remove(atOffsets: offsets)
    }
}

struct CardDetailView: View {
    let card: Regret
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Question")
                    .font(.title2)
                Text(card.regretPrompt)
                
                Text("Answer")
                    .font(.title2)
                Text(card.regret)
                
                Text("Explanation")
                    .font(.title2)
                Text(card.backgroundExplanation)
            }
            .padding()
        }
        .navigationTitle("Card Details")
    }
}


struct NewDeckView: View {
    @EnvironmentObject var deckStore: DeckStore
    @Environment(\.dismiss) var dismiss
    @State private var deckName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Deck Information")) {
                    TextField("Deck Name", text: $deckName)
                        .accessibilityLabel("Deck name entry field")
                }
            }
            .navigationTitle("New Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel deck creation")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newDeck = Deck(
                            name: deckName.trimmingCharacters(in: .whitespaces),
                            cards: []
                        )
                        deckStore.addDeck(newDeck)
                        dismiss()
                    }
                    .disabled(deckName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel(deckName.isEmpty ? "Save disabled" : "Save new deck")
                }
            }
        }
    }
}

