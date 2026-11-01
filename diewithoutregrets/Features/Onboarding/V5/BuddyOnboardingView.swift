import SwiftUI
import FamilyControls
import UserNotifications

struct BuddyPersonalizationIntro: View {
    @ObservedObject var viewModel: SGV5FlowModel
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            HStack(spacing: -20) {
                MonsterArtwork(asset: MonsterPersona.willow.artworkAsset, size: 125)
                MonsterArtwork(asset: MonsterPersona.diva.artworkAsset, size: 150)
                MonsterArtwork(asset: MonsterPersona.gremlin.artworkAsset, size: 125)
            }
            Text("Let’s personalize\nStudy Guard for you.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center).foregroundStyle(SGTheme.paper)
            Text("Your study buddy that never rests.")
                .font(.title3).multilineTextAlignment(.center).foregroundStyle(SGTheme.paperSecondary)
            Spacer()
            SGV5QuizContinueButton(text: "Let’s personalize") { viewModel.nextPage() }
                .sgV5FloatingCTA()
        }
        .padding(.horizontal, 16)
    }
}

struct BuddyOnboardingChatView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @ObservedObject private var decks = DeckStore.shared
    @ObservedObject private var guardManager = StudyGuardManager.shared
    @ObservedObject private var personas = PersonaStore.shared
    @StateObject private var presenter = MonsterTranscriptPresenter(onMonsterMessage: { _ in MonsterChatHaptics.messageReceived() })
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var draft = ""
    @State private var busy = false
    @State private var showUpload = false
    @State private var inputSource: InputSource = .pdf
    @State private var showDeckPicker = false
    @State private var showDate = false
    @State private var examDate = Date()
    @State private var showApps = false
    @State private var appSelection = FamilyActivitySelection()
    @State private var previousSelection = FamilyActivitySelection()
    @State private var error: String?
    @State private var showRound = false
    @State private var session: MonsterSession?
    @State private var tutorTask: Task<Void, Never>?
    @State private var scrollTask: Task<Void, Never>?
    @State private var restoredMessageIDs: Set<UUID>

    init(viewModel: SGV5FlowModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _restoredMessageIDs = State(initialValue: Set(viewModel.buddy.entries.map(\.id)))
    }

    private var phase: BuddyOnboardingPhase { viewModel.buddy.phase }
    private var messages: [MonsterMessage] { viewModel.buddy.entries.map(\.message) }
    private var unobscured: Bool { visible && scenePhase == .active && !showUpload && !showDate && !showDeckPicker && !showApps && !showRound }
    private var canReply: Bool { unobscured && !busy && presenter.revealed >= messages.count && (viewModel.currentPageIndex != 601 || viewModel.accessVerified) }
    private var canType: Bool { [.name, .pronouns, .subject, .practice, .practiceReview].contains(phase) }
    private var placeholder: String {
        switch phase {
        case .name: return "First name or nickname"
        case .pronouns: return "Your pronouns (optional)"
        case .subject: return "Module or topic, e.g. COS 210"
        case .practiceReview: return "Ask about this card…"
        default: return "Your answer"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
        }
        .background(MonsterPalette.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if canType {
                MonsterReplyComposer(draft: $draft, enabled: true, placeholder: placeholder, onSend: send,
                    canSubmit: canReply, maximumLength: phase == .name ? 30 : phase == .pronouns ? 40 : phase == .practice ? 4000 : 500,
                    accessibilityName: placeholder)
                    .padding(.horizontal, 18).padding(.vertical, 10).background(MonsterPalette.bg)
            }
        }
        .sheet(isPresented: $showUpload, onDismiss: acceptUploadedDeck) { uploadSheet }
        .sheet(isPresented: $showDeckPicker) {
            DeckPickerSheet(subtitle: "Choose the cards you’d like to try with your buddy.", activeDeckID: viewModel.buddy.deckID) { deck in
                viewModel.buddyUseDeck(deck, in: decks)
                showDeckPicker = false
            }.environmentObject(decks)
        }
        .sheet(isPresented: $showDate) { dateSheet }
        .familyActivityPicker(isPresented: $showApps, selection: $appSelection)
        .fullScreenCover(isPresented: $showRound, onDismiss: roundClosed) {
            if let session {
                MonsterChatView(session: session, onboardingHistory: messages, onClose: { showRound = false })
            }
        }
        .alert("Let’s try that again", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(MonsterDisplayCopy.text(error ?? "")) }
        .onAppear {
            if !messages.isEmpty { presenter.restoreHistory(messages) }
            visible = true
            appSelection = guardManager.selection
            previousSelection = appSelection
            viewModel.buddyBegin()
            updatePresentation()
        }
        .onDisappear {
            visible = false; presenter.pause(); tutorTask?.cancel(); tutorTask = nil; busy = false
            scrollTask?.cancel()
        }
        .onChange(of: viewModel.buddy.entries.count) { _, _ in updatePresentation() }
        .onChange(of: unobscured) { _, _ in updatePresentation() }
        .onChange(of: phase) { _, _ in draft = "" }
        .onChange(of: personas.selectedID) { _, _ in viewModel.buddyBegin() }
        .onChange(of: appSelection) { _, value in
            if SGContract.tokenCount(value) > SGContract.maxSelectionTokens {
                appSelection = previousSelection
                error = "Choose up to \(SGContract.maxSelectionTokens) apps, categories and websites."
            } else { previousSelection = value }
        }
        .task {
            if viewModel.currentPageIndex == 601 { _ = await viewModel.verifyBuddyAccess() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            MonsterAvatarHeader(persona: personas.persona)
            HStack {
                Text(phase.chapter).font(.caption)
                Spacer()
                Text("\(phase.screenNumber) / \(SGV5V5OnboardingStep.progressCount)").font(.caption.monospacedDigit())
            }.foregroundStyle(MonsterPalette.textDim)
            ProgressView(value: phase.progress).tint(SGTheme.mintDeep)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .foregroundStyle(MonsterPalette.text)
        .background(MonsterPalette.bg)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Measured rows prevent height estimates from jumping during arrival.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(messages.prefix(presenter.revealed))) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            MonsterTextBubble(text: message.text ?? "", sender: message.sender)
                            if let reaction = message.reaction {
                                MonsterReactionView(reaction: reaction, playbackEnabled: unobscured, viewportHeight: 900)
                                    .padding(.leading, 4)
                            }
                        }
                        .modifier(MonsterMessageArrival(isUser: message.sender == .user,
                                                       animated: !restoredMessageIDs.contains(message.id)))
                        .id(message.id)
                    }
                    ZStack(alignment: .leading) {
                        Color.clear.frame(height: 42)
                        if presenter.isTyping || busy {
                            MonsterTypingIndicator(name: personas.persona.name).transition(.opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : MonsterChatMotion.feedback, value: presenter.isTyping || busy)
                    VStack(spacing: 12) {
                        if presenter.revealed >= messages.count {
                            controls.disabled(!canReply).id(phase)
                                .transition(MonsterChatMotion.arrival(reduceMotion: reduceMotion))
                        }
                    }
                    .animation(reduceMotion ? nil : MonsterChatMotion.panel, value: presenter.revealed >= messages.count)
                    Color.clear.frame(height: 8).id("buddy-bottom")
                }
                .padding(18)
            }
            .coordinateSpace(name: "monsterTranscript")
            .scrollDismissesKeyboard(.interactively)
            .onAppear { scrollToLatest(proxy) }
            .onChange(of: presenter.revealed) { _, _ in scrollToLatest(proxy) }
            .onChange(of: presenter.isTyping || busy) { _, _ in scrollToLatest(proxy) }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in scrollToLatest(proxy) }
            .onChange(of: unobscured) { _, shown in
                if shown { scrollToLatest(proxy) }
            }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        scrollTask?.cancel()
        guard unobscured else { return }
        scrollTask = Task { @MainActor in
            // Give the new message and reply choices one layout pass before scrolling.
            do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
            guard unobscured else { return }
            withAnimation(reduceMotion ? nil : MonsterChatMotion.conversation) {
                proxy.scrollTo("buddy-bottom", anchor: .bottom)
            }
        }
    }

    @ViewBuilder private var controls: some View {
        switch phase {
        case .name, .subject: EmptyView()
        case .pronouns:
            replies(["She / her", "He / him", "They / them", "Just my name"]) { viewModel.buddySubmitText($0) }
        case .level:
            let values = SGV5V5OnboardingProfile.StudyLevel.allCases
            MonsterQuickReplies(choices: values.map(\.title)) { viewModel.buddyChooseLevel(values[$0]) }
        case .exam:
            action("Add test or exam date", symbol: "calendar") { examDate = viewModel.v5Profile.examDate ?? Date(); showDate = true }
            action("No date yet") { viewModel.buddyChooseExam(nil) }
        case .age:
            let values = SGV5V5OnboardingProfile.AgeBracket.allCases
            MonsterQuickReplies(choices: values.map(\.title)) { viewModel.buddyChooseAge(values[$0]) }
        case .materials:
            // PDF is the main path; Quizlet and YouTube open the same generator on
            // their own tab. The generator still shows every source once open.
            action("Upload a PDF", symbol: "doc.badge.plus") { openUpload(.pdf) }
            action("Paste a Quizlet export", symbol: "rectangle.on.rectangle") { openUpload(.quizlet) }
            action("Use a YouTube video", symbol: "play.rectangle") { openUpload(.youtube) }
            if decks.decks.contains(where: { $0.cards.contains(where: \.isUsableForStudy) }) {
                action("Use a saved deck") { showDeckPicker = true }
            }
            action("Try a sample deck") { viewModel.buddyUseSample(in: decks) }
        case .practice:
            if let card = viewModel.buddy.practiceCard, card.answerMode == .choices {
                MonsterQuickReplies(choices: card.choices) { viewModel.buddySubmitText(card.choices[$0]) }
            }
            if (viewModel.buddy.practiceAttempts ?? 0) > 0, let card = viewModel.buddy.practiceCard, card.answerMode == .typed {
                action("Try the saved answer") { viewModel.buddySubmitText(card.correctAnswer) }
            }
        case .practiceReview:
            action("Explain the answer", symbol: "bubble.left.and.bubble.right") { askTutor("Explain the answer simply.") }
            action("Let’s make my plan", symbol: "arrow.right") { viewModel.buddyContinueToOffer() }
        case .rule:
            EmptyView() // A saved draft here moves forward in buddyBegin().
        case .offer:
            Text(viewModel.v5Profile.studyRewardSummary).font(.headline).foregroundStyle(MonsterPalette.text)
            action(viewModel.accessVerified ? "Finish setting up" : "Continue to my plan", symbol: "arrow.right") { viewModel.buddyShowOffer() }
        case .permission:
            action("Allow Screen Time", symbol: "hand.raised") { requestPermission() }
            action("Set up later") { viewModel.buddyDeferSetup() }
        case .apps:
            action(SGContract.isSelectionEmpty(appSelection) ? "Choose apps" : "Change selected apps", symbol: "apps.iphone") {
                if guardManager.authorizationStatus == .approved { showApps = true } else { requestPermission() }
            }
            if !SGContract.isSelectionEmpty(appSelection) {
                action("Confirm & start guarding", symbol: "lock.fill") { confirmApps() }
            }
            action("Set up later") { viewModel.buddyDeferSetup() }
        case .firstRound:
            action(session == nil ? "Earn my first break" : "Continue studying", symbol: "sparkles") { startRound() }
            action("Go to Home for now") { viewModel.buddyDeferSetup() }
        case .notifications:
            if let minutes = viewModel.buddy.firstRoundMinutes {
                Text(minutes > 0 ? "You earned \(minutes) minute\(minutes == 1 ? "" : "s")." : "Your progress is saved. Keep practicing when you’re ready.")
                    .font(.headline).foregroundStyle(MonsterPalette.text)
            }
            action("Enable reminders", symbol: "bell") { finish(notifications: true) }
            action("Maybe later. Go to Home") { finish(notifications: false) }
        }
    }

    private func replies(_ labels: [String], action: @escaping (String) -> Void) -> some View {
        MonsterQuickReplies(choices: labels) { action(labels[$0]) }
    }

    private func action(_ title: String, symbol: String? = nil, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack {
                if let symbol { Image(systemName: symbol) }
                Text(MonsterDisplayCopy.text(title)).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(MonsterPalette.text)
            .padding(15).frame(maxWidth: .infinity, minHeight: 48)
            .background(MonsterPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }

    private var dateSheet: some View {
        NavigationStack {
            ScrollView {
                DatePicker("Test or exam date", selection: $examDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }.padding().navigationTitle("Test or exam")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDate = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use date") { viewModel.buddyChooseExam(examDate); showDate = false }
                    }
                }
        }.presentationDetents([.large])
    }

    @ViewBuilder private var uploadSheet: some View {
        if let id = viewModel.buddy.deckID, let index = decks.decks.firstIndex(where: { $0.id == id }) {
            AutoGenerateFlashcardsSheet(deck: $decks.decks[index], initialSource: inputSource)
                .environmentObject(decks).sgSheetChrome()
        } else { Text("This deck is no longer available. Close this sheet and try again.").padding() }
    }

    private func openUpload(_ source: InputSource) {
        _ = viewModel.buddyPrepareDeck(in: decks)
        inputSource = source
        showUpload = true
    }

    private func acceptUploadedDeck() {
        if let id = viewModel.buddy.deckID, let deck = decks.decks.first(where: { $0.id == id }),
           deck.cards.contains(where: \.isUsableForStudy) {
            viewModel.buddyUseDeck(deck, in: decks, confirmation: "Here are my notes")
        }
        updatePresentation()
    }

    private func send() {
        guard canReply else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        if phase == .practiceReview { askTutor(text) } else { viewModel.buddySubmitText(text) }
    }

    private func askTutor(_ question: String) {
        guard canReply, let card = viewModel.buddy.practiceCard else { return }
        busy = true
        viewModel.buddySay(question, isUser: true)
        tutorTask = Task { @MainActor in
            defer { busy = false; tutorTask = nil }
            do {
                let reply = try await FlashcardAPIClient.shared.askTutor(persona: personas.persona.id,
                    card: MonsterTutorCard(card), question: question, history: [])
                guard !Task.isCancelled else { return }
                viewModel.buddySay(reply)
            } catch {
                guard !Task.isCancelled else { return }
                viewModel.buddySay("I can’t reach the live tutor right now. Here’s the saved explanation: \(card.backgroundExplanation.isEmpty ? card.correctAnswer : card.backgroundExplanation)")
            }
        }
    }

    private func requestPermission() {
        guard canReply else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            guard await viewModel.verifyBuddyAccess() else { return }
            let granted = await guardManager.requestAuthorization()
            if granted {
                if phase == .permission { viewModel.buddyMove(to: .apps) } else { showApps = true }
            } else {
                viewModel.buddySay("Screen Time access wasn’t enabled. You can try again, or finish setup later from Home.")
            }
        }
    }

    private func confirmApps() {
        guard canReply, !SGContract.isSelectionEmpty(appSelection) else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            guard await viewModel.verifyBuddyAccess() else { return }
            guard guardManager.authorizationStatus == .approved else { viewModel.buddyMove(to: .permission); return }
            switch guardManager.updateSelection(appSelection) {
            case .refusedTooMany: error = "Choose fewer apps and try again."; return
            case .refusedLocked: error = "Your apps are already guarded. Earn an unlock before changing them."; return
            default: break
            }
            switch guardManager.completeSetup(startLocked: true) {
            case .success:
                viewModel.buddy.guardConfigured = true
                viewModel.buddyMove(to: .firstRound)
            case .failure(let reason): error = reason.localizedDescription
            }
        }
    }

    private func startRound() {
        guard canReply, viewModel.buddy.guardConfigured else { return }
        guard let id = viewModel.buddy.deckID, let deck = decks.decks.first(where: { $0.id == id }),
              deck.cards.contains(where: \.isUsableForStudy) else {
            error = "Your deck needs a usable card. Add cards from Home, then tap Unlock apps."
            return
        }
        decks.selectDeck(deck)
        if session == nil { session = MonsterSession(method: .inChat) }
        showRound = true
    }

    private func roundClosed() {
        if let session, session.isFinished {
            viewModel.buddy.firstRoundMinutes = session.grantedMinutes
            viewModel.buddySay(session.grantedMinutes > 0
                ? "You earned \(session.grantedMinutes) minute\(session.grantedMinutes == 1 ? "" : "s"), \(viewModel.buddyName). That’s a real break."
                : "That round is saved. No time earned yet. We can keep practicing from Home.")
            viewModel.buddyMove(to: .notifications)
        }
        updatePresentation()
    }

    private func finish(notifications: Bool) {
        guard canReply, !viewModel.isFinishing else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            if notifications {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            }
            await viewModel.finishSetup()
        }
    }

    private func updatePresentation() { presenter.update(messages: messages, isVisible: unobscured) }
}

/// Also available from Profile after onboarding, so these choices stay editable.
struct BuddyProfileEditor: View {
    var viewModel: SGV5FlowModel? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pronouns = "Just my name"
    @State private var subject = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("What should your buddy call you?") {
                    TextField("First name or nickname", text: $name).textContentType(.nickname)
                    TextField("Pronouns or just my name", text: $pronouns)
                    Text("Optional: she/her, he/him, they/them, your own wording, or just your name.").font(.caption)
                }
                if viewModel != nil {
                    Section("Your first study focus") { TextField("Module or topic", text: $subject) }
                }
            }
            .navigationTitle("Your details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var identity = viewModel?.buddyIdentity ?? BuddyIdentity.load()
                        identity.name = name
                        identity.pronouns = pronouns.isEmpty ? "Just my name" : pronouns
                        if let viewModel {
                            viewModel.saveBuddyIdentity(identity)
                            if !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.v5Profile.subject = BuddyIdentity.clean(subject, limit: 160)
                                if let id = viewModel.buddy.examID,
                                   var exam = ExamStore.shared.exams.first(where: { $0.id == id }) {
                                    exam.subject = viewModel.v5Profile.studySubject
                                    ExamStore.shared.update(exam)
                                }
                            }
                            viewModel.syncV5Profile()
                        } else { identity.save() }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                let identity = viewModel?.buddyIdentity ?? BuddyIdentity.load()
                name = identity.name
                pronouns = identity.pronouns
                subject = viewModel?.v5Profile.studySubject ?? ""
            }
        }
    }
}
