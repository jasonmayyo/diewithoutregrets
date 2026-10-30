import XCTest
@testable import diewithoutregrets

final class MonsterShieldTests: XCTestCase {
    private var local: UserDefaults!
    private var shared: UserDefaults!
    private var suites: [String] = []
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        suites = ["test.monster-local.\(UUID())", "test.monster-shared.\(UUID())"]
        local = UserDefaults(suiteName: suites[0])
        shared = UserDefaults(suiteName: suites[1])
    }

    override func tearDown() {
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    }

    func testHomeUnlockButtonCoversBlockedAndZeroTimeButNotDisabledOrSetup() {
        XCTAssertTrue(GuardState.locked.offersStudyUnlock(remainingMinutes: 0))
        XCTAssertTrue(GuardState.locked.offersStudyUnlock(remainingMinutes: 15))
        XCTAssertTrue(GuardState.metering.offersStudyUnlock(remainingMinutes: 0))
        XCTAssertFalse(GuardState.metering.offersStudyUnlock(remainingMinutes: 1))
        XCTAssertFalse(GuardState.disabled.offersStudyUnlock(remainingMinutes: 0))
        XCTAssertFalse(GuardState.notSetUp.offersStudyUnlock(remainingMinutes: 0))
    }

    func testManualHomeUnlockOpensMonsterWithoutAShieldTapOrStaleReturnTarget() {
        let navigation = NavigationModel()
        navigation.unlockReturnDestination = .app(bundleIdentifier: "com.example.previous")
        navigation.openMonsterFromHome()
        XCTAssertEqual(navigation.currentDestination, .regretView)
        XCTAssertEqual(navigation.unlockMethodOverride, "monster")
        XCTAssertNil(navigation.unlockReturnDestination)
        XCTAssertFalse(navigation.isLockStampPlaying)
        navigation.returnHome()
        XCTAssertNil(navigation.currentDestination)
    }

    func testLockedBudgetFromYesterdayStillShowsZeroRemaining() {
        seedLockedBudget(grantedAt: now.addingTimeInterval(-86_400))
        let budget = GuardBudgetSnapshot(from: shared, state: GuardState.derive(from: shared), now: now)
        XCTAssertEqual(budget.totalMinutes, 15)
        XCTAssertEqual(budget.usedMinutes, 15)
        XCTAssertEqual(budget.remainingMinutes, 0)
        // A display refresh must not grant time or rewrite the retained lock.
        XCTAssertEqual(shared.double(forKey: SGContract.Keys.budgetGrantedAt), now.timeIntervalSince1970 - 86_400)
        XCTAssertEqual(GuardState.derive(from: shared), .locked)
    }

    func testLockedBudgetWithoutGrantOrUsageStillShowsZeroRemaining() {
        seedLockedBudget(grantedAt: now)
        shared.removeObject(forKey: SGContract.Keys.budgetGrantedAt)
        shared.removeObject(forKey: SGContract.Keys.budgetUsedSeconds)
        let budget = GuardBudgetSnapshot(from: shared, state: GuardState.derive(from: shared), now: now)
        XCTAssertEqual(budget.remainingMinutes, 0)
        XCTAssertEqual(budget.usedMinutes, 15)
    }

    func testLockedBudgetWithoutTotalUsesIntervalAndStillShowsZero() {
        seedLockedBudget(grantedAt: now)
        shared.removeObject(forKey: SGContract.Keys.budgetTotalSeconds)
        shared.set(30, forKey: SGContract.Keys.intervalMinutes)
        let budget = GuardBudgetSnapshot(from: shared, state: .locked, now: now)
        XCTAssertEqual(budget.totalMinutes, 30)
        XCTAssertEqual(budget.remainingMinutes, 0)
    }

    func testTodaysMeteringBudgetRetainsActualUsageAndFreshGrant() {
        seedLockedBudget(grantedAt: now)
        shared.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
        shared.set(420.0, forKey: SGContract.Keys.budgetUsedSeconds)
        let budget = GuardBudgetSnapshot(from: shared, state: GuardState.derive(from: shared), now: now)
        XCTAssertEqual(budget.usedMinutes, 7)
        XCTAssertEqual(budget.remainingMinutes, 8)
        shared.set(180.0, forKey: SGContract.Keys.budgetTotalSeconds)
        shared.set(0.0, forKey: SGContract.Keys.budgetUsedSeconds)
        XCTAssertEqual(GuardBudgetSnapshot(from: shared, state: .metering, now: now).remainingMinutes, 3)
    }

    func testStaleMeteringUsageStillResetsForDisplay() {
        seedLockedBudget(grantedAt: now.addingTimeInterval(-86_400))
        shared.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
        let budget = GuardBudgetSnapshot(from: shared, state: GuardState.derive(from: shared), now: now)
        XCTAssertEqual(budget.remainingMinutes, 15)
        XCTAssertEqual(budget.usedMinutes, 0)
    }

    func testLockKeyAloneCannotBypassSetupOrEnableADisabledGuard() {
        seedLockedBudget(grantedAt: now)
        shared.set(false, forKey: SGContract.Keys.setupComplete)
        XCTAssertEqual(GuardState.derive(from: shared), .notSetUp)
        shared.set(true, forKey: SGContract.Keys.setupComplete)
        shared.set(false, forKey: SGContract.Keys.guardEnabled)
        XCTAssertEqual(GuardState.derive(from: shared), .disabled)
    }

    private func seedLockedBudget(grantedAt: Date) {
        shared.set(true, forKey: SGContract.Keys.setupComplete)
        shared.set(true, forKey: SGContract.Keys.guardEnabled)
        shared.set(SGContract.StateValue.locked, forKey: SGContract.Keys.state)
        shared.set(grantedAt.timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
        shared.set(900.0, forKey: SGContract.Keys.budgetTotalSeconds)
        shared.set(900.0, forKey: SGContract.Keys.budgetUsedSeconds)
    }

    func testExistingChoiceMigratesAndEachNewChoiceReachesTheShield() {
        local.set("gremlin", forKey: SGContract.Keys.selectedPersonaID)
        let store = PersonaStore(defaults: local, sharedDefaults: shared)
        XCTAssertEqual(MonsterPersona.selected(in: shared), .gremlin)
        for persona in MonsterPersona.all {
            store.select(persona)
            XCTAssertEqual(MonsterPersona.selected(in: shared), persona)
            XCTAssertEqual(local.string(forKey: SGContract.Keys.selectedPersonaID), persona.id)
        }
    }

    func testMissingAndUnknownSelectionsUseWillow() {
        XCTAssertEqual(MonsterPersona.selected(in: shared), .willow)
        local.set("unknown", forKey: SGContract.Keys.selectedPersonaID)
        let store = PersonaStore(defaults: local, sharedDefaults: shared)
        XCTAssertEqual(store.persona, .willow)
        XCTAssertEqual(MonsterPersona.selected(in: shared), .willow)
    }

    func testAppChoiceWinsOverAnOldSharedChoice() {
        local.set("coach", forKey: SGContract.Keys.selectedPersonaID)
        shared.set("diva", forKey: SGContract.Keys.selectedPersonaID)
        let store = PersonaStore(defaults: local, sharedDefaults: shared)
        XCTAssertEqual(store.persona, .coach)
        XCTAssertEqual(MonsterPersona.selected(in: shared), .coach)
    }

    func testCopyNamesTheSelectedMonsterAndActualDestination() {
        for persona in MonsterPersona.all {
            let copy = MonsterShieldCopy(persona: persona, applicationName: " Instagram ")
            XCTAssertEqual(copy.title, "\(persona.name) has locked Instagram")
            XCTAssertEqual(copy.button, "Ask Permission")
            XCTAssertTrue(copy.subtitle.contains("Chat with \(persona.name)"))
            XCTAssertTrue(copy.subtitle.contains("flashcards"))
            XCTAssertTrue(copy.subtitle.hasSuffix("Instagram."))
        }
    }

    func testUnknownAppsAndWebsitesDoNotGuessInstagram() {
        for name: String? in [nil, "", "  \n"] {
            XCTAssertEqual(MonsterShieldCopy(persona: .diva, applicationName: name).title,
                           "Zaza has locked this app")
        }
        XCTAssertEqual(MonsterShieldCopy(persona: .coach, applicationName: nil, fallback: "this website").title,
                       "Sarge has locked this website")
        XCTAssertEqual(MonsterShieldCopy(persona: .gremlin, applicationName: "youtube.com").destination, "youtube.com")
    }

    func testColdLaunchCanPeekBeforeActivationConsumesExactlyOnce() {
        seedTap()
        XCTAssertTrue(ShieldChatHandoff.shouldOpenChat(in: shared, now: now))
        XCTAssertTrue(ShieldChatHandoff.shouldOpenChat(in: shared, now: now))
        XCTAssertTrue(ShieldChatHandoff.consume(in: shared, now: now))
        XCTAssertFalse(ShieldChatHandoff.consume(in: shared, now: now))
    }

    func testExpiredFutureAndMissingTapsCannotRoute() {
        for age in [-1.0, 120.0, 300.0] {
            seedTap()
            XCTAssertFalse(ShieldChatHandoff.consume(in: shared, now: now.addingTimeInterval(age)))
            XCTAssertNil(shared.object(forKey: SGContract.Keys.shieldTapAt))
        }
        XCTAssertFalse(ShieldChatHandoff.shouldOpenChat(in: shared, now: now))
    }

    func testUnlockedOrDisabledGuardDoesNotReviveAChat() {
        seedTap()
        shared.set(SGContract.StateValue.metering, forKey: SGContract.Keys.state)
        XCTAssertFalse(ShieldChatHandoff.consume(in: shared, now: now))
        seedTap()
        shared.set(false, forKey: SGContract.Keys.guardEnabled)
        XCTAssertFalse(ShieldChatHandoff.consume(in: shared, now: now))
    }

    @MainActor
    func testLockAnimationRevealsMonsterWithoutASecondTap() throws {
        let navigation = NavigationModel()
        navigation.unlockMethodOverride = "trueFocus"
        XCTAssertTrue(navigation.beginMonsterLockEntry(grantStamp: 10, animated: true))
        let animation = try XCTUnwrap(navigation.monsterLockAnimationID)
        XCTAssertNil(navigation.currentDestination)
        navigation.revealMonsterAfterLock(animationID: animation)
        XCTAssertEqual(navigation.currentDestination, .regretView)
        XCTAssertEqual(navigation.unlockMethodOverride, "monster")
        XCTAssertTrue(navigation.isLockStampPlaying) // overlay survives the root swap
        navigation.finishMonsterLockAnimation(animationID: animation)
        XCTAssertFalse(navigation.isLockStampPlaying)
        XCTAssertNil(navigation.monsterLockAnimationID)
    }

    @MainActor
    func testClosingAutomaticChatDoesNotReopenUntilANewGrant() {
        let navigation = NavigationModel()
        XCTAssertTrue(navigation.beginMonsterLockEntry(grantStamp: 10, animated: false))
        XCTAssertEqual(navigation.unlockMethodOverride, "monster")
        navigation.returnHome()
        XCTAssertFalse(navigation.beginMonsterLockEntry(grantStamp: 10, animated: false))
        XCTAssertNil(navigation.currentDestination)
        XCTAssertTrue(navigation.beginMonsterLockEntry(grantStamp: 20, animated: true))
    }

    @MainActor
    func testShieldEntryCancelsAnimationAndDoesNotReopenAfterClosing() throws {
        let navigation = NavigationModel()
        navigation.beginMonsterLockEntry(grantStamp: 10, animated: true)
        let oldAnimation = try XCTUnwrap(navigation.monsterLockAnimationID)
        navigation.openMonsterFromShield(returnDestination: nil, grantStamp: 10)
        navigation.returnHome()
        navigation.revealMonsterAfterLock(animationID: oldAnimation)
        XCTAssertNil(navigation.currentDestination)
        XCTAssertFalse(navigation.beginMonsterLockEntry(grantStamp: 10, animated: false))
    }

    @MainActor
    func testResetRearmsDebugLockAndIgnoresOldAnimationCallbacks() throws {
        let navigation = NavigationModel()
        navigation.beginMonsterLockEntry(grantStamp: 10, animated: true)
        let oldAnimation = try XCTUnwrap(navigation.monsterLockAnimationID)
        navigation.resetAutomaticMonsterEntry()
        XCTAssertTrue(navigation.beginMonsterLockEntry(grantStamp: 10, animated: true))
        let currentAnimation = try XCTUnwrap(navigation.monsterLockAnimationID)
        navigation.revealMonsterAfterLock(animationID: oldAnimation)
        navigation.finishMonsterLockAnimation(animationID: oldAnimation)
        XCTAssertNil(navigation.currentDestination)
        XCTAssertEqual(navigation.monsterLockAnimationID, currentAnimation)
        XCTAssertTrue(navigation.isLockStampPlaying)
    }

    @MainActor
    func testAutomaticEntryDoesNotInterruptAnExistingFlow() {
        let navigation = NavigationModel()
        navigation.activeWipe = .unlock
        XCTAssertFalse(navigation.beginMonsterLockEntry(grantStamp: 10, animated: true))
        navigation.activeWipe = nil
        navigation.navigate(to: .regretView)
        XCTAssertFalse(navigation.beginMonsterLockEntry(grantStamp: 10, animated: true))
    }

    @MainActor
    func testDirectRouteSkipsHomeAndClearsPendingWipe() {
        let navigation = NavigationModel()
        navigation.unlockMethodOverride = "trueFocus"
        navigation.activeWipe = .lock
        navigation.wipeMidAction = { XCTFail("An old home transition must not run") }
        navigation.openMonsterFromShield(returnDestination: nil)
        XCTAssertEqual(navigation.currentDestination, .regretView)
        XCTAssertEqual(navigation.unlockMethodOverride, "monster")
        XCTAssertNil(navigation.activeWipe)
        XCTAssertNil(navigation.wipeMidAction)
        navigation.returnHome()
        XCTAssertNil(navigation.currentDestination)
        XCTAssertNil(navigation.unlockMethodOverride)
    }

    private func seedTap() {
        shared.set(now.timeIntervalSince1970, forKey: SGContract.Keys.shieldTapAt)
        shared.set(true, forKey: SGContract.Keys.guardEnabled)
        shared.set(SGContract.StateValue.locked, forKey: SGContract.Keys.state)
    }
}
