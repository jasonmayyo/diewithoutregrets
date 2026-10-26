//
//  StudyGuardShieldExtension.swift
//  StudyGuardShield
//
//  Custom shield appearance for Study Guard locks. Adaptive system colors
//  keep all four shield variants readable in light and dark appearances.
//  ONE button only ("Study to unlock") — taps are handled by the
//  StudyGuardShieldAction extension records the tapped shield's return app
//  before opening Study Guard.
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
        remember(application, category: category)
        return studyGuardShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        clearCategoryReturn()
        return studyGuardShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        clearCategoryReturn()
        return studyGuardShield()
    }

    private func remember(_ application: Application, category: ActivityCategory? = nil) {
        ShieldReturnContext.remember(
            tokenData: application.token.flatMap { try? JSONEncoder().encode($0) },
            bundleIdentifier: application.bundleIdentifier,
            categoryTokenData: category?.token.flatMap { try? JSONEncoder().encode($0) },
            in: SGContract.sharedDefaults
        )
    }

    private func clearCategoryReturn() {
        ShieldReturnContext.remember(tokenData: nil, bundleIdentifier: nil, in: SGContract.sharedDefaults)
    }

    fileprivate func studyGuardShield(previewMinutes: Int? = nil) -> ShieldConfiguration {
        // System colors resolve in the shield host's appearance, independently
        // of the main app's light-only theme. Keep the red on the lock and CTA;
        // a material over a red canvas washes it pink in light mode.
        // SGTheme.alarmDeep, kept in UIKit for the extension target.
        let buttonRed = UIColor(red: 0xC2 / 255.0, green: 0x27 / 255.0, blue: 0x1E / 255.0, alpha: 1)

        let armedMinutes = previewMinutes
            ?? SGContract.sharedDefaults?.integer(forKey: SGContract.Keys.armedThresholdMinutes) ?? 0
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
    /// Keep the lock red on a transparent canvas in either appearance.
    private func lockIcon(color: UIColor) -> UIImage? {
        let size = CGSize(width: 88, height: 88)
        let config = UIImage.SymbolConfiguration(pointSize: 42, weight: .semibold)
        guard let lock = UIImage(systemName: "lock.fill", withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            lock.draw(at: CGPoint(x: (size.width - lock.size.width) / 2,
                                 y: (size.height - lock.size.height) / 2))
        }
    }
}

#if DEBUG
import SwiftUI

/// Design review only. Uses the actual extension's configuration and rasterized
/// icon without changing Screen Time state. Apple owns the on-device layout;
/// this approximates its spacing and typography, not its enforcement UI.
struct StudyGuardShieldDesignPreview: View {
    var minutes = 15

    var body: some View {
        let configuration = StudyGuardShieldExtension().studyGuardShield(previewMinutes: minutes)
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: configuration.backgroundColor ?? .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let icon = configuration.icon {
                        Image(uiImage: icon)
                            .padding(.bottom, 24)
                    }
                    if let title = configuration.title {
                        Text(title.text)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(uiColor: title.color))
                            .padding(.bottom, 12)
                    }
                    if let subtitle = configuration.subtitle {
                        Text(subtitle.text)
                            .font(.system(size: 17))
                            .foregroundStyle(Color(uiColor: subtitle.color))
                            .lineSpacing(3)
                    }
                    if let button = configuration.primaryButtonLabel {
                        Text(button.text)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(uiColor: button.color))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(uiColor: configuration.primaryButtonBackgroundColor ?? .systemBlue),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .padding(.top, 32)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(width: min(geometry.size.width - 64, 360))
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.46)
            }
        }
    }
}

#Preview("Current shield · light") {
    StudyGuardShieldDesignPreview()
        .preferredColorScheme(.light)
}

#Preview("Current shield · dark") {
    StudyGuardShieldDesignPreview()
        .preferredColorScheme(.dark)
}
#endif
