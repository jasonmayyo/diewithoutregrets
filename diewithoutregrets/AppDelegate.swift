import SwiftUI
import BranchSDK
import RevenueCat
import PostHog
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] didFinishLaunchingWithOptions")
        
        // Initialize Branch with BranchScene for SwiftUI
        BranchScene.shared().initSession(launchOptions: launchOptions) { params, error, scene in
            if let error = error {
                print("Branch init failed: \(error.localizedDescription)")
            }
            guard let data = params as? [String: Any] else { return }

            var attrs = [String: String]()
            if let influencer = data["$influencer"] as? String {
                attrs["influencer"] = influencer
                print("Branch data found - influencer: \(influencer)")
            }
            if let campaign = data["+campaign"] as? String {
                attrs["campaign"] = campaign
                print("Branch data found - campaign: \(campaign)")
            }
            if !attrs.isEmpty {
                Purchases.shared.setAttributes(attrs)
                print("Setting RevenueCat attributes: \(attrs)")
            } else {
                print("No influencer or campaign data found in Branch params.")
            }
        }

        // Configure RevenueCat
        Purchases.configure(withAPIKey: "appl_ArMMMNZWiwLJiQVDcmVCwLigzmG")

        // Configure PostHog
        let POSTHOG_API_KEY = "phc_CzbpdC9g3azt6oI4GBppF8b9C6x7wA7MkbllkaDCt9D"
        let POSTHOG_HOST = "https://us.i.posthog.com"
        let config = PostHogConfig(apiKey: POSTHOG_API_KEY, host: POSTHOG_HOST)
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            PostHogSDK.shared.capture(
                "first_app_open",
                properties: ["timestamp": Date().ISO8601Format()]
            )
        }
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        NotificationManager.shared.requestAuthorization()

        return true
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
