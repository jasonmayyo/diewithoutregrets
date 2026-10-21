import XCTest
@testable import diewithoutregrets

final class OnboardingV5Tests: XCTestCase {
    func testCurrentSourceOrderIncludesAgeAndLatestSetup() {
        XCTAssertEqual(SGV5V5OnboardingStep.flowOrder,
                       [800, 813, 803, 804, 805, 806, 820, 807, 810, 819,
                        818, 808, 817, 812, 801, 814, 815, 816, 506, 601, 602, 606, 604])
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
        XCTAssertEqual(profile.studyCardCount, 10)
        XCTAssertEqual(profile.studyPerCardSeconds, 30)
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

    func testOlderDraftWithoutStudyRuleDefaultsToTenCards() throws {
        var profile = SGV5V5OnboardingProfile()
        profile.subject = "Biology"
        profile.studyRule = .twenty
        let data = try JSONEncoder().encode(profile)
        var old = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        old.removeValue(forKey: "studyRule")
        let restored = try JSONDecoder().decode(SGV5V5OnboardingProfile.self,
            from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.studyRule)
        XCTAssertEqual(restored.studyCardCount, 10)
        XCTAssertEqual(restored.studyPerCardSeconds, SGContract.defaultPerCardSeconds)
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
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 3)
        profile.examDate = calendar.date(byAdding: .day, value: 3650, to: now)
        XCTAssertEqual(profile.projectedStudyHoursBeforeExam(from: now, calendar: calendar), 5475)
    }

    @MainActor
    func testConfirmingRuleUpdatesRealRateQuizSizeAndRestoresSelection() {
        let suite = "OnboardingV5Tests.\(UUID().uuidString)"
        let groupSuite = suite + ".group"
        let defaults = UserDefaults(suiteName: suite)!
        let group = UserDefaults(suiteName: groupSuite)!
        defer { defaults.removePersistentDomain(forName: suite); group.removePersistentDomain(forName: groupSuite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: group)
        model.currentPageIndex = 812
        defaults.set(true, forKey: "useAllCards")
        model.confirmStudyRule()
        XCTAssertEqual(model.currentPageIndex, 801)
        XCTAssertEqual(SGContract.perCardSeconds(group), 30)
        XCTAssertEqual(defaults.integer(forKey: "flashcardCount"), 10)
        XCTAssertFalse(defaults.bool(forKey: "useAllCards"))
        for rule in [SGV5V5OnboardingProfile.StudyRule.five, .twenty, .ten] {
            model.previousPage()
            XCTAssertEqual(model.currentPageIndex, 812)
            model.v5Profile.studyRule = rule
            model.confirmStudyRule()
            XCTAssertEqual(model.currentPageIndex, 801)
            XCTAssertEqual(SGContract.perCardSeconds(group), rule.secondsPerCard)
            XCTAssertEqual(defaults.integer(forKey: "flashcardCount"), rule.rawValue)
            XCTAssertEqual(model.v5ExampleRewardMinutes, 5)
            let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: group)
            XCTAssertEqual(restored.v5Profile.selectedStudyRule, rule)
            XCTAssertEqual(SGContract.earnedMinutes(cardCount: rule.rawValue,
                perCardSeconds: SGContract.perCardSeconds(group)), 5)
        }
    }

    func testOriginalWelcomeVideoIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "mockupvideo", withExtension: "mp4"))
    }

    @MainActor
    func testRequiredSubjectComesAfterDemoAndBeforeExamDate() async throws {
        let suite = "OnboardingV5Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.currentPageIndex = 803
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 803)
        model.v5Profile.studyLevel = .university
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 804)
        model.currentPageIndex = 806
        try await Task.sleep(for: .milliseconds(500))
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 820)
        try await Task.sleep(for: .milliseconds(500))
        model.v5Profile.subject = "   "
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 820)
        model.v5Profile.subject = "Criminal Law"
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 807)
        model.previousPage()
        XCTAssertEqual(model.currentPageIndex, 820)
        model.previousPage()
        XCTAssertEqual(model.currentPageIndex, 806)
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        XCTAssertEqual(restored.v5Profile.studyLevel, .university)
        XCTAssertEqual(restored.v5Profile.subject, "Criminal Law")
    }

    @MainActor
    func testQuestionsRequireAnAnswerAndOrdinaryAdvanceCannotBypassPaywall() {
        let suite = "OnboardingV5Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        model.currentPageIndex = 819
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 819)
        model.v5Profile.ageBracket = .age25to34
        model.advanceV5()
        XCTAssertEqual(model.currentPageIndex, 818)
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
        XCTAssertEqual(model.currentPageIndex, 813)
        let restored = SGV5FlowModel(defaults: defaults, sharedDefaults: defaults)
        XCTAssertEqual(restored.v5Profile.goal, .learning)
        XCTAssertEqual(restored.v5Profile.timeBackMinutes, 60)
        XCTAssertEqual(restored.currentPageIndex, 800)
    }
}
