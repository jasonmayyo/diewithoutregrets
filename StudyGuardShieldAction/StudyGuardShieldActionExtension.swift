//
//  StudyGuardShieldActionExtension.swift
//  StudyGuardShieldAction
//
//  Handles taps on the shield's "Unlock Apps" button. Deliberately MINIMAL:
//  on tap it stamps sg_shieldTapAt (so the app lands straight on the flashcards
//  when it foregrounds) and directly opens Study Guard via PrivateAppLauncher,
//  then returns .none. NOTHING else runs here — no notifications, no safety
//  net, no analytics, no logging.
//
//  Why so bare: any work before completionHandler delays it, and the system
//  holds the app's foreground until the handler returns. In particular,
//  touching UNUserNotificationCenter from this restricted sandbox can block for
//  ~10s while it sets up its XPC connection — which stalled the open. Keeping
//  the hot path to stamp + launch + completionHandler makes the open as fast
//  as this mechanism allows.
//

import Foundation
import ManagedSettings

final class StudyGuardShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Stamp the tap so the app opens straight to the flashcards.
            SGContract.sharedDefaults?.set(Date().timeIntervalSince1970,
                                           forKey: SGContract.Keys.shieldTapAt)

            // Fire the open on a background thread, then hand the response back
            // immediately. The private open is a SYNCHRONOUS XPC round-trip to
            // LaunchServices that can park its thread for seconds; run inline it
            // would gate completionHandler and the system would hold the app's
            // foreground until it returned — the ~10s stall (the launch parks
            // until it trips the 10s extension watchdog). Dispatching it
            // off-thread BEFORE returning lets the launch fly while the system
            // foregrounds the app without waiting on lsd.
            //
            // `.none`, not `.close`: `.close` means "close the current app / go
            // home" and would bounce us; `.none` issues no competing navigation,
            // so the launch is the sole focus directive and the app stays put.
            DispatchQueue.global(qos: .userInitiated).async {
                PrivateAppLauncher.launch(bundleID: SGContract.hostBundleID)
            }
            completionHandler(.none)

        case .secondaryButtonPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }
}
