//
//  BlocksView.swift
//  diewithoutregrets
//
//  The Blocks tab — one place to see and manage everything about blocking.
//  Redesigned to carry the home screen's language onto the white canvas:
//  a green meadow-gradient hero card owns the guard status (state, time
//  left, on/off), and everything else lives in two grouped cards —
//  Blocking (guarded apps + interval) and Unlock (method, amount, active
//  deck) — with a quiet emergency footer. Stickers lead every row.
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
    @State private var showDeckPicker = false

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                SGScreenHeader(eyebrow: "Study Guard", title: "Blocks")

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard

                        groupedSection(label: "Blocking") {
                            guardedAppsRow
                            rowDivider
                            settingsRow(icon: "sticker-stopwatch",
                                        title: "Usage interval",
                                        value: "\(guardManager.intervalMinutes) min") {
                                showIntervalSheet = true
                            }
                        }

                        groupedSection(label: "Unlock") {
                            methodTiles
                                .padding(14)
                            rowDivider
                            if unlockMethod == "flashcards" {
                                settingsRow(icon: "sticker-checkmark",
                                            title: "Cards to unlock",
                                            value: useAllCards ? "All" : "\(flashcardCount)") {
                                    showFlashcardSettings = true
                                }
                            } else {
                                settingsRow(icon: "sticker-timer",
                                            title: "Focus length",
                                            value: "\(focusDuration) min") {
                                    showFocusDurationSettings = true
                                }
                            }
                            rowDivider
                            settingsRow(icon: "sticker-folder",
                                        title: "Active deck",
                                        value: activeDeckLabel) {
                                showDeckPicker = true
                            }
                        }

                        emergencyFooter
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
        .sheet(isPresented: $showDeckPicker) {
            DeckPickerSheet()
                .environmentObject(deckStore)
        }
        .alert("Apps are locked", isPresented: $showLockedEditAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Unlock your apps first to change your blocking setup.")
        }
    }

    // MARK: - Hero

    private var heroTitle: String {
        switch guardManager.state {
        case .notSetUp: return "Not set up"
        case .metering: return "\(max(0, guardManager.totalMinutes - guardManager.usedMinutes))m left"
        case .locked: return "Locked"
        case .disabled: return "Paused"
        }
    }

    private var heroEyebrow: String {
        switch guardManager.state {
        case .notSetUp: return "Study Guard is off"
        case .metering: return "Guarding"
        case .locked: return "Time's up"
        case .disabled: return "Guard paused"
        }
    }

    private var heroCaption: String {
        switch guardManager.state {
        case .notSetUp: return "Turn on Study Guard from the home tab to start blocking."
        case .metering: return "of app time before your apps lock."
        case .locked: return "Your apps are locked. Study to win them back."
        case .disabled: return "Your apps are free. Resume any time."
        }
    }

    private var heroGradient: LinearGradient {
        switch guardManager.state {
        case .metering:
            // The tab bar's meadow greens — the hero reads as a slab of
            // the home hill carried onto the white canvas.
            return LinearGradient(colors: [Color(hex: 0x3A9144), Color(hex: 0x2F7E37)],
                                  startPoint: .top, endPoint: .bottom)
        case .locked:
            return LinearGradient(colors: [SGTheme.ember, SGTheme.emberDeep],
                                  startPoint: .top, endPoint: .bottom)
        case .notSetUp, .disabled:
            return LinearGradient(colors: [Color(hex: 0x8A9490), Color(hex: 0x76817C)],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    private var heroSticker: String {
        switch guardManager.state {
        case .locked: return "sticker-lock"
        case .disabled, .notSetUp: return "sticker-moon"
        case .metering: return "sticker-shield"
        }
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(heroEyebrow.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .kerning(1.2)
                    .foregroundColor(.white.opacity(0.75))

                Text(heroTitle)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(countsDown: true))

                Text(heroCaption)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(spacing: 10) {
                Image(heroSticker)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)

                if guardManager.state == .metering || guardManager.state == .disabled {
                    Toggle("", isOn: Binding(
                        get: { guardManager.state != .disabled },
                        set: { _ = guardManager.setGuardEnabled($0) }
                    ))
                    .labelsHidden()
                    .tint(.white.opacity(0.35))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                )
        )
        .animation(SGTheme.spring, value: guardManager.state)
    }

    // MARK: - Grouped cards

    @ViewBuilder
    private func groupedSection<Content: View>(label: String,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SGMicroLabel(text: label)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(SGTheme.hairline, lineWidth: 1)
                    )
            )
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(SGTheme.hairline)
            .padding(.leading, 56)
    }

    /// One settings row: sticker, title, value, chevron.
    private func settingsRow(icon: String, title: String, value: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Spacer()

                Text(value)
                    .font(SGTheme.caption.weight(.semibold))
                    .foregroundColor(SGTheme.paperSecondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SGTheme.paperTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
    }

    // MARK: - Guarded apps

    private var guardedCount: Int { SGContract.tokenCount(guardManager.selection) }

    private var guardedAppsRow: some View {
        Button(action: editGuardedApps) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image("sticker-iphone")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)

                    Text("Guarded apps")
                        .font(SGTheme.cardTitle)
                        .foregroundColor(SGTheme.paper)

                    Spacer()

                    Text(guardedCount == 0 ? "Choose" : "\(guardedCount)")
                        .font(SGTheme.caption.weight(.semibold))
                        .foregroundColor(SGTheme.paperSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SGTheme.paperTertiary)
                }

                if guardedCount > 0 {
                    selectionChips
                        .padding(.leading, 42)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
    }

    /// Real token chips (FamilyControls renders each app's own icon+name),
    /// capped to one tidy cloud.
    private var selectionChips: some View {
        let maxVisibleChips = 4
        let apps = Array(guardManager.selection.applicationTokens)
        let categories = Array(guardManager.selection.categoryTokens)
        let visibleApps = Array(apps.prefix(maxVisibleChips))
        let visibleCategories = Array(categories.prefix(max(0, maxVisibleChips - visibleApps.count)))
        let overflow = guardedCount - visibleApps.count - visibleCategories.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8, alignment: .leading)],
                         alignment: .leading, spacing: 8) {
            ForEach(visibleApps, id: \.self) { token in
                chip { Label(token) }
            }
            ForEach(visibleCategories, id: \.self) { token in
                chip { Label(token) }
            }
            if overflow > 0 {
                chip { Text("+\(overflow) more") }
            }
        }
    }

    private func chip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
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

    // MARK: - Unlock method

    private var methodTiles: some View {
        HStack(spacing: 10) {
            SGOptionTile(
                title: "Flashcards",
                icon: "sticker-books",
                selected: unlockMethod == "flashcards"
            ) {
                selectUnlockMethod("flashcards")
            }
            SGOptionTile(
                title: "True Focus",
                icon: "sticker-eye",
                selected: unlockMethod == "trueFocus"
            ) {
                selectUnlockMethod("trueFocus")
            }
        }
    }

    private var activeDeckLabel: String {
        guard let deck = deckStore.selectedDeck ?? deckStore.decks.first else { return "None yet" }
        return deck.name
    }

    private func selectUnlockMethod(_ key: String) {
        if unlockMethod != key {
            Analytics.settingChanged(key: "unlock_method", oldValue: unlockMethod, newValue: key)
            unlockMethod = key
        }
        SGTheme.tapHaptic()
    }

    // MARK: - Emergency

    private var emergencyFooter: some View {
        HStack(spacing: 10) {
            Image("sticker-key")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)

            Text(emergencyText)
                .font(SGTheme.caption)
                .foregroundColor(SGTheme.paperSecondary)
        }
        .padding(.horizontal, 4)
    }

    private var emergencyText: String {
        let remaining = guardManager.emergencyUnlocksRemaining
        if remaining == 0, let next = guardManager.nextEmergencyUnlockDate {
            return "No emergency unlocks left. Next one \(next.formatted(date: .abbreviated, time: .omitted))."
        }
        return "\(remaining) emergency unlock\(remaining == 1 ? "" : "s") left this week."
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

#Preview {
    NavigationStack {
        BlocksView()
            .environmentObject(DeckStore.shared)
    }
}
