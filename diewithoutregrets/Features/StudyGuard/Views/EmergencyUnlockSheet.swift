//
//  EmergencyUnlockSheet.swift
//  diewithoutregrets
//
//  Replaces the old unlimited "Close Anyway": 3 emergency unlocks per rolling
//  7-day week. Exhausted state shows when the next one becomes available.
//
//  Self-sizing: SGFittedSheet pins the detent to the content height, so both
//  states always fit — no clipping on small devices.
//

import SwiftUI

struct EmergencyUnlockSheet: View {
    @ObservedObject private var manager = StudyGuardManager.shared
    @Environment(\.dismiss) private var dismiss
    /// Called after a successful emergency unlock (e.g. dismiss the quiz).
    var onUnlocked: () -> Void

    /// Snapshotted on appear: spending the last unlock flips the live value
    /// while the sheet is animating closed, which would swap the layout and
    /// resize the detent mid-dismissal.
    @State private var exhausted = false

    var body: some View {
        SGFittedSheet(estimatedHeight: 460) {
            VStack(spacing: 20) {
                Image(systemName: exhausted ? "hourglass" : "exclamationmark.shield.fill")
                    .font(SGTheme.display(44, weight: .regular))
                    .foregroundColor(exhausted ? SGTheme.paperTertiary : SGTheme.ember)
                    .padding(.top, 12)

                Text(exhausted ? "No emergency unlocks left" : "Use an emergency unlock?")
                    .font(SGTheme.sheetTitle)
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)

                if exhausted {
                    if let next = manager.nextEmergencyUnlockDate {
                        Text("You've used all \(SGContract.emergencyUnlocksPerWeek) this week. The next one becomes available on \(next.formatted(date: .abbreviated, time: .shortened)).")
                            .font(SGTheme.body)
                            .foregroundColor(SGTheme.paperSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    Text("Until then, your flashcards (or a focus session) are the way back in. You've got this.")
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                } else {
                    Text("You have \(manager.emergencyUnlocksRemaining) of \(SGContract.emergencyUnlocksPerWeek) left this week. Emergencies only. Every skip is a study session you didn't do.")
                        .font(SGTheme.body)
                        .foregroundColor(SGTheme.paperSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }

                VStack(spacing: 12) {
                    if !exhausted {
                        SGButton(title: "Unlock my apps", variant: .ember) {
                            if manager.useEmergencyUnlock() {
                                dismiss()
                                onUnlocked()
                            }
                        }
                    }

                    SGButton(title: exhausted ? "Close" : "Never mind, I'll study", variant: .ghost) {
                        dismiss()
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .onAppear {
            exhausted = manager.emergencyUnlocksRemaining == 0
        }
    }
}
