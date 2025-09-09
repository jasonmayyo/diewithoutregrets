import SwiftUI
import BranchSDK
import RevenueCat
import PostHog
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    var shortcutItemToProcess: UIApplicationShortcutItem?
    
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
        
        // Check if launched from shortcut
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            print("[AppDelegate] Launched with shortcut: \(shortcutItem.type)")
            shortcutItemToProcess = shortcutItem
            // Return false to indicate we'll handle it later
            return false
        }

        return true
    }
    
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("[AppDelegate] configurationForConnecting")
        
        // Store shortcut item to process later
        if let shortcutItem = options.shortcutItem {
            print("[AppDelegate] Found shortcut in scene options: \(shortcutItem.type)")
            handleShortcutItem(shortcutItem)
        }
        
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        print("[AppDelegate] performActionFor: \(shortcutItem.type)")
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("[AppDelegate] applicationDidBecomeActive")
        
        if let shortcutItem = shortcutItemToProcess {
            print("[AppDelegate] Processing deferred shortcut: \(shortcutItem.type)")
            handleShortcutItem(shortcutItem)
            shortcutItemToProcess = nil
        }
    }
    
    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        print("[AppDelegate] handleShortcutItem: \(shortcutItem.type)")
        
        if shortcutItem.type == "com.jasonmayo.diewithoutregrets.buyback" {
            print("[AppDelegate] Setting pending buyback offer")
            ShortcutAction.pending = .buyBackOffer
            
            // Also try to open URL as backup
            if let url = URL(string: "diewithoutregrets://buyback") {
                print("[AppDelegate] Opening URL: \(url)")
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
