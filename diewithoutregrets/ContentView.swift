//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var navigationModel: NavigationModel
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("focusDuration") private var focusDuration: Int = 5

    init() {
        #if DEBUG
        // Screenshot harness: launch with `-sg-preview-tab <index>`.
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-sg-preview-tab"), idx + 1 < args.count,
           let tab = Int(args[idx + 1]) {
            _selectedTab = State(initialValue: tab)
        }
        #endif
    }

    private var tabItems: [SGTabItem] {
        [
            SGTabItem(id: 0, title: "Guard", icon: "house.fill", asset: "home (2)"),
            SGTabItem(id: 1, title: "Study", icon: "rectangle.stack.fill"),
            SGTabItem(id: 2, title: "Blocks", icon: "lock.fill"),
            SGTabItem(id: 3, title: "Profile", icon: "person.fill"),
        ]
    }

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sg-gallery") {
                // Screenshot harness: boot straight into the design gallery.
                NavigationStack { SGGalleryView() }
            } else {
                mainContent
            }
            #else
            mainContent
            #endif
        }
    }

    /// Scene-crossing fade progress — lives HERE (not in the overlay view)
    /// so the root swap underneath can never reset it. The old corner wipe
    /// kept its choreography in its own @State and DispatchQueue timers,
    /// which the swap it orchestrated could destroy mid-flight: the cover
    /// vanished in a flash and a second wipe replayed over the new scene.
    @State private var sceneFadeCovering = false

    private var mainContent: some View {
        rootSwitch
            // The scene-crossing fade rides ABOVE the root switch: a scrim
            // in the DESTINATION's canvas color fades up, the root swaps
            // while covered, and the scrim fades off the new scene — so the
            // transition always lands color-matched, by construction.
            .overlay {
                if let style = navigationModel.activeWipe {
                    (style == .lock ? SGTheme.night : SGTheme.ink)
                        .ignoresSafeArea()
                        .opacity(sceneFadeCovering ? 1 : 0)
                        .contentShape(Rectangle()) // absorb taps mid-transition
                }
            }
            .onChange(of: navigationModel.activeWipe != nil) { _, active in
                if active { runSceneFade() }
            }
    }

    private func runSceneFade() {
        withAnimation(.easeIn(duration: 0.20)) { sceneFadeCovering = true }
        Task { @MainActor in
            // Fully covered: swap the root, hold one beat, reveal.
            try? await Task.sleep(nanoseconds: 240_000_000)
            navigationModel.wipeMidAction?()
            navigationModel.wipeMidAction = nil
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.easeOut(duration: 0.32)) { sceneFadeCovering = false }
            try? await Task.sleep(nanoseconds: 340_000_000)
            navigationModel.activeWipe = nil
            sceneFadeCovering = false
        }
    }

    private var rootSwitch: some View {
        Group {
            if navigationModel.currentDestination == .regretView {
                if (navigationModel.unlockMethodOverride ?? unlockMethod) == "trueFocus" {
                    FocusSessionView(
                        durationMinutes: focusDuration,
                        strictness: .standard,
                        onEndSession: {
                            NavigationModel.shared.returnHome()
                        }
                    )
                } else {
                    RegretView()
                        .environmentObject(DeckStore.shared)
                        .environmentObject(RegretStore.shared)
                }
            } else {
                TabView(selection: $selectedTab) {
                    // First Tab - Guard
                    NavigationStack {
                        RegretGuard()
                            .environmentObject(DeckStore.shared)
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(0)

                    // Second Tab - Decks
                    NavigationStack {
                        DeckListView()
                            .environmentObject(DeckStore.shared)
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(1)

                    // Third Tab - Blocks
                    NavigationStack {
                        BlocksView()
                            .environmentObject(DeckStore.shared)
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(2)

                    // Fourth Tab - Profile
                    NavigationStack {
                        ProfileView()
                            .environmentObject(DeckStore.shared)
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(3)
                }
                .tint(SGTheme.mint)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // Hidden while the Guard home's lock stamp plays so the
                    // overlay owns the whole screen. Night styling while the
                    // locked home is on screen (Guard tab only).
                    SGTabBar(selection: $selectedTab, items: tabItems,
                             onDark: navigationModel.isLockedHomeShowing && selectedTab == 0)
                        .opacity(navigationModel.isLockStampPlaying ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: navigationModel.isLockStampPlaying)
                }
                .background(SGTheme.ink.ignoresSafeArea())
                .onChange(of: selectedTab) { _, newTab in
                    SGTheme.tick()

                    let tabName: String
                    switch newTab {
                    case 0: tabName = "guard"
                    case 1: tabName = "study"
                    case 2: tabName = "blocks"
                    case 3: tabName = "profile"
                    default: tabName = "unknown"
                    }
                    Analytics.tabSelected(tabName)
                    Telemetry.breadcrumb("Tab selected", category: "ui.navigation",
                                         data: ["tab": tabName])
                }
            }
        }
    }
}

#if DEBUG
struct DebugView: View {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
    @State private var lastAction: String = ""
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Home-screen ripple tuner — read live by RegretGuard's MeadowDotRipple.
    @AppStorage("sgRippleSagitta") private var rippleSagitta: Double = 32
    @AppStorage("sgRippleApexInset") private var rippleApexInset: Double = 94
    @AppStorage("sgRippleShiftY") private var rippleShiftY: Double = 0
    @AppStorage("sgHomeBackdrop") private var homeBackdrop: String = "dots"

    var body: some View {
        List {
            Section("Design System") {
                NavigationLink {
                    SGGalleryView()
                } label: {
                    Label("Component Gallery", systemImage: "paintpalette")
                }
            }

            StudyGuardDebugSection()

            Section {
                Picker("Backdrop", selection: $homeBackdrop) {
                    Text("Dots").tag("dots")
                    Text("Clouds").tag("clouds")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Home backdrop")
            } footer: {
                Text("Switches the animated background on the Guard tab between the dot ripple and Clouds.lottie.")
                    .font(.caption2)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Curve (sagitta)")
                        Spacer()
                        Text("\(Int(rippleSagitta))")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $rippleSagitta, in: 1...160, step: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Line offset")
                        Spacer()
                        Text("\(Int(rippleApexInset))")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $rippleApexInset, in: -600...300, step: 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Shift down")
                        Spacer()
                        Text("\(Int(rippleShiftY))")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $rippleShiftY, in: 0...700, step: 5)
                }

                Button {
                    rippleSagitta = 32
                    rippleApexInset = 94
                    rippleShiftY = 0
                    lastAction = "Ripple tuner reset to defaults"
                } label: {
                    Label("Reset to defaults", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Meadow dot ripple")
            } footer: {
                Text("Curve: how rounded the ripple's base arc is (32 matches the hill; smaller = flatter). Line offset: how far below the meadow's top edge the arc sits. Negative raises it into the white area. Shift down: moves the WHOLE dot field down, opening a gap at the top of the screen. Changes apply live on the Guard tab.")
                    .font(.caption2)
            }

            Section("Break / Unlock State") {
                // Current values
                VStack(alignment: .leading, spacing: 6) {
                    debugRow("UserAllowedBreak", value: "\(sharedDefaults?.bool(forKey: "UserAllowedBreak") ?? false)")
                    debugRow("LastBreakTime", value: formattedBreakTime)
                    debugRow("BreakDurationMinutes", value: "\(sharedDefaults?.integer(forKey: "BreakDurationMinutes") ?? 0)")
                    debugRow("LastGuardedApp", value: sharedDefaults?.string(forKey: "LastGuardedApp") ?? "none")
                    debugRow("unlockMethod", value: unlockMethod)
                }
                .padding(.vertical, 4)

                // Reset break button
                Button(role: .destructive) {
                    sharedDefaults?.set(false, forKey: "UserAllowedBreak")
                    sharedDefaults?.removeObject(forKey: "LastBreakTime")
                    sharedDefaults?.removeObject(forKey: "BreakDurationMinutes")
                    sharedDefaults?.synchronize()
                    lastAction = "Break state reset at \(Date().formatted(date: .omitted, time: .standard))"
                } label: {
                    Label("Reset Break State", systemImage: "arrow.counterclockwise")
                }

                // Set a fake guarded app for testing
                Button {
                    sharedDefaults?.set("Instagram", forKey: "LastGuardedApp")
                    sharedDefaults?.synchronize()
                    lastAction = "Set LastGuardedApp = Instagram"
                } label: {
                    Label("Set Guarded App to Instagram", systemImage: "app.badge")
                }
            }

            Section("Trigger Flows") {
                // Simulate the shortcut triggering the app
                Button {
                    sharedDefaults?.set("Instagram", forKey: "LastGuardedApp")
                    sharedDefaults?.set(false, forKey: "UserAllowedBreak")
                    sharedDefaults?.synchronize()
                    NavigationModel.shared.navigate(to: .regretView)
                    lastAction = "Triggered unlock flow (regretView)"
                } label: {
                    Label("Simulate Shortcut Trigger", systemImage: "play.fill")
                        .foregroundColor(Color(hex: 0x2BC391))
                }

                // Quick switch unlock method
                Button {
                    unlockMethod = unlockMethod == "flashcards" ? "trueFocus" : "flashcards"
                    lastAction = "Switched to \(unlockMethod)"
                } label: {
                    Label("Toggle Unlock Method (\(unlockMethod))", systemImage: "arrow.left.arrow.right")
                }
            }

            Section("Onboarding") {
                Button(role: .destructive) {
                    hasCompletedOnboarding = false
                    lastAction = "Onboarding reset, relaunch the app"
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Navigation") {
                Button {
                    NavigationModel.shared.currentDestination = nil
                    lastAction = "Reset navigation to home"
                } label: {
                    Label("Reset to Home", systemImage: "house")
                }
            }

            Section {
                // Handled paths — these run regardless of whether the
                // debugger is attached. They flow through beforeSend, so in
                // a real DEBUG run from Xcode they're DROPPED. To verify
                // them on Sentry's dashboard you need a TestFlight build
                // (env=testflight) or Run-without-debugger on a Release
                // build (env=production).
                Button {
                    let err = NSError(domain: "TestError",
                                      code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Telemetry.capture smoke test"])
                    Telemetry.capture(err,
                                      context: ["triggered_from": "DebugView"],
                                      tags: ["test": "true"])
                    lastAction = "Captured handled error (dropped in DEBUG by beforeSend, verify on TestFlight)"
                } label: {
                    Label("Capture handled error", systemImage: "exclamationmark.triangle")
                }

                Button {
                    Telemetry.captureMessage("Test message from Study Guard",
                                             level: .info,
                                             tags: ["test": "true"])
                    lastAction = "Captured message (dropped in DEBUG)"
                } label: {
                    Label("Capture message", systemImage: "text.bubble")
                }

                // Crash paths — these BYPASS beforeSend (they're written to
                // the on-disk crash file by the signal handler before
                // Sentry has a chance to filter), so they will reach Sentry
                // even from a Release build run from Xcode without the
                // debugger attached. With debugger attached, Xcode catches
                // the signal first and Sentry never sees it.
                Button(role: .destructive) {
                    fatalError("Sentry test crash: Swift fatalError from DebugView")
                } label: {
                    Label("Crash (Swift fatalError)", systemImage: "bolt.fill")
                }

                Button(role: .destructive) {
                    NSException(name: .genericException,
                                reason: "Sentry test crash: NSException from DebugView",
                                userInfo: nil).raise()
                } label: {
                    Label("Crash (NSException)", systemImage: "bolt.trianglebadge.exclamationmark.fill")
                }

                Button(role: .destructive) {
                    // Force a SIGSEGV by dereferencing a null pointer.
                    // UnsafePointer<Int>(bitPattern: 0)!.pointee triggers a
                    // signal-level crash that exercises the Mach exception
                    // path, not the Swift runtime path.
                    let nullPtr = UnsafePointer<Int>(bitPattern: 0)!
                    _ = nullPtr.pointee
                } label: {
                    Label("Crash (SIGSEGV null deref)", systemImage: "memorychip.fill")
                }
            } header: {
                Text("Sentry: test crash menu")
            } footer: {
                Text("⚠️ Crashes only reach Sentry when running WITHOUT the debugger attached. Either uncheck Scheme → Run → Info → \"Debug Executable\", or test on a TestFlight build.")
                    .font(.caption2)
            }

            if !lastAction.isEmpty {
                Section("Last Action") {
                    Text(lastAction)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Debug")
    }

    private var formattedBreakTime: String {
        guard let timestamp = sharedDefaults?.double(forKey: "LastBreakTime"), timestamp > 0 else {
            return "none"
        }
        let date = Date(timeIntervalSince1970: timestamp)
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func debugRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundColor(Color(hex: 0x184449))  
        }
    }
}
#endif

#Preview("Empty / not set up") {
    ContentView()
        .environmentObject(RegretStore.shared)
        .environmentObject(NavigationModel.shared)
}

#if DEBUG
#Preview("Metering") {
    SGPreviewHarness.seed(.metering)
    return ContentView()
        .environmentObject(RegretStore.shared)
        .environmentObject(NavigationModel.shared)
}

#Preview("Locked") {
    SGPreviewHarness.seed(.locked)
    return ContentView()
        .environmentObject(RegretStore.shared)
        .environmentObject(NavigationModel.shared)
}
#endif
