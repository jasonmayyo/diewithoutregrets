//
//  StudyGuardShieldExtension.swift
//  StudyGuardShield
//
//  Custom shield appearance for Study Guard locks. Adaptive system colors
//  keep all four shield variants readable in light and dark appearances.
//  The selected monster invites the user straight into its study chat.
//  StudyGuardShieldAction handles the cross-process handoff.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

final class StudyGuardShieldExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        remember(application)
        return studyGuardShield(applicationName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        remember(application, category: category)
        return studyGuardShield(applicationName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        clearCategoryReturn()
        return studyGuardShield(applicationName: webDomain.domain, fallbackName: "this website")
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        clearCategoryReturn()
        return studyGuardShield(applicationName: webDomain.domain, fallbackName: "this website")
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

    fileprivate func studyGuardShield(applicationName: String? = nil,
                                     fallbackName: String = "this app",
                                     previewPersona: MonsterPersona? = nil) -> ShieldConfiguration {
        let persona = previewPersona ?? MonsterPersona.selected(in: SGContract.sharedDefaults)
        let copy = MonsterShieldCopy(persona: persona, applicationName: applicationName, fallback: fallbackName)
        let buttonColor = UIColor(red: 0.102, green: 0.141, blue: 0.125, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: .systemBackground,
            icon: monsterIcon(persona: persona) ?? lockIcon(color: buttonColor),
            title: ShieldConfiguration.Label(text: copy.title, color: .label),
            subtitle: ShieldConfiguration.Label(
                text: copy.subtitle,
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: copy.button, color: .white),
            primaryButtonBackgroundColor: buttonColor
        )
    }

    /// Bundle only the four original atlas folders in this extension, rather
    /// than the main app's entire asset catalog. Rasterize the firm pose into
    /// a small transparent icon so the returned image does not retain the atlas.
    private func monsterIcon(persona: MonsterPersona) -> UIImage? {
        let bundle = Bundle(for: StudyGuardShieldExtension.self)
        guard let folder = bundle.url(forResource: persona.artworkAsset, withExtension: "imageset"),
              let atlas = UIImage(contentsOfFile: folder.appendingPathComponent("atlas.png").path)?.cgImage else { return nil }
        let cell = CGRect(x: CGFloat(atlas.width) / 3, y: CGFloat(atlas.height) / 2,
                          width: CGFloat(atlas.width) / 3, height: CGFloat(atlas.height) / 2)
        guard let crop = atlas.cropping(to: cell) else { return nil }
        let size = CGSize(width: 128, height: 128)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: crop).draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }

    /// Render in points; the renderer supplies the display scale exactly once.
    /// Safe fallback if a resource is missing in an incorrectly assembled build.
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
    var persona: MonsterPersona = .willow
    var applicationName = "Instagram"

    var body: some View {
        let configuration = StudyGuardShieldExtension().studyGuardShield(applicationName: applicationName, previewPersona: persona)
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
