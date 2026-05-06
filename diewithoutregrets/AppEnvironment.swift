//
//  AppEnvironment.swift
//  diewithoutregrets
//
//  Three-way split for telemetry tagging:
//
//    .debug        — running from Xcode (real device or simulator), DEBUG configuration
//    .testflight   — TestFlight or any non-App-Store install (sandbox StoreKit receipt)
//    .production   — App Store install
//
//  Used as the Sentry `environment` and as a custom tag on every event so we
//  can filter staging crashes separately from real users in production.
//
//  Detection rules:
//    • DEBUG build configuration  → .debug   (catches every Run-from-Xcode build)
//    • Release build + App Store receipt is "sandboxReceipt" → .testflight
//      (Apple writes a sandbox receipt for TestFlight + Xcode-archived adhoc
//       builds; either way it's not a paying user, so we want it labelled.)
//    • Release build + production receipt (or no receipt yet) → .production
//
//  The `appStoreReceiptURL` lookup only fails when no receipt is present,
//  which on an App Store install only happens at first launch before any
//  StoreKit interaction. That edge case falls through to .production, which
//  is the conservative choice — better to over-report than under-report
//  production crashes.
//

import Foundation

enum AppEnvironment: String {
    case debug
    case testflight
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .debug
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testflight
        }
        return .production
        #endif
    }
}
