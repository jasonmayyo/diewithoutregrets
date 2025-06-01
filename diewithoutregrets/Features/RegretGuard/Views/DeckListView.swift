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
    @State private var deckToEdit: Deck? = nil
    @State private var showEditSheet: Bool = false

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
                        if deckStore.decks.isEmpty {
                            // Premium Empty State
                            VStack(spacing: 24) {
                                Spacer()
                                
                                // Icon with gradient background
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
                                        .frame(width: 120, height: 120)
                                        .scaleEffect(1.0)
                                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: UUID())
                                    
                                    Image(systemName: "rectangle.stack.badge.plus")
                                        .font(.system(size: 48, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: 0x3FA4AE),
                                                    Color(hex: 0x2BC391)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .scaleEffect(1.0)
                                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: UUID())
                                }
                                
                                VStack(spacing: 12) {
                                    Text("Create Your First Deck")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: 0x184449))
                                    
                                    Text("Start building your knowledge base with flashcard decks tailored to your learning goals.")
                                        .font(.body)
                                        .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 40)
                                
                                // Premium CTA Button
                                Button(action: { showingNewDeckSheet = true }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18, weight: .medium))
                                        
                                        Text("Create Deck")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
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
                                    .cornerRadius(25)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: Color(hex: 0x3FA4AE).opacity(0.3),
                                        radius: 20,
                                        x: 0,
                                        y: 10
                                    )
                                }
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
                                
                                Spacer()
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                        } else {
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
                                        
                                        Button {
                                            deckToEdit = deck
                                            showEditSheet = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            // Remove extra separators if needed
                            .padding(.top, 8)
                        }
                    }
                }
                .sheet(isPresented: $showingNewDeckSheet) {
                    NewDeckView()
                }
                .sheet(isPresented: $showEditSheet, onDismiss: {
                    deckToEdit = nil
                }) {
                    if let deckToEdit = deckToEdit {
                        EditDeckView(deck: deckToEdit, onSave: { updatedDeck in
                            if let index = deckStore.decks.firstIndex(where: { $0.id == updatedDeck.id }) {
                                deckStore.decks[index] = updatedDeck
                                // Update selected deck if it's the same deck that was edited
                                if deckStore.selectedDeck?.id == updatedDeck.id {
                                    deckStore.selectedDeck = updatedDeck
                                }
                            }
                            showEditSheet = false
                        })
                    } else {
                        // Fallback view if deckToEdit is nil
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            
                            Text("Error Loading Deck")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Unable to load the deck for editing. Please try again.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            Button("Close") {
                                showEditSheet = false
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                    }
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
    @State private var showEditDeckSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if deck.cards.isEmpty {
                // Premium Empty State for No Flashcards
                VStack(spacing: 28) {
                    Spacer()
                    
                    // Animated Icon Stack
                    ZStack {
                        // Background circles with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x3FA4AE).opacity(0.08),
                                        Color(hex: 0x2BC391).opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 140, height: 140)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: UUID())
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x3FA4AE).opacity(0.15),
                                        Color(hex: 0x2BC391).opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: UUID())
                        
                        // Main icon
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x3FA4AE),
                                        Color(hex: 0x2BC391)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: UUID())
                    }
                    
                    VStack(spacing: 16) {
                        Text("No Flashcards Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: 0x184449))
                        
                        Text("Add your first flashcard to start learning. You can create them manually or use AI to generate them automatically.")
                            .font(.body)
                            .foregroundColor(Color(hex: 0x184449).opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Manual Add Button
                        Button(action: { showingNewCardSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                                
                                Text("Add Flashcard")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(20)
                            .shadow(
                                color: Color(hex: 0x184449).opacity(0.3),
                                radius: 15,
                                x: 0,
                                y: 8
                            )
                        }
                        
                        // AI Generate Button
                        Button(action: { showAutoGenerateSheet = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .medium))
                                
                                Text("AI Generate")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
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
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($deck.cards) { $card in
                        Button {
                            selectedCard = $card
                            showEditSheet = true
                        } label: {
                            VStack(alignment: .leading) {
                                Text(card.regretPrompt)
                                    .font(.headline)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                Text(card.regret)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
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
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showEditDeckSheet = true }) {
                        Image(systemName: "pencil")
                            .foregroundColor(Color(hex: 0x184449))
                    }
                    .accessibilityLabel("Edit deck name")
                    
                    Button(action: { showingNewCardSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(Color(hex: 0x184449))
                    }
                    .accessibilityLabel("Add new flashcard")
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
            if let selectedCard = selectedCard,
               let cardIndex = deck.cards.firstIndex(where: { $0.id == selectedCard.wrappedValue.id }) {
                RegretEditorSheet(regret: $deck.cards[cardIndex])
            }
        }
        .sheet(isPresented: $showEditDeckSheet) {
            EditDeckView(deck: deck, onSave: { updatedDeck in
                deck = updatedDeck
                deckStore.updateDeck(updatedDeck)
            })
        }
        .onChange(of: deck) { newDeck in
            // Update the deck store whenever the deck changes
            deckStore.updateDeck(newDeck)
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

struct EditDeckView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var deckStore: DeckStore
    let deck: Deck
    let onSave: (Deck) -> Void
    
    @State private var deckName: String
    @State private var showDuplicateAlert = false
    
    init(deck: Deck, onSave: @escaping (Deck) -> Void) {
        self.deck = deck
        self.onSave = onSave
        self._deckName = State(initialValue: deck.name)
    }
    
    private var isDuplicateName: Bool {
        let trimmedName = deckName.trimmingCharacters(in: .whitespaces).lowercased()
        let originalName = deck.name.lowercased()
        // Don't consider it a duplicate if it's the same as the original name
        return trimmedName != originalName && deckStore.decks.contains { $0.name.lowercased() == trimmedName }
    }
    
    private var isValidName: Bool {
        let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
        return !trimmedName.isEmpty && !isDuplicateName
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
            .navigationTitle("Edit Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel deck editing")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
                        if isDuplicateName {
                            showDuplicateAlert = true
                        } else {
                            var updatedDeck = deck
                            updatedDeck.name = trimmedName
                            onSave(updatedDeck)
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

