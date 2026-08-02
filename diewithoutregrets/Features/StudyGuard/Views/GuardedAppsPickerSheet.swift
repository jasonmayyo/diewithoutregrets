//
//  GuardedAppsPickerSheet.swift
//  diewithoutregrets
//
//  Wraps FamilyActivityPicker behind an authorization gate (the picker
//  renders an empty list without approval) and funnels every save through
//  StudyGuardManager.updateSelection so its refusal rules always apply.
//

import SwiftUI
import FamilyControls

struct GuardedAppsPickerSheet: View {
    @ObservedObject private var manager = StudyGuardManager.shared
    @Environment(\.dismiss) private var dismiss
    /// Lets the setup flow chain to the interval sheet after a save.
    var onSaved: ((StudyGuardManager.SelectionUpdateResult) -> Void)? = nil

    @State private var localSelection = FamilyActivitySelection()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var dismissOnAlertOK = false
    @State private var pendingResult: StudyGuardManager.SelectionUpdateResult?

    var body: some View {
        VStack(spacing: 0) {
            SGSheetHeader(
                title: "Guarded apps",
                subtitle: "He locks these when your scroll time runs out.",
                onClose: { dismiss() }
            )
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            // Tighter than the standard 20: FamilyActivityPicker brings its
            // own top whitespace.
            .padding(.bottom, 8)

            if manager.authorizationStatus == .approved {
                FamilyActivityPicker(selection: $localSelection)
                saveBar
            } else {
                authorizationExplainer
            }
        }
        .background(SGTheme.ink.ignoresSafeArea())
        .tint(SGTheme.mint)
        .sgSheetChrome()
        .onAppear {
            manager.refresh()
            localSelection = manager.selection
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if dismissOnAlertOK {
                    dismiss()
                    if let result = pendingResult {
                        pendingResult = nil
                        onSaved?(result)
                    }
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var saveBar: some View {
        let count = SGContract.tokenCount(localSelection)
        let overLimit = count > SGContract.maxSelectionTokens
        return VStack(spacing: 10) {
            Text(overLimit
                 ? "\(count) of \(SGContract.maxSelectionTokens) selected. Deselect a few."
                 : "\(count) of \(SGContract.maxSelectionTokens) selected")
                .font(SGTheme.caption.weight(.semibold))
                .foregroundColor(overLimit ? SGTheme.emberDeep : SGTheme.paperSecondary)

            SGButton(title: "Save") {
                save()
            }
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(SGTheme.ink)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SGTheme.hairline)
                .frame(height: 1)
        }
    }

    private var authorizationExplainer: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(SGTheme.display(44, weight: .regular))
                .foregroundColor(SGTheme.mint)

            Text("Allow Screen Time access")
                .font(SGTheme.display(24))
                .foregroundColor(SGTheme.paper)

            Text("Study Guard uses Apple's Screen Time to lock your distracting apps. Your app activity stays on your device. We never see it.")
                .font(SGTheme.body)
                .foregroundColor(SGTheme.paperSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            SGButton(title: "Allow access", fullWidth: false) {
                Task { @MainActor in
                    await manager.requestAuthorization()
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(SGTheme.ink)
    }

    private func save() {
        let result = manager.updateSelection(localSelection)
        switch result {
        case .saved:
            captureSelectionAnalytics()
            onSaved?(result)
            dismiss()
        case .refusedEmpty:
            // Persisted, but monitoring is paused until apps are picked again.
            onSaved?(result)
            dismiss()
        case .rebaselined(let remainingMinutes):
            captureSelectionAnalytics()
            pendingResult = result
            dismissOnAlertOK = true
            alertTitle = "Apps updated"
            alertMessage = "Your new apps count toward the \(remainingMinutes) minute\(remainingMinutes == 1 ? "" : "s") you have left."
            showAlert = true
        case .refusedTooMany:
            dismissOnAlertOK = false
            alertTitle = "Too many selected"
            alertMessage = "Screen Time supports up to \(SGContract.maxSelectionTokens) apps, categories, and websites. Deselect a few."
            showAlert = true
        case .refusedLocked:
            // Callers hide editing while locked, but handle it anyway.
            pendingResult = nil
            dismissOnAlertOK = true
            alertTitle = "Apps are locked"
            alertMessage = "Unlock your apps first to edit which ones are guarded."
            showAlert = true
        }
    }

    private func captureSelectionAnalytics() {
        Analytics.capture("guarded_apps_selected", properties: [
            "app_count": localSelection.applicationTokens.count,
            "category_count": localSelection.categoryTokens.count,
            "web_domain_count": localSelection.webDomainTokens.count,
            "surface": "guard_tab",
        ])
    }
}
