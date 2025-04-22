import SwiftUI
import BranchSDK
import RevenueCat
import PostHog

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Branch with BranchScene for SwiftUI
        BranchScene.shared().initSession(launchOptions: launchOptions) { params, error, scene in
            // Handle Branch error if necessary
            if let error = error {
                print("Branch init failed: \(error.localizedDescription)")
            }
            
            guard let data = params as? [String: Any] else { return }

            // Forward referral data to RevenueCat
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

        // Track first app open
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            PostHogSDK.shared.capture(
                "first_app_open",
                properties: ["timestamp": Date().ISO8601Format()]
            )
        }

        return true
    }
} 
