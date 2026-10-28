//
//  MonsterChatView.swift
//  diewithoutregrets
//
//  Tutor Monster (Phase 1): the chat screen. Renders a MonsterSession's transcript
//  with a staggered reveal + typing indicator, and routes answers back to the
//  session. Placeholder styling (MonsterPalette) pending /design-shotgun.
//  See Docs/TutorMonsterPlan.md §4, §6i.
//

import SwiftUI

struct MonsterChatView: View {
    @StateObject private var session: MonsterSession
    @State private var revealed = 0
    @State private var pumping = false
    @State private var showTyping = false

    private let onClose: () -> Void

    init(session: MonsterSession,
         onClose: @escaping () -> Void = { NavigationModel.shared.returnHome() }) {
        _session = StateObject(wrappedValue: session)
        self.onClose = onClose
    }

    private var accent: Color { MonsterPalette.accent(session.persona) }

    var body: some View {
        ZStack {
            MonsterPalette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                transcript
            }
        }
        .onAppear {
            session.start()
            pumpIfIdle()
        }
        .onChange(of: session.messages.count) { _ in pumpIfIdle() }
    }

    private var header: some View {
        HStack {
            MonsterAvatarHeader(persona: session.persona, mood: session.dials.mood)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MonsterPalette.textDim)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(MonsterPalette.bg)
        .overlay(Rectangle().fill(MonsterPalette.surfaceHi).frame(height: 0.5), alignment: .bottom)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleMessages) { msg in
                        row(for: msg).id(msg.id)
                    }
                    if showTyping || session.isThinking {
                        MonsterTypingIndicator(tint: accent).id("typing")
                    }
                    if session.isFinished && revealed >= session.messages.count {
                        doneButton
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: revealed) { _ in scrollToBottom(proxy) }
            .onChange(of: showTyping) { _ in scrollToBottom(proxy) }
        }
    }

    private var visibleMessages: [MonsterMessage] {
        Array(session.messages.prefix(revealed))
    }

    @ViewBuilder
    private func row(for msg: MonsterMessage) -> some View {
        switch msg.kind {
        case let .text(t):
            MonsterTextBubble(text: t, sender: msg.sender, accent: accent)
        case let .card(card):
            MonsterCardBubble(
                card: card,
                accent: accent,
                enabled: session.activeCard?.id == card.id,
                onChoice: { session.answer(choiceIndex: $0) },
                onTyped: { session.answer(typed: $0) }
            )
        case let .reveal(correct, answer, why):
            MonsterRevealBubble(correct: correct, answer: answer, why: why)
        case let .grant(minutes):
            MonsterGrantBubble(minutes: minutes, accent: accent)
        }
    }

    private var doneButton: some View {
        Button(action: onClose) {
            Text(session.grantedMinutes > 0 ? "Done" : "Close")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 8)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: Staggered reveal (decouples chat pacing from the session's logic)

    private func pumpIfIdle() {
        guard !pumping, revealed < session.messages.count else { return }
        pumping = true
        step()
    }

    private func step() {
        guard revealed < session.messages.count else {
            pumping = false
            showTyping = false
            return
        }
        let next = session.messages[revealed]
        let isMonsterText = next.sender == .monster && next.text != nil
        showTyping = isMonsterText
        let delay = isMonsterText ? 0.6 : 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            showTyping = false
            withAnimation(.easeOut(duration: 0.2)) { revealed += 1 }
            step()
        }
    }
}
