import XCTest
@testable import diewithoutregrets

final class OnboardingV5Tests: XCTestCase {
    func testChatDisplayPunctuationPreservesSourceAndParagraphs() throws {
        let original = "One\u{2014}two.\n\n\u{2014}A quoted line. Keep self-study, 18–24 and −2."
        let expected = "One, two.\n\nA quoted line. Keep self-study, 18–24 and −2."
        var state = BuddyOnboardingState()
        state.entries = [.init(text: original)]
        let restored = try JSONDecoder().decode(BuddyOnboardingState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(MonsterDisplayCopy.text(original), expected)
        XCTAssertEqual(MonsterDisplayCopy.text(restored.entries[0].text), expected)
        XCTAssertEqual(restored.entries[0].text, original, "Presentation must not rewrite saved content")
        XCTAssertEqual(MonsterDisplayCopy.text("Nice work \u{2014} keep going."), "Nice work, keep going.")
        XCTAssertEqual(MonsterDisplayCopy.text(expected), expected)
    }

    func testOnboardingPromptsAndPhoneEstimatesAvoidEmDashes() {
        for persona in MonsterPersona.all {
            for phase in BuddyOnboardingPhase.allCases {
                let copy = BuddyOnboardingCopy.prompt(phase, name: "Alex", subject: "Biology", persona: persona, card: nil)
                XCTAssertFalse(copy.contains("\u{2014}"), "Unexpected punctuation in \(phase)")
            }
        }
        for baseline in SGV5V5OnboardingProfile.Baseline.allCases {
            var profile = SGV5V5OnboardingProfile()
            profile.baseline = baseline
            XCTAssertFalse(profile.phoneEstimateExplanation.contains("\u{2014}"))
        }
    }

    @MainActor
    func testNormalPersonalQuestionsPersistAndGateForwardNavigation() async throws {
        let suite = "BuddyNormalQuestions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        model.currentPageIndex = SGV5V5OnboardingStep.personalize.rawValue
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.gender.rawValue)
        try await Task.sleep(for: .milliseconds(500))
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.gender.rawValue)
        model.v5Profile.gender = .nonBinary
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.age.rawValue)
        try await Task.sleep(for: .milliseconds(500))
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.age.rawValue)
        model.v5Profile.ageBracket = .age18to24
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.baseline.rawValue)
        try await Task.sleep(for: .milliseconds(500))
        model.v5Profile.baseline = .twoToFour
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.phoneTimeCost.rawValue)
        try await Task.sleep(for: .milliseconds(500))
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.persona.rawValue)
        model.previousPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.phoneTimeCost.rawValue)
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        XCTAssertEqual(restored.v5Profile.gender, .nonBinary)
        XCTAssertEqual(restored.v5Profile.ageBracket, .age18to24)
        XCTAssertEqual(restored.v5Profile.baseline, .twoToFour)
        XCTAssertEqual(restored.buddyIdentity.gender, "Non-binary")
        XCTAssertEqual(restored.buddyIdentity.pronouns, "Just my name")
    }

    @MainActor
    func testNewChatSkipsPersonalQuestionsAlreadyAnsweredOnNormalScreens() {
        let suite = "BuddySkipProfile.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        model.v5Profile.gender = .preferNotToSay
        model.v5Profile.ageBracket = .age18to24
        model.v5Profile.baseline = .twoToFour
        model.buddyBegin()
        model.buddySubmitText("Alex")
        XCTAssertEqual(model.buddy.phase, .level)
        model.buddyChooseLevel(.university)
        // Study level now leads straight to the notes upload. Subject is no longer
        // asked, and the exam date comes after the upload.
        XCTAssertEqual(model.buddy.phase, .materials)
        XCTAssertNil(model.buddyIdentity.gender, "A declined gender answer must not be sent as a gender")
        XCTAssertFalse(model.buddy.entries.contains {
            $0.text.contains("Which age range") || $0.text.contains("pick pronouns") || $0.text.contains("module or topic")
        })
        let entries = model.buddy.entries.map(\.id)
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        restored.buddyBegin()
        XCTAssertEqual(restored.buddy.phase, .materials)
        XCTAssertEqual(restored.buddy.entries.map(\.id), entries)
    }

    @MainActor
    func testResumingSkipsAnsweredPendingQuestionWithoutDeletingCompletedHistory() {
        let suite = "BuddySkipPending.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        model.saveBuddyIdentity(.init(name: "Alex", pronouns: "They / them"))
        model.buddy.personaID = model.buddyPersona.id
        model.v5Profile.gender = .nonBinary
        model.v5Profile.ageBracket = .age18to24
        model.v5Profile.studyLevel = .university
        model.v5Profile.subject = "COS 210"
        model.v5Profile.noExamYet = true
        XCTAssertEqual(model.buddyUnansweredPhase(startingAt: .name), .materials)
        model.buddy.phase = .age
        model.buddySay("No date yet", isUser: true)
        let savedID = model.buddy.entries[0].id
        model.buddyPrompt()
        model.buddyBegin()
        XCTAssertEqual(model.buddy.phase, .materials)
        XCTAssertEqual(model.buddy.entries.first?.id, savedID)
        XCTAssertEqual(model.buddy.entries.count, 2)
        let count = model.buddy.entries.count
        model.buddyBegin()
        XCTAssertEqual(model.buddy.entries.count, count)
        XCTAssertEqual(model.buddyUnansweredPhase(startingAt: .practice), .practice)
    }

    func testOldProfileDraftsStillDecodeAndExplicitGenderUsesExistingTutorContext() throws {
        let old = try JSONDecoder().decode(SGV5V5OnboardingProfile.self,
            from: Data("{\"dailyReductionMinutes\":30,\"startSmaller\":false}".utf8))
        XCTAssertNil(old.gender)
        let identity = BuddyIdentity(name: "Alex", pronouns: "Just my name", gender: "Non-binary")
        let question = identity.tutorQuestion(String(repeating: "🦖", count: 900))
        XCTAssertTrue(question.contains("My gender is Non-binary"))
        XCTAssertTrue(question.contains("Just my name"))
        XCTAssertLessThanOrEqual(question.utf16.count, 1000)
    }

    @MainActor
    func testResumingRefreshesOnlyTheUnansweredStudyQuestion() {
        let suite = "BuddyStudyCopy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.saveBuddyIdentity(.init(name: "Alex", pronouns: "Just my name"))
        model.buddy.personaID = model.buddyPersona.id
        // A legacy draft parked on the retired subject question resumes into the
        // current flow: the subject is detected from notes, so the draft advances to
        // the upload step and the obsolete question is not left in the transcript.
        model.buddy.phase = .subject
        model.buddySay("What are we studying, Alex?")
        model.buddyBegin()
        XCTAssertEqual(model.buddy.phase, .materials)
        XCTAssertFalse(model.buddy.entries.contains {
            $0.text.contains("What are we studying") || $0.text.contains("module or topic")
        })

        model.v5Profile.subject = "COS 210"
        model.buddy.phase = .exam
        model.buddy.entries = [
            .init(text: "What are we studying, Alex?"),
            .init(text: "COS 210", isUser: true),
            .init(text: "When’s your next COS 210 exam? No date yet is completely fine.")
        ]
        model.buddyBegin()
        XCTAssertEqual(model.buddy.entries[0].text, "What are we studying, Alex?")
        XCTAssertEqual(model.buddy.entries[1].text, "COS 210")
        XCTAssertTrue(model.buddy.entries[2].text.contains("test or exam coming up for COS 210"))
        let refreshed = model.buddy.entries.map(\.text)
        let resumed = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        resumed.buddyBegin()
        XCTAssertEqual(resumed.buddy.entries.map(\.text), refreshed)
    }

    @MainActor
    func testOpeningMemeIsGuaranteedAndResumeDoesNotRepeatIt() throws {
        let suite = "BuddyOpening.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.buddyBegin()
        XCTAssertEqual(model.buddy.entries.count, 2)
        XCTAssertNotNil(model.buddy.entries.first?.reaction)
        model.buddySubmitText("  Alex  ")
        model.buddySubmitText("They / them")
        XCTAssertEqual(model.buddyIdentity.name, "Alex")
        XCTAssertEqual(model.buddyIdentity.pronouns, "They / them")
        XCTAssertEqual(model.buddy.phase, .level)
        let count = model.buddy.entries.count
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        restored.buddyBegin()
        XCTAssertEqual(restored.buddy.entries.count, count)
        XCTAssertEqual(restored.buddy.entries.filter { $0.reaction != nil }.count, 1)
    }

    @MainActor
    func testPracticeRetryDoesNotAwardTimeOrRecordMastery() throws {
        let card = SGV5FlowModel.buddySampleCards[0]
        var state = BuddyOnboardingState()
        state.phase = .practice
        state.practiceCard = card
        XCTAssertEqual(state.answerPractice("wrong"), false)
        XCTAssertEqual(state.phase, .practice)
        XCTAssertEqual(state.answerPractice(card.correctAnswer), true)
        XCTAssertEqual(state.phase, .practiceReview)
        XCTAssertNil(state.answerPractice(card.correctAnswer), "Repeated taps must not grade again")
        XCTAssertEqual(state.practiceCard?.timesSeen, 0)
        XCTAssertNil(state.firstRoundMinutes)
        XCTAssertFalse(state.guardConfigured)
        let restored = try JSONDecoder().decode(BuddyOnboardingState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(restored.practicePassed)
        XCTAssertEqual(restored.practiceCard?.id, card.id)
    }

    func testIdentityIsExplicitAndTutorContextStaysWithinRequestLimit() {
        let identity = BuddyIdentity(name: "Alex", pronouns: "They / them")
        let question = identity.tutorQuestion(String(repeating: "🦖", count: 900))
        XCTAssertTrue(question.contains("Alex"))
        XCTAssertTrue(question.contains("They / them"))
        XCTAssertLessThanOrEqual(question.utf16.count, 1000)
        XCTAssertEqual(BuddyIdentity().tutorQuestion("Why?"), "Why?")
        XCTAssertEqual(identity.addressBanter("Nice work, girl."), "Nice work, friend.")
    }

    @MainActor
    func testNoExamChoiceClearsLegacyExamAndSetupDeferralIsHonest() {
        let suite = "BuddyNoExam.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Date().timeIntervalSince1970, forKey: "examDate")
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.buddy.phase = .exam
        model.buddyChooseExam(nil)
        XCTAssertNil(defaults.object(forKey: "examDate"))
        XCTAssertFalse(defaults.bool(forKey: "hasExams"))
        model.buddy.phase = .permission
        model.buddyDeferSetup()
        XCTAssertEqual(model.buddy.phase, .notifications)
        XCTAssertFalse(model.buddy.guardConfigured)
        XCTAssertNil(model.buddy.firstRoundMinutes)
    }
    func testCurrentSourceOrderIncludesAgeAndLatestSetup() {
        XCTAssertEqual(SGV5V5OnboardingStep.flowOrder,
                       [800, 824, 825, 822, 828, 819, 810, 827, 821, 823, 506, 601])
        XCTAssertEqual(SGV5V5OnboardingProfile.StudyLevel.allCases.count, 4)
    }

    func testTimeBackDirectionSnappingAndPersistenceAcrossAllBaselines() throws {
        var profile = SGV5V5OnboardingProfile()
        profile.examDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        for baseline in SGV5V5OnboardingProfile.Baseline.allCases {
            profile.baseline = baseline
            var previousDays = -1.0
            for minutes in stride(from: 0, through: profile.maximumTimeBackMinutes, by: 15) {
                profile.setTimeBackMinutes(Double(minutes))
                XCTAssertGreaterThan(profile.reclaimedHoursBeforeExam, previousDays)
                XCTAssertEqual(profile.effectiveGoalMinutes + profile.dailyReductionMinutes,
                               profile.estimatedDailyMinutes)
                previousDays = profile.reclaimedHoursBeforeExam
                XCTAssertLessThanOrEqual(profile.reclaimedHoursBeforeExam, Double(profile.phoneHoursBeforeExam))
            }
            profile.setTimeBackMinutes(37.5)
            XCTAssertEqual(profile.timeBackMinutes, min(45, profile.maximumTimeBackMinutes))
            let restored = try JSONDecoder().decode(SGV5V5OnboardingProfile.self,
                from: JSONEncoder().encode(profile))
            XCTAssertEqual(restored, profile)
            profile.setTimeBackMinutes(-100)
            XCTAssertEqual(profile.timeBackMinutes, 0)
            profile.setTimeBackMinutes(.greatestFiniteMagnitude)
            XCTAssertEqual(profile.effectiveGoalMinutes, 30)
            let before = profile
            profile.setTimeBackMinutes(.nan)
            XCTAssertEqual(profile, before)
        }
    }

    func testExamProjectionUsesDaysAndBaselineInsteadOfAge() {
        var profile = SGV5V5OnboardingProfile()
        profile.baseline = .twoToFour
        profile.examDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        profile.setTimeBackMinutes(90)
        XCTAssertEqual(profile.examDays, 30)
        XCTAssertEqual(profile.phoneHoursBeforeExam, 90)
        XCTAssertEqual(profile.reclaimedHoursBeforeExam, 45)
        profile.ageBracket = .age55plus
        XCTAssertEqual(profile.phoneHoursBeforeExam, 90)
        profile.baseline = .underTwo
        profile.setTimeBackMinutes(500)
        XCTAssertLessThanOrEqual(profile.reclaimedHoursBeforeExam, Double(profile.phoneHoursBeforeExam))
    }

    func testExamCountdownHandlesDSTTodayAndPastDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 15))!
        var profile = SGV5V5OnboardingProfile()
        profile.examDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        XCTAssertEqual(profile.daysUntilExam(from: now, calendar: calendar), 2)
        XCTAssertTrue(profile.hasUpcomingExam(from: now, calendar: calendar))
        profile.examDate = calendar.startOfDay(for: now)
        XCTAssertEqual(profile.daysUntilExam(from: now, calendar: calendar), 0)
        XCTAssertTrue(profile.hasUpcomingExam(from: now, calendar: calendar))
        profile.examDate = calendar.date(byAdding: .day, value: -1, to: now)
        XCTAssertEqual(profile.daysUntilExam(from: now, calendar: calendar), 0)
        XCTAssertFalse(profile.hasUpcomingExam(from: now, calendar: calendar))
    }

    func testStudyDetailsAndExamPersistAndOldDraftsDecode() throws {
        var profile = SGV5V5OnboardingProfile()
        profile.studyLevel = .university
        profile.subject = "  Biology  "
        profile.examDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        XCTAssertEqual(profile.studySubject, "Biology")
        XCTAssertTrue(profile.canContinue(from: .goal))
        XCTAssertTrue(profile.canContinue(from: .subject))
        XCTAssertTrue(profile.canContinue(from: .habit))
        let data = try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(SGV5V5OnboardingProfile.self, from: data), profile)
        var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for key in ["studyLevel", "subject", "examDate"] { old.removeValue(forKey: key) }
        let oldData = try JSONSerialization.data(withJSONObject: old)
        let restored = try JSONDecoder().decode(SGV5V5OnboardingProfile.self, from: oldData)
        XCTAssertFalse(restored.canContinue(from: .goal))
        XCTAssertFalse(restored.canContinue(from: .subject))
        XCTAssertFalse(restored.canContinue(from: .habit))
        profile.subject = "   "
        XCTAssertTrue(profile.canContinue(from: .goal))
        XCTAssertFalse(profile.canContinue(from: .subject))
        XCTAssertFalse(profile.isReady)
    }

    func testStudyRulesEarnExactlyFiveMinutesForEverySupportedChoice() throws {
        var profile = SGV5V5OnboardingProfile()
        profile.subject = "Criminal Law"
        XCTAssertEqual(profile.studyCardCount, 5)
        XCTAssertEqual(profile.studyPerCardSeconds, 60)
        for (rule, seconds) in [(SGV5V5OnboardingProfile.StudyRule.five, 60), (.ten, 30), (.twenty, 15)] {
            profile.studyRule = rule
            XCTAssertEqual(profile.studyPerCardSeconds, seconds)
            let completed = Array<Bool?>(repeating: true, count: rule.rawValue)
            XCTAssertEqual(SGContract.completedQuizMinutes(results: completed, perCardSeconds: seconds), 5)
            XCTAssertEqual(SGContract.earnedMinutes(cardCount: rule.rawValue * 2, perCardSeconds: seconds), 10)
            XCTAssertEqual(SGContract.completedQuizMinutes(results: [true, nil], perCardSeconds: seconds), 0)
            XCTAssertEqual(SGContract.completedQuizMinutes(results: [false], perCardSeconds: seconds), 0)
            XCTAssertEqual(profile.habitAction, "Review \(rule.rawValue) Criminal Law flashcards")
            XCTAssertEqual(profile.studyRuleSummary, "\(rule.rawValue) correct flashcards → 5 minutes")
            let restored = try JSONDecoder().decode(SGV5V5OnboardingProfile.self, from: JSONEncoder().encode(profile))
            XCTAssertEqual(restored.selectedStudyRule, rule)
        }
    }

    func testOlderDraftWithoutStudyRuleDefaultsToOneMinutePerCard() throws {
        var profile = SGV5V5OnboardingProfile()
        profile.subject = "Biology"
        profile.studyRule = .twenty
        let data = try JSONEncoder().encode(profile)
        var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        old.removeValue(forKey: "studyRule")
        let restored = try JSONDecoder().decode(SGV5V5OnboardingProfile.self,
            from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.studyRule)
        XCTAssertEqual(restored.studyCardCount, 5)
        XCTAssertEqual(restored.studyPerCardSeconds, 60)
        XCTAssertEqual(restored.studyRewardSummary, "1 minute per correct card")
        XCTAssertEqual(restored.subject, "Biology")
    }

    func testExtraStudyHoursReplacePartOfTheSameScrollingWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!
        var profile = SGV5V5OnboardingProfile()
        profile.examDate = calendar.date(byAdding: .day, value: 30, to: now)
        profile.baseline = .twoToFour // 90 hours in the existing phone window.
        for (rule, hours) in [(SGV5V5OnboardingProfile.StudyRule.five, 30.0), (.ten, 45.0), (.twenty, 60.0)] {
            profile.studyRule = rule
            XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), hours, accuracy: 0.0001)
        }
        for baseline in SGV5V5OnboardingProfile.Baseline.allCases {
            profile.baseline = baseline
            var previous = 0.0
            for rule in SGV5V5OnboardingProfile.StudyRule.allCases {
                profile.studyRule = rule
                let study = profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar)
                let phoneWindow = Double(30 * profile.estimatedDailyHours)
                let remainingScroll = study / profile.projectedStudyMinutesPerUnlock * 5
                XCTAssertGreaterThan(study, previous)
                XCTAssertLessThan(study, phoneWindow)
                XCTAssertEqual(study + remainingScroll, phoneWindow, accuracy: 0.0001)
                previous = study
            }
        }
        profile.examDate = now
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 0)
        profile.examDate = calendar.date(byAdding: .day, value: -1, to: now)
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 0)
        profile.examDate = nil
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 0)
    }

    func testStudyProjectionUsesCalendarDaysAcrossDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 15))!
        var profile = SGV5V5OnboardingProfile()
        profile.baseline = .twoToFour
        profile.examDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 2)
        profile.examDate = calendar.date(byAdding: .day, value: 3650, to: now)
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 3650)
    }

    @MainActor
    func testPracticeContinuesDirectlyToOfferWithOneMinutePerCorrectCard() {
        let suite = "BuddyRule.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.currentPageIndex = 823
        model.buddy.phase = .practiceReview
        model.buddy.practicePassed = true
        model.buddyContinueToOffer()
        XCTAssertEqual(model.buddy.phase, .offer)
        XCTAssertEqual(SGContract.perCardSeconds(defaults), 60)
        XCTAssertEqual(defaults.integer(forKey: "flashcardCount"), 5)
        XCTAssertTrue(defaults.bool(forKey: BuddyIdentity.ruleKey))
        XCTAssertFalse(defaults.bool(forKey: "useAllCards"))
        XCTAssertEqual(model.v5Profile.studyRewardSummary, "1 minute per correct card")
        XCTAssertEqual(SGContract.completedQuizMinutes(results: [true, false, true], perCardSeconds: SGContract.perCardSeconds(defaults)), 2)
        XCTAssertEqual(SGContract.completedQuizMinutes(results: [true, nil], perCardSeconds: SGContract.perCardSeconds(defaults)), 0)
        XCTAssertFalse(model.buddy.entries.contains(where: \.isUser), "Do not fabricate a rate-selection answer")
        let count = model.buddy.entries.count
        model.buddyContinueToOffer()
        XCTAssertEqual(model.buddy.entries.count, count)
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        XCTAssertEqual(restored.v5Profile.selectedStudyRule, .five)
        XCTAssertEqual(restored.buddy.phase, .offer)
        restored.buddyShowOffer()
        XCTAssertEqual(restored.currentPageIndex, 506, "Subscription verification still gates setup")
    }

    @MainActor
    func testSavedRemovedRuleQuestionResumesAtOfferWithoutRepeatingIt() {
        let suite = "BuddyRemovedRule.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.buddy.personaID = model.buddyPersona.id
        model.buddy.phase = .rule
        model.buddy.practicePassed = true
        model.v5Profile.studyRule = .twenty
        model.buddySay("Practice complete.")
        let savedID = model.buddy.entries[0].id
        model.buddySay("A few correct cards before you scroll. What feels doable? Each choice earns five minutes when you get that many right. Shorter rounds earn proportionally.")
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        restored.buddyBegin()
        XCTAssertEqual(restored.buddy.phase, .offer)
        XCTAssertEqual(restored.v5Profile.studyPerCardSeconds, 60)
        XCTAssertEqual(SGContract.perCardSeconds(defaults), 60)
        XCTAssertEqual(restored.buddy.entries.first?.id, savedID)
        XCTAssertEqual(restored.buddy.entries.count, 2)
        XCTAssertFalse(restored.buddy.entries.contains { $0.text.contains("What feels doable?") })
        restored.buddyBegin()
        XCTAssertEqual(restored.buddy.entries.count, 2)
    }

    @MainActor
    func testRemovedRuleCannotSkipUnfinishedPracticeOnResume() {
        let suite = "BuddyRemovedRuleBoundary.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        model.buddy.phase = .rule
        model.buddy.practiceCard = SGV5FlowModel.buddySampleCards[0]
        model.buddyBegin()
        XCTAssertEqual(model.buddy.phase, .practice)
        XCTAssertFalse(model.buddy.practicePassed)
        XCTAssertFalse(model.accessVerified)
    }

    func testOriginalWelcomeVideoIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "mockupvideo", withExtension: "mp4"))
    }

    @MainActor
    func testNotesUploadComesBeforeExamAndSubjectIsDerivedFromNotes() async throws {
        let suite = "BuddyQuestions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let storeDefaults = UserDefaults(suiteName: "\(suite).decks")!
        defer { storeDefaults.removePersistentDomain(forName: "\(suite).decks") }
        let store = DeckStore(defaults: storeDefaults)
        let exams = ExamStore(defaults: storeDefaults, sharedDefaults: nil)
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.currentPageIndex = 823
        model.buddy.phase = .level
        model.buddyChooseLevel(.university)
        // Notes come right after study level; the subject is not asked.
        XCTAssertEqual(model.buddy.phase, .materials)
        XCTAssertTrue(model.v5Profile.studySubject.isEmpty)

        // Simulate uploaded notes: a draft deck whose generated cards carry a topic.
        let draftID = model.buddyPrepareDeck(in: store)
        XCTAssertEqual(store.decks.first { $0.id == draftID }?.name, "My study notes")
        var draft = store.decks.first { $0.id == draftID }!
        draft.cards = [
            Regret(regretPrompt: "What is the powerhouse of the cell?", regret: "Mitochondrion",
                   choices: ["Nucleus", "Mitochondrion", "Ribosome"], correctAnswerIndex: 1,
                   backgroundExplanation: "Mitochondria produce most of the cell's ATP.", topic: "Cell Biology"),
            Regret(regretPrompt: "Where is DNA stored in a eukaryotic cell?", regret: "Nucleus",
                   choices: ["Nucleus", "Cytoplasm", "Ribosome"], correctAnswerIndex: 0,
                   backgroundExplanation: "The nucleus holds the cell's DNA.", topic: "Cell Biology")
        ]
        store.updateDeck(draft)
        model.buddyUseDeck(store.decks.first { $0.id == draftID }!, in: store)
        XCTAssertEqual(model.v5Profile.studySubject, "Cell Biology", "Subject is read from the notes")
        XCTAssertEqual(store.decks.first { $0.id == draftID }?.name, "Cell Biology", "Deck is named after the subject")
        XCTAssertEqual(model.buddy.phase, .exam, "Exam date comes after the upload")
        XCTAssertTrue(model.buddy.entries.contains { !$0.isUser && $0.text.contains("Cell Biology") })

        model.buddySubmitText("   ")
        XCTAssertEqual(model.buddy.phase, .exam)
        let date = Calendar.current.date(byAdding: .day, value: 20, to: Date())!
        model.buddyChooseExam(date, exams: exams)
        XCTAssertEqual(model.buddy.phase, .practice)
        XCTAssertEqual(model.v5Profile.examDate.map { Calendar.current.startOfDay(for: $0) },
                       Calendar.current.startOfDay(for: date))
        XCTAssertEqual(exams.exams.count, 1)
        XCTAssertEqual(exams.exams.first?.subject, "Cell Biology")
        XCTAssertEqual(exams.exams.first?.deckIDs, [draftID])

        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        XCTAssertEqual(restored.v5Profile.studySubject, "Cell Biology")
        XCTAssertEqual(restored.buddy.phase, .practice)
        XCTAssertEqual(restored.currentPageIndex, 823)
    }

    @MainActor
    func testSampleDeckSetsSubjectButIsNeverLinkedToTheUsersExam() {
        let suite = "BuddySample.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let storeDefaults = UserDefaults(suiteName: "\(suite).decks")!
        defer { storeDefaults.removePersistentDomain(forName: "\(suite).decks") }
        let store = DeckStore(defaults: storeDefaults)
        let exams = ExamStore(defaults: storeDefaults, sharedDefaults: nil)
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.buddy.phase = .materials
        model.buddyUseSample(in: store)
        XCTAssertEqual(model.buddy.phase, .exam)
        XCTAssertEqual(model.v5Profile.studySubject, "Biology")
        let date = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        model.buddyChooseExam(date, exams: exams)
        XCTAssertTrue(exams.exams.isEmpty, "A sample deck must not inherit the user's real exam")
        XCTAssertEqual(model.buddy.phase, .practice)
    }

    @MainActor
    func testQuestionsRequireAnAnswerAndOrdinaryAdvanceCannotBypassPaywall() {
        let suite = "BuddyBoundary.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.currentPageIndex = 823
        model.buddySubmitText("  ")
        XCTAssertEqual(model.buddy.phase, .name)
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, 823)
        model.buddy.phase = .practiceReview
        model.buddyContinueToOffer()
        XCTAssertEqual(model.buddy.phase, .practiceReview, "Practice must finish before the offer")
        model.currentPageIndex = 506
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, 506)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    @MainActor
    func testProfilePersistsAndDoubleTapOnlyAdvancesOnce() {
        let suite = "OnboardingV5Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.v5Profile.goal = .learning
        model.v5Profile.baseline = .twoToFour
        model.v5Profile.setTimeBackMinutes(60)
        model.nextPage()
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, 824)
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        XCTAssertEqual(restored.v5Profile.goal, .learning)
        XCTAssertEqual(restored.v5Profile.timeBackMinutes, 60)
        XCTAssertEqual(restored.currentPageIndex, 824)
    }

    func testAnnualPhoneTimeUsesStatedEstimateAndFullDays() {
        var profile = SGV5V5OnboardingProfile()
        let cases: [(SGV5V5OnboardingProfile.Baseline, Int)] = [
            (.underTwo, 365), (.twoToFour, 1095), (.fourToSix, 1825), (.sixPlus, 2190)
        ]
        for (baseline, hours) in cases {
            profile.baseline = baseline
            XCTAssertEqual(profile.yearlyPhoneHours, hours)
            XCTAssertEqual(profile.yearlyPhoneDays * 24, Double(hours), accuracy: 0.0001)
            XCTAssertFalse(profile.phoneEstimateIsExample)
        }
        profile.baseline = .unsure
        XCTAssertTrue(profile.phoneEstimateIsExample)
        XCTAssertEqual(profile.yearlyPhoneHours, 1460)
        XCTAssertTrue(profile.phoneEstimateExplanation.contains("not measured"))
        profile.baseline = nil
        XCTAssertFalse(profile.canContinue(from: .baseline))
        XCTAssertTrue(profile.phoneEstimateIsExample)
    }

    func testProgressIncludesIntroAndContinuesThroughChat() {
        let steps = SGV5V5OnboardingStep.prePaywallSteps
        XCTAssertEqual(Array(steps.dropFirst().prefix(3)), [.howGuard, .howStudy, .personalize])
        XCTAssertFalse(steps.contains(.howEarn))
        XCTAssertFalse(BuddyOnboardingPhase.activePhases.contains(.rule))
        XCTAssertFalse(BuddyOnboardingPhase.activePhases.contains(.subject), "Subject is detected from notes, not a screen")
        XCTAssertEqual(SGV5V5OnboardingStep.progressCount, 20)
        XCTAssertGreaterThan(BuddyOnboardingPhase.name.progress, SGV5V5OnboardingStep.persona.progress)
        XCTAssertEqual(BuddyOnboardingPhase.notifications.progress, 1)
        XCTAssertEqual(BuddyOnboardingPhase.name.screenNumber, 10)
        // Upload notes (materials) now comes before the exam date in the flow.
        XCTAssertLessThan(BuddyOnboardingPhase.materials.screenNumber, BuddyOnboardingPhase.exam.screenNumber)
    }

    @MainActor
    func testRetiredEarnIntroResumesAtCombinedStudyPage() {
        let suite = "BuddyCondensedIntro.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(SGV5V5OnboardingStep.howEarn.rawValue, forKey: "sg_buddyOnboardingPage")
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: nil)
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.howStudy.rawValue)
        model.nextPage()
        XCTAssertEqual(model.currentPageIndex, SGV5V5OnboardingStep.personalize.rawValue)
    }
}
