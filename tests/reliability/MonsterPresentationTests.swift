import XCTest
@testable import StudyReliability

final class MonsterPresentationTests: XCTestCase {
    @MainActor
    private final class ManualClock {
        var waits: [CheckedContinuation<Void, Error>] = []
        func sleep(_ duration: Duration) async throws {
            try await withCheckedThrowingContinuation { waits.append($0) }
        }
        func finishNext() { waits.removeFirst().resume() }
        func finishAll() { while !waits.isEmpty { finishNext() } }
    }

    @MainActor private func drain() async {
        for _ in 0..<30 { await Task.yield() }
    }

    @MainActor func testCoveredChatDoesNotStartAndBackgroundDoesNotConsumeMessages() async {
        let clock = ManualClock()
        var arrivals: [UUID] = []
        let presenter = MonsterTranscriptPresenter(sleep: clock.sleep, onMonsterMessage: { arrivals.append($0.id) })
        let messages: [MonsterMessage] = [.monster("Hello"), .monster("Ready for a question?")]
        presenter.update(messages: messages, isVisible: false)
        await drain()
        XCTAssertEqual(presenter.revealed, 0)
        XCTAssertTrue(clock.waits.isEmpty)
        XCTAssertTrue(arrivals.isEmpty)
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertTrue(presenter.isTyping)
        clock.finishNext()
        await drain()
        XCTAssertEqual(presenter.revealed, 1)
        XCTAssertEqual(arrivals, [messages[0].id])
        XCTAssertFalse(presenter.isTyping, "Give the first message a reading beat")
        presenter.pause()
        clock.finishNext() // The suspended reading beat resumes after backgrounding.
        await drain()
        XCTAssertEqual(presenter.revealed, 1)
        XCTAssertFalse(presenter.isTyping)
        XCTAssertEqual(arrivals, [messages[0].id], "Backgrounding must not produce arrival haptics")
        presenter.update(messages: messages, isVisible: true)
        await drain()
        clock.finishNext() // A fresh reading beat, not background elapsed time.
        await drain()
        XCTAssertTrue(presenter.isTyping)
        XCTAssertEqual(presenter.revealed, 1)
        clock.finishNext()
        await drain()
        XCTAssertEqual(presenter.revealed, 2)
        XCTAssertFalse(presenter.isTyping)
        XCTAssertEqual(arrivals, messages.map(\.id))
    }

    @MainActor func testReplacingRoundCancelsOldTypingAndDoesNotReplayHistoryHaptics() async {
        let clock = ManualClock()
        var arrivals: [UUID] = []
        let presenter = MonsterTranscriptPresenter(sleep: clock.sleep, onMonsterMessage: { arrivals.append($0.id) })
        let old = [MonsterMessage.monster("Old deck")]
        presenter.update(messages: old, isVisible: true)
        await drain()
        presenter.restoreHistory([])
        let fresh = [MonsterMessage.monster("New deck")]
        presenter.update(messages: fresh, isVisible: true)
        await drain()
        clock.finishNext()
        await drain()
        XCTAssertEqual(presenter.revealed, 0)
        clock.finishNext()
        await drain()
        XCTAssertEqual(arrivals, fresh.map(\.id))
        presenter.restoreHistory(fresh)
        presenter.update(messages: fresh, isVisible: true)
        await drain()
        XCTAssertEqual(presenter.revealed, 1)
        XCTAssertEqual(arrivals, fresh.map(\.id))
        XCTAssertTrue(clock.waits.isEmpty)
    }

    @MainActor func testEveryMonsterMessageGetsOneArrivalIncludingQuestionsAndVerdicts() async {
        let clock = ManualClock()
        var arrivals: [UUID] = []
        let presenter = MonsterTranscriptPresenter(sleep: clock.sleep, onMonsterMessage: { arrivals.append($0.id) })
        let card = Regret(regretPrompt: "What do plants absorb?", regret: "light",
                          choices: ["light", "sand"], correctAnswerIndex: 0,
                          backgroundExplanation: "Light supplies energy.")
        let messages: [MonsterMessage] = [
            .monster("Ready?"), .init(sender: .monster, kind: .card(card)),
            .user("light"), .init(sender: .monster, kind: .reveal(correct: true, answer: "light", why: nil)),
            .monster("Exactly!", reaction: .delightedLaugh), .init(sender: .monster, kind: .grant(minutes: 1)),
            .system("Round complete")
        ]
        presenter.update(messages: messages, isVisible: true)
        for _ in 0..<20 {
            await drain()
            if presenter.revealed == messages.count { break }
            if !clock.waits.isEmpty { clock.finishNext() }
        }
        await drain()
        XCTAssertEqual(presenter.revealed, messages.count)
        XCTAssertEqual(arrivals, messages.filter { $0.sender == .monster }.map(\.id))
        presenter.pause()
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertEqual(arrivals.count, 5, "Returning to a transcript must not replay feedback")
        XCTAssertTrue(clock.waits.isEmpty)
    }

    @MainActor func testLateCancelledTypingCannotRevealOrClearTheResumedTask() async {
        let clock = ManualClock()
        let presenter = MonsterTranscriptPresenter(sleep: clock.sleep)
        let messages = [MonsterMessage.monster("First message")]
        presenter.update(messages: messages, isVisible: true)
        await drain()
        presenter.pause()
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertEqual(clock.waits.count, 2)
        clock.finishNext() // Deliberately non-cooperative cancellation.
        await drain()
        XCTAssertEqual(presenter.revealed, 0)
        XCTAssertTrue(presenter.isTyping)
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertEqual(clock.waits.count, 1, "Repeated updates must not start another timer")
        clock.finishNext()
        await drain()
        XCTAssertEqual(presenter.revealed, 1)
        presenter.pause()
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertTrue(clock.waits.isEmpty, "Already viewed messages must not replay")
    }

    @MainActor func testBufferedRepliesStayHiddenAndResumeOneAtATime() async {
        let clock = ManualClock()
        let presenter = MonsterTranscriptPresenter(sleep: clock.sleep)
        var messages = [MonsterMessage.user("Why?")]
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertEqual(presenter.revealed, 1, "Sent messages are immediate")
        presenter.pause()
        messages += [.monster("An explanation"), .monster("Ready to continue?")]
        presenter.update(messages: messages, isVisible: false)
        await drain()
        XCTAssertEqual(presenter.revealed, 1)
        XCTAssertTrue(clock.waits.isEmpty)
        presenter.update(messages: messages, isVisible: true)
        await drain()
        XCTAssertTrue(presenter.isTyping)
        clock.finishNext()
        await drain()
        XCTAssertEqual(presenter.revealed, 2, "A return must not flush the whole buffer")
        presenter.pause()
        clock.finishAll()
        await drain()
        XCTAssertEqual(presenter.revealed, 2)
    }

    func testBottomPanelWaitsBetweenCardsAndRepeatedCardOccurrences() {
        let card = Regret(regretPrompt: "What do plants absorb?", regret: "light",
                          choices: ["light", "sand"], correctAnswerIndex: 0,
                          backgroundExplanation: "Light supplies energy.")
        let question = MonsterMessage(sender: .monster, kind: .card(card))
        let target = MonsterReplyTarget(messageID: question.id, card: card)
        XCTAssertEqual(MonsterInlineReplyPhase.current(messages: [], replyTarget: nil, isFinished: false), .introduction)
        XCTAssertEqual(MonsterInlineReplyPhase.current(messages: [question], replyTarget: target, isFinished: false), .answering(question.id))
        let answeringTurn: [MonsterMessage] = [question, .user("sand"), .monster("Let's try again.")]
        XCTAssertEqual(MonsterInlineReplyPhase.current(messages: answeringTurn, replyTarget: nil, isFinished: false), .waiting(question.id))
        let retry = MonsterMessage(sender: .monster, kind: .card(card))
        let retryTarget = MonsterReplyTarget(messageID: retry.id, card: card)
        XCTAssertEqual(MonsterInlineReplyPhase.current(messages: answeringTurn + [retry], replyTarget: retryTarget, isFinished: false), .answering(retry.id))
        XCTAssertEqual(MonsterInlineReplyPhase.current(messages: answeringTurn, replyTarget: nil, isFinished: true), .complete)
    }
}
