//
//  ProfileView.swift
//  diewithoutregrets
//
//  Profile tab + its settings sheets. Split out of ContentView.swift
//  during the Teal Ink redesign so diffs stay reviewable.
//

import SwiftUI
import StoreKit

struct ProfileView: View {
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var showingFlashcardSettings = false
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @State private var showingManageSubscriptions = false
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("focusDuration") private var focusDuration: Int = 5
    @AppStorage("flashcardBreakDuration") private var flashcardBreakDuration: Int = 5
    @AppStorage("trueFocusBreakDuration") private var trueFocusBreakDuration: Int = 30
    @State private var showingFocusDurationSettings = false
    @State private var showingBreakDurationSettings = false
    @ObservedObject private var studyGuard = StudyGuardManager.shared
    @State private var showingUsageIntervalSettings = false
    @State private var showingGuardedAppsPicker = false
    @State private var showingLockedEditAlert = false
    #if DEBUG
    @State private var showingDebug = false
    #endif

    private var totalAvailableCards: Int {
        deckStore.decks.reduce(0) { $0 + $1.cards.count }
    }

    private static let feedbackURL = "https://studyguard.framer.website/support"

    /// Feedback card pinned to the top: the clipboard monster taking notes.
    /// Tapping opens the support page.
    private var feedbackCard: some View {
        Button {
            Analytics.helpLinkClicked(link: "Feedback card", url: Self.feedbackURL)
            if let url = URL(string: Self.feedbackURL) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                MascotView(pose: .clipboard)
                    .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: 5) {
                    SGMicroLabel(text: "Feedback", color: SGTheme.mintDeep)
                    Text("Help shape Study Guard")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                    Text("He's taking notes. Tell us what to build next.")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(SGTheme.rowLabel)
                    .foregroundColor(SGTheme.mint)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, SGTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                    .fill(SGTheme.mint.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                            .strokeBorder(SGTheme.mint.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SGPressStyle())
        .padding(.horizontal, SGTheme.screenPadding)
    }

    private func selectUnlockMethod(_ key: String) {
        if unlockMethod != key {
            Analytics.settingChanged(key: "unlock_method", oldValue: unlockMethod, newValue: key)
            unlockMethod = key
        }
        SGTheme.tapHaptic()
    }

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                SGScreenHeader(eyebrow: "Your account", title: "Profile")

                ScrollView {
                    VStack(spacing: SGTheme.sectionSpacing) {
                feedbackCard

                // Stats Overview
                SGCard(shadowed: false) {
                    HStack(spacing: 40) {
                        StatItem(title: "Decks", value: "\(deckStore.decks.count)", icon: "rectangle.stack.fill")
                        StatItem(title: "Cards", value: "\(totalAvailableCards)", icon: "doc.text.fill")
                        StatItem(title: "To Unlock", value: useAllCards ? "All" : "\(flashcardCount)", icon: "lock.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, SGTheme.screenPadding)
                
                // Study Settings Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Study Settings")
                    
                    // Unlock method picker
                    HStack(spacing: 10) {
                            SGOptionTile(
                                title: "Flashcards",
                                icon: "rectangle.stack.fill",
                                selected: unlockMethod == "flashcards"
                            ) {
                                selectUnlockMethod("flashcards")
                            }
                            SGOptionTile(
                                title: "True Focus",
                                icon: "eye.fill",
                                selected: unlockMethod == "trueFocus"
                            ) {
                                selectUnlockMethod("trueFocus")
                        }
                    }

                    // Flashcard count setting - only relevant when flashcards is selected
                    if unlockMethod == "flashcards" {
                        SGListRow(
                            title: "Flashcards before unlocking",
                            subtitle: useAllCards ? "All cards" : "\(flashcardCount) cards"
                        ) {
                            showingFlashcardSettings = true
                        }
                    }

                    // Focus duration setting - only relevant when True Focus is selected
                    if unlockMethod == "trueFocus" {
                        SGListRow(
                            title: "Focus session length",
                            subtitle: "\(focusDuration) minutes"
                        ) {
                            showingFocusDurationSettings = true
                        }
                    }

                    if studyGuard.isSetupComplete {
                        // v2: usage interval — how long the apps are usable
                        // before they lock (replaces the legacy break duration).
                        SGListRow(
                            title: "Usage interval",
                            subtitle: "\(studyGuard.intervalMinutes) minutes of app use before they lock"
                        ) {
                            showingUsageIntervalSettings = true
                        }

                        // v2: guarded apps
                        SGListRow(
                            title: "Guarded apps",
                            subtitle: SGContract.isSelectionEmpty(studyGuard.selection)
                                ? "No apps guarded yet. Tap to choose"
                                : "\(SGContract.tokenCount(studyGuard.selection)) of \(SGContract.maxSelectionTokens) guarded"
                        ) {
                            if studyGuard.state == .locked {
                                showingLockedEditAlert = true
                            } else {
                                showingGuardedAppsPicker = true
                            }
                        }
                    } else {
                        // Legacy Shortcuts users keep their break-duration
                        // setting until they migrate to Screen Time.
                        SGListRow(
                            title: "Break duration",
                            subtitle: "\(unlockMethod == "trueFocus" ? trueFocusBreakDuration : flashcardBreakDuration) minutes"
                        ) {
                            showingBreakDurationSettings = true
                        }
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                
                // Account Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Account")

                    // Every user is either subscribed or in a trial, so the
                    // only account action is managing that subscription.
                    SGListRow(title: "Manage Subscription", icon: "crown.fill") {
                        showingManageSubscriptions = true
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                
                // Help Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Help & Legal")
                    
                    VStack(spacing: 10) {
                        LinkMenuItem(icon: "questionmark.circle", title: "FAQs", url: "https://studyguard.framer.website/")
                        LinkMenuItem(icon: "exclamationmark.triangle", title: "Report an Error", url: "https://studyguard.framer.website/support")
                        LinkMenuItem(icon: "doc.text", title: "Terms of Use", url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        LinkMenuItem(icon: "hand.raised", title: "Privacy Policy", url: "https://studyguard.framer.website/legal/privacy-policy")
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)

                #if DEBUG
                // Developer Section (debug builds only). The push happens via
                // navigationDestination so the row can be a standard SGListRow.
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Developer")

                    SGListRow(title: "Debug", icon: "ant.fill") {
                        showingDebug = true
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                #endif
                    }
                    .padding(.top, 14)
                    .padding(.bottom, SGTheme.tabBarClearance)
                }
            }
        }
        .navigationBarHidden(true)
        #if DEBUG
        .navigationDestination(isPresented: $showingDebug) {
            DebugView()
        }
        #endif
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .sheet(isPresented: $showingFlashcardSettings) {
            FlashcardSettingsSheet(flashcardCount: $flashcardCount, useAllCards: $useAllCards)
        }
        .sheet(isPresented: $showingFocusDurationSettings) {
            FocusDurationSettingsSheet(focusDuration: $focusDuration)
        }
        .sheet(isPresented: $showingBreakDurationSettings) {
            BreakDurationSettingsSheet(
                breakDuration: unlockMethod == "trueFocus"
                    ? $trueFocusBreakDuration
                    : $flashcardBreakDuration,
                unlockMethod: unlockMethod
            )
        }
        .sheet(isPresented: $showingUsageIntervalSettings) {
            UsageIntervalSheet()
        }
        .sheet(isPresented: $showingGuardedAppsPicker) {
            GuardedAppsPickerSheet()
        }
        .alert("Apps are locked", isPresented: $showingLockedEditAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unlock your apps first to edit which ones are guarded.")
        }
        .onChange(of: flashcardCount) { oldValue, newValue in
            Analytics.settingChanged(key: "flashcard_count", oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: useAllCards) { oldValue, newValue in
            Analytics.settingChanged(key: "use_all_cards", oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: focusDuration) { oldValue, newValue in
            Analytics.settingChanged(key: "focus_duration_minutes", oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: flashcardBreakDuration) { oldValue, newValue in
            Analytics.settingChanged(key: "flashcard_break_minutes", oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: trueFocusBreakDuration) { oldValue, newValue in
            Analytics.settingChanged(key: "true_focus_break_minutes", oldValue: oldValue, newValue: newValue)
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        SGMicroLabel(text: title)
    }
}

/// Help/legal row: an SGListRow that opens an external URL (arrow instead of
/// chevron) and logs the tap before leaving the app.
struct LinkMenuItem: View {
    let icon: String
    let title: String
    let url: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        SGListRow(title: title, icon: icon, trailingIcon: "arrow.up.right") {
            Analytics.helpLinkClicked(link: title, url: url)
            if let destination = URL(string: url) {
                openURL(destination)
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(SGTheme.mint.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(SGTheme.display(20, weight: .medium))
                    .foregroundColor(SGTheme.mint)
            }

            Text(value)
                .font(SGTheme.display(22))
                .monospacedDigit()
                .foregroundColor(SGTheme.paper)

            Text(title)
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperSecondary)
        }
    }
}

struct FlashcardSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var flashcardCount: Int
    @Binding var useAllCards: Bool

    let options = [3, 5, 10, 15, 20, 25]

    var body: some View {
        SGFittedSheet(estimatedHeight: 640) {
            VStack(alignment: .leading, spacing: 20) {
                SGSheetHeader(
                    title: "Flashcards",
                    subtitle: "How many cards you answer to unlock your apps.",
                    onClose: { dismiss() }
                )

                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { number in
                        SGPickerRow(title: "\(number) cards",
                                    selected: !useAllCards && flashcardCount == number) {
                            flashcardCount = number
                            useAllCards = false
                            SGTheme.tapHaptic()
                            dismiss()
                        }
                    }

                    SGPickerRow(title: "All cards", selected: useAllCards) {
                        useAllCards = true
                        SGTheme.tapHaptic()
                        dismiss()
                    }
                }

                Text("If you pick more cards than a deck has, the whole deck is used.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperTertiary)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
    }
}

struct FocusDurationSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var focusDuration: Int

    let options = [1, 3, 5, 10, 15, 20, 25, 30]

    var body: some View {
        SGFittedSheet(estimatedHeight: 700) {
            VStack(alignment: .leading, spacing: 20) {
                SGSheetHeader(
                    title: "Focus session",
                    subtitle: "How long your True Focus session lasts.",
                    onClose: { dismiss() }
                )

                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { minutes in
                        SGPickerRow(title: "\(minutes) \(minutes == 1 ? "minute" : "minutes")",
                                    selected: focusDuration == minutes) {
                            focusDuration = minutes
                            SGTheme.tapHaptic()
                            dismiss()
                        }
                    }
                }

                Text("Finishing a session earns a break on your blocked apps. You set the break length separately.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperTertiary)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
    }
}

struct BreakDurationSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var breakDuration: Int
    let unlockMethod: String

    let options = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        SGFittedSheet(estimatedHeight: 680) {
            VStack(alignment: .leading, spacing: 20) {
                SGSheetHeader(
                    title: "Break duration",
                    subtitle: "How long apps stay unlocked after you \(unlockMethod == "trueFocus" ? "finish a focus session" : "answer your flashcards").",
                    onClose: { dismiss() }
                )

                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { minutes in
                        SGPickerRow(title: "\(minutes) minutes",
                                    selected: breakDuration == minutes) {
                            breakDuration = minutes
                            SGTheme.tapHaptic()
                            dismiss()
                        }
                    }
                }

                Text("When your break ends, apps never suddenly close. The next time you open one, you study again to unlock it. You're always in control.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperTertiary)
            }
            .padding(.horizontal, SGTheme.screenPadding)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Debug View (only included in debug builds)
