//
//  ProfileView.swift
//  diewithoutregrets
//
//  Profile tab + its settings sheets. Split out of ContentView.swift
//  during the Teal Ink redesign so diffs stay reviewable.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct ProfileView: View {
    @EnvironmentObject var deckStore: DeckStore
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var showingSettings = false
    @State private var showingFlashcardSettings = false
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @State private var showingPaywall = false
    @State private var currentOffering: Offering?
    @AppStorage("hasSeenPaywall") private var hasSeenPaywall = false
    @AppStorage("selectedAnimationType") private var selectedAnimationType: String = AnimationType.lockAnimation.rawValue
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("focusDuration") private var focusDuration: Int = 5
    @AppStorage("flashcardBreakDuration") private var flashcardBreakDuration: Int = 5
    @AppStorage("trueFocusBreakDuration") private var trueFocusBreakDuration: Int = 30
    @State private var didCompletePurchase = false
    @State private var showingFocusDurationSettings = false
    @State private var showingBreakDurationSettings = false
    @ObservedObject private var studyGuard = StudyGuardManager.shared
    @State private var showingUsageIntervalSettings = false
    @State private var showingGuardedAppsPicker = false
    @State private var showingLockedEditAlert = false

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
                    .font(.system(size: 14, weight: .semibold))
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
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        StatItem(title: "Decks", value: "\(deckStore.decks.count)", icon: "rectangle.stack.fill")
                        StatItem(title: "Cards", value: "\(totalAvailableCards)", icon: "doc.text.fill")
                        StatItem(title: "To Unlock", value: useAllCards ? "All" : "\(flashcardCount)", icon: "lock.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(SGTheme.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                        .fill(SGTheme.inkRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: SGTheme.cardRadius, style: .continuous)
                                .strokeBorder(SGTheme.hairline, lineWidth: 1)
                        )
                )
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
                        Button(action: { showingFlashcardSettings = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Flashcards before unlocking")
                                        .font(SGTheme.cardTitle)
                                        .foregroundColor(SGTheme.paper)
                                    
                                    Text(useAllCards ? "All cards" : "\(flashcardCount) cards")
                                        .font(SGTheme.caption)
                                        .foregroundColor(SGTheme.paperSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SGTheme.mint)
                            }
                            .padding(SGTheme.cardPadding)
                            .sgRowCard()
                        }
                        .buttonStyle(SGPressStyle())
                    }
                    
                    // Focus duration setting - only relevant when True Focus is selected
                    if unlockMethod == "trueFocus" {
                        Button(action: { showingFocusDurationSettings = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Focus session length")
                                        .font(SGTheme.cardTitle)
                                        .foregroundColor(SGTheme.paper)
                                    
                                    Text("\(focusDuration) minutes")
                                        .font(SGTheme.caption)
                                        .foregroundColor(SGTheme.paperSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SGTheme.mint)
                            }
                            .padding(SGTheme.cardPadding)
                            .sgRowCard()
                        }
                        .buttonStyle(SGPressStyle())
                    }
                    
                    if studyGuard.isSetupComplete {
                        // v2: usage interval — how long the apps are usable
                        // before they lock (replaces the legacy break duration).
                        Button(action: { showingUsageIntervalSettings = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Usage interval")
                                        .font(SGTheme.cardTitle)
                                        .foregroundColor(SGTheme.paper)

                                    Text("\(studyGuard.intervalMinutes) minutes of app use before they lock")
                                        .font(SGTheme.caption)
                                        .foregroundColor(SGTheme.paperSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SGTheme.mint)
                            }
                            .padding(SGTheme.cardPadding)
                            .sgRowCard()
                        }
                        .buttonStyle(SGPressStyle())

                        // v2: guarded apps
                        Button(action: {
                            if studyGuard.state == .locked {
                                showingLockedEditAlert = true
                            } else {
                                showingGuardedAppsPicker = true
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Guarded apps")
                                        .font(SGTheme.cardTitle)
                                        .foregroundColor(SGTheme.paper)

                                    Text(SGContract.isSelectionEmpty(studyGuard.selection)
                                         ? "No apps guarded yet. Tap to choose"
                                         : "\(SGContract.tokenCount(studyGuard.selection)) of \(SGContract.maxSelectionTokens) guarded")
                                        .font(SGTheme.caption)
                                        .foregroundColor(SGTheme.paperSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SGTheme.mint)
                            }
                            .padding(SGTheme.cardPadding)
                            .sgRowCard()
                        }
                        .buttonStyle(SGPressStyle())
                    } else {
                        // Legacy Shortcuts users keep their break-duration
                        // setting until they migrate to Screen Time.
                        Button(action: { showingBreakDurationSettings = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Break duration")
                                        .font(SGTheme.cardTitle)
                                        .foregroundColor(SGTheme.paper)

                                    Text("\(unlockMethod == "trueFocus" ? trueFocusBreakDuration : flashcardBreakDuration) minutes")
                                        .font(SGTheme.caption)
                                        .foregroundColor(SGTheme.paperSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(SGTheme.mint)
                            }
                            .padding(SGTheme.cardPadding)
                            .sgRowCard()
                        }
                        .buttonStyle(SGPressStyle())
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                
                // App Experience Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "App Experience")
                    
                    VStack(spacing: 10) {
                        // Lock Animation Option
                        AnimationOptionRow(
                            type: .lockAnimation,
                            isSelected: selectedAnimationType == AnimationType.lockAnimation.rawValue,
                            onSelect: { 
                                if selectedAnimationType != AnimationType.lockAnimation.rawValue {
                                    Analytics.settingChanged(
                                        key: "animation_type",
                                        oldValue: selectedAnimationType,
                                        newValue: AnimationType.lockAnimation.rawValue
                                    )
                                }
                                selectedAnimationType = AnimationType.lockAnimation.rawValue
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        )
                        
                        // Meme Video Option  
                        AnimationOptionRow(
                            type: .memeVideo,
                            isSelected: selectedAnimationType == AnimationType.memeVideo.rawValue,
                            onSelect: { 
                                if selectedAnimationType != AnimationType.memeVideo.rawValue {
                                    Analytics.settingChanged(
                                        key: "animation_type",
                                        oldValue: selectedAnimationType,
                                        newValue: AnimationType.memeVideo.rawValue
                                    )
                                }
                                selectedAnimationType = AnimationType.memeVideo.rawValue
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        )
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                
                // Account Section
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Account")
                    
                    SGPrimaryButton(title: "Upgrade to Pro", icon: "crown.fill") {
                        didCompletePurchase = false  // Reset flag when showing paywall
                        Analytics.upgradeButtonTapped(surface: "profile")
                        showingPaywall = true
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
                // Developer Section (debug builds only)
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Developer")

                    NavigationLink {
                        DebugView()
                    } label: {
                        HStack {
                            Image(systemName: "ant.fill")
                                .font(.system(size: 18))
                                .foregroundColor(SGTheme.mint)
                                .frame(width: 24)

                            Text("Debug")
                                .font(SGTheme.cardTitle)
                                .foregroundColor(SGTheme.paper)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SGTheme.mint)
                        }
                        .padding(SGTheme.cardPadding)
                        .sgRowCard()
                    }
                    .buttonStyle(SGPressStyle())
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
        .onAppear {
            // Fetch the offering when view appears
            Purchases.shared.getOfferings { offerings, error in
                DispatchQueue.main.async {
                    // Use the default/current offering (can be changed in RevenueCat dashboard)
                    self.currentOffering = offerings?.current
                    
                    if let current = offerings?.current {
                        print("✅ Using default offering: \(current.identifier)")
                    } else {
                        print("⚠️ No current offering set - check RevenueCat dashboard")
                    }
                }
            }
            
            // Show paywall for existing users who haven't seen it
            if !hasSeenPaywall {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingPaywall = true
                }
            }
        }
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
        .sheet(isPresented: $showingPaywall) {
            if let offering = currentOffering {
                PaywallView(offering: offering)
                    .onAppear {
                        Analytics.paywallViewed(surface: "profile", properties: [
                            "offering_id": offering.identifier,
                            "has_offering": true
                        ])
                        // Mark that user viewed the paywall
                        NotificationManager.shared.markPaywallViewedWithoutPurchase()
                        print("[ContentView] 📝 Marked paywall as viewed")
                    }
                    .onPurchaseCompleted { customerInfo in
                        var price: Double?
                        var currency: String?
                        var productId: String = "unknown"
                        var isTrial: Bool = false

                        if let entitlement = customerInfo.entitlements.active.values.first,
                           let package = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == entitlement.productIdentifier }) {
                            price = Double(truncating: package.storeProduct.price as NSNumber)
                            currency = package.storeProduct.currencyCode ?? "USD"
                            productId = package.storeProduct.productIdentifier
                            isTrial = entitlement.periodType == .trial

                            if isTrial {
                                AdsTracker.trackStartTrial(
                                    productId: package.storeProduct.productIdentifier,
                                    productName: package.storeProduct.localizedTitle,
                                    price: price ?? 0,
                                    currency: currency ?? "USD"
                                )
                            } else {
                                AdsTracker.trackSubscribe(
                                    productId: package.storeProduct.productIdentifier,
                                    productName: package.storeProduct.localizedTitle,
                                    price: price ?? 0,
                                    currency: currency ?? "USD"
                                )
                                AdsTracker.trackPurchase(
                                    productId: package.storeProduct.productIdentifier,
                                    productName: package.storeProduct.localizedTitle,
                                    price: price ?? 0,
                                    currency: currency ?? "USD"
                                )
                            }
                        }

                        Analytics.subscriptionStarted(
                            surface: "profile",
                            productId: productId,
                            price: price,
                            currency: currency,
                            isTrial: isTrial,
                            offeringId: offering.identifier,
                            entitlements: customerInfo.entitlements.active.keys.map { $0 }
                        )

                        hasSeenPaywall = true
                        didCompletePurchase = true
                        showingPaywall = false
                        
                        NotificationManager.shared.resetPaywallTracking()
                    }
                    .onRestoreCompleted { customerInfo in
                        let hasActive = !customerInfo.entitlements.active.isEmpty
                        Analytics.restorePurchasesSucceeded(
                            surface: "profile",
                            hasActiveEntitlements: hasActive
                        )
                        hasSeenPaywall = true
                        didCompletePurchase = true
                        showingPaywall = false
                        
                        NotificationManager.shared.resetPaywallTracking()
                    }
                    .onDisappear {
                        Analytics.paywallDismissed(
                            surface: "profile",
                            didPurchase: didCompletePurchase
                        )
                        // Mark as seen even if user dismisses without purchasing
                        hasSeenPaywall = true
                        
                        print("[ContentView] 🔍 Paywall disappeared - didCompletePurchase: \(didCompletePurchase)")
                        // Note: Paywall was already marked as viewed in onAppear
                        // We don't need to do anything here since the flag is already set
                    }
            } else {
                // Fallback paywall without specific offering
                PaywallView()
                    .onAppear {
                        Analytics.paywallViewed(surface: "profile", properties: [
                            "has_offering": false
                        ])
                        // Mark that user viewed the paywall
                        NotificationManager.shared.markPaywallViewedWithoutPurchase()
                        print("[ContentView] 📝 Marked fallback paywall as viewed")
                    }
                    .onPurchaseCompleted { customerInfo in
                        if let entitlement = customerInfo.entitlements.active.values.first {
                            Task {
                                let products = await Purchases.shared.products([entitlement.productIdentifier])
                                if let product = products.first {
                                    let price = Double(truncating: product.price as NSNumber)
                                    let currency = product.currencyCode ?? "USD"
                                    let isTrial = entitlement.periodType == .trial
                                    if isTrial {
                                        AdsTracker.trackStartTrial(
                                            productId: product.productIdentifier,
                                            productName: product.localizedTitle,
                                            price: price,
                                            currency: currency
                                        )
                                    } else {
                                        AdsTracker.trackSubscribe(
                                            productId: product.productIdentifier,
                                            productName: product.localizedTitle,
                                            price: price,
                                            currency: currency
                                        )
                                        AdsTracker.trackPurchase(
                                            productId: product.productIdentifier,
                                            productName: product.localizedTitle,
                                            price: price,
                                            currency: currency
                                        )
                                    }
                                    Analytics.subscriptionStarted(
                                        surface: "profile",
                                        productId: product.productIdentifier,
                                        price: price,
                                        currency: currency,
                                        isTrial: isTrial,
                                        offeringId: nil,
                                        entitlements: customerInfo.entitlements.active.keys.map { $0 }
                                    )
                                }
                            }
                        }

                        hasSeenPaywall = true
                        didCompletePurchase = true
                        showingPaywall = false
                        
                        NotificationManager.shared.resetPaywallTracking()
                    }
                    .onDisappear {
                        Analytics.paywallDismissed(
                            surface: "profile",
                            didPurchase: didCompletePurchase
                        )
                        hasSeenPaywall = true
                        
                        print("[ContentView] 🔍 Fallback paywall disappeared - didCompletePurchase: \(didCompletePurchase)")
                    }
            }
        }
        .onChange(of: navigationModel.shouldDismissPaywall) { oldValue, newValue in
            if newValue {
                print("[ContentView] 🚪 Received dismiss signal, closing paywall")
                showingPaywall = false
            }
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

struct LinkMenuItem: View {
    let icon: String
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(SGTheme.mint)
                    .frame(width: 24)

                Text(title)
                    .font(SGTheme.cardTitle)
                    .foregroundColor(SGTheme.paper)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SGTheme.mint)
            }
            .padding(SGTheme.cardPadding)
            .sgRowCard()
        }
        .buttonStyle(SGPressStyle())
        .simultaneousGesture(TapGesture().onEnded {
            Analytics.helpLinkClicked(link: title, url: url)
        })
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
                    .font(.system(size: 20))
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

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account").foregroundColor(SGTheme.paperSecondary)) {
                    NavigationLink {
                        Text("Account Settings")
                    } label: {
                        Label("Account Settings", systemImage: "person.circle")
                            .foregroundColor(SGTheme.paper)
                    }
                    .listRowBackground(SGTheme.inkRaised)

                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                            .foregroundColor(SGTheme.paper)
                    }
                    .listRowBackground(SGTheme.inkRaised)
                }

                Section(header: Text("Preferences").foregroundColor(SGTheme.paperSecondary)) {
                    NavigationLink {
                        Text("Study Settings")
                    } label: {
                        Label("Study Settings", systemImage: "book")
                            .foregroundColor(SGTheme.paper)
                    }
                    .listRowBackground(SGTheme.inkRaised)

                    NavigationLink {
                        Text("Appearance")
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                            .foregroundColor(SGTheme.paper)
                    }
                    .listRowBackground(SGTheme.inkRaised)
                }

                Section(header: Text("Support").foregroundColor(SGTheme.paperSecondary)) {
                    NavigationLink {
                        Text("Help Center")
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle")
                            .foregroundColor(SGTheme.paper)
                    }
                    .listRowBackground(SGTheme.inkRaised)

                    NavigationLink {
                        Text("Contact Us")
                    } label: {
                        Label("Contact Us", systemImage: "envelope")
                            .foregroundColor(SGTheme.paper)
                    }
                    .listRowBackground(SGTheme.inkRaised)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SGTheme.ink)
            .tint(SGTheme.mint)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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

// MARK: - Teal Ink helpers

private extension View {
    /// Settings-row surface: inkRaised fill + hairline stroke, no drop shadow.
    func sgRowCard(radius: CGFloat = SGTheme.cardRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(SGTheme.inkRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(SGTheme.hairline, lineWidth: 1)
                )
        )
    }
}

// MARK: - Debug View (only included in debug builds)
