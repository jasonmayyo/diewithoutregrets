//
//  ExamCalendarView.swift
//  diewithoutregrets
//
//  The Study tab's calendar and its full exam-management destination.
//  Both use the same ExamStore that provides the monster's study context.
//

import SwiftUI

struct StudyExamCalendarSection: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var store = ExamStore.shared
    @ObservedObject private var decks = DeckStore.shared
    @State private var displayedMonth = Date()
    @State private var selectedDay: Date?
    @State private var showingAdd = false
    @State private var editing: StudyExam?
    let onShowAllExams: () -> Void
    var onShowDecks: (StudyExam) -> Void = { _ in }

    private var month: StudyCalendarMonth {
        StudyCalendarMonth(containing: displayedMonth, calendar: calendar)
    }

    private var visibleExams: [StudyExam] {
        if let selectedDay {
            return exams(on: selectedDay)
        }
        return store.nextExam.map { [$0] } ?? []
    }

    var body: some View {
        VStack(spacing: 8) {
            monthHeader
            calendarGrid
            Divider().overlay(SGTheme.hairline)
            examSummary
        }
        .padding(14)
        .background(SGTheme.inkRaised, in: RoundedRectangle(cornerRadius: SGTheme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: SGTheme.cardRadius).strokeBorder(SGTheme.hairline))
        .sheet(isPresented: $showingAdd) {
            ExamEditSheet(initialDate: selectedDay, accent: SGTheme.mintDeep) { store.add($0) }
        }
        .sheet(item: $editing) { exam in
            ExamEditSheet(exam: exam, accent: SGTheme.mintDeep,
                          onSave: { store.update($0) }, onDelete: { store.remove($0) })
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(SGTheme.cardTitle).foregroundStyle(SGTheme.paper)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button {
                updateCalendar {
                    displayedMonth = Date()
                    selectedDay = calendar.startOfDay(for: Date())
                }
            } label: {
                Text("Today").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SGTheme.mintDeep)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Show today")
            monthButton("chevron.left", label: "Previous month", offset: -1)
            monthButton("chevron.right", label: "Next month", offset: 1)
        }
        .buttonStyle(.plain)
    }

    private func monthButton(_ icon: String, label: String, offset: Int) -> some View {
        Button {
            guard let next = calendar.date(byAdding: .month, value: offset, to: month.start) else { return }
            updateCalendar { displayedMonth = next; selectedDay = nil }
        } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SGTheme.paper)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(month.weekdaySymbols[index])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SGTheme.paperSecondary)
                    .frame(height: 24)
                    .accessibilityHidden(true)
            }
            ForEach(Array(month.days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayButton(day)
                } else {
                    Color.clear.frame(height: 44).accessibilityHidden(true)
                }
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = selectedDay.map { calendar.isDate(day, inSameDayAs: $0) } ?? false
        let isToday = calendar.isDateInToday(day)
        let dayExams = exams(on: day)
        return Button {
            updateCalendar { selectedDay = isSelected ? nil : day }
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium, design: .rounded))
                Circle()
                    .fill(isSelected ? SGTheme.ink : SGTheme.mintDeep)
                    .frame(width: 4, height: 4)
                    .opacity(dayExams.isEmpty ? 0 : 1)
            }
            .foregroundStyle(isSelected ? SGTheme.ink : SGTheme.paper)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background {
                Circle().fill(isSelected ? SGTheme.mintDeep : isToday ? SGTheme.mintTint : .clear)
                    .frame(width: 38, height: 38)
            }
            .overlay {
                if isToday && !isSelected {
                    Circle().strokeBorder(SGTheme.mint.opacity(0.6), lineWidth: 1).frame(width: 38, height: 38)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(dayExams.isEmpty ? "No exams" : dayExams.map(\.subject).joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var examSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(selectedDay.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "Up next")
                    .font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                Spacer()
                Button("All exams", action: onShowAllExams)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SGTheme.mintDeep)
                    .frame(minHeight: 44)
                    .padding(.trailing, 8)
                    .buttonStyle(.plain)
                Button { showingAdd = true } label: {
                    Label("Add exam", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(SGTheme.mintDeep)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            if visibleExams.isEmpty {
                Text(selectedDay == nil ? "Add an exam to plan your study." : "No exams on this day.")
                    .font(SGTheme.body).foregroundStyle(SGTheme.paperSecondary)
                    .padding(.bottom, 8)
            } else {
                ForEach(visibleExams) { exam in
                    Button { editing = exam } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(exam.subject).font(SGTheme.cardTitle)
                                Text(exam.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(SGTheme.caption).foregroundStyle(SGTheme.paperSecondary)
                            }
                            Spacer(minLength: 8)
                            Text(countdown(exam)).font(SGTheme.buttonSmall)
                                .foregroundStyle(SGTheme.mintDeep)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(SGTheme.mintTint, in: Capsule())
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SGTheme.paperSecondary)
                        }
                        .foregroundStyle(SGTheme.paper)
                        .frame(minHeight: 44).padding(.bottom, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit exam")
                    Button {
                        if StudyMaterialLinks.decks(for: exam, in: decks.decks).isEmpty { editing = exam }
                        else { onShowDecks(exam) }
                    } label: {
                        let linked = StudyMaterialLinks.decks(for: exam, in: decks.decks)
                        Label(linked.isEmpty ? "Link flashcard decks" : "View \(linked.count) linked \(linked.count == 1 ? "deck" : "decks")",
                              systemImage: "rectangle.on.rectangle")
                            .font(SGTheme.caption.weight(.semibold)).foregroundStyle(SGTheme.mintDeep)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exams(on day: Date) -> [StudyExam] {
        store.exams.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    private func countdown(_ exam: StudyExam) -> String {
        switch exam.daysUntil(calendar: calendar) {
        case ..<0: return "Past"
        case 0: return "Today"
        case 1: return "Tomorrow"
        case let days: return "In \(days) days"
        }
    }

    private func updateCalendar(_ change: () -> Void) {
        SGV5Haptics.play(.selection)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18), change)
    }
}

struct ExamCalendarView: View {
    @ObservedObject private var store = ExamStore.shared
    @ObservedObject private var deckStore = DeckStore.shared
    @ObservedObject private var enrichment = DeckEnrichment.shared
    @State private var editing: StudyExam?
    @State private var showingAdd = false
    @State private var pendingTopic: String?
    @State private var topUpResult: String?

    /// Approximate Meadow mint; replace with SGTheme tokens in the design pass.
    private let accent = Color(red: 0.17, green: 0.76, blue: 0.57)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                countdownHero
                topUpSection
                if !store.exams.isEmpty { examList }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Exams")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            ExamEditSheet(accent: accent) { store.add($0) }
        }
        .sheet(item: $editing) { exam in
            ExamEditSheet(exam: exam, accent: accent,
                          onSave: { store.update($0) },
                          onDelete: { store.remove($0) })
        }
    }

    @ViewBuilder private var countdownHero: some View {
        if let next = store.nextExam {
            VStack(spacing: 6) {
                Text(next.subject).font(.headline).foregroundStyle(.secondary)
                Text("\(max(0, next.daysUntil()))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                Text(next.daysUntil() == 1 ? "day to go" : "days to go")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let r = readiness(next) {
                    ProgressView(value: r).tint(accent).frame(maxWidth: 200).padding(.top, 4)
                    Text("\(Int(r * 100))% ready").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28)
            .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus").font(.system(size: 34)).foregroundStyle(accent)
                Text("No exams yet").font(.headline)
                Text("Add your exams so the monster knows what to drill, and when.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button { showingAdd = true } label: {
                    Text("Add an exam").font(.subheadline.weight(.semibold))
                }.padding(.top, 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28).padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var examList: some View {
        VStack(spacing: 10) {
            ForEach(store.exams.sorted { $0.date < $1.date }) { exam in
                Button { editing = exam } label: { examRow(exam) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func examRow(_ exam: StudyExam) -> some View {
        let d = exam.daysUntil()
        let cram = d >= 0 && d <= 3
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exam.subject).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                Text(exam.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
                let linked = StudyMaterialLinks.decks(for: exam, in: deckStore.decks)
                Text(linked.isEmpty ? "No decks linked" : "\(linked.count) decks · \(linked.reduce(0) { $0 + $1.cards.count }) flashcards")
                    .font(.caption).foregroundStyle(accent)
                if !exam.topics.isEmpty {
                    Text(exam.topics.joined(separator: ", "))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(d < 0 ? "past" : "\(d)d")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(cram ? .orange : .primary)
                if cram { Text("CRAM").font(.caption2.bold()).foregroundStyle(.orange) }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Readiness covers the same linked material the user chose for the exam.
    private func readiness(_ exam: StudyExam) -> Double? {
        let cards = StudyMaterialLinks.decks(for: exam, in: deckStore.decks).flatMap(\.cards)
            .filter(\.isUsableForStudy)
        guard !cards.isEmpty else { return nil }
        return Double(cards.filter { !$0.isWeak }.count) / Double(cards.count)
    }

    // MARK: Phase 3 top-up (prompted, never silent)

    @ViewBuilder private var topUpSection: some View {
        let topics = DeckEnrichment.examTopUpTopics(exam: store.nextExam, decks: deckStore.decks)
        if let exam = store.nextExam, !topics.isEmpty, !deckStore.decks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Top up for \(exam.subject)").font(.system(size: 15, weight: .semibold))
                Text("These topics are thin or shaky. Pull a few fresh cards so the monster can drill them.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(topics.prefix(3)), id: \.self) { topic in
                    Button { Task { await runTopUp(topic) } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Top up \(topic)")
                            Spacer()
                            if enrichment.phase == .generating, pendingTopic == topic {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle")
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(12).frame(maxWidth: .infinity)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(enrichment.isWorking)
                }
                if let topUpResult {
                    Text(topUpResult).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func runTopUp(_ topic: String) async {
        guard let exam = store.nextExam, let deckID = enrichment.targetDeckID(forTopic: topic, exam: exam) else {
            topUpResult = "Link a deck to this exam first, then top up."
            return
        }
        pendingTopic = topic
        topUpResult = nil
        let added = await enrichment.topUp(topic: topic, into: deckID)
        pendingTopic = nil
        if added > 0 {
            let deckName = deckStore.decks.first(where: { $0.id == deckID })?.name ?? "your deck"
            topUpResult = "Added \(added) \(topic) card\(added == 1 ? "" : "s") to \(deckName)."
        } else {
            topUpResult = enrichment.lastError ?? "No new cards were added."
        }
    }
}

struct ExamEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject: String
    @State private var date: Date
    @State private var topicsText: String
    @State private var subjectID: UUID?
    @State private var deckIDs: Set<UUID>
    @State private var showingDeckPicker = false
    @ObservedObject private var decks = DeckStore.shared
    @ObservedObject private var subjects = StudySubjectStore.shared
    private let existing: StudyExam?
    private let accent: Color
    private let onSave: (StudyExam) -> Void
    private let onDelete: ((StudyExam) -> Void)?

    init(exam: StudyExam? = nil,
         initialDate: Date? = nil,
         initialSubjectID: UUID? = nil,
         accent: Color,
         onSave: @escaping (StudyExam) -> Void,
         onDelete: ((StudyExam) -> Void)? = nil) {
        self.existing = exam
        self.accent = accent
        self.onSave = onSave
        self.onDelete = onDelete
        _subject = State(initialValue: exam?.subject ?? "")
        _date = State(initialValue: exam?.date ?? initialDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        _topicsText = State(initialValue: exam?.topics.joined(separator: ", ") ?? "")
        _subjectID = State(initialValue: exam?.subjectID ?? initialSubjectID)
        _deckIDs = State(initialValue: Set(exam?.deckIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exam") {
                    TextField("Exam name (e.g. Biology final)", text: $subject)
                        .accessibilityLabel("Exam name")
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    StudySubjectField(selection: $subjectID)
                } footer: { Text("You can use the subject name, or give this exam its own name.") }
                Section {
                    Button { showingDeckPicker = true } label: {
                        HStack {
                            Label("Choose decks", systemImage: "rectangle.on.rectangle")
                            Spacer()
                            Text("\(linkedDecks.count)").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .frame(minHeight: 36)
                    }
                    ForEach(linkedDecks) { deck in
                        HStack {
                            Text(deck.name)
                            Spacer()
                            Text("\(deck.cards.count) cards").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: { Text("Flashcard decks") }
                footer: { Text("Link the decks this exam covers. The monster will use this exam's countdown only when you study a linked deck.") }
                Section {
                    TextField("Comma-separated (e.g. skeletal, cardiac)", text: $topicsText)
                } header: {
                    Text("Topics")
                } footer: {
                    Text("Optional. Prioritise these topics within the linked decks as this exam nears.")
                }
                if let existing, let onDelete {
                    Section {
                        Button(role: .destructive) { onDelete(existing); dismiss() } label: {
                            Text("Delete exam")
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Exam" : "Edit Exam")
            .tint(accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(examName.isEmpty)
                }
            }
            .sheet(isPresented: $showingDeckPicker) { StudyExamDeckPicker(selection: $deckIDs, subjectID: subjectID) }
        }
    }

    private var linkedDecks: [Deck] { decks.decks.filter { deckIDs.contains($0.id) } }
    private var examName: String {
        let name = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? (subjects.name(for: subjectID) ?? "") : name
    }

    private func save() {
        let topics = topicsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        onSave(StudyExam(id: existing?.id ?? UUID(),
                         subject: examName,
                         date: date,
                         topics: topics,
                         createdAt: existing?.createdAt ?? Date(), subjectID: subjectID,
                         deckIDs: linkedDecks.map(\.id)))
        dismiss()
    }
}
