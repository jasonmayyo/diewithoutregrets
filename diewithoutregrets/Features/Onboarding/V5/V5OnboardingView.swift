// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
import SwiftUI
import FamilyControls
import UIKit
import Lottie

/// V5 changes the sequence and personalization, while retaining the original
/// onboarding screens, animations, and shared quiz components.
struct SGV5V5OnboardingView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    let step: SGV5V5OnboardingStep

    var body: some View {
        switch step {
        case .welcome: SGV5WelcomeView(viewModel: viewModel)
        case .personalize: BuddyPersonalizationIntro(viewModel: viewModel)
        case .buddyChat: BuddyOnboardingChatView(viewModel: viewModel)
        case .howGuard, .howStudy, .howEarn: BuddyHowItWorksView(viewModel: viewModel, step: step)
        case .phoneTimeCost: BuddyPhoneTimeCostView(viewModel: viewModel)
        case .moreLife: SGV5V4FightingBackView(viewModel: viewModel, showsReviews: true)
        case .stoppingPoint: SGV5RetiredView(viewModel: viewModel)
        case .goal:
            SGV5StudyLevelView(viewModel: viewModel)
        case .subject:
            SGV5ExamSubjectView(viewModel: viewModel)
        case .pain:
            question("What bothers you about your scrolling?",
                     choices: SGV5V5OnboardingProfile.Pain.allCases, selection: $viewModel.v5Profile.pain)
        case .moment:
            question("When does a minute turn into an hour?",
                     choices: SGV5V5OnboardingProfile.Moment.allCases, selection: $viewModel.v5Profile.moment)
        case .activities:
            SGV5FlashcardGenerationDemo(viewModel: viewModel)
        case .habit:
            SGV5ExamDateView(viewModel: viewModel)
        case .empathy: SGV5V4NotYourFaultView(viewModel: viewModel)
        case .founders: SGV5RetiredView(viewModel: viewModel)
        case .baseline:
            question("How much time do you spend on your phone each day?",
                     choices: SGV5V5OnboardingProfile.Baseline.allCases, selection: $viewModel.v5Profile.baseline)
        case .age:
            question("How old are you?",
                     choices: SGV5V5OnboardingProfile.AgeBracket.allCases, selection: $viewModel.v5Profile.ageBracket)
        case .gender:
            question("What’s your gender?",
                     choices: SGV5V5OnboardingProfile.Gender.allCases, selection: $viewModel.v5Profile.gender)
        case .reflection: SGV5V5PatternView(viewModel: viewModel)
        case .lifeCost: SGV5ExamCostView(viewModel: viewModel)
        case .timeBack: SGV5StudyRuleView(viewModel: viewModel)
        case .method: SGV5V4ScienceBackedView(viewModel: viewModel)
        case .persona: SGV5PersonaPickerView(viewModel: viewModel)
        case .demo: SGV5V4EarnScreenTimeView(viewModel: viewModel, includesShowcase: false)
        case .commitment: SGV5V4GhostWitnessCommitmentView(viewModel: viewModel)
        case .assembly: SGV5V4GeneratingPlanView(viewModel: viewModel)
        case .plan: SGV5V4PersonalizedPlanView(viewModel: viewModel)
        }
    }

    private func question<Choice: SGV5V5OnboardingChoice>(
        _ title: String, choices: [Choice], selection: Binding<Choice?>
    ) -> some View {
        SGV5V5QuestionView(viewModel: viewModel, step: step, title: title,
                       choices: choices, selection: selection)
    }
}

private struct SGV5V5QuestionView<Choice: SGV5V5OnboardingChoice>: View {
    @ObservedObject var viewModel: SGV5FlowModel
    let step: SGV5V5OnboardingStep
    let title: String
    let choices: [Choice]
    @Binding var selection: Choice?
    @State private var showContent = false
    @State private var advanceTask: Task<Void, Never>?

    var body: some View {
        SGV5QuizScreenContainer(progress: step.progress, onBack: { viewModel.previousPage() }) {
            VStack(spacing: 24) {
                Spacer().frame(height: 4)
                Group {
                    if step == .gender || step == .age || step == .baseline {
                        Text(title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(SGTheme.paper)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        SGV5QuizGhostSpeechBubble(question: title)
                    }
                }
                    .padding(.horizontal, SGV5Theme.horizontalPadding)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)

                ScrollView(showsIndicators: step == .goal) {
                    if step == .habit {
                        // Two-column emoji grid: quicker to scan and pick than a long
                        // single-column list.
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                                SGV5V5EmojiOptionButton(emoji: (choice as? SGV5V5OnboardingProfile.Habit)?.emoji ?? "",
                                                    title: choice.title,
                                                    isSelected: selection == choice) {
                                    select(choice)
                                }
                                .accessibilityAddTraits(selection == choice ? .isSelected : [])
                                .accessibilityIdentifier("onboarding.choice.\(choice.rawValue)")
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                                .animation(.easeOut(duration: 0.5).delay(0.3 + Double(index) * 0.05), value: showContent)
                            }
                        }
                        .padding(.horizontal, SGV5Theme.horizontalPadding)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                                Group {
                                    if let goal = choice as? SGV5V5OnboardingProfile.Goal {
                                        SGV5V5IllustratedOptionButton(title: goal.title, isSelected: selection == choice, action: {
                                            select(choice)
                                        }) {
                                            Image(SGV5Assets.name(goal.ghostAssetName))
                                                .resizable()
                                                .scaledToFit()
                                                .blendMode(.multiply)
                                        }
                                    } else if let pain = choice as? SGV5V5OnboardingProfile.Pain {
                                        SGV5V5IllustratedOptionButton(title: pain.title, isSelected: selection == choice, action: {
                                            select(choice)
                                        }) {
                                            Image(SGV5Assets.name("concern-\(pain.rawValue)"))
                                                .resizable()
                                                .scaledToFit()
                                                .blendMode(.multiply)
                                        }
                                    } else {
                                        SGV5NumberedOptionButton(number: index + 1, text: choice.title,
                                                             subtext: choice.detail.isEmpty ? nil : choice.detail,
                                                             isSelected: selection == choice,
                                                             showsSelectionIndicator: false) {
                                            select(choice)
                                        }
                                    }
                                }
                                .accessibilityAddTraits(selection == choice ? .isSelected : [])
                                .accessibilityIdentifier("onboarding.choice.\(choice.rawValue)")
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                                .animation(.easeOut(duration: 0.5).delay(0.3 + Double(index) * 0.05), value: showContent)
                            }
                        }
                        .padding(.horizontal, SGV5Theme.horizontalPadding)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear { showContent = true }
        .onDisappear { advanceTask?.cancel() }
    }

    private func select(_ choice: Choice) {
        guard advanceTask == nil else { return }
        SGV5Haptics.play(.selection)
        selection = choice
        if step == .habit { viewModel.v5Profile.startSmaller = false }
        viewModel.trackUserInput(screenId: step.rawValue, inputType: "single_choice", value: choice.rawValue)
        advanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, viewModel.currentPageIndex == step.rawValue else { return }
            viewModel.advanceV5()
        }
    }
}

private struct SGV5V5IllustratedOptionButton<Illustration: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                illustration()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14).fill(SGTheme.inkRaised))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? SGTheme.mintDeep : SGTheme.paper.opacity(0.15), lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(SGV5ScaleButtonStyle())
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

/// A compact grid cell: emoji + short label. Powers the "What's your One Thing?"
/// two-column layout so options are quick to scan and tap.
private struct SGV5V5EmojiOptionButton: View {
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 22))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SGTheme.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(SGTheme.inkRaised))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? SGTheme.mintDeep : SGTheme.paper.opacity(0.15), lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(SGV5ScaleButtonStyle())
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

/// The new answer reflection uses the original ghost, typography and quiz chrome.
private struct SGV5V5PatternView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    private var profile: SGV5V5OnboardingProfile { viewModel.v5Profile }

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.reflection.progress, onBack: { viewModel.previousPage() }) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    SGV5V4GhostView(mood: .hopeful, size: 100)
                        .padding(.top, 28)
                    Text("A small change.\nIn the right moment.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(SGTheme.paper).multilineTextAlignment(.center)
                    Text(profile.pain?.reflection ?? "Let's make room for what matters to you.")
                        .font(.system(size: 16)).foregroundColor(SGTheme.paper.opacity(0.5))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 20) {
                        answer("What matters", value: profile.goalLabel)
                        answer("Your moment", value: profile.moment?.title ?? "Your next scroll")
                        answer("Your first step", value: profile.habitAction)
                    }.padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(SGTheme.paper.opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SGTheme.paper.opacity(0.1), lineWidth: 1))
                    Text("A starting point built from your answers. You can adjust it as you go.")
                        .font(.system(size: 13)).foregroundColor(SGTheme.paper.opacity(0.4))
                        .multilineTextAlignment(.center)
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
            SGV5QuizContinueButton(text: "Continue") { viewModel.advanceV5() }
                .sgV5FloatingCTA()
        }.background(SGTheme.ink.ignoresSafeArea())
    }

    private func answer(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13)).foregroundColor(SGTheme.paper.opacity(0.4))
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundColor(SGTheme.paper)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A three-stop choice that becomes the real per-card earning rate.
private struct SGV5StudyRuleView: View {
    @ObservedObject var viewModel: SGV5FlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var showsEstimate = false
    private var profile: SGV5V5OnboardingProfile { viewModel.v5Profile }
    private var rules: [SGV5V5OnboardingProfile.StudyRule] { SGV5V5OnboardingProfile.StudyRule.allCases }
    private var selectedIndex: Int { rules.firstIndex(of: profile.selectedStudyRule) ?? 1 }

    var body: some View {
        SGV5QuizScreenContainer(progress: SGV5V5OnboardingStep.timeBack.progress,
                               onBack: { viewModel.previousPage() }) {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        Text("Take your time back.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(-0.7).multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        studyDial(size: min(292, geometry.size.width - 56))

                        Text(profile.examDays == 0
                             ? "Your exam is today.\nEvery card counts."
                             : "before your \(profile.subjectLabel) exam.")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 8) {
                            (Text("\(profile.studyCardCount) flashcards").foregroundColor(SGTheme.mintDeep)
                             + Text(" → 5 min scroll").foregroundColor(SGTheme.paperSecondary))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .monospacedDigit().contentTransition(.numericText())
                                .multilineTextAlignment(.center)
                                .accessibilityLabel(profile.studyRuleSummary)
                                .accessibilityIdentifier("onboarding.studyRule.exchange")

                            SGV5StudyRuleSlider(value: selectedIndex, cards: profile.studyCardCount, onChange: choose)
                            HStack {
                                ForEach(Array(rules.enumerated()), id: \.element) { index, rule in
                                    if index > 0 { Spacer(minLength: 0) }
                                    Button { choose(Double(index)) } label: {
                                        VStack(spacing: 3) {
                                            Text("\(rule.rawValue)").font(.system(size: 16, weight: .semibold))
                                            Text(rule == .ten ? "default" : "cards")
                                                .font(.system(size: 10))
                                        }
                                        .frame(width: 56, height: 44)
                                        .foregroundStyle(profile.selectedStudyRule == rule ? SGTheme.mintDeep : SGTheme.paperSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(rule.rawValue) flashcards for 5 minutes")
                                    .accessibilityAddTraits(profile.selectedStudyRule == rule ? .isSelected : [])
                                }
                            }
                            Button {
                                SGV5Haptics.play(.selection)
                                showsEstimate = true
                            } label: {
                                Label("Estimate · 30 sec per card", systemImage: "info.circle")
                                    .font(.system(size: 11)).foregroundStyle(SGTheme.paperSecondary)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("How your extra study time is estimated")
                        }
                    }
                    .padding(.horizontal, 28).padding(.vertical, 20)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
            SGV5QuizContinueButton(text: "Make this my goal") {
                viewModel.trackUserInput(screenId: 812, inputType: "flashcards_per_five_minutes",
                                        value: String(profile.studyCardCount))
                viewModel.confirmStudyRule()
            }
            .accessibilityIdentifier("onboarding.studyRule.continue")
            .sgV5FloatingCTA()
        }
        .foregroundStyle(SGTheme.paper)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65)) { appeared = true }
        }
        .alert("Your potential study time", isPresented: $showsEstimate) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(profile.studyProjectionExplanation)
        }
    }

    private func studyDial(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [SGTheme.mint.opacity(0.12), .clear],
                                         center: .center, startRadius: 0, endRadius: size / 2))
            SGV5StudyTimeDial(fraction: appeared && profile.examDays > 0 ? profile.projectedStudyShare : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85),
                           value: profile.projectedStudyShare)
            VStack(spacing: 5) {
                Text(profile.projectedStudyHoursLabel)
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .monospacedDigit().minimumScaleFactor(0.45).lineLimit(1)
                    .contentTransition(.numericText(value: profile.projectedStudyHoursBeforeExam()))
                    .frame(maxWidth: size * 0.72)
                (Text("hours of ") + Text("EXTRA").foregroundColor(SGTheme.mintDeep))
                    .font(.system(size: 16, weight: .medium))
                Text("study time").font(.system(size: 16, weight: .medium))
            }
            .offset(y: -size * 0.13)
            Image("sgv5-mascot-idle").resizable().scaledToFit()
                .frame(width: size * 0.42, height: size * 0.42)
                .blendMode(.multiply).offset(y: size * 0.30)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Potential extra study time before your \(profile.subjectLabel) exam")
        .accessibilityValue("Approximately \(profile.projectedStudyHoursLabel) hours")
        .accessibilityIdentifier("onboarding.studyRule.projection")
    }

    private func choose(_ index: Double) {
        let next = rules[min(2, max(0, Int(index.rounded())))]
        guard next != profile.selectedStudyRule else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
            viewModel.v5Profile.studyRule = next
        }
        SGV5Haptics.play(.selection)
    }
}

/// The same open, tick-mark dial as OneThing, filled by the share of the
/// existing scrolling window that would become studying in this scenario.
private struct SGV5StudyTimeDial: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geometry in
            let radius = geometry.size.width / 2 - 8
            ZStack {
                ForEach(0..<49, id: \.self) { index in
                    let filled = fraction > 0 && Double(index) / 48 <= fraction
                    Capsule().fill(filled ? SGTheme.mintDeep : SGTheme.paper.opacity(0.12))
                        .frame(width: 2, height: index.isMultiple(of: 4) ? 13 : 7)
                        .offset(y: -radius)
                        .rotationEffect(.degrees(-135 + Double(index) / 48 * 270))
                }
                Circle().fill(SGTheme.mintDeep).frame(width: 6, height: 6)
                    .offset(y: -(radius - 18))
                    .rotationEffect(.degrees(-135 + fraction * 270))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

private struct SGV5StudyRuleSlider: View {
    let value: Int
    let cards: Int
    let onChange: (Double) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var touching = false

    var body: some View {
        GeometryReader { geometry in
            let thumb: CGFloat = 36
            let travel = max(1, geometry.size.width - thumb)
            ZStack(alignment: .leading) {
                Capsule().fill(SGTheme.paper.opacity(0.10)).frame(height: 14)
                Capsule().fill(SGTheme.mint).frame(width: thumb / 2 + travel * CGFloat(value) / 2, height: 14)
                ForEach(0..<3) { index in
                    Circle().fill(index <= value ? SGTheme.mintDeep : SGTheme.paper.opacity(0.2))
                        .frame(width: 5, height: 5)
                        .offset(x: thumb / 2 + travel * CGFloat(index) / 2 - 2.5)
                }
                Circle().fill(SGTheme.ink)
                    .overlay(Circle().stroke(SGTheme.mintDeep, lineWidth: 3))
                    .shadow(color: SGTheme.mintDeep.opacity(0.15), radius: 5, y: 3)
                    .frame(width: thumb, height: thumb)
                    .scaleEffect(touching && !reduceMotion ? 1.08 : 1)
                    .offset(x: travel * CGFloat(value) / 2)
            }
            .frame(height: 44).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($touching) { _, state, _ in state = true }
                .onChanged { gesture in
                    onChange(Double(min(1, max(0, (gesture.location.x - thumb / 2) / travel))) * 2)
                })
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flashcards for 5 minutes")
        .accessibilityValue("\(cards) correct flashcards")
        .accessibilityHint("Choose 5, 10, or 20 cards.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(Double(min(2, value + 1)))
            case .decrement: onChange(Double(max(0, value - 1)))
            @unknown default: break
            }
        }
        .accessibilityIdentifier("onboarding.studyRule.slider")
    }
}
