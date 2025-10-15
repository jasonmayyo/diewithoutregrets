//
//  NotificationManager.swift
//  diewithoutregrets
//
//  Created by AI Assistant
//

import Foundation
import UserNotifications
import RevenueCat

class NotificationManager {
    static let shared = NotificationManager()
    
    // UserDefaults keys
    private let hasSeenBuybackNotificationKey = "hasSeenBuybackNotification"
    private let didViewPaywallWithoutPurchasingKey = "didViewPaywallWithoutPurchasing"
    
    // Notification identifier
    private let buybackNotificationIdentifier = "buyback_offer_notification"
    
    private init() {}
    
    /// Request notification permissions
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationManager] ❌ Authorization error: \(error.localizedDescription)")
            }
            print("[NotificationManager] ✅ Authorization granted: \(granted)")
            completion?(granted)
        }
    }
    
    /// Schedule the buyback offer notification (10 seconds after app backgrounds)
    func scheduleBuybackNotification() {
        // Check if we should schedule
        guard !hasSeenBuybackNotification() else {
            print("[NotificationManager] ⏭️ User has already seen buyback notification")
            return
        }
        
        guard didViewPaywallWithoutPurchasing() else {
            print("[NotificationManager] ⏭️ User did not view paywall or already purchased")
            return
        }
        
        // Check if user is already subscribed
        Purchases.shared.getCustomerInfo { customerInfo, error in
            guard let customerInfo = customerInfo, error == nil else {
                print("[NotificationManager] ❌ Error checking subscription: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            // Don't show notification if user has active entitlements
            if !customerInfo.entitlements.active.isEmpty {
                print("[NotificationManager] ⏭️ User has active subscription, skipping notification")
                return
            }
            
            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "One Time Offer - 80% OFF!"
            content.body = "You left without claiming your discount."
            content.sound = .default
            content.badge = 1
            content.categoryIdentifier = "BUYBACK_OFFER"
            
            // Create trigger (3 seconds from now)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: self.buybackNotificationIdentifier,
                content: content,
                trigger: trigger
            )
            
            // Schedule notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[NotificationManager] ❌ Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    print("[NotificationManager] ✅ Buyback notification scheduled for 3 seconds")
                }
            }
        }
    }
    
    /// Cancel any pending buyback notifications
    func cancelBuybackNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [buybackNotificationIdentifier]
        )
        print("[NotificationManager] 🗑️ Cancelled pending buyback notification")
    }
    
    /// Mark that the user has viewed the paywall without purchasing
    func markPaywallViewedWithoutPurchase() {
        UserDefaults.standard.set(true, forKey: didViewPaywallWithoutPurchasingKey)
        print("[NotificationManager] 📝 Marked paywall viewed without purchase")
    }
    
    /// Mark that the buyback notification has been seen
    func markBuybackNotificationSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenBuybackNotificationKey)
        print("[NotificationManager] 📝 Marked buyback notification as seen")
    }
    
    /// Reset the paywall tracking flag (e.g., after successful purchase)
    func resetPaywallTracking() {
        UserDefaults.standard.set(false, forKey: didViewPaywallWithoutPurchasingKey)
        print("[NotificationManager] 🔄 Reset paywall tracking")
    }
    
    /// Check if user has seen the buyback notification
    func hasSeenBuybackNotification() -> Bool {
        return UserDefaults.standard.bool(forKey: hasSeenBuybackNotificationKey)
    }
    
    /// Check if user viewed paywall without purchasing
    func didViewPaywallWithoutPurchasing() -> Bool {
        return UserDefaults.standard.bool(forKey: didViewPaywallWithoutPurchasingKey)
    }
}

