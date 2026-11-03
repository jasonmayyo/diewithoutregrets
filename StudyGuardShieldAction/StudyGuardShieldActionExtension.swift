//
//  StudyGuardShieldActionExtension.swift
//  StudyGuardShieldAction
//
// Records the handoff before asking iOS to open Study Guard. Older iOS
// versions close the blocked app; shield copy explains the manual route.

import Foundation
import ManagedSettings

final class StudyGuardShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, applicationTokenData: try? JSONEncoder().encode(application), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, categoryTokenData: try? JSONEncoder().encode(category), completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, applicationTokenData: Data? = nil,
                         categoryTokenData: Data? = nil,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            let defaults = SGContract.sharedDefaults
            if let categoryTokenData {
                ShieldReturnContext.prepareCategoryReturn(for: categoryTokenData, in: defaults)
            } else {
                ShieldReturnContext.prepareReturn(for: applicationTokenData, in: defaults)
            }
            // Stamp the tap so the app opens directly in the chosen monster's chat.
            defaults?.set(Date().timeIntervalSince1970, forKey: SGContract.Keys.shieldTapAt)
            // Count this as a gate encounter — the tutor-monster pressure signal.
            // Pure UserDefaults increment; adds no measurable delay to the hot path.
            SGContract.recordGateEncounter(defaults)
            defaults?.synchronize()

            if #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                completionHandler(.close)
            }

        case .secondaryButtonPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }
}
