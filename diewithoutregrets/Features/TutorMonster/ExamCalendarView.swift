//
//  ExamCalendarView.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 2): the dedicated exam surface. A prominent next-exam
//  countdown, the list of exams with readiness + a cram badge, and add/edit.
//  The nearest exam feeds the monster's pressure + topic weighting via ExamStore.
//  Styling is light/functional; adopt the Meadow design system in a design pass.
//  See Docs/TutorMonsterPlan.md §6d, Appendix D.
//

import SwiftUI

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

    /// Fraction mastered across the cards tagged with this exam's topics, nil
    /// when no topics are linked or no cards match yet.
    private func readiness(_ exam: StudyExam) -> Double? {
        let topics = Set(exam.topics)
        guard !topics.isEmpty else { return nil }
        let cards = deckStore.decks.flatMap(\.cards).filter { ($0.topic.map(topics.contains)) ?? false }
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
        guard let deckID = enrichment.targetDeckID(forTopic: topic) else {
            topUpResult = "Create a deck first, then top up."
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
    private let existing: StudyExam?
    private let accent: Color
    private let onSave: (StudyExam) -> Void
    private let onDelete: ((StudyExam) -> Void)?

    init(exam: StudyExam? = nil,
         accent: Color,
         onSave: @escaping (StudyExam) -> Void,
         onDelete: ((StudyExam) -> Void)? = nil) {
        self.existing = exam
        self.accent = accent
        self.onSave = onSave
        self.onDelete = onDelete
        _subject = State(initialValue: exam?.subject ?? "")
        _date = State(initialValue: exam?.date ?? Date().addingTimeInterval(7 * 86_400))
        _topicsText = State(initialValue: exam?.topics.joined(separator: ", ") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exam") {
                    TextField("Subject (e.g. Anatomy)", text: $subject)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section {
                    TextField("Comma-separated (e.g. skeletal, cardiac)", text: $topicsText)
                } header: {
                    Text("Topics")
                } footer: {
                    Text("The monster weights these topics as this exam nears.")
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let topics = topicsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        onSave(StudyExam(id: existing?.id ?? UUID(),
                         subject: subject.trimmingCharacters(in: .whitespaces),
                         date: date,
                         topics: topics,
                         createdAt: existing?.createdAt ?? Date()))
        dismiss()
    }
}
