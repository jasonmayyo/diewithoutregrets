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
            ZStack {
                SGTheme.ink.ignoresSafeArea()

                VStack(spacing: 0) {
                    SGScreenHeader(eyebrow: "Your decks", title: "Decks") {
                        Button(action: { showingNewDeckSheet = true }) {
                            Image(systemName: "plus")
                                .font(SGTheme.cardTitle) // 17 semibold — header icon size
                                .foregroundColor(SGTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(SGTheme.mint, in: Circle())
                        }
                        .buttonStyle(SGPressStyle())
                        .accessibilityLabel("Create new deck")
                    }

                    // List of decks with swipe delete
                    if deckStore.decks.isEmpty {
                        // Empty State
                        VStack(spacing: 24) {
                            Spacer()

                            MascotView(pose: .clipboard)
                                .frame(width: 140, height: 140)

                            VStack(spacing: 10) {
                                Text("Create your first deck")
                                    .font(SGTheme.display(24))
                                    .foregroundColor(SGTheme.paper)

                                Text("Start building your knowledge base with flashcard decks tailored to your learning goals.")
                                    .font(SGTheme.body)
                                    .foregroundColor(SGTheme.paperSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 32)

                            SGButton(title: "Create Deck", icon: "plus", fullWidth: false) {
                                showingNewDeckSheet = true
                            }

                            Spacer()
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, SGTheme.screenPadding)
                        .padding(.bottom, SGTheme.tabBarClearance)
                    } else {
                        List {
                            ForEach($deckStore.decks) { $deck in
                                ZStack {
                                    NavigationLink(destination: DeckView(deck: $deck)) {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(deck.name)
                                                .font(SGTheme.cardTitle)
                                                .foregroundColor(SGTheme.paper)

                                            HStack(spacing: 5) {
                                                Image(systemName: "rectangle.on.rectangle")
                                                    .font(SGTheme.caption) // matches the count label beside it
                                                Text("\(deck.cards.count) cards")
                                                    .font(SGTheme.caption)
                                            }
                                            .foregroundColor(SGTheme.paperSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(SGTheme.rowLabel) // 14 semibold — the disclosure chevron
                                            .foregroundColor(SGTheme.mint)
                                    }
                                    .padding(SGTheme.cardPadding)
                                    .background(
                                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                            .fill(SGTheme.inkRaised)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                                    .strokeBorder(SGTheme.hairline, lineWidth: 1)
                                            )
                                    )
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: SGTheme.screenPadding, bottom: 6, trailing: SGTheme.screenPadding))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deckToDelete = deck
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(SGTheme.ember)

                                    Button {
                                        deckToEdit = deck
                                        showEditSheet = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(SGTheme.teal)
                                }
                            }

                            // Clearance so the floating tab bar never covers the last row.
                            Color.clear
                                .frame(height: SGTheme.tabBarClearance)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .background(SGTheme.ink)
                        .padding(.top, 8)
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
                        ZStack {
                            SGTheme.ink.ignoresSafeArea()

                            VStack(spacing: 20) {
                                Image("sticker-error")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)

                                Text("Error Loading Deck")
                                    .font(SGTheme.display(22))
                                    .foregroundColor(SGTheme.paper)

                                Text("Unable to load the deck for editing. Please try again.")
                                    .font(SGTheme.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(SGTheme.paperSecondary)

                                SGButton(title: "Close", variant: .ghost, fullWidth: false) {
                                    showEditSheet = false
                                }
                            }
                            .padding()
                        }
                        .sgSheetChrome()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Confirm Deletion", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete,
                       let index = deckStore.decks.firstIndex(where: { $0.id == deck.id }) {
                        let cardCount = deck.cards.count
                        deckStore.decks.remove(at: index)
                        Analytics.deckDeleted(
                            name: deck.name,
                            cardCount: cardCount,
                            totalDecksAfter: deckStore.decks.count
                        )
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
        .tint(SGTheme.mint)
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
            // Header — same pattern as DeckListView: eyebrow + big rounded
            // title with 44pt mint circle actions. The system nav bar keeps
            // its back button but the title is hidden (the header owns it).
            SGScreenHeader(eyebrow: "Deck", title: deck.name) {
                HStack(spacing: 10) {
                    Button(action: { showEditDeckSheet = true }) {
                        Image(systemName: "pencil")
                            .font(SGTheme.cardTitle) // 17 semibold — header icon size
                            .foregroundColor(SGTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(SGTheme.mint, in: Circle())
                    }
                    .buttonStyle(SGPressStyle())
                    .accessibilityLabel("Edit deck name")

                    Button(action: { showingNewCardSheet = true }) {
                        Image(systemName: "plus")
                            .font(SGTheme.cardTitle)
                            .foregroundColor(SGTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(SGTheme.mint, in: Circle())
                    }
                    .buttonStyle(SGPressStyle())
                    .accessibilityLabel("Add new flashcard")
                }
            }

            if deck.cards.isEmpty {
                // Empty State for No Flashcards
                VStack(spacing: 24) {
                    Spacer()

                    MascotView(pose: .clipboard)
                        .frame(width: 140, height: 140)

                    VStack(spacing: 10) {
                        Text("No flashcards yet")
                            .font(SGTheme.display(24))
                            .foregroundColor(SGTheme.paper)

                        Text("Add your first flashcard to start learning. You can create them manually or use AI to generate them automatically.")
                            .font(SGTheme.body)
                            .foregroundColor(SGTheme.paperSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)

                    // Action Buttons
                    VStack(spacing: 12) {
                        // Manual Add Button
                        SGButton(title: "Add Flashcard", icon: "plus.circle.fill") {
                            showingNewCardSheet = true
                        }

                        // AI Generate Button
                        AIGenerateButton(title: "AI Generate") {
                            showAutoGenerateSheet = true
                        }
                    }
                    .padding(.horizontal, SGTheme.screenPadding)

                    Spacer()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Same dock clearance as the Decks-tab empty state.
                .padding(.bottom, SGTheme.tabBarClearance)
            } else {
                List {
                    ForEach($deck.cards) { $card in
                        Button {
                            selectedCard = $card
                            showEditSheet = true
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(card.regretPrompt)
                                    .font(SGTheme.cardTitle)
                                    .foregroundColor(SGTheme.paper)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                                Text(card.regret)
                                    .font(SGTheme.caption)
                                    .foregroundColor(SGTheme.paperSecondary)
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(SGTheme.cardPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                    .fill(SGTheme.inkRaised)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: SGTheme.screenPadding, bottom: 6, trailing: SGTheme.screenPadding))
                    }
                    .onDelete(perform: deleteCards)
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .tint(SGTheme.mint)

                // Practice & Auto Generate Buttons
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(SGTheme.hairline)
                        .frame(height: 1)

                    VStack(spacing: 12) {
                        // Add Practice Button
                        SGButton(title: "Practice Deck", assetIcon: "sticker-graduation-cap", enabled: !deck.cards.isEmpty) {
                            deckStore.selectDeck(deck) // Ensure this deck is selected
                            showingPractice = true
                        }
                        .fullScreenCover(isPresented: $showingPractice) {
                            PracticeView(deck: deck)
                                .environmentObject(deckStore)
                        }

                        // Existing Auto Generate Button
                        AIGenerateButton(title: "Auto Generate Flashcards") {
                            showAutoGenerateSheet = true
                        }
                    }
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.top, 16)
                    // Clearance instead of symmetric padding: the floating
                    // dock hovers over the bottom of the screen, so the
                    // buttons lift above it while the raised slab runs on
                    // underneath.
                    .padding(.bottom, SGTheme.tabBarClearance)
                }
                .background(SGTheme.inkRaised.ignoresSafeArea(edges: .bottom))
            }
        }
        .background(SGTheme.ink.ignoresSafeArea())
        // The system bar keeps only the back button; the deck name lives in
        // the SGScreenHeader above (same chrome as the Decks tab).
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAutoGenerateSheet) {
            AutoGenerateFlashcardsSheet(deck: $deck)
                .sgSheetChrome()
        }
        .sheet(isPresented: $showingNewCardSheet) {
            NewFlashcardSheet(deck: $deck)
                .sgSheetChrome()
        }
        .sheet(isPresented: $showEditSheet, onDismiss: { selectedCard = nil }) {
            if let selectedCard = selectedCard,
               let cardIndex = deck.cards.firstIndex(where: { $0.id == selectedCard.wrappedValue.id }) {
                RegretEditorSheet(regret: $deck.cards[cardIndex])
                    .sgSheetChrome()
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
        let count = offsets.count
        deck.cards.remove(atOffsets: offsets)
        Analytics.flashcardDeleted(
            deckId: deck.id.uuidString,
            deckName: deck.name,
            count: count
        )
    }
}

/// The mint-outline secondary capsule shared by both AI-generate entry
/// points (the empty state and the bottom bar). One fill, one stroke, one
/// label size — the two hand-rolled copies converged here.
private struct AIGenerateButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image("sticker-sparkling")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(title)
            }
            .font(SGTheme.buttonSmall)
            .foregroundColor(SGTheme.mint)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(SGTheme.mint.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(SGTheme.mint.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SGPressStyle())
    }
}

struct CardDetailView: View {
    let card: Regret

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Question")
                    .font(SGTheme.display(20))
                    .foregroundColor(SGTheme.paper)
                Text(card.regretPrompt)
                    .foregroundColor(SGTheme.paperSecondary)

                Text("Answer")
                    .font(SGTheme.display(20))
                    .foregroundColor(SGTheme.paper)
                Text(card.regret)
                    .foregroundColor(SGTheme.paperSecondary)

                Text("Explanation")
                    .font(SGTheme.display(20))
                    .foregroundColor(SGTheme.paper)
                Text(card.backgroundExplanation)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .padding()
        }
        .background(SGTheme.ink.ignoresSafeArea())
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
        // Standard sheet anatomy: fitted detent, round-close header, one
        // input well, mint primary pinned at the bottom — no nav-bar chrome.
        SGFittedSheet(estimatedHeight: 320) {
            VStack(alignment: .leading, spacing: 20) {
                SGSheetHeader(title: "New Deck", onClose: { dismiss() })

                VStack(alignment: .leading, spacing: 10) {
                    SGMicroLabel(text: "Deck information")

                    SGField(placeholder: "Deck Name", text: $deckName)
                        .accessibilityLabel("Deck name entry field")

                    if isDuplicateName && !deckName.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(SGTheme.caption) // matches the warning text beside it
                            Text("A deck with this name already exists")
                                .font(SGTheme.caption)
                        }
                        .foregroundColor(SGTheme.ember)
                    }
                }

                SGButton(title: "Create", enabled: isValidName) {
                    let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
                    if isDuplicateName {
                        showDuplicateAlert = true
                    } else {
                        let newDeck = Deck(
                            name: trimmedName,
                            cards: []
                        )
                        deckStore.addDeck(newDeck)
                        Analytics.deckCreated(
                            name: trimmedName,
                            totalDecksAfter: deckStore.decks.count
                        )
                        dismiss()
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
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
        // Same anatomy as NewDeckView: fitted detent, round-close header,
        // one input well, mint primary at the bottom.
        SGFittedSheet(estimatedHeight: 320) {
            VStack(alignment: .leading, spacing: 20) {
                SGSheetHeader(title: "Edit Deck", onClose: { dismiss() })

                VStack(alignment: .leading, spacing: 10) {
                    SGMicroLabel(text: "Deck information")

                    SGField(placeholder: "Deck Name", text: $deckName)
                        .accessibilityLabel("Deck name entry field")

                    if isDuplicateName && !deckName.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(SGTheme.caption) // matches the warning text beside it
                            Text("A deck with this name already exists")
                                .font(SGTheme.caption)
                        }
                        .foregroundColor(SGTheme.ember)
                    }
                }

                SGButton(title: "Save", enabled: isValidName) {
                    let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
                    if isDuplicateName {
                        showDuplicateAlert = true
                    } else {
                        var updatedDeck = deck
                        updatedDeck.name = trimmedName
                        if trimmedName != deck.name {
                            Analytics.deckRenamed(
                                oldName: deck.name,
                                newName: trimmedName
                            )
                        }
                        onSave(updatedDeck)
                        dismiss()
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
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
