//
//  OnboardingView.swift
//  diewithoutregrets
//
//  Onboarding v2 container. Screens crossfade (0.3s opacity); the backdrop
//  runs the narrative arc — daylight hook, night sky through the villain
//  arc and reality check, dawn at the turn (.reclaim) and daylight after.
//  The clipboard mascot "interviewer" is rendered ONCE here as an overlay
//  above the four quiz screens, so he floats continuously while questions
//  swap beneath him and takes a note on every answer.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            NightSkyBackdrop()
                .opacity(onboardingViewModel.currentStep.isNight ? 1 : 0)
                .animation(.easeInOut(duration: 1.2), value: onboardingViewModel.currentStep.isNight)

            Group {
                switch onboardingViewModel.currentStep {
                // Phase 1 — Discovery
                case .hook:
                    HookView()
                case .notYourFault:
                    NotYourFaultView()
                case .fightingBack:
                    FightingBackView()
                case .meetYourGuard:
                    MeetYourGuardView()
                case .quizAge:
                    QuizAgeView()
                case .quizStudentType:
                    QuizStudentTypeView()
                case .quizScreenTime:
                    QuizScreenTimeView()
                case .quizScrollTimes:
                    QuizScrollTimesView()

                // Phase 2 — Reality check
                case .calculating:
                    CalculatingView()
                case .lifeDrain:
                    LifeDrainView()
                case .studyVsScroll:
                    StudyVsScrollChartView()
                case .hoursLost:
                    HoursLostCycleView()
                case .reclaim:
                    ReclaimView()
                case .afterChart:
                    AfterChartView()

                // Phase 3 — Convert
                case .science:
                    ScienceView()
                case .coreMechanic:
                    CoreMechanicView()
                case .moreFeatures:
                    MoreFeaturesView()
                case .founderStory:
                    FounderStoryView()
                case .reviews:
                    ReviewsView()
                case .paywall:
                    HardPaywallView()

                // Phase 4 — Post-purchase setup
                case .screenTimeExplainer:
                    ScreenTimeExplainerView()
                case .screenTimePermission:
                    ScreenTimePermissionView()
                case .guardedApps:
                    GuardedAppsOnboarding()
                case .usageInterval:
                    UsageIntervalOnboarding()
                case .notificationPrimer:
                    NotificationPrimerView()
                case .unlockMethod:
                    UnlockMethodChoiceView()
                case .createFirstCards:
                    CreateFirstCardsOnboardingView()
                case .completion:
                    CompletionView()
                }
            }
            .environmentObject(onboardingViewModel)
            .id(onboardingViewModel.currentStep)
            .transition(.opacity)

            // The interviewer: one mascot instance floating above all four
            // quiz screens, replaying his note-taking on every answer.
            if onboardingViewModel.currentStep.isQuizStep {
                VStack {
                    MascotView(pose: .clipboard, loops: nil,
                               replayKey: onboardingViewModel.quizNoteKey)
                        .frame(width: 112, height: 112)
                        .shadow(color: SGTheme.mint.opacity(0.35), radius: 22)
                        .padding(.top, 56)
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingViewModel.currentStep)
    }
}

#Preview {
    OnboardingView()
}
