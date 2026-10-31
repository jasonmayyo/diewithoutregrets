import SwiftUI

/// The same subject control is used by deck and exam forms.
struct StudySubjectField: View {
    @Binding var selection: UUID?
    @ObservedObject private var subjects = StudySubjectStore.shared
    @State private var showingPicker = false

    var body: some View {
        Button { showingPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "tag").foregroundStyle(SGTheme.mintDeep)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Subject").font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                    Text(subjects.name(for: selection) ?? "Choose a subject")
                        .font(SGTheme.rowLabel).foregroundStyle(SGTheme.paper)
                }
                Spacer()
                Image(systemName: "chevron.right").font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
            }
            .frame(minHeight: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose subject")
        .accessibilityValue(subjects.name(for: selection) ?? "No subject")
        .sheet(isPresented: $showingPicker) { StudySubjectPickerSheet(selection: $selection) }
    }
}

struct StudySubjectPickerSheet: View {
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subjects = StudySubjectStore.shared
    @State private var newName = ""
    @State private var renaming: StudySubject?
    @State private var renameText = ""
    @State private var showingRename = false
    @State private var removing: StudySubject?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { selection = nil; dismiss() } label: {
                        choiceRow("No subject", selected: selection == nil)
                    }
                    ForEach(subjects.sorted) { subject in
                        Button { selection = subject.id; dismiss() } label: {
                            choiceRow(subject.name, selected: selection == subject.id)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { removing = subject } label: { Label("Remove", systemImage: "trash") }
                            Button {
                                renaming = subject; renameText = subject.name; showingRename = true
                            } label: { Label("Rename", systemImage: "pencil") }
                            .tint(SGTheme.teal)
                        }
                    }
                } footer: { Text("Subjects group your decks. Swipe a subject to rename or remove it.") }
                Section("New subject") {
                    TextField("e.g. Biology", text: $newName)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("New subject name")
                    Button("Add subject") {
                        if let subject = subjects.add(name: newName) { selection = subject.id; dismiss() }
                    }
                    .disabled(StudySubject.cleanName(newName).isEmpty)
                }
            }
            .navigationTitle("Subjects")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .tint(SGTheme.mintDeep)
            .alert("Rename subject", isPresented: $showingRename) {
                TextField("Subject name", text: $renameText)
                Button("Save") { if let renaming { _ = subjects.rename(renaming, to: renameText) } }
                    .disabled(!validRename)
                Button("Cancel", role: .cancel) {}
            } message: { Text("Choose a unique name. Linked decks and exams will stay linked.") }
            .confirmationDialog("Remove subject?", isPresented: Binding(
                get: { removing != nil }, set: { if !$0 { removing = nil } })) {
                Button("Remove subject", role: .destructive) {
                    guard let removing else { return }
                    subjects.remove(removing, decks: .shared, exams: .shared)
                    if selection == removing.id { selection = nil }
                    self.removing = nil
                }
            } message: { Text("Your decks, exams, and flashcards will remain. Only the subject grouping is removed.") }
        }
    }

    private var validRename: Bool {
        !StudySubject.cleanName(renameText).isEmpty && !subjects.subjects.contains {
            $0.id != renaming?.id && StudySubject.nameKey($0.name) == StudySubject.nameKey(renameText)
        }
    }

    private func choiceRow(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(SGTheme.paper)
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(SGTheme.mintDeep) }
        }
        .frame(minHeight: 36).contentShape(Rectangle())
    }
}

struct StudyExamLinksField: View {
    @Binding var selection: Set<UUID>
    let subjectID: UUID?
    @ObservedObject private var exams = ExamStore.shared
    @State private var showingPicker = false

    var body: some View {
        Button { showingPicker = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar").foregroundStyle(SGTheme.mintDeep)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Linked exams").font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                    Text(names.isEmpty ? "Choose exams" : names.joined(separator: ", "))
                        .font(SGTheme.rowLabel).foregroundStyle(SGTheme.paper).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
            }
            .frame(minHeight: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose linked exams")
        .accessibilityValue(names.isEmpty ? "None" : names.joined(separator: ", "))
        .sheet(isPresented: $showingPicker) { StudyExamLinksPicker(selection: $selection, subjectID: subjectID) }
    }

    private var names: [String] { exams.exams.filter { selection.contains($0.id) }.map(\.subject) }
}

struct StudyExamLinksPicker: View {
    @Binding var selection: Set<UUID>
    let subjectID: UUID?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var exams = ExamStore.shared
    @ObservedObject private var subjects = StudySubjectStore.shared
    @State private var addingExam = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(exams.exams.sorted { lhs, rhs in
                        let l = subjectID != nil && lhs.subjectID == subjectID
                        let r = subjectID != nil && rhs.subjectID == subjectID
                        return l != r ? l : lhs.date < rhs.date
                    }) { exam in
                        Button { toggle(exam.id) } label: {
                            HStack(spacing: 12) {
                                StudyLinkCheckmark(selected: selection.contains(exam.id))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exam.subject).font(SGTheme.rowLabel).foregroundStyle(SGTheme.paper)
                                    Text([subjects.name(for: exam.subjectID), exam.date.formatted(date: .abbreviated, time: .omitted)]
                                        .compactMap { $0 }.joined(separator: " · "))
                                        .font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                                }
                                Spacer()
                            }
                            .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection.contains(exam.id) ? .isSelected : [])
                    }
                    if exams.exams.isEmpty { Text("No exams yet. Add one below to link this deck.").foregroundStyle(.secondary) }
                } footer: { Text("Select every exam this deck covers. You can reuse a deck across exams.") }
                Button { addingExam = true } label: { Label("Add exam", systemImage: "plus") }
            }
            .navigationTitle("Link exams")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(SGTheme.mintDeep)
            .sheet(isPresented: $addingExam) {
                ExamEditSheet(initialSubjectID: subjectID, accent: SGTheme.mintDeep) { exam in
                    exams.add(exam); selection.insert(exam.id)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        SGV5Haptics.play(.selection)
    }
}

struct StudyExamDeckPicker: View {
    @Binding var selection: Set<UUID>
    let subjectID: UUID?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var decks = DeckStore.shared
    @ObservedObject private var subjects = StudySubjectStore.shared
    @State private var addingDeck = false

    private var subjectDecks: [Deck] { decks.decks.filter { subjectID != nil && $0.subjectID == subjectID } }

    var body: some View {
        NavigationStack {
            List {
                if !subjectDecks.isEmpty {
                    Section(subjects.name(for: subjectID) ?? "This subject") {
                        Button("Select all decks in this subject") { selection.formUnion(subjectDecks.map(\.id)) }
                        ForEach(subjectDecks) { row($0) }
                    }
                }
                Section(subjectDecks.isEmpty ? "Your decks" : "Other decks") {
                    ForEach(decks.decks.filter { subjectID == nil || $0.subjectID != subjectID }) { row($0) }
                    if decks.decks.isEmpty { Text("Create a deck to add flashcards for this exam.").foregroundStyle(.secondary) }
                }
                Section {
                    Button { addingDeck = true } label: { Label("Create new deck", systemImage: "plus") }
                } footer: { Text("Only selected decks are linked. You can add more later, including decks from another subject.") }
            }
            .navigationTitle("Exam flashcards")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(SGTheme.mintDeep)
            .sheet(isPresented: $addingDeck) {
                NewDeckView(initialSubjectID: subjectID) { selection.insert($0.id) }
                    .environmentObject(decks)
            }
        }
    }

    private func row(_ deck: Deck) -> some View {
        Button {
            if selection.contains(deck.id) { selection.remove(deck.id) } else { selection.insert(deck.id) }
            SGV5Haptics.play(.selection)
        } label: {
            HStack(spacing: 12) {
                StudyLinkCheckmark(selected: selection.contains(deck.id))
                VStack(alignment: .leading, spacing: 3) {
                    Text(deck.name).font(SGTheme.rowLabel).foregroundStyle(SGTheme.paper)
                    Text([subjects.name(for: deck.subjectID), "\(deck.cards.count) flashcards"].compactMap { $0 }.joined(separator: " · "))
                        .font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                }
                Spacer()
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection.contains(deck.id) ? .isSelected : [])
    }
}

private struct StudyLinkCheckmark: View {
    let selected: Bool
    var body: some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22)).foregroundStyle(selected ? SGTheme.mintDeep : SGTheme.paperSecondary)
            .accessibilityHidden(true)
    }
}

struct StudyDeckFilterMenu: View {
    @Binding var selection: StudyLibraryFilter
    @ObservedObject private var subjects = StudySubjectStore.shared
    @ObservedObject private var exams = ExamStore.shared

    var body: some View {
        Menu {
            Button("All decks") { selection = .all }
            Button("No subject") { selection = .unassigned }
            Section("Subjects") {
                ForEach(subjects.sorted) { subject in Button(subject.name) { selection = .subject(subject.id) } }
            }
            Section("Exams") {
                ForEach(exams.exams.sorted { $0.date < $1.date }) { exam in
                    Button("\(exam.subject) · \(exam.date.formatted(date: .abbreviated, time: .omitted))") { selection = .exam(exam.id) }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .font(SGTheme.rowLabel).foregroundStyle(SGTheme.mintDeep)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(SGTheme.mintTint, in: Capsule())
        }
        .accessibilityLabel("Filter decks")
        .accessibilityValue(title)
        .onChange(of: subjects.subjects.map(\.id)) { _, ids in
            if case .subject(let id) = selection, !ids.contains(id) { selection = .all }
        }
        .onChange(of: exams.exams.map(\.id)) { _, ids in
            if case .exam(let id) = selection, !ids.contains(id) { selection = .all }
        }
    }

    private var title: String {
        switch selection {
        case .all: return "All decks"
        case .unassigned: return "No subject"
        case .subject(let id): return "Subject: \(subjects.name(for: id) ?? "Unknown")"
        case .exam(let id): return "Exam: \(exams.exams.first { $0.id == id }?.subject ?? "Unknown")"
        }
    }
}
