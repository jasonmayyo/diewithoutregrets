//
//  StudyGuardShieldExtension.swift
//  StudyGuardShield
//
//  Custom shield appearance for Study Guard locks. Static branded config for
//  all four shield variants; the only dynamic read is the armed threshold for
//  the title. The primary button performs the system default (close the
//  shielded app) — shield buttons cannot open the host app, so re-entry is
//  driven by the lock notification and the shield copy naming Study Guard.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class StudyGuardShieldExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        studyGuardShield()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        studyGuardShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        studyGuardShield()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        studyGuardShield()
    }

    private func studyGuardShield() -> ShieldConfiguration {
        // Teal Ink tokens (extensions can't share SwiftUI theme code).
        let ink = UIColor(red: 0x0C / 255.0, green: 0x1E / 255.0, blue: 0x22 / 255.0, alpha: 1)
        let mint = UIColor(red: 0x2B / 255.0, green: 0xC3 / 255.0, blue: 0x91 / 255.0, alpha: 1)
        let paper = UIColor(red: 0xEA / 255.0, green: 0xF4 / 255.0, blue: 0xF1 / 255.0, alpha: 1)

        let armedMinutes = SGContract.sharedDefaults?.integer(forKey: SGContract.Keys.armedThresholdMinutes) ?? 0
        let subtitle = armedMinutes > 0
            ? "Your \(armedMinutes) minutes are up. Your flashcards are waiting in Study Guard."
            : "Your scroll time is up. Your flashcards are waiting in Study Guard."

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterialDark,
            backgroundColor: ink,
            icon: scaledIcon(),
            title: ShieldConfiguration.Label(text: "Caught you scrolling.", color: paper),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: paper.withAlphaComponent(0.75)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: ink),
            primaryButtonBackgroundColor: mint
        )
    }

    /// Shield icons are not auto-scaled — pre-render at point size × screen scale.
    private func scaledIcon() -> UIImage? {
        guard let url = Bundle(for: StudyGuardShieldExtension.self).url(forResource: "angry-mascot", withExtension: "png"),
              let source = UIImage(contentsOfFile: url.path) else { return nil }
        let pointSize: CGFloat = 110
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: pointSize * scale, height: pointSize * scale)
        let renderer = UIGraphicsImageRenderer(size: pixelSize)
        let rendered = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
        return UIImage(cgImage: rendered.cgImage!, scale: 1, orientation: .up)
    }
}
