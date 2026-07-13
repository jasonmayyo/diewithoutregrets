import SwiftUI
import Sentry
import BranchSDK
import RevenueCat
import PostHog
import UIKit
import UserNotifications
import AppTrackingTransparency
import TikTokBusinessSDK
import FamilyControls

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Sentry must initialize FIRST so its crash handlers install before
        // anything else (RevenueCat, Branch, PostHog, TikTok) can crash.
        startSentry()

        print("[AppDelegate] didFinishLaunchingWithOptions")

        // Configure RevenueCat before attribution callbacks can set attributes.
        Purchases.configure(withAPIKey: "appl_ArMMMNZWiwLJiQVDcmVCwLigzmG")

        // RevenueCat assigns an anonymous appUserID at first launch, which
        // is the same ID PostHog identifies with. Reuse it for Sentry user
        // attribution so a crash report can be tied back to a PostHog user.
        let user = User()
        user.userId = Purchases.shared.appUserID
        SentrySDK.setUser(user)
        
        // Initialize Branch with BranchScene for SwiftUI (deep linking only).
        BranchScene.shared().initSession(launchOptions: launchOptions) { params, error, scene in
            if let error = error {
                print("Branch init failed: \(error.localizedDescription)")
            }
            let data = params as? [String: Any] ?? [:]

            var attrs = [String: String]()
            if let influencer = data["$influencer"] as? String {
                attrs["influencer"] = influencer
                print("Branch data found - influencer: \(influencer)")
            }
            if let campaign = (data["+campaign"] as? String) ?? (data["~campaign"] as? String) {
                attrs["campaign"] = campaign
                print("Branch data found - campaign: \(campaign)")
            }
            if let channel = data["~channel"] as? String {
                attrs["channel"] = channel
                print("Branch data found - channel: \(channel)")
            }
            if let feature = data["~feature"] as? String {
                attrs["feature"] = feature
                print("Branch data found - feature: \(feature)")
            }
            if !attrs.isEmpty {
                Purchases.shared.setAttributes(attrs)
                print("Setting RevenueCat attributes: \(attrs)")
            } else {
                print("No influencer or campaign data found in Branch params.")
            }
        }

        // Configure PostHog
        let POSTHOG_API_KEY = "phc_CzbpdC9g3azt6oI4GBppF8b9C6x7wA7MkbllkaDCt9D"
        let POSTHOG_HOST = "https://us.i.posthog.com"
        let posthogConfig = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        posthogConfig.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(posthogConfig)
        PostHogSDK.shared.identify(Purchases.shared.appUserID)

        // Stamp Sentry's scope with PostHog identifiers so a Sentry issue
        // can be jumped from to the matching PostHog session replay. Keep
        // this in sync on app foreground (PostHog rotates session IDs after
        // 30 minutes of inactivity).
        attachPostHogIdentifiersToSentry()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForegroundRefreshSentryScope),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            Analytics.capture("first_app_open")
        }

        // Initialize TikTok Business SDK for Spark Ads attribution.
        AdsTracker.initializeSDK()
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Note: Notification permissions are requested during onboarding flow

        return true
    }

    // MARK: - Sentry

    /// Initialize Sentry. Called as the very first thing in
    /// `didFinishLaunchingWithOptions` so its crash handlers are armed before
    /// any other SDK has a chance to crash.
    ///
    /// Sample-rate decisions, bundled here for one-stop tweaking:
    ///   • sessionReplay.sessionSampleRate = 0   — never replay random sessions
    ///   • sessionReplay.onErrorSampleRate = 1   — always replay around errors
    ///   • tracesSampleRate                = 0   — Performance disabled for now
    ///   • sendDefaultPii                  = false — no IP / UA harvesting
    ///   • beforeSend                      → drops every event in DEBUG so
    ///     local dev never pollutes the dashboard
    private func startSentry() {
        SentrySDK.start { options in
            options.dsn = SecretsLoader.sentryDSN

            // --- Release & environment ---
            let bundle = Bundle.main
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            options.releaseName = "\(bundle.bundleIdentifier ?? "com.jasonmayo.diewithoutregrets")@\(version)+\(build)"
            options.environment = AppEnvironment.current.rawValue
            options.dist = build

            // --- Error monitoring ---
            // attachScreenshot + attachViewHierarchy give us "what was on
            // screen at the moment of crash" for triage. Worth the bandwidth.
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            options.enableAppHangTracking = true
            options.enableWatchdogTerminationTracking = true

            // --- Session Replay ---
            // 0 random session sampling (cost control), 100 % on error (the
            // highest-value debug signal Sentry produces).
            options.sessionReplay.sessionSampleRate = 0.0
            options.sessionReplay.onErrorSampleRate = 1.0
            // Sentry-cocoa 8.58+ refuses to enable Session Replay on iOS 26+
            // unless `UIDesignRequiresCompatibility` is set in Info.plist
            // (which would freeze the app to the legacy appearance). Study
            // Guard's SwiftUI views use the rendering path Sentry's masking
            // logic has always supported, so we override the check rather
            // than commit to a design-language decision here. Revisit if/when
            // we adopt the iOS 26 Liquid Glass redesign.
            options.experimental.enableSessionReplayInUnreliableEnvironment = true

            // --- Performance: explicitly off for now ---
            // We'll enable Tracing/Profiling separately once we see what the
            // baseline error volume looks like.
            options.tracesSampleRate = 0.0

            // --- Privacy ---
            // No IP / user-agent enrichment unless we explicitly opt in later.
            options.sendDefaultPii = false

            #if DEBUG
            options.debug = true
            #else
            options.debug = false
            #endif

            // --- Drop all dev events ---
            options.beforeSend = { event in
                if AppEnvironment.current == .debug {
                    return nil
                }
                return event
            }

            // --- Tags applied to every event ---
            // app_name lets us filter cross-app if Study Guard ever shares an
            // org-level view with a sibling app (e.g. One Thing). environment
            // is also on options.environment, but tagging it makes filter
            // expressions work uniformly with everything else.
            options.initialScope = { scope in
                scope.setTag(value: "Study Guard", key: "app_name")
                scope.setTag(value: AppEnvironment.current.rawValue, key: "environment")
                return scope
            }
        }
    }

    /// Stamp Sentry's scope with the PostHog distinct ID so a Sentry issue
    /// links 1:1 to the matching PostHog user (and replays filtered by that
    /// user). Safe to call repeatedly — `setTag` is a write, not an append.
    ///
    /// Note: `posthog_session_id` would let us jump straight to the *single*
    /// replay around the crash. PostHog iOS exposes `getSessionId()` from
    /// 3.25.0+; we're on 3.24.0 so we skip it for now. Bump posthog-ios in
    /// Package.resolved and add the line below to enable:
    ///
    ///     scope.setTag(value: PostHogSDK.shared.getSessionId(), key: "posthog_session_id")
    private func attachPostHogIdentifiersToSentry() {
        let distinctId = PostHogSDK.shared.getDistinctId()
        SentrySDK.configureScope { scope in
            scope.setTag(value: distinctId, key: "posthog_distinct_id")
        }
    }

    @objc private func applicationWillEnterForegroundRefreshSentryScope() {
        attachPostHogIdentifiersToSentry()
    }

    // MARK: - Lifecycle

    // Request ATT in applicationDidBecomeActive per TikTok's recommended pattern.
    // TikTokBusiness.requestTrackingAuthorization wraps ATTrackingManager and notifies
    // the SDK directly when the user responds, so events flush immediately after.
    func applicationDidBecomeActive(_ application: UIApplication) {
        TikTokBusiness.requestTrackingAuthorization { status in
            print("[AppDelegate] ATT status: \(status)")
        }
    }
    
    // MARK: - URL & Universal Link Handling
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return Branch.getInstance().continue(userActivity)
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return Branch.getInstance().application(app, open: url, options: options)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("[AppDelegate] 🔔 Will present notification: \(notification.request.identifier)")
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("[AppDelegate] 🔔 User tapped notification: \(response.notification.request.identifier)")

        // Study Guard lock/warning notifications route into the unlock flow.
        let identifier = response.notification.request.identifier
        if identifier == SGContract.lockNotificationID || identifier == SGContract.warningNotificationID {
            Analytics.capture("lock_notification_tapped", properties: ["identifier": identifier])
            DispatchQueue.main.async {
                StudyGuardManager.shared.reconcileOnForeground()
                if StudyGuardManager.shared.state == .locked {
                    NavigationModel.shared.navigate(to: .regretView)
                }
            }
        }

        if response.notification.request.identifier == "buyback_offer_notification" {
            Analytics.buybackNotificationTapped()
            // Mark notification as seen
            NotificationManager.shared.markBuybackNotificationSeen()
            
            // Present buyback offer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .showBuyBackOffer, object: nil)
            }
        }
        
        completionHandler()
    }
}

// Add notification name extension
extension Notification.Name {
    static let showBuyBackOffer = Notification.Name("showBuyBackOffer")
}

// MARK: - Analytics
//
// Centralized PostHog wrapper. Use this instead of calling PostHogSDK directly
// so event names and property keys stay consistent across the app.
//
// Generic helpers:
//   Analytics.capture("event_name", properties: ["key": value])
//   Analytics.setPersonProperties(["age": "18-24"])
//
// Specific helpers exist for the most common flows (onboarding, paywall,
// purchases). Add new helpers here when you introduce a new event so the
// property shape stays consistent everywhere it's emitted.

enum Analytics {

    // MARK: Generic

    /// Capture a custom event. `timestamp` is added automatically.
    static func capture(_ event: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["timestamp"] = Date().ISO8601Format()
        PostHogSDK.shared.capture(event, properties: props)
    }

    /// Attach properties to the current user. These auto-attach to every
    /// future event in PostHog so demographic filters work without a join.
    static func setPersonProperties(_ properties: [String: Any]) {
        PostHogSDK.shared.identify(
            Purchases.shared.appUserID,
            userProperties: properties
        )
    }

    // MARK: Study Guard — extension analytics drain

    /// PostHog can't run inside the Screen Time extensions, so they queue
    /// events into the app group (`sg_pendingEvents`). Drained on every
    /// foreground. The queue is swapped to a drain key first so an extension
    /// appending mid-drain can't be lost to a read-modify-write race.
    static func flushStudyGuardExtensionEvents() {
        guard let defaults = SGContract.sharedDefaults else { return }
        defaults.synchronize()

        // Swap: move pending → draining, clear pending.
        if let data = defaults.data(forKey: SGContract.Keys.pendingEvents) {
            defaults.set(data, forKey: SGContract.Keys.pendingEventsDraining)
            defaults.removeObject(forKey: SGContract.Keys.pendingEvents)
            defaults.synchronize()
        }

        guard let draining = defaults.data(forKey: SGContract.Keys.pendingEventsDraining),
              let events = try? JSONSerialization.jsonObject(with: draining) as? [[String: Any]],
              !events.isEmpty else {
            defaults.removeObject(forKey: SGContract.Keys.pendingEventsDraining)
            return
        }

        for event in events {
            guard let name = event["event"] as? String else { continue }
            var props: [String: Any] = [:]
            for (key, value) in event where key != "event" {
                props[key] = value
            }
            // Original timestamp is preserved as a property; PostHog ingestion
            // time will differ (events arrive at next foreground).
            if let ts = event["timestamp"] as? Double {
                props["original_timestamp"] = Date(timeIntervalSince1970: ts).ISO8601Format()
            }
            capture(name, properties: props)
        }
        defaults.removeObject(forKey: SGContract.Keys.pendingEventsDraining)
        defaults.synchronize()

        // Legacy automation tail: how often old Shortcut automations still
        // fire post-migration (drives the 3.0 decision to delete the intent
        // targets). Flushed as a delta since the last drain.
        let totalFires = defaults.integer(forKey: SGContract.Keys.legacyIntentFireCount)
        let lastFlushed = UserDefaults.standard.integer(forKey: "lastFlushedLegacyIntentFireCount")
        if totalFires > lastFlushed {
            capture("legacy_intent_noop", properties: [
                "count": totalFires - lastFlushed,
                "total": totalFires,
            ])
            UserDefaults.standard.set(totalFires, forKey: "lastFlushedLegacyIntentFireCount")
        }

        // Keep Study Guard person properties fresh (cheap; piggybacks the drain).
        var personProps: [String: Any] = [
            "screen_time_setup_complete": defaults.bool(forKey: SGContract.Keys.setupComplete),
            "usage_interval_minutes": defaults.integer(forKey: SGContract.Keys.intervalMinutes),
        ]
        if let selection = SGContract.decodeSelection(defaults) {
            personProps["guarded_token_count"] = SGContract.tokenCount(selection)
        }
        setPersonProperties(personProps)
    }

    // MARK: Onboarding — funnel

    /// Fired every time an onboarding step is shown to the user. Lets you
    /// build a 20-step funnel chart in PostHog from a single event.
    static func onboardingStepViewed(step: String, stepIndex: Int, totalSteps: Int) {
        capture("onboarding_step_viewed", properties: [
            "step_name": step,
            "step_index": stepIndex,
            "total_steps": totalSteps
        ])
    }

    // MARK: Onboarding — interactions

    static func onboardingFeelingsSelected(_ feelings: [String]) {
        capture("onboarding_feelings_selected", properties: [
            "feelings": Array(feelings).sorted(),
            "count": feelings.count
        ])
    }

    static func onboardingObstaclesSelected(_ obstacles: [String]) {
        capture("onboarding_obstacles_selected", properties: [
            "obstacles": Array(obstacles).sorted(),
            "count": obstacles.count
        ])
    }

    static func onboardingScreenTimeSelected(_ screenTime: String) {
        capture("onboarding_screen_time_selected", properties: [
            "screen_time": screenTime
        ])
    }

    static func onboardingNameEntered(name: String) {
        capture("onboarding_name_entered", properties: [
            "name_length": name.count,
            "is_empty": name.isEmpty
        ])
    }

    static func onboardingAgeSelected(_ age: String) {
        capture("onboarding_age_selected", properties: [
            "age_range": age
        ])
    }

    static func onboardingUnlockMethodSelected(_ method: String) {
        capture("onboarding_unlock_method_selected", properties: [
            "unlock_method": method
        ])
    }

    static func onboardingAppToggled(app: String, isSelected: Bool, totalSelected: Int) {
        capture("onboarding_app_toggled", properties: [
            "app": app,
            "is_selected": isSelected,
            "total_selected": totalSelected
        ])
    }

    static func onboardingAppsConfirmed(apps: [String]) {
        capture("onboarding_apps_confirmed", properties: [
            "apps": apps,
            "count": apps.count
        ])
    }

    static func onboardingNotificationPermission(granted: Bool) {
        capture("onboarding_notification_permission", properties: [
            "granted": granted
        ])
    }

    // MARK: Paywall (multi-surface)
    //
    // `surface` should be one of:
    //   "onboarding_pre"   — the custom $0 marketing pre-paywall (PayWallView)
    //   "onboarding_rc"    — the RevenueCat paywall in onboarding
    //   "profile"          — the in-app "Upgrade to Pro" paywall
    //   "buyback"          — the post-dismiss buyback offer

    static func paywallViewed(surface: String, properties: [String: Any] = [:]) {
        var props = properties
        props["surface"] = surface
        capture("paywall_viewed", properties: props)
    }

    static func paywallDismissed(surface: String, didPurchase: Bool) {
        capture("paywall_dismissed", properties: [
            "surface": surface,
            "did_purchase": didPurchase
        ])
    }

    static func subscriptionStarted(
        surface: String,
        productId: String,
        price: Double?,
        currency: String?,
        isTrial: Bool,
        offeringId: String?,
        entitlements: [String]
    ) {
        var props: [String: Any] = [
            "surface": surface,
            "product_id": productId,
            "is_trial": isTrial,
            "entitlements": entitlements
        ]
        if let price = price { props["price"] = price }
        if let currency = currency { props["currency"] = currency }
        if let offeringId = offeringId { props["offering_id"] = offeringId }
        capture("subscription_started", properties: props)
    }

    // MARK: Restore purchases

    static func restorePurchasesAttempted(surface: String) {
        capture("restore_purchases_attempted", properties: ["surface": surface])
    }

    static func restorePurchasesSucceeded(surface: String, hasActiveEntitlements: Bool) {
        capture("restore_purchases_succeeded", properties: [
            "surface": surface,
            "has_active_entitlements": hasActiveEntitlements
        ])
    }

    static func restorePurchasesFailed(surface: String, error: String) {
        capture("restore_purchases_failed", properties: [
            "surface": surface,
            "error": error
        ])
    }

    // MARK: - Tab navigation

    /// Fired when the user switches between the Guard / Study / Profile tabs.
    static func tabSelected(_ tab: String) {
        capture("tab_selected", properties: ["tab": tab])
    }

    // MARK: - Unlock flow (RegretView — flashcard quiz to unlock blocked apps)

    /// User has triggered the unlock flow (came in from a Shortcut). This is
    /// the most important "is the core product being used?" event.
    static func unlockAttempted(
        appName: String,
        unlockMethod: String,
        flashcardCount: Int,
        useAllCards: Bool,
        animationType: String,
        deckId: String?,
        deckName: String?,
        availableCards: Int
    ) {
        var props: [String: Any] = [
            "app_name": appName,
            "unlock_method": unlockMethod,
            "flashcard_count_setting": flashcardCount,
            "use_all_cards": useAllCards,
            "animation_type": animationType,
            "available_cards": availableCards
        ]
        if let deckId = deckId { props["deck_id"] = deckId }
        if let deckName = deckName { props["deck_name"] = deckName }
        capture("unlock_attempted", properties: props)
    }

    /// User finished the quiz and tapped Unlock. The app is opening.
    static func unlockCompleted(
        appName: String,
        correctCount: Int,
        totalQuestions: Int,
        hadRetries: Bool,
        durationSec: Double,
        breakDurationMinutes: Int
    ) {
        capture("unlock_completed", properties: [
            "app_name": appName,
            "correct_count": correctCount,
            "total_questions": totalQuestions,
            "accuracy_pct": totalQuestions == 0 ? 0 : Double(correctCount) / Double(totalQuestions),
            "had_retries": hadRetries,
            "duration_sec": durationSec,
            "break_duration_minutes": breakDurationMinutes
        ])
    }

    /// User tapped "Retry Questions" after getting one or more wrong.
    static func unlockRetried(
        appName: String,
        correctCount: Int,
        totalQuestions: Int,
        attemptNumber: Int
    ) {
        capture("unlock_retried", properties: [
            "app_name": appName,
            "correct_count": correctCount,
            "total_questions": totalQuestions,
            "attempt_number": attemptNumber
        ])
    }

    /// Rage-quit signal: user tapped "Close Anyway" / "Close [App]" instead
    /// of completing the quiz.
    static func unlockCloseAnyway(
        appName: String,
        currentStep: Int,
        totalSteps: Int,
        hadIncorrectAnswers: Bool,
        durationSec: Double
    ) {
        capture("unlock_close_anyway", properties: [
            "app_name": appName,
            "current_step": currentStep,
            "total_steps": totalSteps,
            "had_incorrect_answers": hadIncorrectAnswers,
            "duration_sec": durationSec
        ])
    }

    /// User selected an answer for one quiz question. Useful for accuracy
    /// breakdowns by deck/card.
    static func unlockQuestionAnswered(
        appName: String,
        questionIndex: Int,
        totalQuestions: Int,
        isCorrect: Bool
    ) {
        capture("unlock_question_answered", properties: [
            "app_name": appName,
            "question_index": questionIndex,
            "total_questions": totalQuestions,
            "is_correct": isCorrect
        ])
    }

    // MARK: - True Focus session (camera-based focus)

    /// User entered the focus screen. May not yet have granted camera
    /// permission — see `focusCameraPermission` and `focusSessionStarted`.
    static func focusSessionEntered(durationMinutes: Int, strictness: String) {
        capture("focus_session_entered", properties: [
            "duration_minutes": durationMinutes,
            "strictness": strictness
        ])
    }

    /// Camera permission outcome for a focus session.
    static func focusCameraPermission(granted: Bool) {
        capture("focus_camera_permission", properties: ["granted": granted])
    }

    /// Setup phase finished — user has held face + scene for the required
    /// number of seconds and the timer actually starts.
    static func focusSessionStarted(
        durationMinutes: Int,
        strictness: String,
        setupSec: Double
    ) {
        capture("focus_session_started", properties: [
            "duration_minutes": durationMinutes,
            "strictness": strictness,
            "setup_sec": setupSec
        ])
    }

    /// Pomodoro timer hit zero — user earned their break.
    static func focusSessionCompleted(
        durationMinutes: Int,
        strictness: String,
        breakDurationMinutes: Int,
        appName: String?,
        wallClockSec: Double
    ) {
        var props: [String: Any] = [
            "duration_minutes": durationMinutes,
            "strictness": strictness,
            "break_duration_minutes": breakDurationMinutes,
            "wall_clock_sec": wallClockSec
        ]
        if let appName = appName { props["app_name"] = appName }
        capture("focus_session_completed", properties: props)
    }

    /// User hit the X button before the timer reached zero.
    static func focusSessionAbandoned(
        durationMinutes: Int,
        strictness: String,
        focusedSecondsCompleted: Int,
        completionPct: Double,
        wasInSetup: Bool
    ) {
        capture("focus_session_abandoned", properties: [
            "duration_minutes": durationMinutes,
            "strictness": strictness,
            "focused_seconds_completed": focusedSecondsCompleted,
            "completion_pct": completionPct,
            "was_in_setup": wasInSetup
        ])
    }

    // MARK: - Flashcards (manual create / edit / delete)

    /// `source` is one of: "manual", "ai_pdf", "ai_text", "ai_youtube",
    /// "ai_quizlet", "ai_quizlet_direct", "onboarding".
    static func flashcardCreated(source: String, deckId: String?, deckName: String?) {
        var props: [String: Any] = ["source": source]
        if let deckId = deckId { props["deck_id"] = deckId }
        if let deckName = deckName { props["deck_name"] = deckName }
        capture("flashcard_created", properties: props)
    }

    static func flashcardEdited(deckId: String?, deckName: String?) {
        var props: [String: Any] = [:]
        if let deckId = deckId { props["deck_id"] = deckId }
        if let deckName = deckName { props["deck_name"] = deckName }
        capture("flashcard_edited", properties: props)
    }

    static func flashcardDeleted(deckId: String?, deckName: String?, count: Int = 1) {
        var props: [String: Any] = ["count": count]
        if let deckId = deckId { props["deck_id"] = deckId }
        if let deckName = deckName { props["deck_name"] = deckName }
        capture("flashcard_deleted", properties: props)
    }

    // MARK: - AI Flashcard Generation
    //
    // `source` here is one of: "pdf", "text", "youtube", "quizlet"
    // (Quizlet direct import uses `quizlet_direct` for its own dedicated
    // event since it doesn't hit the AI pipeline.)

    /// User tapped Generate. Starts the API call.
    static func aiGenerateAttempted(source: String, language: String, charCount: Int) {
        capture("ai_generate_attempted", properties: [
            "source": source,
            "language": language,
            "char_count": charCount
        ])
    }

    /// AI returned cards and they were appended to the deck.
    static func aiGenerateSucceeded(
        source: String,
        language: String,
        cardCount: Int,
        durationSec: Double
    ) {
        capture("ai_generate_succeeded", properties: [
            "source": source,
            "language": language,
            "card_count": cardCount,
            "duration_sec": durationSec
        ])
    }

    /// AI generation hit an error or validation failure. `errorType` should
    /// match a `FlashcardGenerationError` case (e.g. "tokenLimitExceeded").
    static func aiGenerateFailed(
        source: String,
        errorType: String,
        message: String?
    ) {
        var props: [String: Any] = [
            "source": source,
            "error_type": errorType
        ]
        if let message = message { props["message"] = message }
        capture("ai_generate_failed", properties: props)
    }

    /// Source picker tabs in the AI sheet (PDF / Paste Text / YouTube / Quizlet).
    static func aiInputSourceSelected(_ source: String) {
        capture("ai_input_source_selected", properties: ["source": source])
    }

    /// PDF upload picked — file selected (before extraction).
    static func aiPdfPicked(fileName: String, sizeBytes: Int) {
        capture("ai_pdf_picked", properties: [
            "file_name": fileName,
            "size_bytes": sizeBytes
        ])
    }

    /// YouTube transcript fetch finished.
    static func aiYoutubeTranscriptFetched(success: Bool, charCount: Int, error: String?) {
        var props: [String: Any] = [
            "success": success,
            "char_count": charCount
        ]
        if let error = error { props["error"] = error }
        capture("ai_youtube_transcript_fetched", properties: props)
    }

    /// Quizlet pasted text was parsed into N pairs.
    static func aiQuizletParsed(pairCount: Int, delimiter: String, useAi: Bool) {
        capture("ai_quizlet_parsed", properties: [
            "pair_count": pairCount,
            "delimiter": delimiter,
            "use_ai": useAi
        ])
    }

    /// Quizlet direct import (no AI) succeeded.
    static func aiQuizletDirectImported(cardCount: Int) {
        capture("ai_quizlet_direct_imported", properties: ["card_count": cardCount])
    }

    // MARK: - Decks

    static func deckCreated(name: String, totalDecksAfter: Int) {
        capture("deck_created", properties: [
            "name": name,
            "total_decks_after": totalDecksAfter
        ])
    }

    static func deckDeleted(name: String, cardCount: Int, totalDecksAfter: Int) {
        capture("deck_deleted", properties: [
            "name": name,
            "card_count": cardCount,
            "total_decks_after": totalDecksAfter
        ])
    }

    static func deckRenamed(oldName: String, newName: String) {
        capture("deck_renamed", properties: [
            "old_name": oldName,
            "new_name": newName
        ])
    }

    static func deckSelected(name: String, cardCount: Int) {
        capture("deck_selected", properties: [
            "name": name,
            "card_count": cardCount
        ])
    }

    // MARK: - Practice mode

    static func practiceSessionStarted(deckId: String, deckName: String, cardCount: Int) {
        capture("practice_session_started", properties: [
            "deck_id": deckId,
            "deck_name": deckName,
            "card_count": cardCount
        ])
    }

    static func practiceSessionCompleted(
        deckId: String,
        deckName: String,
        correctCount: Int,
        totalQuestions: Int,
        hadRetries: Bool,
        durationSec: Double
    ) {
        capture("practice_session_completed", properties: [
            "deck_id": deckId,
            "deck_name": deckName,
            "correct_count": correctCount,
            "total_questions": totalQuestions,
            "accuracy_pct": totalQuestions == 0 ? 0 : Double(correctCount) / Double(totalQuestions),
            "had_retries": hadRetries,
            "duration_sec": durationSec
        ])
    }

    static func practiceSessionAbandoned(
        deckId: String,
        deckName: String,
        currentStep: Int,
        totalQuestions: Int
    ) {
        capture("practice_session_abandoned", properties: [
            "deck_id": deckId,
            "deck_name": deckName,
            "current_step": currentStep,
            "total_questions": totalQuestions
        ])
    }

    // MARK: - Settings

    /// One unified event for any setting change. `key` is the setting name,
    /// values are arbitrary so this works for ints, strings, booleans.
    static func settingChanged(key: String, oldValue: Any?, newValue: Any) {
        var props: [String: Any] = [
            "key": key,
            "new_value": newValue
        ]
        if let oldValue = oldValue { props["old_value"] = oldValue }
        capture("setting_changed", properties: props)

        // Also keep relevant settings on the user as person properties so
        // every event auto-segments by them.
        if key == "unlock_method" || key == "animation_type" {
            setPersonProperties([key: newValue])
        }
    }

    // MARK: - App selection (Profile / Guard view)

    /// User tapped an app in the Study Guard app grid.
    static func appSelectionToggled(app: String, surface: String) {
        capture("app_selection_toggled", properties: [
            "app": app,
            "surface": surface
        ])
    }

    static func appInstructionSheetViewed(app: String, surface: String) {
        capture("app_instruction_sheet_viewed", properties: [
            "app": app,
            "surface": surface
        ])
    }

    // MARK: - Help & support links

    static func helpLinkClicked(link: String, url: String) {
        capture("help_link_clicked", properties: [
            "link": link,
            "url": url
        ])
    }

    // MARK: - Buyback (post-paywall-dismiss notification)

    static func buybackNotificationScheduled() {
        capture("buyback_notification_scheduled")
    }

    static func buybackNotificationSkipped(reason: String) {
        capture("buyback_notification_skipped", properties: ["reason": reason])
    }

    static func buybackNotificationTapped() {
        capture("buyback_notification_tapped")
    }

    // MARK: - Profile / In-app paywall convenience

    /// "Upgrade to Pro" button tapped on the Profile screen.
    static func upgradeButtonTapped(surface: String) {
        capture("upgrade_button_tapped", properties: ["surface": surface])
    }
}
