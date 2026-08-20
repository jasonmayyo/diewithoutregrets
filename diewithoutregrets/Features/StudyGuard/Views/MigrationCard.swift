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
            SGCard(padding: 16, shadowed: false, dashed: SGTheme.mint) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image("sticker-sparkling")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                        Text("One last thing")
                            .font(SGTheme.cardTitle)
                            .foregroundColor(SGTheme.paper)
                    }

                    Text("Study Guard now locks your apps automatically. No Shortcuts needed. If you set up Shortcut automations before, they're inactive now. Remove them to stop the Shortcuts banner appearing when you open apps:")
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)

                    VStack(alignment: .leading, spacing: 6) {
                        migrationStep(1, "Open the Shortcuts app")
                        migrationStep(2, "Go to the Automation tab")
                        migrationStep(3, "Tap each “When … is opened” automation")
                        migrationStep(4, "Swipe left (or tap Delete) to remove it")
                    }

                    HStack(spacing: 12) {
                        SGButton(title: "Open Shortcuts") {
                            Analytics.capture("migration_shortcut_opened")
                            if let url = URL(string: "shortcuts://") {
                                UIApplication.shared.open(url)
                            }
                        }

                        SGButton(title: "I've removed them", variant: .ghost) {
                            let fires = SGContract.sharedDefaults?.integer(forKey: SGContract.Keys.legacyIntentFireCount) ?? 0
                            Analytics.capture("migration_completed", properties: ["legacy_fire_count": fires])
                            dismissed = true
                        }
                    }
                }
            }
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
                .font(SGTheme.caption.bold())
                .foregroundColor(SGTheme.mint)
            Text(text)
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperSecondary)
        }
    }
}
