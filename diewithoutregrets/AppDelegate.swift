import SwiftUI
import BranchSDK
import RevenueCat
import PostHog
import UIKit
import UserNotifications
import AppTrackingTransparency
import Singular

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] didFinishLaunchingWithOptions")

        // Configure RevenueCat before attribution callbacks can set attributes.
        Purchases.configure(withAPIKey: "appl_ArMMMNZWiwLJiQVDcmVCwLigzmG")
        
        // Initialize Branch with BranchScene for SwiftUI
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

            self.requestTrackingPermissionIfNeeded()
        }

        // Configure PostHog
        let POSTHOG_API_KEY = "phc_CzbpdC9g3azt6oI4GBppF8b9C6x7wA7MkbllkaDCt9D"
        let POSTHOG_HOST = "https://us.i.posthog.com"
        let posthogConfig = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        posthogConfig.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(posthogConfig)

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            PostHogSDK.shared.capture(
                "first_app_open",
                properties: ["timestamp": Date().ISO8601Format()]
            )
        }
        
        // Initialize Singular for TikTok Spark Ads attribution
        if let singularConfig = getSingularConfig() {
            Singular.start(singularConfig)
        }
    
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Note: Notification permissions are requested during onboarding flow

        return true
    }
    
    // MARK: - Singular Configuration
    
    func getSingularConfig(openUrl: URL? = nil, userActivity: NSUserActivity? = nil) -> SingularConfig? {
        guard let config = SingularConfig(apiKey: "tryonething_6e0547e1", andSecret: "b70c4ed63107874b7078333fec27658e") else {
            print("[Singular] Failed to create config")
            return nil
        }
        
        // Wait up to 300s for the user's ATT response before finalizing attribution
        config.waitForTrackingAuthorizationWithTimeoutInterval = 300
        
        config.skAdNetworkEnabled = true
        
        config.conversionValuesUpdatedCallback = { conversionValue, coarse, lock in
            print("[Singular] Conversion value updated: \(conversionValue)")
        }
        
        config.singularLinksHandler = { params in
            if let params = params {
                self.handleSingularDeeplink(params: params)
            }
        }
        
        if let openUrl = openUrl {
            config.openUrl = openUrl
        }
        
        if let userActivity = userActivity {
            config.userActivity = userActivity
        }
        
        return config
    }
    
    private func handleSingularDeeplink(params: SingularLinkParams) {
        let deeplink = params.getDeepLink()
        let passthrough = params.getPassthrough()
        let isDeferred = params.isDeferred()
        print("[Singular] Deep link received - deeplink: \(deeplink ?? "nil"), passthrough: \(passthrough ?? "nil"), deferred: \(isDeferred)")
    }
    
    // MARK: - URL & Universal Link Handling for Singular
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if let config = getSingularConfig(userActivity: userActivity) {
            Singular.start(config)
        }
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if let config = getSingularConfig(openUrl: url) {
            Singular.start(config)
        }
        return true
    }

    private func requestTrackingPermissionIfNeeded() {
        guard #available(iOS 14, *),
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        DispatchQueue.main.async {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("[AppDelegate] ATT status: \(status.rawValue)")
            }
        }
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
        
        if response.notification.request.identifier == "buyback_offer_notification" {
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
