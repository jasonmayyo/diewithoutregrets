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
import UIKit

struct EmergencyUnlockSheet: View {
    @ObservedObject private var manager = StudyGuardManager.shared
    @Environment(\.dismiss) private var dismiss
    /// Called after a successful emergency unlock (e.g. dismiss the quiz).
    var onUnlocked: () -> Void

    /// Snapshotted on appear: spending the last unlock flips the live value
    /// while the sheet is animating closed, which would swap the layout and
    /// resize the detent mid-dismissal.
    @State private var exhausted = false
    @State private var hasUnlocked = false
    @State private var returnDestination: ShieldReturnDestination?
    @StateObject private var appReturn = UnlockAppReturn()

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
                        SGButton(title: hasUnlocked ? "Return to app" : "Unlock my apps",
                                 variant: .ember, loading: appReturn.isOpening, action: unlockAndReturn)
                    }

                    SGButton(title: hasUnlocked ? "Stay in Study Guard" : (exhausted ? "Close" : "Never mind, I'll study"), variant: .ghost) {
                        if hasUnlocked { finish() } else { dismiss() }
                    }
                    .disabled(appReturn.isOpening)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .onAppear {
            guard !hasUnlocked else { return }
            exhausted = manager.emergencyUnlocksRemaining == 0
            returnDestination = NavigationModel.shared.unlockReturnDestination
        }
        .interactiveDismissDisabled(hasUnlocked)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            appReturn.didEnterBackground()
        }
        .alert("Your apps are unlocked", isPresented: $appReturn.showFallback) {
            if returnDestination != nil {
                Button("Try again", action: unlockAndReturn)
            }
            Button("Done", action: finish)
        } message: {
            Text(UnlockAppReturn.fallbackMessage(for: returnDestination))
        }
    }

    private func unlockAndReturn() {
        guard !appReturn.isOpening else { return }
        // A failed app open may be retried, but must never spend another unlock.
        if !hasUnlocked {
            guard manager.useEmergencyUnlock() else {
                exhausted = manager.emergencyUnlocksRemaining == 0
                return
            }
            hasUnlocked = true
        }
        appReturn.open(returnDestination, onReturned: finish)
    }

    private func finish() {
        dismiss()
        onUnlocked()
    }
}
