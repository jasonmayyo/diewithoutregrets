//
//  BlocksView.swift
//  diewithoutregrets
//
//  The Blocks tab — one place to see and manage everything about blocking:
//  guard on/off, guarded apps, usage interval, which deck unlocks the apps,
//  the unlock method, and emergency unlocks. Mirrors the Decks page layout:
//  hidden nav bar, big display header, token-styled cards.
//

import SwiftUI
import FamilyControls

struct BlocksView: View {
    @EnvironmentObject var deckStore: DeckStore
    @ObservedObject private var guardManager = StudyGuardManager.shared

    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @AppStorage("focusDuration") private var focusDuration: Int = 5

    @State private var showGuardedAppsPicker = false
    @State private var showIntervalSheet = false
    @State private var showLockedEditAlert = false
    @State private var showFlashcardSettings = false
    @State private var showFocusDurationSettings = false

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                SGScreenHeader(eyebrow: "Study Guard", title: "Blocks")

                ScrollView {
                    VStack(alignment: .leading, spacing: SGTheme.sectionSpacing) {
                        statusCard

                        guardSection

                        deckSection

                        unlockMethodSection

                        emergencySection
                    }
                    .padding(.horizontal, SGTheme.screenPadding)
                    .padding(.top, 14)
                    .padding(.bottom, SGTheme.tabBarClearance)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { guardManager.refresh() }
        .sheet(isPresented: $showGuardedAppsPicker) {
            GuardedAppsPickerSheet()
        }
        .sheet(isPresented: $showIntervalSheet) {
            UsageIntervalSheet()
        }
        .sheet(isPresented: $showFlashcardSettings) {
            FlashcardSettingsSheet(flashcardCount: $flashcardCount, useAllCards: $useAllCards)
        }
        .sheet(isPresented: $showFocusDurationSettings) {
            FocusDurationSettingsSheet(focusDuration: $focusDuration)
        }
        .alert("Apps are locked", isPresented: $showLockedEditAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unlock your apps first to change your blocking setup.")
        }
    }

    // MARK: - Status

    private var statusText: (title: String, detail: String) {
        switch guardManager.state {
        case .notSetUp:
            return ("Not set up", "Turn on Study Guard from the home tab to start blocking.")
        case .metering:
            let remaining = max(0, guardManager.totalMinutes - guardManager.usedMinutes)
            return ("Guarding", "\(remaining) min of app time left before they lock.")
        case .locked:
            return ("Locked", "Your apps are locked. Study to win them back.")
        case .disabled:
            return ("Paused", "Your apps are free. Resume any time.")
        }
    }

    private var statusColor: Color {
        switch guardManager.state {
        case .metering: return SGTheme.mint
        case .locked: return SGTheme.ember
        case .notSetUp, .disabled: return SGTheme.paperTertiary
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: guardManager.state == .locked ? "lock.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusText.title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Text(statusText.detail)
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }

            Spacer()

            if guardManager.state == .metering || guardManager.state == .disabled {
                Toggle("", isOn: Binding(
                    get: { guardManager.state != .disabled },
                    set: { _ = guardManager.setGuardEnabled($0) }
                ))
                .labelsHidden()
                .tint(SGTheme.mint)
            }
        }
        .padding(SGTheme.cardPadding)
        .blocksCard()
    }

    // MARK: - Guard settings

    private var guardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SGMicroLabel(text: "Blocking")

            // Guarded apps
            Button(action: editGuardedApps) {
                VStack(alignment: .leading, spacing: 12) {
                    settingRowLabel(
                        title: "Guarded apps",
                        detail: SGContract.isSelectionEmpty(guardManager.selection)
                            ? "No apps guarded yet. Tap to choose"
                            : "\(SGContract.tokenCount(guardManager.selection)) of \(SGContract.maxSelectionTokens) guarded"
                    )

                    if !SGContract.isSelectionEmpty(guardManager.selection) {
                        selectionChips
                    }
                }
                .padding(SGTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .blocksCard()
            }
            .buttonStyle(SGPressStyle())

            // Usage interval
            Button(action: { showIntervalSheet = true }) {
                settingRowLabel(
                    title: "Usage interval",
                    detail: "\(guardManager.intervalMinutes) minutes of app use before they lock"
                )
                .padding(SGTheme.cardPadding)
                .blocksCard()
            }
            .buttonStyle(SGPressStyle())
        }
    }

    /// Title + caption + mint chevron, the standard tappable settings row.
    private func settingRowLabel(title: String, detail: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)
                Text(detail)
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(SGTheme.mint)
        }
    }

    private var selectionChips: some View {
        let maxVisibleChips = 8
        let apps = Array(guardManager.selection.applicationTokens)
        let categories = Array(guardManager.selection.categoryTokens)
        let visibleApps = Array(apps.prefix(maxVisibleChips))
        let visibleCategories = Array(categories.prefix(max(0, maxVisibleChips - visibleApps.count)))
        let overflow = SGContract.tokenCount(guardManager.selection) - visibleApps.count - visibleCategories.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(visibleApps, id: \.self) { token in
                Label(token)
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paper)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(SGTheme.glaze(0.06))
                            .overlay(Capsule().strokeBorder(SGTheme.hairline, lineWidth: 1))
                    )
            }
            ForEach(visibleCategories, id: \.self) { token in
                Label(token)
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paper)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(SGTheme.glaze(0.06))
                            .overlay(Capsule().strokeBorder(SGTheme.hairline, lineWidth: 1))
                    )
            }
            if overflow > 0 {
                Text("+\(overflow) more")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(SGTheme.glaze(0.06))
                            .overlay(Capsule().strokeBorder(SGTheme.hairline, lineWidth: 1))
                    )
            }
        }
    }

    // MARK: - Active deck

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SGMicroLabel(text: "Active deck")

            if deckStore.decks.isEmpty {
                Text("No decks yet. Create one in the Study tab.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .padding(SGTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .blocksCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(deckStore.decks) { deck in
                        deckRow(deck)
                    }
                }
                Text("Answering cards from the active deck unlocks your apps.")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperTertiary)
                    .padding(.leading, 4)
            }
        }
    }

    private func deckRow(_ deck: Deck) -> some View {
        let isActive = deckStore.selectedDeck?.id == deck.id
        return Button {
            if !isActive {
                Analytics.deckSelected(name: deck.name, cardCount: deck.cards.count)
                deckStore.selectDeck(deck)
                SGTheme.tapHaptic()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isActive ? SGTheme.mint.opacity(0.15) : SGTheme.glaze(0.06))
                        .frame(width: 30, height: 30)
                    if isActive {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(SGTheme.mintDeep)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(deck.name)
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                        .lineLimit(1)
                    Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                        .font(SGTheme.caption)
                        .foregroundColor(SGTheme.paperSecondary)
                }

                Spacer()

                if isActive {
                    SGMicroLabel(text: "Active", color: SGTheme.mintDeep)
                }
            }
            .padding(.horizontal, SGTheme.cardPadding)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(isActive ? SGTheme.mint.opacity(0.5) : SGTheme.hairline,
                                          lineWidth: isActive ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(SGTheme.springFast, value: isActive)
    }

    // MARK: - Unlock method

    private var unlockMethodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SGMicroLabel(text: "Unlock method")

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

            if unlockMethod == "flashcards" {
                Button(action: { showFlashcardSettings = true }) {
                    settingRowLabel(
                        title: "Flashcards before unlocking",
                        detail: useAllCards ? "All cards" : "\(flashcardCount) cards"
                    )
                    .padding(SGTheme.cardPadding)
                    .blocksCard()
                }
                .buttonStyle(SGPressStyle())
            } else {
                Button(action: { showFocusDurationSettings = true }) {
                    settingRowLabel(
                        title: "Focus session length",
                        detail: "\(focusDuration) minutes"
                    )
                    .padding(SGTheme.cardPadding)
                    .blocksCard()
                }
                .buttonStyle(SGPressStyle())
            }
        }
    }

    private func selectUnlockMethod(_ key: String) {
        if unlockMethod != key {
            Analytics.settingChanged(key: "unlock_method", oldValue: unlockMethod, newValue: key)
            unlockMethod = key
        }
        SGTheme.tapHaptic()
    }

    // MARK: - Emergency unlocks

    private var emergencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SGMicroLabel(text: "Emergency")

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(SGTheme.ember.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "key.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(SGTheme.ember)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(guardManager.emergencyUnlocksRemaining) emergency unlock\(guardManager.emergencyUnlocksRemaining == 1 ? "" : "s") left this week")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)
                    if guardManager.emergencyUnlocksRemaining == 0,
                       let next = guardManager.nextEmergencyUnlockDate {
                        Text("Next one available \(next.formatted(date: .abbreviated, time: .omitted))")
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)
                    } else {
                        Text("Use them from the home screen when locked.")
                            .font(SGTheme.caption)
                            .foregroundColor(SGTheme.paperSecondary)
                    }
                }
                Spacer()
            }
            .padding(SGTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .blocksCard()
        }
    }

    // MARK: - Actions

    private func editGuardedApps() {
        if guardManager.state == .locked {
            showLockedEditAlert = true
        } else {
            showGuardedAppsPicker = true
        }
    }
}

// MARK: - Styling

private extension View {
    /// Settings-row surface: inkRaised fill + hairline stroke.
    func blocksCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        BlocksView()
            .environmentObject(DeckStore.shared)
    }
}
