//
//  StudyGuardShieldExtension.swift
//  StudyGuardShield
//
//  Custom shield appearance for Study Guard locks. Adaptive system colors
//  keep all four shield variants readable in light and dark appearances.
//  ONE button only ("Study to unlock") — taps are handled by the
//  StudyGuardShieldAction extension: on iOS 26.5+ it returns
//  ShieldActionResponse.openParentalControlsApp for a direct, zero-tap open of
//  Study Guard; on older iOS it posts an instant time-sensitive unlock
//  notification (the only public route back into the app).
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class StudyGuardShieldExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        remember(application)
        return studyGuardShield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        remember(application)
        return studyGuardShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        studyGuardShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        studyGuardShield()
    }

    private func remember(_ application: Application) {
        ShieldReturnContext.remember(
            tokenData: application.token.flatMap { try? JSONEncoder().encode($0) },
            bundleIdentifier: application.bundleIdentifier,
            in: SGContract.sharedDefaults
        )
    }

    private func studyGuardShield() -> ShieldConfiguration {
        // System colors resolve in the shield host's appearance, independently
        // of the main app's light-only theme. Keep the red on the lock and CTA;
        // a material over a red canvas washes it pink in light mode.
        // SGTheme.alarmDeep, kept in UIKit for the extension target.
        let buttonRed = UIColor(red: 0xC2 / 255.0, green: 0x27 / 255.0, blue: 0x1E / 255.0, alpha: 1)

        let armedMinutes = SGContract.sharedDefaults?.integer(forKey: SGContract.Keys.armedThresholdMinutes) ?? 0
        let subtitle = armedMinutes > 0
            ? "Your \(armedMinutes) minutes are up.\nStudy to earn 5 min."
            : "Study to earn 5 min."

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: .systemBackground,
            icon: lockIcon(color: buttonRed),
            title: ShieldConfiguration.Label(text: "Caught you scrolling", color: .label),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: .secondaryLabel
            ),
            // ONE button, no escape hatch: the tap always yields a way into
            // Study Guard (direct open when iOS honors it, otherwise the
            // instant notification), so the copy promises the outcome, not
            // the mechanism. A second "Close" button only diluted the single
            // path forward.
            primaryButtonLabel: ShieldConfiguration.Label(text: "Study to unlock", color: .white),
            primaryButtonBackgroundColor: buttonRed
        )
    }

    /// Render in points; the renderer supplies the display scale exactly once.
    /// An opaque badge keeps the rasterized lock legible in either appearance.
    private func lockIcon(color: UIColor) -> UIImage? {
        let size = CGSize(width: 88, height: 88)
        let config = UIImage.SymbolConfiguration(pointSize: 42, weight: .semibold)
        guard let lock = UIImage(systemName: "lock.fill", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return nil }

        return UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            lock.draw(at: CGPoint(x: (size.width - lock.size.width) / 2,
                                 y: (size.height - lock.size.height) / 2))
        }
    }
}
