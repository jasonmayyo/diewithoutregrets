import SwiftUI

/// The round stays in one sheet. Only its invitation and recap enter the chat.
struct MonsterStudySheet: View {
    @ObservedObject var session: MonsterSession
    let onAsk: (MonsterReplyTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ""
    @State private var displayedSeconds = 0
    @State private var bump = 0
    @State private var coins: [QV2CoinModel] = []
    @State private var landed: Set<Int> = []
    @State private var serial = 0
    @State private var rewardStart = 0
    @State private var rewardTarget = 0
    @State private var chipFrame: CGRect = .zero
    @State private var answerFrame: CGRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            header
            if let round = session.studyRound, let question = round.currentQuestion {
                ProgressView(value: Double(round.answers.count), total: Double(round.questions.count))
                    .tint(MonsterPalette.successText)
                    .padding(.horizontal, 24).padding(.bottom, 16)
                    .accessibilityLabel("Flashcards answered")
                    .accessibilityValue("\(round.answers.count) of \(round.questions.count)")
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text(question.card.topic ?? round.title).lineLimit(2)
                            Spacer(minLength: 8)
                            Text("\(round.index + 1) of \(round.questions.count)").monospacedDigit().fixedSize()
                        }
                        .font(.caption.weight(.medium)).foregroundStyle(MonsterPalette.textDim)
                        Text(question.card.quizPrompt.text)
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if question.card.answerMode == .choices {
                            choices(question: question, answer: round.currentAnswer)
                        } else if let answer = round.currentAnswer {
                            Text(answer.text).font(.body).padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(MonsterPalette.surface, in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            MonsterReplyComposer(draft: $draft, enabled: !session.isThinking,
                                placeholder: "Your answer…", onSend: {
                                    session.answerStudyTyped(questionID: question.id, text: draft)
                                })
                        }
                        feedback(question: question, answer: round.currentAnswer)
                            .background(QV2GlobalFrameReader { answerFrame = $0 })
                    }
                    .padding(.horizontal, 24).padding(.bottom, 20)
                    .id(question.id)
                }
                .scrollDismissesKeyboard(.interactively)
                footer(round: round, question: question)
            }
        }
        .foregroundStyle(MonsterPalette.text)
        .background(MonsterPalette.bg)
        .overlay {
            QV2CoinFlightOverlay(coins: coins, spawnFrame: answerFrame, targetFrame: chipFrame, onLand: bank)
                .accessibilityHidden(true)
        }
        .onAppear { displayedSeconds = session.studyEarnedSeconds }
        .onChange(of: session.studyRound?.currentQuestion?.id) { _, _ in draft = "" }
        .onChange(of: session.studyRound?.currentAnswer?.id) { _, id in
            guard id != nil, session.studyRound?.currentAnswer?.correct == true else { return }
            guard !reduceMotion, scenePhase == .active else { settle(); return }
            rewardStart = displayedSeconds
            rewardTarget = session.studyEarnedSeconds
            serial += 1
            landed = []
            coins = QV2CoinModel.flock(of: 6, serial: serial)
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { settle() } }
        .onChange(of: reduceMotion) { _, reduced in if reduced { settle() } }
        .onDisappear { settle() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.studyRound?.isFollowUp == true ? "A little extra practice" : "Your study round")
                    .font(.headline)
                Text("\(session.persona.name) will meet you after")
                    .font(.caption).foregroundStyle(MonsterPalette.textDim)
            }
            Spacer(minLength: 0)
            MonsterAllowanceChip(seconds: displayedSeconds, bump: bump, isEarning: true)
                .background(QV2GlobalFrameReader { chipFrame = $0 })
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(MonsterPalette.surface, in: Circle())
            }
            .buttonStyle(.plain).accessibilityLabel("Pause round and return to chat")
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 20)
    }

    private func choices(question: MonsterStudyQuestion, answer: MonsterStudyAnswer?) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                 count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
            ForEach(question.card.choices.indices, id: \.self) { index in
                let right = answer != nil && index == question.card.correctAnswerIndex
                let wrong = answer?.choiceIndex == index && answer?.correct == false
                Button { session.answerStudyChoice(questionID: question.id, index: index) } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(String(UnicodeScalar(65 + index) ?? UnicodeScalar(65)))
                            Spacer()
                            if right || wrong { Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle") }
                        }
                        .font(.caption.weight(.semibold))
                        Text(question.card.choices[index]).font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                    .padding(14)
                    .background(right ? MonsterPalette.successBg : wrong ? Color.orange.opacity(0.09) : .white,
                                in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(
                        right ? MonsterPalette.successText.opacity(0.5) : wrong ? Color.orange.opacity(0.5) : MonsterPalette.hairline))
                }
                .buttonStyle(.plain)
                .disabled(answer != nil || session.isThinking)
                .accessibilityLabel("\(question.card.choices[index])\(right ? ", correct answer" : wrong ? ", your answer, incorrect" : "")")
            }
        }
    }

    @ViewBuilder private func feedback(question: MonsterStudyQuestion, answer: MonsterStudyAnswer?) -> some View {
        if let answer {
            VStack(alignment: .leading, spacing: 7) {
                Label(answer.correct ? "Correct · +\(QV2EarnedChip.label(seconds: session.secondsPerCorrectAnswer))" : "Not quite",
                      systemImage: answer.correct ? "checkmark.circle.fill" : "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(answer.correct ? MonsterPalette.successText : MonsterPalette.text)
                if !answer.correct { Text("Answer: \(question.card.correctAnswer)").font(.subheadline.weight(.medium)) }
                if !question.card.backgroundExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(question.card.backgroundExplanation).font(.subheadline).foregroundStyle(MonsterPalette.textDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text(question.card.answerMode == .choices ? "Choose one answer. Take your time." : "Try recalling it in your own words.")
                .font(.caption).foregroundStyle(MonsterPalette.textDim)
        }
    }

    private func footer(round: MonsterStudyRound, question: MonsterStudyQuestion) -> some View {
        VStack(spacing: 10) {
            MonsterStudyButton(title: round.index == round.questions.count - 1 ? "Back to \(session.persona.name)" : "Next card",
                               enabled: round.currentAnswer != nil && coins.isEmpty && !session.isThinking) {
                if session.advanceStudyRound(questionID: question.id) { dismiss() }
            }
            Button {
                onAsk(MonsterReplyTarget(messageID: question.id, card: question.card))
                dismiss()
            } label: {
                Label("Ask \(session.persona.name) about this card", systemImage: "bubble.left")
                    .font(.caption).frame(minHeight: 30)
            }
            .buttonStyle(.plain).foregroundStyle(MonsterPalette.textDim)
            .disabled(session.isThinking)
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
        .background(MonsterPalette.bg)
    }

    private func bank(_ coin: QV2CoinModel) {
        guard coins.contains(where: { $0.id == coin.id }), landed.insert(coin.id).inserted else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            displayedSeconds = rewardStart + (rewardTarget - rewardStart) * landed.count / coin.flockSize
            bump += 1
        }
        QuizHaptics.coinLand(progress: Double(landed.count) / Double(coin.flockSize))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { coins.removeAll { $0.id == coin.id } }
    }

    private func settle() {
        coins = []; landed = []; displayedSeconds = session.studyEarnedSeconds
    }
}

struct MonsterStudyButton: View {
    let title: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right").font(.subheadline.weight(.semibold))
            }
            .padding(16).foregroundStyle(.white)
            .background(MonsterPalette.text.opacity(enabled ? 1 : 0.25), in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain).disabled(!enabled)
    }
}

struct MonsterStudyInvitation: View {
    let round: MonsterStudyRound
    let persona: MonsterPersona
    let isCurrent: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.title3).foregroundStyle(MonsterPalette.successText)
                    .frame(width: 42, height: 42).background(MonsterPalette.successBg, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.isFollowUp ? "Your follow-up round" : "A quick study round").font(.headline)
                    Text("\(round.title) · \(round.cardDescription)").font(.caption).foregroundStyle(MonsterPalette.textDim)
                }
            }
            Text(round.isFollowUp
                 ? "One final set. Your earned time is kept."
                 : "Get \(round.requiredCorrect) of \(round.questions.count) right. If needed, one short follow-up before unlocking.")
                .font(.subheadline).foregroundStyle(MonsterPalette.textDim)
            Label(isCurrent ? "\(persona.name) will meet you after" : "Round complete",
                  systemImage: isCurrent ? "bubble.left" : "checkmark.circle")
                .font(.caption.weight(.medium)).foregroundStyle(MonsterPalette.successText)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(MonsterPalette.hairline))
    }
}

struct MonsterStudyRecap: View {
    let summary: MonsterStudySummary
    let canAsk: Bool
    let onAsk: (MonsterReplyTarget) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(summary.round.isFollowUp ? "Follow-up complete" : "Round complete")
                .font(.subheadline.weight(.medium)).foregroundStyle(MonsterPalette.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(summary.round.correctCount)").font(.system(size: 38, weight: .semibold, design: .rounded))
                Text("/ \(summary.round.questions.count) correct").font(.body).foregroundStyle(MonsterPalette.textDim)
            }
            HStack(spacing: 8) {
                ForEach(summary.round.answers) { answer in
                    Image(systemName: answer.correct ? "checkmark" : "minus")
                        .font(.caption.weight(.bold)).frame(width: 30, height: 30)
                        .foregroundStyle(answer.correct ? MonsterPalette.successText : MonsterPalette.textDim)
                        .background(answer.correct ? MonsterPalette.successBg : MonsterPalette.surface, in: Circle())
                }
            }.accessibilityHidden(true)
            Label("\(QV2EarnedChip.label(seconds: summary.earnedSeconds)) earned so far", systemImage: "hourglass")
                .font(.subheadline).foregroundStyle(MonsterPalette.successText)
            Menu {
                ForEach(summary.round.questions) { question in
                    Button(question.card.quizPrompt.text) {
                        onAsk(MonsterReplyTarget(messageID: question.id, card: question.card))
                    }
                }
            } label: {
                Label("Ask about a card", systemImage: "bubble.left").font(.caption)
            }
            .disabled(!canAsk).foregroundStyle(MonsterPalette.textDim)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(MonsterPalette.hairline))
    }
}
