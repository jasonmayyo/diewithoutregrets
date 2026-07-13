//
//  StudyGuardDebugSection.swift
//  diewithoutregrets
//
//  DEBUG-only harness for the Screen Time engine. Screen Time does not run
//  in the Simulator, so this panel is the primary iteration tool on device:
//  full state dump, force lock/unlock, monitoring restart, notification
//  routing test, and the extension's ring-buffer log.
//

#if DEBUG
import SwiftUI
import FamilyControls
import UserNotifications

struct StudyGuardDebugSection: View {
    @ObservedObject private var manager = StudyGuardManager.shared
    @State private var pickerPresented = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var lastAction = ""

    var body: some View {
        Section("Study Guard v2 (Screen Time)") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(manager.debugStateDump(), id: \.0) { key, value in
                    HStack {
                        Text(key).font(.caption.monospaced()).foregroundColor(.secondary)
                        Spacer()
                        Text(value).font(.caption.monospaced())
                    }
                }
            }
            .padding(.vertical, 4)

            Button {
                Task {
                    let ok = await manager.requestAuthorization()
                    lastAction = ok ? "Authorization approved" : "Authorization NOT approved"
                }
            } label: {
                Label("Request Screen Time authorization", systemImage: "checkmark.shield")
            }

            Button {
                pickerSelection = manager.selection
                pickerPresented = true
            } label: {
                Label("Pick guarded apps", systemImage: "apps.iphone")
            }
            .familyActivityPicker(isPresented: $pickerPresented, selection: $pickerSelection)
            .onChange(of: pickerPresented) { _, presented in
                if !presented {
                    let result = manager.updateSelection(pickerSelection)
                    lastAction = "updateSelection → \(String(describing: result))"
                }
            }

            Button {
                let result = manager.completeSetup()
                lastAction = "completeSetup → \(String(describing: result))"
            } label: {
                Label("Complete setup (flips kill switch)", systemImage: "flag.checkered")
            }

            Button {
                manager.debugForceLock()
                lastAction = "Forced lock"
            } label: {
                Label("Force lock now", systemImage: "lock.fill")
            }

            Button {
                manager.grantFreshBudget(reason: .debug)
                lastAction = "Granted fresh budget"
            } label: {
                Label("Grant fresh budget (unlock)", systemImage: "lock.open.fill")
            }

            Button {
                manager.reconcileOnForeground()
                lastAction = "Reconciled"
            } label: {
                Label("Run foreground reconcile", systemImage: "arrow.triangle.2.circlepath")
            }

            Button {
                let content = UNMutableNotificationContent()
                content.title = "Time's up! Apps locked"
                content.body = "Answer your flashcards in Study Guard to unlock them."
                content.userInfo = ["deeplink": SGContract.unlockDeepLink]
                let request = UNNotificationRequest(identifier: SGContract.lockNotificationID, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
                lastAction = "Posted test lock notification"
            } label: {
                Label("Send test lock notification", systemImage: "bell.badge")
            }

            NavigationLink {
                List(Array(manager.debugExtensionLog().enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption2.monospaced())
                }
                .navigationTitle("Extension log")
            } label: {
                Label("View extension log (sg_extLog)", systemImage: "doc.plaintext")
            }

            Button(role: .destructive) {
                manager.debugResetAll()
                lastAction = "All sg_ state cleared"
            } label: {
                Label("Reset ALL Study Guard state", systemImage: "trash")
            }

            if !lastAction.isEmpty {
                Text(lastAction).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
#endif
