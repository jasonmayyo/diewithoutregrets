import SwiftUI
import RevenueCat
import RevenueCatUI

struct OnboardingView: View {
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    
    private var showProgressBar: Bool {
        let step = onboardingViewModel.currentStep
        return step != .theHook
            && step != .completion
            && step != .paywall
            && step != .notificationPermission
    }
    
    private var isDarkStep: Bool {
        switch onboardingViewModel.currentStep {
        case .theHook:
            return true
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showProgressBar {
                ZStack(alignment: .top) {
                    (isDarkStep ? Color(hex: 0x184449) : Color.white)
                        .ignoresSafeArea(.all, edges: .top)
                        .frame(height: 40)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(isDarkStep ? Color.white.opacity(0.15) : Color(hex: 0x184449).opacity(0.1))
                                .frame(height: 5)
                                .cornerRadius(2.5)
                            
                            Rectangle()
                                .fill(isDarkStep ? Color.white : Color(hex: 0x184449))
                                .frame(width: geometry.size.width * CGFloat(onboardingViewModel.progress), height: 5)
                                .cornerRadius(2.5)
                                .animation(.easeInOut(duration: 0.5), value: onboardingViewModel.progress)
                        }
                    }
                    .frame(height: 5)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .padding(.top, 24)
                }
            }
            
            Group {
                switch onboardingViewModel.currentStep {
                // Phase 1: Emotional Hook
                case .theHook:
                    TheHookView()
                        .environmentObject(onboardingViewModel)
                case .theFeeling:
                    TheFeelingView()
                        .environmentObject(onboardingViewModel)
                case .theObstacle:
                    TheObstacleView()
                        .environmentObject(onboardingViewModel)
                    
                // Phase 2: Reality Check
                case .screenTimeStudy:
                    ScreenTimeStudyView()
                        .environmentObject(onboardingViewModel)
                case .yourScreenTime:
                    YourScreenTimeView()
                        .environmentObject(onboardingViewModel)
                case .yourName:
                    NameView()
                        .environmentObject(onboardingViewModel)
                case .yourAge:
                    AgeSelectView()
                        .environmentObject(onboardingViewModel)
                case .theCost:
                    BreakdownView()
                        .environmentObject(onboardingViewModel)
                    
                // Phase 3: The Shift
                case .procrastinationStudy:
                    ProcrastinationStudyView()
                        .environmentObject(onboardingViewModel)
                case .consistencyReframe:
                    StudyConsistancy()
                        .environmentObject(onboardingViewModel)
                    
                // Phase 4: The Solution
                case .howItWorks:
                    HowItWorksView()
                        .environmentObject(onboardingViewModel)
                case .aiFlashcards:
                    AIFlashcardDemo()
                        .environmentObject(onboardingViewModel)
                case .flashcardSources:
                    FlashcardSourcesView()
                        .environmentObject(onboardingViewModel)
                case .retentionStudy:
                    LongTermResultsView()
                        .environmentObject(onboardingViewModel)
                case .socialProof:
                    RatingView()
                        .environmentObject(onboardingViewModel)
                    
                // Phase 5: Setup & Commitment
                case .readyView:
                    StudyGuardReadyView()
                        .environmentObject(onboardingViewModel)
                case .paywall:
                    PayWallView()
                        .environmentObject(onboardingViewModel)
                case .notificationPermission:
                    FreeTrialReminderView()
                        .environmentObject(onboardingViewModel)
                case .unlockMethodChoice:
                    UnlockMethodChoiceView()
                        .environmentObject(onboardingViewModel)
                case .appSelection:
                    AppSelectionOnboarding()
                        .environmentObject(onboardingViewModel)
                case .createFirstCards:
                    CreateFirstCardsOnboardingView()
                        .environmentObject(onboardingViewModel)
                case .completion:
                    CompletionView()
                        .environmentObject(onboardingViewModel)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
