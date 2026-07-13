//
//  MigrationCard.swift
//  diewithoutregrets
//
//  Shown to legacy Shortcut users after they complete Screen Time setup.
//  Their old automations are already silent no-ops (both intents check
//  sg_setupComplete) — this card just walks them through deleting the
//  automations so Shortcuts stops flashing its banner. Self-contained:
//  decides its own visibility, so callers can place it unconditionally.
//

import SwiftUI

struct MigrationCard: View {
    @ObservedObject private var manager = StudyGuardManager.shared
    /// v1 wrote this for every onboarded user (not only actual automation
    /// users), hence the conditional "If you set up…" copy.
    private let wasLegacyUser = UserDefaults.standard.bool(forKey: "hasSetUpShortcut")
    @AppStorage("migrationCardDismissed") private var dismissed = false
    @AppStorage("migrationCardShownTracked") private var shownTracked = false

    var body: some View {
        if wasLegacyUser && manager.isSetupComplete && !dismissed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(SGTheme.mint)
                    Text("One last thing")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(SGTheme.paper)
                }

                Text("Study Guard now locks your apps automatically. No Shortcuts needed. If you set up Shortcut automations before, they're inactive now. Remove them to stop the Shortcuts banner appearing when you open apps:")
                    .font(.subheadline)
                    .foregroundColor(SGTheme.paperSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    migrationStep(1, "Open the Shortcuts app")
                    migrationStep(2, "Go to the Automation tab")
                    migrationStep(3, "Tap each “When … is opened” automation")
                    migrationStep(4, "Swipe left (or tap Delete) to remove it")
                }

                HStack(spacing: 12) {
                    Button {
                        Analytics.capture("migration_shortcut_opened")
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Shortcuts")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(SGTheme.ink)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(SGTheme.mint)
                            .cornerRadius(50)
                    }

                    Button {
                        let fires = SGContract.sharedDefaults?.integer(forKey: SGContract.Keys.legacyIntentFireCount) ?? 0
                        Analytics.capture("migration_completed", properties: ["legacy_fire_count": fires])
                        dismissed = true
                    } label: {
                        Text("I've removed them")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(SGTheme.paper)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(SGTheme.glaze(0.08))
                            .cornerRadius(50)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .strokeBorder(SGTheme.mint.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
            .onAppear {
                if !shownTracked {
                    shownTracked = true
                    Analytics.capture("migration_card_shown")
                }
            }
        }
    }

    private func migrationStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.bold())
                .foregroundColor(SGTheme.mint)
            Text(text)
                .font(.caption)
                .foregroundColor(SGTheme.paperSecondary)
        }
    }
}
