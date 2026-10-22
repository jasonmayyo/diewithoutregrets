// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
//
//  SGV5V4GeneratingPlanView.swift
//  OneThing
//
//  Screen 500 (V4): Ghost-led plan generation with personalized checklist.
//

import SwiftUI
import UIKit

struct SGV5V4GeneratingPlanView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var checkedItems: Set<Int> = []
    @State private var showGhost = false
    private var usesV5Profile: Bool { viewModel.currentPageIndex == SGV5V5OnboardingStep.assembly.rawValue }

    private var checklistItems: [String] {
        if usesV5Profile {
            let profile = viewModel.v5Profile
            return [
                "Your studies: \(profile.goalLabel)",
                "Your subject: \(profile.subjectLabel)",
                "Your exam: \(profile.examDateLabel)",
                "Your rule: \(profile.studyRuleSummary)",
                "Your study moment: \(profile.momentLabel)",
            ]
        }
        let hours: String
        if let real = viewModel.userData.realAverageScreenTimeMinutes {
            hours = "\(real / 60)h \(real % 60)m"
        } else {
            hours = "\(viewModel.userData.dailyScreenTimeHours)h"
        }
        let occupation = viewModel.userData.occupation.isEmpty ? "your" : viewModel.userData.occupation
        let habit = viewModel.userData.selectedOneThing.isEmpty ? "your One Thing" : viewModel.userData.selectedOneThing

        return [
            "Analyzing your \(hours) of daily usage...",
            "Building your personalized \(occupation) plan...",
            "Setting your One Thing: \(habit)...",
            "Calculating your recovery timeline...",
            "Preparing your app blocking schedule...",
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SGTheme.ink,
                    SGTheme.ink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Ghost with clipboard
                SGV5V4GhostView(mood: .clipboard, size: 100)
                    .opacity(showGhost ? 1 : 0)
                    .scaleEffect(showGhost ? 1 : 0.7)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showGhost)

                Text("Building your plan...")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(SGTheme.paper)

                // Checklist
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(checklistItems.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(SGTheme.paper.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 22, height: 22)

                                if checkedItems.contains(index) {
                                    Circle()
                                        .fill(Color(red: 0.3, green: 0.9, blue: 0.5))
                                        .frame(width: 22, height: 22)

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(SGTheme.paper)
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: checkedItems.contains(index))

                            Text(item)
                                .font(.system(size: 14))
                                .foregroundColor(checkedItems.contains(index) ? SGTheme.paper : SGTheme.paper.opacity(0.4))
                                .animation(.easeOut(duration: 0.3), value: checkedItems.contains(index))
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            showGhost = true
            if usesV5Profile {
                viewModel.syncV5Profile()
            } else {
                viewModel.generateRecoveryPlan()
            }
            await startChecklist()
        }
    }

    @MainActor private func startChecklist() async {
        let screenId = viewModel.currentPageIndex
        for index in checklistItems.indices where !checkedItems.contains(index) {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled, viewModel.currentPageIndex == screenId else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) { _ = checkedItems.insert(index) }
            SGV5Haptics.animate(.reveal)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled, viewModel.currentPageIndex == screenId else { return }
        SGV5Haptics.animate(.success)
        if usesV5Profile { viewModel.advanceV5() } else { viewModel.nextPage() }
    }

}


