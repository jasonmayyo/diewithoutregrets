import XCTest
@testable import StudyReliability

final class MonsterTextOnlyTests: XCTestCase {
    func testLegacyMessageAttachmentIsIgnoredWithoutLosingTextOrIdentity() throws {
        let original = MonsterMessage.monster("Your progress is saved.")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy["reaction"] = "double-take"
        let restored = try JSONDecoder().decode(MonsterMessage.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored, original)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        XCTAssertNil(saved["reaction"])
    }

    func testLegacySheetAttachmentIsIgnoredWithoutLosingTheAcceptedAnswer() throws {
        let original = MonsterStudyAnswer(id: UUID(), correct: true, text: "light", choiceIndex: 0)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy["reaction"] = "retired-or-unknown-media"
        let restored = try JSONDecoder().decode(MonsterStudyAnswer.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored, original)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        XCTAssertNil(saved["reaction"])
    }

    @MainActor func testBothStudyModesResumeLegacyMediaSnapshotsAndSettleOnlyOnce() throws {
        for method in MonsterStudyMethod.allCases {
            let suite = "MonsterTextOnlyTests.\(UUID())"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = DeckStore()
            store.selectedDeck = Deck(name: "Biology", cards: (0..<8).map {
                Regret(regretPrompt: "Question \($0): what do plants absorb?", regret: "light",
                       choices: ["light", "sand"], correctAnswerIndex: 0,
                       backgroundExplanation: "Light supplies energy.")
            })
            let manager = StudyGuardManager()
            func makeSession() -> MonsterSession {
                MonsterSession(deckStore: store, examStore: ExamStore(), personaStore: PersonaStore(),
                    studyGuard: manager, sharedDefaults: nil, creatorDefaults: defaults,
                    persistsProgress: true, method: method, loadBundle: { _, _, _ in nil })
            }
            let first = makeSession()
            first.start()
            if method == .inChat { first.answer(choiceIndex: 0) }
            else {
                XCTAssertTrue(first.beginStudyRound())
                first.answerStudyChoice(questionID: try XCTUnwrap(first.studyRound?.currentQuestion?.id), index: 0)
            }
            first.stop()
            let expectedMessages = first.messages
            let expectedRoundID = first.roundID
            let earned = first.studyEarnedSeconds
            var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: MonsterSession.progressKey))) as? [String: Any])
            var messages = try XCTUnwrap(legacy["messages"] as? [[String: Any]])
            messages[0]["reaction"] = "delighted-laugh"
            legacy["messages"] = messages
            if var round = legacy["studyRound"] as? [String: Any], var answers = round["answers"] as? [[String: Any]], !answers.isEmpty {
                answers[0]["reaction"] = "double-take"
                round["answers"] = answers
                legacy["studyRound"] = round
            }
            defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: MonsterSession.progressKey)
            let resumed = makeSession()
            resumed.start()
            XCTAssertEqual(resumed.messages, expectedMessages)
            XCTAssertEqual(resumed.roundID, expectedRoundID)
            XCTAssertEqual(resumed.studyEarnedSeconds, earned)
            XCTAssertEqual(manager.grants, 0)
            if method == .inChat {
                for _ in 0..<30 where !resumed.isFinished { resumed.answer(choiceIndex: 0) }
            } else {
                XCTAssertTrue(resumed.beginStudyRound())
                for _ in 0..<30 where resumed.studySheetState != .readyToUnlock {
                    let id = try XCTUnwrap(resumed.studyRound?.currentQuestion?.id)
                    resumed.answerStudyChoice(questionID: id, index: 0)
                    _ = resumed.advanceStudyRound(questionID: id)
                }
                resumed.claimStudyTime()
                resumed.claimStudyTime()
            }
            XCTAssertTrue(resumed.isFinished)
            XCTAssertEqual(manager.grants, 1)
            XCTAssertGreaterThan(resumed.grantedMinutes, 0)
            XCTAssertFalse(String(decoding: try JSONEncoder().encode(resumed.messages), as: UTF8.self).contains("\"reaction\""))
            resumed.stop(); resumed.start()
            XCTAssertEqual(manager.grants, 1)
        }
    }
}
