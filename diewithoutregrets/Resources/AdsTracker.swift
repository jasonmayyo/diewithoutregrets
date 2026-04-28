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
            print("[AdsTracker] TikTok credentials missing or unset in Info.plist; skipping SDK initialization.")
            return
        }

        guard let config = TikTokConfig(accessToken: accessToken,
                                        appId: appId,
                                        tiktokAppId: tiktokAppId) else {
            print("[AdsTracker] Failed to construct TikTokConfig.")
            return
        }

        config.setDelayForATTUserAuthorizationInSeconds(120)

        #if DEBUG
        config.enableDebugMode()
        #endif

        TikTokBusiness.initializeSdk(config) { success, error in
            if let error = error {
                print("[AdsTracker] TikTok init error: \(error.localizedDescription)")
            }
            if success {
                print("[AdsTracker] TikTok SDK initialized.")
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
    }

    static func trackStartTrial(productId: String,
                                price: Double,
                                currency: String) {
        let event = TikTokBaseEvent(eventName: TTEventName.startTrial.rawValue)
        _ = event.addProperty(withKey: "content_id", value: productId)
        _ = event.addProperty(withKey: "content_type", value: "product")
        _ = event.addProperty(withKey: "currency", value: currency)
        _ = event.addProperty(withKey: "value", value: price)
        TikTokBusiness.trackTTEvent(event)
    }

    static func trackSubscribe(productId: String,
                               price: Double,
                               currency: String) {
        let event = TikTokBaseEvent(eventName: TTEventName.subscribe.rawValue)
        _ = event.addProperty(withKey: "content_id", value: productId)
        _ = event.addProperty(withKey: "content_type", value: "product")
        _ = event.addProperty(withKey: "currency", value: currency)
        _ = event.addProperty(withKey: "value", value: price)
        TikTokBusiness.trackTTEvent(event)
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
    }

    static func trackViewContent(name: String) {
        let event = TikTokViewContentEvent(eventId: UUID().uuidString)
        event.setContentType("product")
        event.setContentId(name)
        TikTokBusiness.trackTTEvent(event)
    }
}
