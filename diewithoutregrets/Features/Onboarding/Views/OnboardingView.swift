//
//  OnboardingView.swift
//  diewithoutregrets
//
//  Onboarding v3 container. Screens crossfade (0.3s opacity); the backdrop
//  runs the narrative arc — daylight hook, night falls at .theFeeling and
//  holds through the semester receipt, dawn at the turn (.theImagine) and
//  daylight after. The clipboard mascot "interviewer" is rendered ONCE here
//  as an overlay above the five quiz screens, so he floats continuously
//  while questions swap beneath him.
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
                // Phase 1 — The pain
                case .hook:
                    HookView()
                case .theFeeling:
                    TheFeelingIntroView()
                case .notYourFault:
                    NotYourFaultView()
                case .willpowerLie:
                    WillpowerLieView()
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
                case .quizExamDate:
                    QuizExamDateView()

                // Phase 2 — The semester receipt
                case .calculating:
                    CalculatingView()
                case .semesterDrain:
                    SemesterDrainView()
                case .daysLost:
                    DaysLostCycleView()
                case .theImagine:
                    TheImagineView()

                // Phase 3 — The offer
                case .science:
                    ScienceView()
                case .coreMechanic:
                    CoreMechanicView()
                case .noWillpower:
                    NoWillpowerView()
                case .moreFeatures:
                    MoreFeaturesView()
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

            // The interviewer: one mascot instance floating above all the
            // quiz screens, looping continuously while questions crossfade
            // beneath him. Respects the flow-chrome inset so he sits below
            // the progress bar; identity is stable across steps so the
            // Lottie never restarts mid-quiz.
            if onboardingViewModel.currentStep.isQuizStep {
                VStack {
                    MascotView(pose: .clipboard, loops: nil)
                        .frame(width: 112, height: 112)
                        .sgShadow(SGTheme.glow(SGTheme.mint))
                        .padding(.top, 8)
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        // The flow-wide chrome (Secure pattern): ONE progress bar + back
        // affordance persisting across steps while content crossfades
        // beneath it, so the whole funnel reads as a single journey.
        .safeAreaInset(edge: .top, spacing: 0) {
            if onboardingViewModel.currentStep.showsFlowChrome {
                flowChrome
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingViewModel.currentStep)
    }

    private var flowChrome: some View {
        HStack(spacing: 14) {
            if onboardingViewModel.canGoBack {
                // 34pt visual chip inside a 44pt tap target.
                Button {
                    onboardingViewModel.backStep()
                } label: {
                    Image(systemName: "arrow.backward")
                        .font(SGTheme.buttonSmall)
                        .foregroundColor(night ? OnbNight.textPrimary : SGTheme.paper)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(night ? OnbNight.chipFill : SGTheme.glaze(0.06))
                        )
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SGPressStyle())
                .accessibilityLabel("Back")
            }

            SGProgressBar(progress: onboardingViewModel.overallProgress,
                          tint: night ? .white : SGTheme.mint)
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .animation(SGTheme.springFast, value: onboardingViewModel.canGoBack)
    }

    private var night: Bool { onboardingViewModel.currentStep.isNight }
}

#Preview {
    OnboardingView()
}
