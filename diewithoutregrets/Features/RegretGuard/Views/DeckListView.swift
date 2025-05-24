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
    @State private var isPracticing = false // Add this state variable
    @EnvironmentObject var deckStore: DeckStore // Add this environment object
        @State private var showingPractice = false

    var body: some View {
        VStack(spacing: 0) {
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
            
            // Practice & Auto Generate Buttons
            VStack(spacing: 12) {
                // Add Practice Button
                Button {
                    deckStore.selectDeck(deck) // Ensure this deck is selected
                    showingPractice = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Practice Deck")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: 0x184449))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: Color(hex: 0x184449).opacity(0.3),
                        radius: 15,
                        x: 0,
                        y: 8
                    )
                }
                .disabled(deck.cards.isEmpty)
                            .fullScreenCover(isPresented: $showingPractice) {
                                PracticeView(deck: deck)
                                    .environmentObject(deckStore)
                            }
                
                // Existing Auto Generate Button
                Button {
                    showAutoGenerateSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Auto Generate Flashcards")
                            .font(.headline)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x3FA4AE),
                                Color(hex: 0x2BC391)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: Color(hex: 0x3FA4AE).opacity(0.3),
                        radius: 15,
                        x: 0,
                        y: 8
                    )
                }
                .buttonStyle(GenerateButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(Color(hex: 0xF8F9FA))
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewCardSheet = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color(hex: 0x184449))
                }
            }
        }
        .sheet(isPresented: $showAutoGenerateSheet) {
            AutoGenerateFlashcardsSheet(deck: $deck)
                .presentationCornerRadius(30)
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
    @State private var showDuplicateAlert = false
    
    private var isDuplicateName: Bool {
        let trimmedName = deckName.trimmingCharacters(in: .whitespaces).lowercased()
        return deckStore.decks.contains { $0.name.lowercased() == trimmedName }
    }
    
    private var isValidName: Bool {
        !deckName.trimmingCharacters(in: .whitespaces).isEmpty && !isDuplicateName
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Deck Information")) {
                    TextField("Deck Name", text: $deckName)
                        .accessibilityLabel("Deck name entry field")
                    
                    if isDuplicateName && !deckName.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("A deck with this name already exists")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
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
                        let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
                        if isDuplicateName {
                            showDuplicateAlert = true
                        } else {
                            let newDeck = Deck(
                                name: trimmedName,
                                cards: []
                            )
                            deckStore.addDeck(newDeck)
                            dismiss()
                        }
                    }
                    .disabled(!isValidName)
                }
            }
            .alert("Duplicate Deck Name", isPresented: $showDuplicateAlert) {
                Button("OK") {
                    showDuplicateAlert = false
                }
            } message: {
                Text("A deck with the name '\(deckName.trimmingCharacters(in: .whitespaces))' already exists. Please choose a different name.")
            }
        }
    }
}

