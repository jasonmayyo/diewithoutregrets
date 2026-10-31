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
    @State private var deckToDelete: Deck?
    @State private var deckToEdit: Deck?
    @State private var showDeleteAlert = false
    @State private var showingAllExams = false
    @State private var filter: StudyLibraryFilter = .all
    @State private var editingFilteredExam: StudyExam?
    @ObservedObject private var exams = ExamStore.shared
    @ObservedObject private var subjects = StudySubjectStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SGScreenHeader(title: "Study")

                ScrollViewReader { proxy in
                  List {
                    StudyExamCalendarSection(onShowAllExams: { showingAllExams = true }, onShowDecks: { exam in
                        filter = .exam(exam.id)
                        withAnimation { proxy.scrollTo("study-decks", anchor: .top) }
                    })
                        .listRowInsets(EdgeInsets(top: 0, leading: SGTheme.screenPadding,
                                                  bottom: 16, trailing: SGTheme.screenPadding))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    decksHeading
                        .id("study-decks")
                        .listRowInsets(EdgeInsets(top: 8, leading: SGTheme.screenPadding,
                                                  bottom: 6, trailing: SGTheme.screenPadding))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if deckStore.decks.isEmpty {
                        emptyDecks
                            .listRowInsets(EdgeInsets(top: 6, leading: SGTheme.screenPadding,
                                                      bottom: 6, trailing: SGTheme.screenPadding))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else if filteredDecks.isEmpty {
                        filteredEmptyState
                            .listRowInsets(EdgeInsets(top: 10, leading: SGTheme.screenPadding, bottom: 10, trailing: SGTheme.screenPadding))
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    } else {
                        ForEach($deckStore.decks) { $deck in
                          if filter.includes(deck, exams: exams.exams) {
                            deckRow($deck)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: SGTheme.screenPadding,
                                                          bottom: 6, trailing: SGTheme.screenPadding))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deckToDelete = deck
                                        showDeleteAlert = true
                                    } label: { Label("Delete", systemImage: "trash") }
                                    .tint(SGTheme.ember)
                                    Button { deckToEdit = deck } label: { Label("Edit", systemImage: "pencil") }
                                        .tint(SGTheme.teal)
                                }
                          }
                        }
                    }
                    Color.clear.frame(height: SGTheme.tabBarClearance)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(SGTheme.ink)
                }
            }
            .background(SGTheme.ink.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingAllExams) { ExamCalendarView() }
            .sheet(isPresented: $showingNewDeckSheet) {
                NewDeckView(initialSubjectID: filterSubjectID, initialExamIDs: filterExam.map { [$0.id] } ?? [])
            }
            .sheet(item: $editingFilteredExam) { exam in
                ExamEditSheet(exam: exam, accent: SGTheme.mintDeep, onSave: { exams.update($0) }, onDelete: { exams.remove($0) })
            }
            .sheet(item: $deckToEdit) { deck in
                EditDeckView(deck: deck) { updated in deckStore.updateDeck(updated) }
            }
            .alert("Delete deck?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete,
                       let index = deckStore.decks.firstIndex(where: { $0.id == deck.id }) {
                        deckStore.decks.remove(at: index)
                        Analytics.deckDeleted(name: deck.name, cardCount: deck.cards.count,
                                              totalDecksAfter: deckStore.decks.count)
                    }
                    deckToDelete = nil
                }
                Button("Cancel", role: .cancel) { deckToDelete = nil }
            } message: {
                Text("Delete \"\(deckToDelete?.name ?? "this deck")\" and its flashcards?")
            }
        }
        .tint(SGTheme.mintDeep)
    }

    private var decksHeading: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Your decks").font(SGTheme.display(22)).foregroundStyle(SGTheme.paper)
                Text("\(filteredDecks.reduce(0) { $0 + $1.cards.count }) flashcards")
                    .font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
            }
            Spacer()
            Button { showingNewDeckSheet = true } label: {
                Label("New deck", systemImage: "plus")
                    .font(SGTheme.buttonSmall)
                    .foregroundStyle(SGTheme.mintDeep)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(SGTheme.mintTint, in: Capsule())
            }
            .buttonStyle(SGPressStyle())
            .accessibilityLabel("Create new deck")
        }
        HStack {
            StudyDeckFilterMenu(selection: $filter)
            Spacer()
            if let exam = filterExam {
                Button("Edit links") { editingFilteredExam = exam }
                    .font(SGTheme.rowLabel).foregroundStyle(SGTheme.mintDeep)
                    .frame(minHeight: 44).buttonStyle(.plain)
            }
        }
      }
    }

    private var filteredDecks: [Deck] { deckStore.decks.filter { filter.includes($0, exams: exams.exams) } }
    private var filterExam: StudyExam? {
        guard case .exam(let id) = filter else { return nil }
        return exams.exams.first { $0.id == id }
    }
    private var filterSubjectID: UUID? {
        if case .subject(let id) = filter { return id }
        return filterExam?.subjectID
    }
    private var filteredEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(filterExam == nil ? "No decks in this subject yet." : "No decks linked to this exam yet.")
                .font(SGTheme.body).foregroundStyle(SGTheme.paperSecondary)
            if let exam = filterExam {
                Button("Link existing decks") { editingFilteredExam = exam }.buttonStyle(.plain)
            }
            Button("Show all decks") { filter = .all }.buttonStyle(.plain)
        }
        .foregroundStyle(SGTheme.mintDeep)
    }

    private var emptyDecks: some View {
        SGCard(shadowed: false) {
            VStack(spacing: 14) {
                Image("sticker-books").resizable().scaledToFit().frame(width: 56, height: 56)
                Text("Create your first deck").font(SGTheme.cardTitle).foregroundStyle(SGTheme.paper)
                Text("Keep your notes and flashcards together, ready for your next study session.")
                    .font(SGTheme.body).foregroundStyle(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                SGButton(title: "Create deck", icon: "plus") { showingNewDeckSheet = true }
            }
            .padding(.vertical, 8)
        }
    }

    private func deckRow(_ deck: Binding<Deck>) -> some View {
        ZStack {
            NavigationLink(destination: DeckView(deck: deck)) { EmptyView() }.opacity(0)
            HStack(spacing: 14) {
                Image("sticker-books").resizable().scaledToFit().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.wrappedValue.name).font(SGTheme.cardTitle).foregroundStyle(SGTheme.paper)
                    Text("\(deck.wrappedValue.cards.count) flashcards")
                        .font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                    if let subjectName = subjects.name(for: deck.wrappedValue.subjectID) {
                        Text(subjectName).font(SGTheme.caption.weight(.semibold)).foregroundStyle(SGTheme.mintDeep)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(SGTheme.rowLabel).foregroundStyle(SGTheme.mintDeep)
            }
            .padding(SGTheme.cardPadding)
            .background(RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .strokeBorder(SGTheme.hairline, lineWidth: 1)))
        }
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
    @ObservedObject private var enrichment = DeckEnrichment.shared
    @State private var enrichmentNote: String?
    @ObservedObject private var subjects = StudySubjectStore.shared
    @ObservedObject private var exams = ExamStore.shared

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
                    .accessibilityLabel("Edit deck details")

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

            Button { showEditDeckSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                    Text(subjects.name(for: deck.subjectID) ?? "Link a subject")
                    Spacer()
                    let count = StudyMaterialLinks.exams(for: deck.id, in: exams.exams).count
                    Text(count == 0 ? "Link exams" : "\(count) linked \(count == 1 ? "exam" : "exams")")
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(SGTheme.caption.weight(.semibold)).foregroundStyle(SGTheme.mintDeep)
                .padding(.horizontal, SGTheme.screenPadding).frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit subject and exam links")

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
                                Text(card.quizPrompt.text)
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

                        // Phase 3: upgrade typed cards to tap-tiles (prompted, offline-safe).
                        if deck.cards.contains(where: { $0.answerMode == .typed }) {
                            AIGenerateButton(title: enrichment.phase == .backfilling ? "Adding answer options…" : "Add answer options") {
                                Task { await runBackfill() }
                            }
                            .disabled(enrichment.isWorking)
                        }
                        if let enrichmentNote {
                            Text(enrichmentNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
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
        .toolbar(.visible, for: .navigationBar)
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
    }

    private func runBackfill() async {
        let upgraded = await enrichment.backfillDistractors(in: deck.id)
        if upgraded > 0 {
            if let updated = deckStore.decks.first(where: { $0.id == deck.id }) { deck = updated }
            enrichmentNote = "Added answer options to \(upgraded) card\(upgraded == 1 ? "" : "s")."
        } else {
            enrichmentNote = enrichment.lastError ?? "No typed cards needed answer options."
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
                Text(card.quizPrompt.text)
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
    @State private var subjectID: UUID?
    @State private var examIDs: Set<UUID>
    var onCreate: ((Deck) -> Void)?

    init(initialSubjectID: UUID? = nil, initialExamIDs: Set<UUID> = [], onCreate: ((Deck) -> Void)? = nil) {
        _subjectID = State(initialValue: initialSubjectID)
        _examIDs = State(initialValue: initialExamIDs)
        self.onCreate = onCreate
    }

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
        SGFittedSheet(estimatedHeight: 480) {
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

                StudySubjectField(selection: $subjectID)
                StudyExamLinksField(selection: $examIDs, subjectID: subjectID)

                SGButton(title: "Create", enabled: isValidName) {
                    let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
                    if isDuplicateName {
                        showDuplicateAlert = true
                    } else {
                        let newDeck = Deck(
                            name: trimmedName,
                            cards: [], subjectID: subjectID
                        )
                        deckStore.addDeck(newDeck)
                        ExamStore.shared.link(examIDs, to: newDeck.id)
                        onCreate?(newDeck)
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
    @State private var subjectID: UUID?
    @State private var examIDs: Set<UUID>

    init(deck: Deck, onSave: @escaping (Deck) -> Void) {
        self.deck = deck
        self.onSave = onSave
        self._deckName = State(initialValue: deck.name)
        _subjectID = State(initialValue: deck.subjectID)
        _examIDs = State(initialValue: Set(StudyMaterialLinks.exams(for: deck.id, in: ExamStore.shared.exams).map(\.id)))
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
        SGFittedSheet(estimatedHeight: 480) {
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

                StudySubjectField(selection: $subjectID)
                StudyExamLinksField(selection: $examIDs, subjectID: subjectID)

                SGButton(title: "Save", enabled: isValidName) {
                    let trimmedName = deckName.trimmingCharacters(in: .whitespaces)
                    if isDuplicateName {
                        showDuplicateAlert = true
                    } else {
                        // Metadata edits must not replace cards added while this sheet was open.
                        var updatedDeck = deckStore.decks.first { $0.id == deck.id } ?? deck
                        updatedDeck.name = trimmedName
                        updatedDeck.subjectID = subjectID
                        if trimmedName != deck.name {
                            Analytics.deckRenamed(
                                oldName: deck.name,
                                newName: trimmedName
                            )
                        }
                        onSave(updatedDeck)
                        ExamStore.shared.link(examIDs, to: deck.id)
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
