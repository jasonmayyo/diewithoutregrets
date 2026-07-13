//
//  StudyGuardReadyView.swift
//  diewithoutregrets
//
//  Onboarding v2 hard paywall (step 20, daylight). Personalized backdrop
//  (mascot + "win back your N years" + feature rows) that auto-presents the
//  RevenueCatUI paywall once offerings load. Purchase/restore are the ONLY
//  paths that advance. Declines run the ladder: dismiss #1 shows a reason
//  survey then the buyback offer; dismiss #2+ goes straight to buyback via
//  NavigationModel.presentBuyBackOffer().
//

import SwiftUI
import RevenueCat
import RevenueCatUI
import PostHog

struct HardPaywallView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @ObservedObject private var navigationModel = NavigationModel.shared

    // Entrance
    @State private var shown = false
    @State private var appeared = false

    // Offerings
    @State private var currentOffering: Offering?
    @State private var isLoadingOffering = true
    @State private var loadFailed = false
    @State private var didAutoRetry = false
    @State private var hasAutoPresented = false

    // RevenueCat cover
    @State private var showingRevenueCatPaywall = false
    @State private var didCompletePurchase = false
    /// Set when NavigationModel closes the cover (buyback deep link etc.) so
    /// the dismissal doesn't count as a user decline.
    @State private var externallyDismissed = false

    // Decline ladder
    @State private var declineCount = 0
    @State private var showDeclineSurvey = false
    /// Idempotency latch: at most one buyback presentation per cover
    /// dismissal round. Reset at the start of each new dismissal.
    @State private var didTriggerBuyBackThisRound = false

    // Restore
    @State private var isRestoringPurchases = false
    @State private var restoreErrorMessage: String?
    @State private var restoreSuccessMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer()

            hero
                .padding(.horizontal, SGTheme.screenPadding)

            Spacer()

            footer
                .padding(.bottom, 20)
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .fullScreenCover(isPresented: $showingRevenueCatPaywall, onDismiss: handleCoverDismissed) {
            paywallCover
        }
        .sheet(isPresented: $showDeclineSurvey, onDismiss: presentBuyBack) {
            DeclineSurveySheet { reason in
                viewModel.screenAction("decline_survey_reason", properties: ["reason": reason])
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Restore Error", isPresented: .constant(restoreErrorMessage != nil)) {
            Button("OK") { restoreErrorMessage = nil }
        } message: {
            Text(restoreErrorMessage ?? "Unknown error")
        }
        .alert("Restore Successful", isPresented: .constant(restoreSuccessMessage != nil)) {
            Button("OK") { restoreSuccessMessage = nil }
        } message: {
            Text(restoreSuccessMessage ?? "Purchases restored successfully")
        }
        .onChange(of: navigationModel.shouldDismissPaywall) { _, newValue in
            if newValue && showingRevenueCatPaywall {
                print("[HardPaywallView] Received dismiss signal, closing paywall")
                externallyDismissed = true
                showingRevenueCatPaywall = false
            }
        }
        .onChange(of: navigationModel.buyBackPurchasedDuringOnboarding) { _, newValue in
            guard newValue else { return }
            print("[HardPaywallView] Buyback purchased during onboarding, advancing")
            didCompletePurchase = true
            navigationModel.buyBackPurchasedDuringOnboarding = false
            if showingRevenueCatPaywall {
                externallyDismissed = true
                showingRevenueCatPaywall = false
            }
            if showDeclineSurvey {
                showDeclineSurvey = false
            }
            viewModel.nextStep()
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            shown = true

            Analytics.paywallViewed(surface: "onboarding_v2", properties: [
                "student_type": viewModel.studentType,
                "screen_time": viewModel.screenTime,
                "reclaim_years": viewModel.reclaimYears
            ])
            Telemetry.breadcrumb("Paywall viewed", category: "paywall",
                                 data: ["surface": "onboarding_v2"])
            AdsTracker.trackViewContent(name: "onboarding_paywall")

            loadCurrentOffering()
        }
    }

    // MARK: - Backdrop pieces

    private var header: some View {
        HStack {
            Spacer()

            Button {
                Task { await restorePurchases() }
            } label: {
                HStack(spacing: 4) {
                    if isRestoringPurchases {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: SGTheme.paper))
                            .scaleEffect(0.7)
                    }
                    Text(isRestoringPurchases ? "Restoring..." : "Restore")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(SGTheme.paperSecondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(isRestoringPurchases)
            .accessibilityLabel("Restore purchases")
        }
        .padding(.horizontal, SGTheme.screenPadding)
        .padding(.top, 10)
        .fadeRise(shown)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            MascotView(pose: .idle)
                .frame(width: 90, height: 90)
                .fadeRise(shown)

            Text(viewModel.reclaimYears > 1
                 ? "Win back your \(viewModel.reclaimYears) years"
                 : "Win back your time")
                .font(SGTheme.display(28))
                .foregroundColor(SGTheme.paper)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .fadeRise(shown, delay: 0.1)

            if !viewModel.studentType.isEmpty {
                Text("Your \(viewModel.studentType.lowercased()) study plan is ready.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .fadeRise(shown, delay: 0.15)
            }

            VStack(alignment: .leading, spacing: 14) {
                PaywallFeatureRow(icon: "lock.fill",
                                  text: "Apps lock when your time runs out")
                PaywallFeatureRow(icon: "rectangle.stack.fill",
                                  text: "Flashcards and focus sessions earn it back")
                PaywallFeatureRow(icon: "sparkles",
                                  text: "AI generates cards from your notes")
                PaywallFeatureRow(icon: "cross.circle.fill",
                                  text: "Emergency unlocks for real emergencies")
            }
            .padding(.top, 28)
            .fadeRise(shown, delay: 0.25)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SGTheme.mintDeep)
                Text("Cancel anytime in the App Store")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .padding(.top, 24)
            .fadeRise(shown, delay: 0.3)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isLoadingOffering {
            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: SGTheme.mintDeep))
                Text("Loading your plan...")
                    .font(SGTheme.caption)
                    .foregroundColor(SGTheme.paperSecondary)
            }
            .frame(height: 76)
            .accessibilityLabel("Loading your plan")
        } else if loadFailed {
            VStack(spacing: 12) {
                Text("Couldn't load plans. Check your connection.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.screenAction("offering_retry_tapped")
                    didAutoRetry = false
                    loadCurrentOffering()
                } label: {
                    Text("Retry")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(SGTheme.mint, in: Capsule(style: .continuous))
                }
                .buttonStyle(SGPressStyle())
                .accessibilityLabel("Retry loading plans")
            }
            .padding(.horizontal, SGTheme.screenPadding)
        } else {
            OnbCTA(title: "See plans", visible: shown) {
                viewModel.screenAction("see_plans_tapped", properties: [
                    "decline_count": declineCount
                ])
                showingRevenueCatPaywall = true
            }
        }
    }

    // MARK: - RevenueCat cover

    @ViewBuilder
    private var paywallCover: some View {
        if let offering = currentOffering {
            PaywallView(offering: offering)
                .onAppear {
                    print("🎯 Showing paywall with offering: \(offering.identifier)")
                    Analytics.paywallViewed(surface: "onboarding_v2_rc", properties: [
                        "offering_id": offering.identifier,
                        "has_offering": true
                    ])
                    viewModel.screenAction("rc_paywall_presented", properties: [
                        "offering_id": offering.identifier,
                        "has_offering": true
                    ])

                    // Mark that user viewed the paywall (drives the buyback
                    // notification when they leave without purchasing).
                    NotificationManager.shared.markPaywallViewedWithoutPurchase()
                    print("[HardPaywallView] 📝 Marked paywall as viewed")
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

                    // New unified subscription event (replaces the old
                    // `onboarding_purchase_completed` event — kept below
                    // for dashboards that haven't migrated yet).
                    Analytics.subscriptionStarted(
                        surface: "onboarding_v2",
                        productId: productId,
                        price: price,
                        currency: currency,
                        isTrial: isTrial,
                        offeringId: offering.identifier,
                        entitlements: customerInfo.entitlements.active.keys.map { $0 }
                    )
                    Analytics.capture("onboarding_purchase_completed", properties: [
                        "offering_id": offering.identifier,
                        "entitlements": customerInfo.entitlements.active.keys.map { $0 }
                    ])

                    didCompletePurchase = true

                    NotificationManager.shared.resetPaywallTracking()

                    showingRevenueCatPaywall = false
                    viewModel.nextStep()
                }
                .onRestoreCompleted { customerInfo in
                    let hasActive = !customerInfo.entitlements.active.isEmpty
                    Analytics.restorePurchasesSucceeded(
                        surface: "onboarding_v2",
                        hasActiveEntitlements: hasActive
                    )
                    if hasActive {
                        didCompletePurchase = true
                        NotificationManager.shared.resetPaywallTracking()
                        showingRevenueCatPaywall = false
                        viewModel.nextStep()
                    }
                }
                .onDisappear {
                    Analytics.paywallDismissed(
                        surface: "onboarding_v2_rc",
                        didPurchase: didCompletePurchase
                    )
                }
        } else {
            PaywallView()
                .onAppear {
                    print("❌ ERROR: Showing fallback paywall - currentOffering is nil!")
                    Analytics.paywallViewed(surface: "onboarding_v2_rc", properties: [
                        "has_offering": false
                    ])
                    viewModel.screenAction("rc_paywall_presented", properties: [
                        "has_offering": false
                    ])
                    NotificationManager.shared.markPaywallViewedWithoutPurchase()
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
                                    surface: "onboarding_v2",
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
                    Analytics.capture("onboarding_purchase_completed", properties: [
                        "offering_id": "fallback",
                        "entitlements": customerInfo.entitlements.active.keys.map { $0 }
                    ])

                    didCompletePurchase = true
                    NotificationManager.shared.resetPaywallTracking()
                    showingRevenueCatPaywall = false
                    viewModel.nextStep()
                }
                .onRestoreCompleted { customerInfo in
                    let hasActive = !customerInfo.entitlements.active.isEmpty
                    Analytics.restorePurchasesSucceeded(
                        surface: "onboarding_v2",
                        hasActiveEntitlements: hasActive
                    )
                    if hasActive {
                        didCompletePurchase = true
                        NotificationManager.shared.resetPaywallTracking()
                        showingRevenueCatPaywall = false
                        viewModel.nextStep()
                    }
                }
                .onDisappear {
                    Analytics.paywallDismissed(
                        surface: "onboarding_v2_rc",
                        didPurchase: didCompletePurchase
                    )
                }
        }
    }

    // MARK: - Decline ladder

    private func handleCoverDismissed() {
        if didCompletePurchase { return }
        if externallyDismissed {
            externallyDismissed = false
            return
        }

        didTriggerBuyBackThisRound = false
        declineCount += 1
        viewModel.screenAction("paywall_declined", properties: [
            "decline_count": declineCount
        ])

        if declineCount == 1 {
            // Let the cover finish its dismissal transition before the sheet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Guard the race: skip if the RC cover was re-presented in
                // the meantime or the survey is already up.
                guard !showingRevenueCatPaywall, !showDeclineSurvey else { return }
                showDeclineSurvey = true
            }
        } else {
            presentBuyBack()
        }
    }

    /// Presents the app-level BuyBackOfferView (mounted as a fullScreenCover
    /// on NavigationModel.showBuyBackOffer in diewithoutregretsApp).
    private func presentBuyBack() {
        guard !didCompletePurchase, !didTriggerBuyBackThisRound else { return }
        didTriggerBuyBackThisRound = true
        viewModel.screenAction("buyback_presented", properties: [
            "decline_count": declineCount
        ])
        NavigationModel.shared.presentBuyBackOffer()
    }

    // MARK: - Offerings

    private func loadCurrentOffering() {
        isLoadingOffering = true
        loadFailed = false

        Purchases.shared.getOfferings { offerings, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ RevenueCat Offerings Error: \(error.localizedDescription)")
                    if !didAutoRetry {
                        // One automatic retry before surfacing the failure UI.
                        didAutoRetry = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            loadCurrentOffering()
                        }
                    } else {
                        isLoadingOffering = false
                        loadFailed = true
                    }
                    return
                }

                if let offerings = offerings {
                    print("✅ Available offerings: \(offerings.all.keys)")
                    print("🔍 Current offering: \(offerings.current?.identifier ?? "none")")

                    // Use the default/current offering (can be changed in RevenueCat dashboard)
                    currentOffering = offerings.current

                    if let current = offerings.current {
                        print("✅ Using default offering: \(current.identifier)")
                        print("📦 Available packages: \(current.availablePackages.map { $0.identifier })")
                    } else {
                        print("⚠️ No current offering set - check RevenueCat dashboard")
                    }
                } else {
                    print("❌ No offerings available - check RevenueCat configuration")
                    currentOffering = nil
                }

                isLoadingOffering = false
                loadFailed = false
                autoPresentIfNeeded()
            }
        }
    }

    /// Auto-presents the RC paywall the first time offerings land — the
    /// backdrop is only briefly visible behind it. Later re-presents go
    /// through the "See plans" CTA.
    private func autoPresentIfNeeded() {
        guard !hasAutoPresented, !didCompletePurchase, !isRestoringPurchases else { return }
        hasAutoPresented = true

        let delay = UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !didCompletePurchase, !isRestoringPurchases else { return }
            showingRevenueCatPaywall = true
        }
    }

    // MARK: - Restore Purchases

    private func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        Analytics.restorePurchasesAttempted(surface: "onboarding_v2")

        do {
            print("🔄 Starting restore purchases...")

            // Invalidate cache before restore to get fresh data
            Purchases.shared.invalidateCustomerInfoCache()

            // Add small delay to ensure cache invalidation completes
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            let customerInfo = try await Purchases.shared.restorePurchases()

            // Check if user has active entitlements after restore
            if !customerInfo.entitlements.active.isEmpty {
                print("✅ Restore successful - user has active entitlements: \(customerInfo.entitlements.active.keys)")
                Analytics.restorePurchasesSucceeded(surface: "onboarding_v2", hasActiveEntitlements: true)

                // Guard the decline ladder and auto-present: they have Pro now.
                didCompletePurchase = true

                // Show success message
                DispatchQueue.main.async {
                    self.restoreSuccessMessage = "Your purchases have been restored successfully!"
                }

                // Continue onboarding flow
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.viewModel.nextStep()
                }
            } else {
                print("ℹ️ Restore completed but no active entitlements found")
                Analytics.restorePurchasesSucceeded(surface: "onboarding_v2", hasActiveEntitlements: false)
                DispatchQueue.main.async {
                    self.restoreErrorMessage = "No previous purchases found to restore."
                }
            }
        } catch {
            print("❌ Restore purchases error: \(error)")
            Analytics.restorePurchasesFailed(surface: "onboarding_v2", error: error.localizedDescription)
            Telemetry.capture(error,
                              tags: ["feature": "paywall", "surface": "onboarding_v2", "operation": "restore_purchases"])
            DispatchQueue.main.async {
                self.restoreErrorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Feature row

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SGTheme.mintDeep)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SGTheme.inkRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(SGTheme.hairline, lineWidth: 1)
                        )
                )
                .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(SGTheme.paper)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Decline survey

/// Decline #1 sheet: one tap on a reason, then the buyback offer. The
/// reason fires through `onReason`; the presenting view triggers buyback in
/// the sheet's onDismiss (so a swipe-away still leads to the offer).
private struct DeclineSurveySheet: View {
    let onReason: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: String?

    private let reasons = [
        "Too expensive",
        "Not sure it'll work for me",
        "Just exploring",
        "Other",
    ]

    var body: some View {
        ZStack {
            SGTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("What's holding you back?")
                    .font(SGTheme.display(22))
                    .foregroundColor(SGTheme.paper)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                Text("One tap. It helps us make Study Guard better.")
                    .font(SGTheme.body)
                    .foregroundColor(SGTheme.paperSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)

                VStack(spacing: 10) {
                    ForEach(reasons, id: \.self) { reason in
                        reasonRow(reason)
                    }
                }
                .padding(.horizontal, SGTheme.screenPadding)
                .padding(.top, 24)

                Spacer(minLength: 0)
            }
        }
    }

    private func reasonRow(_ reason: String) -> some View {
        let isSelected = selected == reason

        return Button {
            pick(reason)
        } label: {
            HStack(spacing: 12) {
                Text(reason)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(SGTheme.paper)

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? SGTheme.mintDeep : SGTheme.paperTertiary,
                                      lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle().fill(SGTheme.mint).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                    .fill(SGTheme.inkRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: SGTheme.tileRadius, style: .continuous)
                            .strokeBorder(isSelected ? SGTheme.mintDeep : SGTheme.hairline,
                                          lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SGPressStyle())
        .animation(SGTheme.springFast, value: isSelected)
    }

    private func pick(_ reason: String) {
        guard selected == nil else { return }
        selected = reason
        SGTheme.tapHaptic()
        onReason(reason)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

#Preview {
    ZStack {
        SGTheme.ink.ignoresSafeArea()
        HardPaywallView()
            .environmentObject(OnboardingViewModel())
    }
}

#Preview("Decline survey") {
    DeclineSurveySheet { _ in }
}
