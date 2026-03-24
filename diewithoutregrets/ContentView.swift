//
//  ContentView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/13.
//

import SwiftUI
import RevenueCat
import RevenueCatUI
import Singular

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var navigationModel: NavigationModel
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("focusDuration") private var focusDuration: Int = 5
    
    var body: some View {
        Group {
            if navigationModel.currentDestination == .regretView {
                if unlockMethod == "trueFocus" {
                    FocusSessionView(
                        durationMinutes: focusDuration,
                        strictness: .standard,
                        onEndSession: {
                            NavigationModel.shared.navigate(to: .regretReport)
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
                    }
                    .tabItem {
                        Label("Guard", systemImage: "shield.lefthalf.filled")
                    }
                    .tag(0)
                    
                    // Second Tab - Decks
                    NavigationStack {
                        DeckListView()
                            .environmentObject(DeckStore.shared)
                    }
                    .tabItem {
                        Label("Study", systemImage: "rectangle.stack.fill")
                    }
                    .tag(1)
                    
                    // Third Tab - Profile
                    NavigationStack {
                        ProfileView()
                            .environmentObject(DeckStore.shared)
                    }
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(2)
                    
                    #if DEBUG
                    // Fourth Tab - Debug (only in debug builds)
                    NavigationStack {
                        DebugView()
                    }
                    .tabItem {
                        Label("Debug", systemImage: "ant.fill")
                    }
                    .tag(3)
                    #endif
                }
                .tint(Color(hex: 0x184449))
                .onChange(of: selectedTab) {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.prepare()
                    generator.impactOccurred()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

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
    
    private var totalAvailableCards: Int {
        deckStore.decks.reduce(0) { $0 + $1.cards.count }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Stats Overview
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        StatItem(title: "Decks", value: "\(deckStore.decks.count)", icon: "rectangle.stack.fill")
                        StatItem(title: "Cards", value: "\(totalAvailableCards)", icon: "doc.text.fill")
                        StatItem(title: "To Unlock", value: useAllCards ? "All" : "\(flashcardCount)", icon: "lock.fill")
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal)
                
                // Study Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Study Settings")
                    
                    // Unlock Method Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unlock Method")
                            .font(.headline)
                            .foregroundColor(Color(hex: 0x184449))
                        
                        Text("How you unlock blocked apps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            // Flashcards option
                            Button(action: {
                                unlockMethod = "flashcards"
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "rectangle.stack.fill")
                                        .font(.title2)
                                    Text("Flashcards")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(unlockMethod == "flashcards"
                                            ? Color(hex: 0x2BC391).opacity(0.15)
                                            : Color.gray.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(unlockMethod == "flashcards"
                                            ? Color(hex: 0x2BC391) : Color.clear, lineWidth: 2)
                                )
                                .foregroundColor(Color(hex: 0x184449))
                            }
                            
                            // True Focus option
                            Button(action: {
                                unlockMethod = "trueFocus"
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "eye.fill")
                                        .font(.title2)
                                    Text("True Focus")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(unlockMethod == "trueFocus"
                                            ? Color(hex: 0x2BC391).opacity(0.15)
                                            : Color.gray.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(unlockMethod == "trueFocus"
                                            ? Color(hex: 0x2BC391) : Color.clear, lineWidth: 2)
                                )
                                .foregroundColor(Color(hex: 0x184449))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    
                    // Flashcard count setting - only relevant when flashcards is selected
                    if unlockMethod == "flashcards" {
                        Button(action: { showingFlashcardSettings = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Flashcards before unlocking")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: 0x184449))
                                    
                                    Text(useAllCards ? "All cards" : "\(flashcardCount) cards")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Focus duration setting - only relevant when True Focus is selected
                    if unlockMethod == "trueFocus" {
                        Button(action: { showingFocusDurationSettings = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Focus session length")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: 0x184449))
                                    
                                    Text("\(focusDuration) minutes")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Break duration setting - shown for both methods
                    Button(action: { showingBreakDurationSettings = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Break duration")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: 0x184449))
                                
                                Text("\(unlockMethod == "trueFocus" ? trueFocusBreakDuration : flashcardBreakDuration) minutes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // App Experience Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "App Experience")
                    
                    VStack(spacing: 12) {
                        // Lock Animation Option
                        AnimationOptionRow(
                            type: .lockAnimation,
                            isSelected: selectedAnimationType == AnimationType.lockAnimation.rawValue,
                            onSelect: { 
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
                                selectedAnimationType = AnimationType.memeVideo.rawValue
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Account Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Account")
                    
                    Button(action: {
                        didCompletePurchase = false  // Reset flag when showing paywall
                        showingPaywall = true
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Upgrade to Pro")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x3FA4AE), Color(hex: 0x2BC391)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Help Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Help & Legal")
                    
                    VStack(spacing: 2) {
                        LinkMenuItem(icon: "questionmark.circle", title: "FAQs", url: "https://studyguard.framer.website/")
                        LinkMenuItem(icon: "exclamationmark.triangle", title: "Report an Error", url: "https://studyguard.framer.website/support")
                        LinkMenuItem(icon: "doc.text", title: "Terms of Use", url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        LinkMenuItem(icon: "hand.raised", title: "Privacy Policy", url: "https://studyguard.framer.website/legal/privacy-policy")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(hex: 0xF8F9FA))
        .navigationTitle("Profile")
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
                .presentationCornerRadius(30)
                .presentationDetents([.fraction(0.8)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingFocusDurationSettings) {
            FocusDurationSettingsSheet(focusDuration: $focusDuration)
                .presentationCornerRadius(30)
                .presentationDetents([.fraction(0.8)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingBreakDurationSettings) {
            BreakDurationSettingsSheet(
                breakDuration: unlockMethod == "trueFocus"
                    ? $trueFocusBreakDuration
                    : $flashcardBreakDuration,
                unlockMethod: unlockMethod
            )
                .presentationCornerRadius(30)
                .presentationDetents([.fraction(0.8)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingPaywall) {
            if let offering = currentOffering {
                PaywallView(offering: offering)
                    .onAppear {
                        // Mark that user viewed the paywall
                        NotificationManager.shared.markPaywallViewedWithoutPurchase()
                        print("[ContentView] 📝 Marked paywall as viewed")
                    }
                    .onPurchaseCompleted { customerInfo in
                        Singular.event("subscription_purchase", withArgs: [
                            "source": "profile_paywall"
                        ])
                        
                        if let entitlement = customerInfo.entitlements.active.values.first,
                           let package = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == entitlement.productIdentifier }) {
                            let price = Double(truncating: package.storeProduct.price as NSNumber)
                            let currency = package.storeProduct.currencyCode ?? "USD"
                            Singular.customRevenue(
                                "subscription_purchase",
                                currency: currency,
                                amount: price,
                                productSKU: package.storeProduct.productIdentifier,
                                productName: package.storeProduct.localizedTitle,
                                productCategory: "subscription",
                                productQuantity: 1,
                                productPrice: price
                            )
                        }
                        
                        hasSeenPaywall = true
                        didCompletePurchase = true
                        showingPaywall = false
                        
                        NotificationManager.shared.resetPaywallTracking()
                    }
                    .onRestoreCompleted { customerInfo in
                        Singular.event("subscription_purchase", withArgs: [
                            "source": "profile_restore"
                        ])
                        
                        hasSeenPaywall = true
                        didCompletePurchase = true
                        showingPaywall = false
                        
                        NotificationManager.shared.resetPaywallTracking()
                    }
                    .onDisappear {
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
                        // Mark that user viewed the paywall
                        NotificationManager.shared.markPaywallViewedWithoutPurchase()
                        print("[ContentView] 📝 Marked fallback paywall as viewed")
                    }
                    .onPurchaseCompleted { customerInfo in
                        Singular.event("subscription_purchase", withArgs: [
                            "source": "profile_fallback_paywall"
                        ])
                        
                        if let entitlement = customerInfo.entitlements.active.values.first {
                            Task {
                                let products = await Purchases.shared.products([entitlement.productIdentifier])
                                if let product = products.first {
                                    let price = Double(truncating: product.price as NSNumber)
                                    let currency = product.currencyCode ?? "USD"
                                    Singular.customRevenue(
                                        "subscription_purchase",
                                        currency: currency,
                                        amount: price,
                                        productSKU: product.productIdentifier,
                                        productName: product.localizedTitle,
                                        productCategory: "subscription",
                                        productQuantity: 1,
                                        productPrice: price
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
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Color(hex: 0x184449))
            .padding(.leading, 4)
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
                    .foregroundColor(Color(hex: 0x184449))
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(Color(hex: 0x184449))
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
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
                    .fill(Color(hex: 0x184449).opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: 0x184449))
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: 0x184449))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account")) {
                    NavigationLink {
                        Text("Account Settings")
                    } label: {
                        Label("Account Settings", systemImage: "person.circle")
                    }
                    
                    NavigationLink {
                        Text("Notifications")
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                }
                
                Section(header: Text("Preferences")) {
                    NavigationLink {
                        Text("Study Settings")
                    } label: {
                        Label("Study Settings", systemImage: "book")
                    }
                    
                    NavigationLink {
                        Text("Appearance")
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                }
                
                Section(header: Text("Support")) {
                    NavigationLink {
                        Text("Help Center")
                    } label: {
                        Label("Help Center", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink {
                        Text("Contact Us")
                    } label: {
                        Label("Contact Us", systemImage: "envelope")
                    }
                }
            }
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
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.self) { number in
                        Button(action: {
                            flashcardCount = number
                            useAllCards = false
                            dismiss()
                        }) {
                            HStack {
                                Text("\(number) cards")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !useAllCards && flashcardCount == number {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: 0x184449))
                                }
                            }
                        }
                    }
                    
                    Button(action: {
                        useAllCards = true
                        dismiss()
                    }) {
                        HStack {
                            Text("All cards")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if useAllCards {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(hex: 0x184449))
                            }
                        }
                    }
                } header: {
                    Text("Select the number of flashcards required to unlock")
                } footer: {
                    Text("If you select more cards than available in a deck, all cards from that deck will be used.")
                }
            }
            .navigationTitle("Flashcard Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(UIScreen.main.bounds.height * 0.6)])
        .presentationDragIndicator(.visible)
    }
}

struct FocusDurationSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var focusDuration: Int
    
    let options = [1, 3, 5, 10, 15, 20, 25, 30]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.self) { minutes in
                        Button(action: {
                            focusDuration = minutes
                            dismiss()
                        }) {
                            HStack {
                                Text("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if focusDuration == minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: 0x184449))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select how long your True Focus session should be")
                } footer: {
                    Text("After completing a focus session, you'll earn a break to use the blocked app. You can set the break length separately.")
                }
            }
            .navigationTitle("Focus Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(UIScreen.main.bounds.height * 0.6)])
        .presentationDragIndicator(.visible)
    }
}

struct BreakDurationSettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var breakDuration: Int
    let unlockMethod: String
    
    let options = [5, 10, 15, 20, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            List {
                // Explanation section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: 0x3FA4AE))
                            
                            Text("How breaks work")
                                .font(.headline)
                                .foregroundColor(Color(hex: 0x184449))
                        }
                        
                        Text("After you complete \(unlockMethod == "trueFocus" ? "a True Focus session" : "your flashcards"), your blocked app is unlocked and you can use it freely.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Once your break time is up, the app won't suddenly close or lock you out. Instead, the next time you try to open that app after the break has expired, you'll need to complete \(unlockMethod == "trueFocus" ? "another focus session" : "flashcards again") to unlock it.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: 0x2BC391))
                            
                            Text("You're always in control — no sudden interruptions.")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: 0x184449))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                // Duration options
                Section {
                    ForEach(options, id: \.self) { minutes in
                        Button(action: {
                            breakDuration = minutes
                            dismiss()
                        }) {
                            HStack {
                                Text(minutes >= 60 ? "\(minutes / 60) hour" : "\(minutes) minutes")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if breakDuration == minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: 0x184449))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select your break length")
                } footer: {
                    Text("This is how long you can freely use the app before needing to \(unlockMethod == "trueFocus" ? "focus" : "study") again.")
                }
            }
            .navigationTitle("Break Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(UIScreen.main.bounds.height * 0.75)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Debug View (only included in debug builds)

#if DEBUG
struct DebugView: View {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
    @State private var lastAction: String = ""
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        List {
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
                    lastAction = "Onboarding reset — relaunch the app"
                } label: {
                    Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Navigation") {
                Button {
                    NavigationModel.shared.navigate(to: .regretReport)
                    lastAction = "Navigated to regretReport"
                } label: {
                    Label("Go to Regret Report", systemImage: "doc.text")
                }

                Button {
                    NavigationModel.shared.currentDestination = nil
                    lastAction = "Reset navigation to home"
                } label: {
                    Label("Reset to Home", systemImage: "house")
                }
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

#Preview {
    ContentView()
        .environmentObject(RegretStore.shared)
        .environmentObject(NavigationModel.shared)
}
