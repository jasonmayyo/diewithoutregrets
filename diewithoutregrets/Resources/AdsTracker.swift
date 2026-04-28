//
//  AdsTracker.swift
//  diewithoutregrets
//
//  Wrapper around the TikTok Business iOS SDK for ad-attribution events.
//  All view-layer code should call AdsTracker.* and never the SDK directly,
//  so the underlying provider can be swapped in one place.
//

import Foundation
import TikTokBusinessSDK
import RevenueCat

enum AdsTracker {

    private static let statusKey = "AdsTracker.lastStatus"

    private static func recordStatus(_ status: String) {
        print("[AdsTracker] \(status)")
        UserDefaults.standard.set("\(Date()): \(status)", forKey: statusKey)
    }

    static var lastStatus: String {
        UserDefaults.standard.string(forKey: statusKey) ?? "(no status yet)"
    }

    // MARK: - SDK lifecycle

    static func initializeSDK() {
        guard let info = Bundle.main.infoDictionary,
              let accessToken = info["TikTokAccessToken"] as? String,
              let appId = info["AppStoreAppID"] as? String,
              let tiktokAppId = info["TikTokAppID"] as? String,
              accessToken.isEmpty == false,
              appId.isEmpty == false,
              tiktokAppId.isEmpty == false,
              accessToken.hasPrefix("REPLACE_WITH") == false,
              appId.hasPrefix("REPLACE_WITH") == false,
              tiktokAppId.hasPrefix("REPLACE_WITH") == false
        else {
            recordStatus("TikTok credentials missing or unset in Info.plist; skipping SDK initialization.")
            return
        }

        guard let config = TikTokConfig(accessToken: accessToken,
                                        appId: appId,
                                        tiktokAppId: tiktokAppId) else {
            recordStatus("Failed to construct TikTokConfig.")
            return
        }

        // ATT delay matches TikTok's recommended sample. Buffers events until the user
        // responds to ATT so the SDK can attach IDFA when the response is "Allow".
        config.setDelayForATTUserAuthorizationInSeconds(20)

        // Disable the SDK's automatic StoreKit observer. We fire Purchase / StartTrial /
        // Subscribe manually from the paywall with rich properties and proper trial gating.
        // Leaving this enabled causes the SDK to replay every historical transaction
        // (including sandbox history) on launch, producing duplicate Purchase events with
        // sparse properties (content_type:"SUB", no content_name).
        config.disablePaymentTracking()

        #if DEBUG
        config.setLogLevel(TikTokLogLevelVerbose)
        config.enableDebugMode()
        #else
        config.setLogLevel(TikTokLogLevelInfo)
        #endif

        TikTokBusiness.initializeSdk(config) { success, error in
            if let error = error {
                recordStatus("TikTok init error: \(error.localizedDescription)")
            }
            if success {
                recordStatus("TikTok SDK initialized.")
                identifyCurrentUser()
            }
        }
    }

    static func identifyCurrentUser() {
        let externalId = Purchases.shared.appUserID
        TikTokBusiness.identify(withExternalID: externalId,
                                externalUserName: nil,
                                phoneNumber: nil,
                                email: nil)
    }

    // MARK: - Standard events

    static func trackCompleteRegistration() {
        let event = TikTokBaseEvent(eventName: TTEventName.registration.rawValue)
        TikTokBusiness.trackTTEvent(event)
        recordStatus("trackCompleteRegistration fired")
    }

    static func trackStartTrial(productId: String,
                                productName: String,
                                price: Double,
                                currency: String) {
        let event = TikTokBaseEvent(eventName: TTEventName.startTrial.rawValue)
        _ = event.addProperty(withKey: "content_id", value: productId)
        _ = event.addProperty(withKey: "content_type", value: "product")
        _ = event.addProperty(withKey: "currency", value: currency)
        _ = event.addProperty(withKey: "value", value: price)
        _ = event.addProperty(withKey: "contents", value: [richContents(productId: productId,
                                                                        productName: productName,
                                                                        price: price,
                                                                        currency: currency)])
        TikTokBusiness.trackTTEvent(event)
        recordStatus("trackStartTrial fired (\(productId), \(price) \(currency))")
    }

    static func trackSubscribe(productId: String,
                               productName: String,
                               price: Double,
                               currency: String) {
        let event = TikTokBaseEvent(eventName: TTEventName.subscribe.rawValue)
        _ = event.addProperty(withKey: "content_id", value: productId)
        _ = event.addProperty(withKey: "content_type", value: "product")
        _ = event.addProperty(withKey: "currency", value: currency)
        _ = event.addProperty(withKey: "value", value: price)
        _ = event.addProperty(withKey: "contents", value: [richContents(productId: productId,
                                                                        productName: productName,
                                                                        price: price,
                                                                        currency: currency)])
        TikTokBusiness.trackTTEvent(event)
        recordStatus("trackSubscribe fired (\(productId), \(price) \(currency))")
    }

    static func trackPurchase(productId: String,
                              productName: String,
                              price: Double,
                              currency: String) {
        let purchase = TikTokPurchaseEvent(eventId: UUID().uuidString)
        purchase.setCurrency(TTCurrency(rawValue: currency))
        purchase.setValue(String(price))
        purchase.setContentId(productId)
        purchase.setContentType("product")

        let item = TikTokContentParams()
        item.contentId = productId
        item.contentName = productName
        item.contentCategory = "subscription"
        item.price = NSNumber(value: price)
        item.quantity = 1
        purchase.setContents([item])

        TikTokBusiness.trackTTEvent(purchase)
        recordStatus("trackPurchase fired (\(productId), \(price) \(currency))")
    }

    private static func richContents(productId: String,
                                     productName: String,
                                     price: Double,
                                     currency: String) -> [String: Any] {
        return [
            "content_id": productId,
            "content_name": productName,
            "content_type": "product",
            "content_category": "subscription",
            "price": String(price),
            "quantity": "1",
            "currency": currency
        ]
    }

    static func trackViewContent(name: String) {
        let event = TikTokViewContentEvent(eventId: UUID().uuidString)
        event.setContentType("product")
        event.setContentId(name)
        TikTokBusiness.trackTTEvent(event)
        recordStatus("trackViewContent fired (\(name))")
    }
}
