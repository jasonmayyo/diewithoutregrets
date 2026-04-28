import SwiftUI
import BranchSDK
import RevenueCat
import PostHog
import UIKit
import UserNotifications
import AppTrackingTransparency

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] didFinishLaunchingWithOptions")

        // Configure RevenueCat before attribution callbacks can set attributes.
        Purchases.configure(withAPIKey: "appl_ArMMMNZWiwLJiQVDcmVCwLigzmG")
        
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

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            PostHogSDK.shared.capture(
                "first_app_open",
                properties: ["timestamp": Date().ISO8601Format()]
            )
        }

        // Initialize TikTok Business SDK for Spark Ads attribution.
        AdsTracker.initializeSDK()

        // Request ATT independently of Branch so it isn't gated by the Branch callback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.requestTrackingPermissionIfNeeded()
        }
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Note: Notification permissions are requested during onboarding flow

        return true
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

    private func requestTrackingPermissionIfNeeded() {
        guard #available(iOS 14, *),
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        ATTrackingManager.requestTrackingAuthorization { status in
            print("[AppDelegate] ATT status: \(status.rawValue)")
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
