// Adapted from OneThing working copy, 20 October 2026.
// Layout and questions preserved; Study Guard colors and mascot substituted.
import Foundation

/// Stable screen IDs keep the new funnel distinct from the previous onboarding.
enum SGV5V5OnboardingStep: Int, CaseIterable {
    case welcome = 800, moreLife, stoppingPoint, goal, pain, moment, activities, habit
    case empathy, founders, baseline, reflection, timeBack, demo, commitment, assembly, plan
    // Added after `plan` so every existing screen keeps its stable raw value.
    case method
    // Appended last to keep every raw value stable. Placed before `timeBack` in the
    // funnel (see `prePaywallSteps`): now the phone-time cost before their exam.
    case lifeCost
    // Appended last to keep every raw value stable. Placed before `lifeCost` in the
    // funnel: the age question retained for a later content pass.
    case age
    // Separate subject question; preserve the IDs of all existing screens.
    case subject

    // Keep IDs stable when moving screens or retiring one from the active funnel.
    // `reflection` and `founders` are retired. The exam-time projection leads into
    // reassurance, the method, then the user's study-to-scroll rule.
    static let prePaywallSteps: [Self] = [
        .welcome, .demo, .goal, .pain, .moment, .activities, .subject, .habit,
        .baseline, .age, .lifeCost, .empathy, .method, .timeBack,
        .moreLife, .commitment, .assembly, .plan
    ]
    static let flowOrder = prePaywallSteps.map(\.rawValue) + [506, 601, 602, 606, 604]

    static var isPreviewEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-onboarding-preview")
        #else
        return false
        #endif
    }

    var progress: Double {
        Double(Self.prePaywallSteps.firstIndex(of: self) ?? 0) / Double(Self.prePaywallSteps.count - 1)
    }

    var name: String {
        switch self {
        case .welcome: return "Welcome"
        case .moreLife: return "Study More"
        case .stoppingPoint: return "A Stopping Point"
        case .goal: return "Your Study Level"
        case .subject: return "Your Exam Subject"
        case .pain: return "Your Friction"
        case .moment: return "Your Scrolling Moment"
        case .activities: return "Generate Flashcards"
        case .habit: return "Your Next Exam"
        case .empathy: return "It's Not Your Fault"
        case .founders: return "Founder Story"
        case .baseline: return "Your Starting Point"
        case .age: return "Your Age"
        case .reflection: return "Your Pattern"
        case .lifeCost: return "Time Before Your Exam"
        case .timeBack: return "Your Extra Study Time"
        case .method: return "One Thing Method"
        case .demo: return "Try Your One Thing"
        case .commitment: return "Start Small"
        case .assembly: return "Build Your Plan"
        case .plan: return "Your Personal Plan"
        }
    }

    var phase: String {
        switch self {
        case .welcome, .demo, .stoppingPoint: return "Value"
        case .goal, .subject, .pain, .moment, .activities, .habit: return "Personalize"
        case .founders: return "Trust"
        case .baseline, .age, .reflection, .lifeCost, .empathy, .timeBack, .method: return "Time Back"
        case .moreLife, .commitment, .assembly, .plan: return "Your Plan"
        }
    }
}

protocol SGV5V5OnboardingChoice: RawRepresentable, CaseIterable, Hashable, Identifiable where RawValue == String {
    var title: String { get }
    var detail: String { get }
    var symbol: String { get }
}

extension SGV5V5OnboardingChoice {
    var id: String { rawValue }
}

struct SGV5V5OnboardingProfile: Codable, Equatable {
    static let draftKey = "studyguard.onboarding.v5.profile"
    // Optional additions keep first-copy saved drafts decodable.
    var studyLevel: StudyLevel? = nil
    var subject: String? = nil
    var examDate: Date? = nil
    /// Missing in earlier drafts; the displayed default is ten correct cards.
    var studyRule: StudyRule? = nil
    var goal: Goal?
    var pain: Pain?
    var moment: Moment?
    var habit: Habit?
    var baseline: Baseline?
    /// Retained answer, independent of the exam-time projection.
    var ageBracket: AgeBracket? = nil
    var dailyReductionMinutes = 30
    var startSmaller = false
    /// Daily screen-time goal (minutes) chosen on the time-back slider. Optional so
    /// older saved drafts keep decoding; falls back to `defaultGoalMinutes`.
    var dailyGoalMinutes: Int? = nil

    private var hasAvailableGoal: Bool { goal.map { Goal.availableChoices.contains($0) } ?? false }
    var isReady: Bool { hasStudyContext && hasUpcomingExam() && pain != nil && moment != nil && baseline != nil }
    var hoursOver30Days: Double { Double(dailyReductionMinutes) / 2 }
    var hoursLabel: String { hoursOver30Days.formatted(.number.precision(.fractionLength(0...1))) }

    /// Self-reported daily hours, used only for the exam-countdown and goal
    /// projections. A mid estimate stands in when the user wasn't sure. These are
    /// the user's own estimate, never presented as measured Screen Time.
    var estimatedDailyHours: Int { baseline?.estimatedHours ?? 4 }
    /// Match the self-reported estimate; never reclaim more time than that estimate.
    var estimatedDailyMinutes: Int { max(30, estimatedDailyHours * 60) }
    var studySubject: String { (subject ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasStudyContext: Bool { studyLevel != nil && !studySubject.isEmpty }
    var subjectLabel: String { studySubject.isEmpty ? "your subject" : studySubject }

    func hasUpcomingExam(from now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let examDate else { return false }
        return calendar.startOfDay(for: examDate) >= calendar.startOfDay(for: now)
    }
    /// Calendar days avoid 23/25-hour DST-day errors. Today means zero full days.
    func daysUntilExam(from now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let examDate else { return 0 }
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                              to: calendar.startOfDay(for: examDate)).day ?? 0)
    }
    var examDays: Int { daysUntilExam() }
    var phoneHoursBeforeExam: Int { examDays * estimatedDailyHours }
    var reclaimedHoursBeforeExam: Double { Double(timeBackMinutes * examDays) / 60 }
    var reclaimedHoursLabel: String { reclaimedHoursBeforeExam.formatted(.number.precision(.fractionLength(0...1))) }
    var examDateLabel: String { examDate?.formatted(date: .abbreviated, time: .omitted) ?? "your exam" }
    /// A sensible starting goal: roughly half of today's usage, on a 30-min grid.
    var defaultGoalMinutes: Int { max(30, (estimatedDailyMinutes / 2 / 30) * 30) }
    /// The chosen goal, clamped into the slider's range.
    var effectiveGoalMinutes: Int { min(estimatedDailyMinutes, max(30, dailyGoalMinutes ?? defaultGoalMinutes)) }
    /// The time-back control runs left-to-right from no reduction to a 30-minute
    /// phone goal. Keep its projection, snapping, and persisted plan in sync.
    static let timeBackStepMinutes = 15
    var maximumTimeBackMinutes: Int { estimatedDailyMinutes - 30 }
    var timeBackMinutes: Int { estimatedDailyMinutes - effectiveGoalMinutes }
    var timeBackWholeWeeks: Int { Int(reclaimedHoursBeforeExam / 168) }

    func snappedTimeBackMinutes(_ minutes: Double) -> Int {
        guard minutes.isFinite else { return timeBackMinutes }
        let clamped = min(Double(maximumTimeBackMinutes), max(0, minutes))
        let step = Double(Self.timeBackStepMinutes)
        return min(maximumTimeBackMinutes, Int((clamped / step).rounded()) * Self.timeBackStepMinutes)
    }

    mutating func setTimeBackMinutes(_ minutes: Double) {
        let reclaimed = snappedTimeBackMinutes(minutes)
        dailyGoalMinutes = estimatedDailyMinutes - reclaimed
        dailyReductionMinutes = reclaimed
    }
    var habitMinutes: Int {
        let minutes = habit == .journal ? 5 : 10
        return startSmaller ? max(2, minutes / 2) : minutes
    }
    var selectedStudyRule: StudyRule { studyRule ?? .ten }
    var studyCardCount: Int { selectedStudyRule.rawValue }
    var studyPerCardSeconds: Int { selectedStudyRule.secondsPerCard }
    var studyRuleSummary: String { "\(studyCardCount) correct flashcards → 5 minutes" }
    var habitAction: String { "Review \(studyCardCount) \(subjectLabel) flashcards" }

    /// A scenario, not a measured saving: each study/scroll cycle replaces time
    /// inside the user's existing phone window. Keep study + scroll time fixed;
    /// do not count study on top of an unchanged scrolling baseline.
    static let projectedSecondsPerStudyCard = 30.0
    var projectedStudyMinutesPerUnlock: Double {
        Double(studyCardCount) * Self.projectedSecondsPerStudyCard / 60
    }
    var projectedStudyShare: Double {
        projectedStudyMinutesPerUnlock / (projectedStudyMinutesPerUnlock + Double(StudyRule.rewardMinutes))
    }
    func projectedStudyHoursBeforeExam(from now: Date = Date(), calendar: Calendar = .current) -> Double {
        Double(daysUntilExam(from: now, calendar: calendar) * estimatedDailyHours) * projectedStudyShare
    }
    var projectedStudyHoursLabel: String {
        projectedStudyHoursBeforeExam().formatted(.number.precision(.fractionLength(0...1)))
    }
    var studyProjectionExplanation: String {
        let minutes = projectedStudyMinutesPerUnlock.formatted(.number.precision(.fractionLength(0...1)))
        return "Based on \(examDays) days until your exam and your estimate of \(estimatedDailyHours) hours a day on your phone.\n\nWe assume 30 seconds per correct flashcard: \(studyCardCount) cards take about \(minutes) minutes of study, followed by 5 minutes of scrolling.\n\nIf those study-and-scroll cycles replace that same phone-time window, about \(projectedStudyHoursLabel) hours shift to studying. Your actual usage and study pace will vary."
    }

    enum StudyRule: Int, Codable, CaseIterable, Identifiable {
        case five = 5, ten = 10, twenty = 20
        var id: Int { rawValue }
        static let rewardMinutes = 5
        var secondsPerCard: Int { Self.rewardMinutes * 60 / rawValue }
    }
    var momentLabel: String { moment?.planLabel ?? "before your next scroll" }
    var goalLabel: String { studyLevel?.title ?? "Your studies" }

    func canContinue(from step: SGV5V5OnboardingStep) -> Bool {
        switch step {
        case .goal: return studyLevel != nil
        case .subject: return !studySubject.isEmpty
        case .pain: return pain != nil
        case .moment: return moment != nil
        case .habit: return hasUpcomingExam()
        case .baseline: return baseline != nil
        case .age: return ageBracket != nil
        case .assembly, .plan: return isReady
        default: return true
        }
    }

    mutating func clearRetiredPriority() {
        if goal != nil && !hasAvailableGoal { goal = nil }
    }

    enum StudyLevel: String, Codable, SGV5V5OnboardingChoice {
        case highSchool, university, postgraduate, professional
        var title: String {
            switch self {
            case .highSchool: return "High school"
            case .university: return "College / university"
            case .postgraduate: return "Postgraduate"
            case .professional: return "Professional exams"
            }
        }
        var legacyValue: String {
            switch self {
            case .highSchool: return "High school"
            case .university: return "College"
            case .postgraduate: return "Grad school"
            case .professional: return "Other"
            }
        }
        var detail: String { "" }
        var symbol: String {
            switch self {
            case .highSchool: return "backpack"
            case .university: return "graduationcap"
            case .postgraduate: return "books.vertical"
            case .professional: return "briefcase"
            }
        }
    }

    enum Goal: String, Codable, SGV5V5OnboardingChoice {
        // Retired values remain decodable so older drafts keep their other answers.
        case focus, fitness, learning, people, creativity, evenings, calm, myself
        static let availableChoices: [Self] = [.focus, .fitness, .learning, .people, .creativity, .calm]

        var ghostAssetName: String {
            switch self {
            case .evenings, .myself: return "ghost-neutral"
            default: return "priority-ghost-\(rawValue)"
            }
        }
        var title: String {
            switch self {
            case .focus: return "More focus"
            case .fitness: return "Health and fitness"
            case .learning: return "Reading and learning"
            case .people: return "Time with my people"
            case .creativity: return "Hobbies and creativity"
            case .evenings: return "Better evenings"
            case .calm: return "A calmer mind"
            case .myself: return "Something just for me"
            }
        }
        var detail: String { "" }
        var symbol: String {
            switch self {
            case .focus: return "scope"
            case .fitness: return "figure.walk"
            case .learning: return "book"
            case .people: return "person.2"
            case .creativity: return "paintpalette"
            case .evenings: return "moon.stars"
            case .calm: return "wind"
            case .myself: return "leaf"
            }
        }
        var planTitle: String {
            switch self {
            case .focus: return "Your focus,\nprotected."
            case .fitness: return "More movement.\nMore energy."
            case .learning: return "More pages.\nMore possibilities."
            case .people: return "More here.\nLess elsewhere."
            case .creativity: return "Make room\nto create."
            case .evenings: return "Your evenings,\nreclaimed."
            case .calm: return "Less noise.\nMore calm."
            case .myself: return "Your goals.\nIn motion."
            }
        }
    }

    enum Pain: String, Codable, SGV5V5OnboardingChoice {
        case time, plans, sleep, presence
        var title: String {
            switch self { case .time: return "Time just disappears"; case .plans: return "I put my own plans off"; case .sleep: return "I stay up later than I want"; case .presence: return "I'm there, but not really present" }
        }
        var detail: String { "" }
        var symbol: String {
            switch self { case .time: return "clock"; case .plans: return "calendar"; case .sleep: return "moon"; case .presence: return "heart" }
        }
        var reflection: String {
            switch self { case .time: return "You want to notice where your time goes."; case .plans: return "You want your own plans to come first."; case .sleep: return "You want an easier place to stop at night."; case .presence: return "You want to be more present in your own life." }
        }
    }

    enum Moment: String, Codable, SGV5V5OnboardingChoice {
        case morning, work, gaps, bedtime
        var title: String {
            switch self { case .morning: return "First thing in the morning"; case .work: return "During work or study"; case .gaps: return "In the gaps in my day"; case .bedtime: return "When I get into bed" }
        }
        var detail: String { "" }
        var symbol: String {
            switch self { case .morning: return "sunrise"; case .work: return "laptopcomputer"; case .gaps: return "cup.and.saucer"; case .bedtime: return "bed.double" }
        }
        var planLabel: String {
            switch self { case .morning: return "before your morning scroll"; case .work: return "before scrolling during work or study"; case .gaps: return "before scrolling in a spare moment"; case .bedtime: return "before your bedtime scroll" }
        }
        var legacyValue: String {
            switch self { case .morning: return "First thing in the morning"; case .work: return "During work or study hours"; case .gaps: return "During breaks"; case .bedtime: return "In bed before sleep" }
        }
    }

    enum Habit: String, Codable, SGV5V5OnboardingChoice {
        // Order here is the on-screen order (a 2-column emoji grid). Keep the count
        // even so the grid has no orphan row. Every case must map (via activityTitle)
        // to a title in OneThingActivity.all, or syncV5Profile can't build the
        // starter activity and selectedOneThing never gets set.
        case reading, walk, exercise, run, meditate, journal, study, deepWork, instrument, social
        // Short label shown in the grid (no duration, so it stays scannable). The
        // commitment length still comes from habitMinutes and shows up in the plan copy.
        var title: String {
            switch self {
            case .reading: return "Read"
            case .walk: return "Walk"
            case .exercise: return "Exercise"
            case .run: return "Run"
            case .meditate: return "Meditate"
            case .journal: return "Journal"
            case .study: return "Study"
            case .deepWork: return "Focus"
            case .instrument: return "Make music"
            case .social: return "Connect"
            }
        }
        var detail: String { "" }
        var emoji: String {
            switch self {
            case .reading: return "📖"
            case .walk: return "🚶"
            case .exercise: return "💪"
            case .run: return "🏃"
            case .meditate: return "🧘"
            case .journal: return "📝"
            case .study: return "🎓"
            case .deepWork: return "🎯"
            case .instrument: return "🎸"
            case .social: return "💬"
            }
        }
        var symbol: String {
            switch self {
            case .reading: return "book"
            case .walk: return "figure.walk"
            case .exercise: return "dumbbell"
            case .run: return "figure.run"
            case .meditate: return "figure.mind.and.body"
            case .journal: return "pencil.and.outline"
            case .study: return "graduationcap"
            case .deepWork: return "laptopcomputer"
            case .instrument: return "music.note"
            case .social: return "bubble.left.and.bubble.right"
            }
        }
        var activityTitle: String {
            switch self {
            case .reading: return "Reading"
            case .walk: return "Walk"
            case .exercise: return "Gym"
            case .run: return "Run"
            case .meditate: return "Meditation"
            case .journal: return "Journal"
            case .study: return "Studying"
            case .deepWork: return "Deep Work"
            case .instrument: return "Practice Instrument"
            case .social: return "Social"
            }
        }
        var verb: String {
            switch self {
            case .reading: return "Read"
            case .walk: return "Walk"
            case .exercise: return "Exercise"
            case .run: return "Run"
            case .meditate: return "Meditate"
            case .journal: return "Journal"
            case .study: return "Study"
            case .deepWork: return "Focus"
            case .instrument: return "Play an instrument"
            case .social: return "Connect with someone"
            }
        }
        var animation: String { self == .reading ? "4_teaching" : "1_idle" }
    }

    enum Baseline: String, Codable, SGV5V5OnboardingChoice {
        case underTwo, twoToFour, fourToSix, sixPlus, unsure
        var title: String {
            switch self { case .underTwo: return "Less than 2 hours"; case .twoToFour: return "2–4 hours"; case .fourToSix: return "4–6 hours"; case .sixPlus: return "6+ hours"; case .unsure: return "I'm not sure" }
        }
        var detail: String { "" }
        var symbol: String { self == .unsure ? "questionmark" : "iphone" }
        /// Estimates are used only by legacy plan storage, never presented as measured usage.
        var estimatedHours: Int? {
            switch self { case .underTwo: return 1; case .twoToFour: return 3; case .fourToSix: return 5; case .sixPlus: return 6; case .unsure: return nil }
        }
    }

    enum AgeBracket: String, Codable, SGV5V5OnboardingChoice {
        case under18, age18to24, age25to34, age35to44, age45to54, age55plus
        var title: String {
            switch self {
            case .under18: return "Under 18"
            case .age18to24: return "18-24"
            case .age25to34: return "25-34"
            case .age35to44: return "35-44"
            case .age45to54: return "45-54"
            case .age55plus: return "55+"
            }
        }
        var detail: String { "" }
        var symbol: String { "person" }
        /// A mid age for the bracket, used to project remaining life. Titles match the
        /// legacy `RecoveryPlan.parseAge` buckets so downstream estimates line up.
        var representativeAge: Int {
            switch self {
            case .under18: return 16
            case .age18to24: return 21
            case .age25to34: return 30
            case .age35to44: return 40
            case .age45to54: return 50
            case .age55plus: return 60
            }
        }
    }
}
