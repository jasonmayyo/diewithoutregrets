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
    @State private var deckToDelete: Deck? = nil
    @State private var showDeleteAlert: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                ZStack(alignment: .top) {
                    // Background image
                    Image("dwr-background3")
                        .resizable()
                        .frame(height: 145)
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
                            .padding(.horizontal)
                            .padding(.bottom, 25)
                        }

                        // List of decks with swipe delete
                        List {
                            ForEach($deckStore.decks) { $deck in
                                NavigationLink(destination: DeckView(deck: $deck)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(deck.name)
                                                .font(.headline)
                                                .foregroundColor(.black)

                                            HStack(spacing: 3) {
                                                Image(systemName: "rectangle.on.rectangle")
                                                    .foregroundColor(.black)
                                                    .font(.caption)
                                                Text("\(deck.cards.count)")
                                                    .foregroundColor(Color(hex: 0x184449))
                                                    .font(.caption)
                                            }
                                        }

                                        Spacer()
                                       
                                    }
                                    .padding(8)
                                    .background(Color.white)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deckToDelete = deck
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        // Remove extra separators if needed
                        .padding(.top, 8)
                    }
                }
                .sheet(isPresented: $showingNewDeckSheet) {
                    NewDeckView()
                }
            }
            .navigationBarHidden(true)
            .alert("Confirm Deletion", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete,
                       let index = deckStore.decks.firstIndex(where: { $0.id == deck.id }) {
                        deckStore.decks.remove(at: index)
                    }
                    deckToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    deckToDelete = nil
                }
            } message: {
                if let deck = deckToDelete {
                    Text("Are you sure you want to delete the deck \"\(deck.name)\"?")
                } else {
                    Text("Are you sure you want to delete this deck?")
                }
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
    @State private var showAutoGenerateSheet = false
    @State private var selectedCard: Binding<Regret>? = nil
    @State private var showEditSheet = false
    
    var body: some View {
        VStack {
            List {
                ForEach($deck.cards) { $card in
                    Button {
                        selectedCard = $card
                        showEditSheet = true
                    } label: {
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
            .listStyle(PlainListStyle())
            .tint(.black)
            .navigationTitle(deck.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewCardSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(Color(hex: 0x184449))
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Auto Generate Flashcards") {
                        showAutoGenerateSheet = true
                    }
                }
            }
            .sheet(isPresented: $showAutoGenerateSheet) {
                AutoGenerateFlashcardsSheet(deck: $deck)
            }
            .sheet(isPresented: $showingNewCardSheet) {
                NewFlashcardSheet(deck: $deck)
            }
            .sheet(isPresented: $showEditSheet, onDismiss: { selectedCard = nil }) {
                if let selectedCard = selectedCard {
                    RegretEditorSheet(regret: selectedCard)
                }
            }
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
                }
            }
        }
    }
}

