//
//  UsageIntervalSheet.swift
//  diewithoutregrets
//
//  Picks the usage interval (N minutes before lock). In setup mode the
//  confirm button hands off to the caller (which runs completeSetup);
//  otherwise selection applies immediately via updateInterval.
//
//  Self-sizing: SGFittedSheet pins the detent to the content height, so the
//  full interval list is always visible — no clipping, no half-sheet scroll.
//

import SwiftUI

struct UsageIntervalSheet: View {
    @ObservedObject private var manager = StudyGuardManager.shared
    @Environment(\.dismiss) private var dismiss
    var isSetupMode = false
    var onConfirm: (() -> Void)? = nil

    var body: some View {
        SGFittedSheet(estimatedHeight: 560) {
            VStack(alignment: .leading, spacing: 20) {
                SGSheetHeader(
                    title: "Usage interval",
                    subtitle: "Your daily starter budget, and what True Focus and emergency unlocks grant. Flashcards earn time per card answered.",
                    onClose: isSetupMode ? nil : { dismiss() }
                )

                VStack(spacing: 8) {
                    ForEach(SGContract.allowedIntervals, id: \.self) { minutes in
                        intervalRow(minutes)
                    }
                }

                if isSetupMode {
                    SGButton(title: "Start guarding") {
                        // Persist the highlighted selection explicitly, so the
                        // guard always starts with exactly what's on screen.
                        manager.updateInterval(manager.intervalMinutes)
                        onConfirm?()
                    }
                    .padding(.top, 4)
                } else {
                    Text("Changes take effect at your next unlock or daily reset.")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperTertiary)
                }
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        // Setup must finish through "Start guarding" — a swipe-down here
        // would silently skip completeSetup after the apps were saved.
        .interactiveDismissDisabled(isSetupMode)
    }

    private func intervalRow(_ minutes: Int) -> some View {
        let isSelected = manager.intervalMinutes == minutes
        return Button {
            if !isSelected {
                manager.updateInterval(minutes)
                SGTheme.tapHaptic()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? SGTheme.mint.opacity(0.15) : SGTheme.glaze(0.06))
                        .frame(width: 30, height: 30)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(SGTheme.micro.weight(.bold))
                            .foregroundColor(SGTheme.mintDeep)
                    }
                }

                Text("\(minutes) minutes")
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Spacer()
            }
            .padding(.horizontal, SGTheme.cardPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(isSelected ? SGTheme.mint.opacity(0.5) : SGTheme.hairline,
                                          lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(SGTheme.springFast, value: isSelected)
    }
}
