//
//  FreeTrialReminderView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/10/20.
//

import SwiftUI
import UserNotifications
import RevenueCat
import RevenueCatUI
import PostHog

struct FreeTrialReminderView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @StateObject private var navigationModel = NavigationModel.shared
    
    // State variables to control the opacity and offset of each element
    @State private var showTitle = false
    @State private var showBellIcon = false
    @State private var showPaymentStatus = false
    @State private var showButton = false
    @State private var showSubscriptionDetails = false

    @State private var isRequestingPermission = false
    @State private var isRestoringPurchases = false
    @State private var restoreErrorMessage: String?
    @State private var restoreSuccessMessage: String?
    
    @State private var showingRevenueCatPaywall = false
    @State private var currentOffering: Offering?
    @State private var isLoadingOffering = true
    @State private var didCompletePurchase = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            VStack(spacing: 0) {
                // Header with restore button only
                HStack {
                    Spacer()
                    
                    Button(action: {
                        Task { await restorePurchases() }
                    }) {
                        HStack(spacing: 4) {
                            if isRestoringPurchases {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: 0x184449)))
                                    .scaleEffect(0.7)
                            }
                            Text(isRestoringPurchases ? "Restoring..." : "Restore")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                        }
                    }
                    .disabled(isRestoringPurchases)
                    .accessibilityLabel("Restore purchases")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Main content
                VStack(spacing: 40) {
                    // Title text
                    VStack(spacing: 8) {
                        Text("We'll send you")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                        
                        Text("a reminder before your")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                        
                        Text("free trial ends")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 30)
                    .animation(.easeOut(duration: 1.0).delay(0.2), value: showTitle)
                    .accessibilityLabel("We'll send you a reminder before your free trial ends")
                    
                    // Bell icon with notification badge
                    ZStack {
                        Image(systemName: "bell")
                            .font(.system(size: 80))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.3))
                        
                        // Notification badge
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 24, height: 24)
                                    
                                    Text("1")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                        .frame(width: 80, height: 80)
                    }
                    .opacity(showBellIcon ? 1 : 0)
                    .offset(y: showBellIcon ? 0 : 30)
                    .animation(.easeOut(duration: 1.0).delay(0.4), value: showBellIcon)
                    .accessibilityLabel("Bell icon with notification")
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Footer content
                VStack(spacing: 20) {
                    // Payment status
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449))
                        
                        Text("No Payment Due Now")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(hex: 0x184449))
                    }
                    .opacity(showPaymentStatus ? 1 : 0)
                    .offset(y: showPaymentStatus ? 0 : 20)
                    .animation(.easeOut(duration: 1.0).delay(0.6), value: showPaymentStatus)
                    .accessibilityLabel("No Payment Due Now")
                    
                    // Continue button
                    Button(action: {
                        requestNotificationPermission()
                    }) {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isRequestingPermission ? "Requesting..." : "Continue for FREE")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(hex: 0x184449))
                        .cornerRadius(28)
                    }
                    .padding(.horizontal, 20)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 1.0).delay(0.8), value: showButton)
                    .accessibilityLabel("Continue for FREE")
                    .accessibilityHint("Tap to continue with your free trial")
                    .accessibilityAddTraits(.isButton)
                    .disabled(isRequestingPermission)
                }
                .padding(.bottom, 20)
            }
        }
        .alert("Restore Error", isPresented: .constant(restoreErrorMessage != nil)) {
            Button("OK") { 
                restoreErrorMessage = nil 
            }
        } message: {
            Text(restoreErrorMessage ?? "Unknown error")
        }
        .alert("Restore Successful", isPresented: .constant(restoreSuccessMessage != nil)) {
            Button("OK") { 
                restoreSuccessMessage = nil 
            }
        } message: {
            Text(restoreSuccessMessage ?? "Purchases restored successfully")
        }
        .fullScreenCover(isPresented: $showingRevenueCatPaywall) {
            if let offering = currentOffering {
                PaywallView(offering: offering)
                    .onAppear {
                        print("🎯 Showing paywall with offering: \(offering.identifier)")
                        
                        // Mark that user viewed the paywall
                        NotificationManager.shared.markPaywallViewedWithoutPurchase()
                        print("[FreeTrialReminderView] 📝 Marked paywall as viewed")
                    }
                    .onPurchaseCompleted { customerInfo in
                        // Track successful purchase
                        PostHogSDK.shared.capture(
                            "onboarding_purchase_completed",
                            properties: [
                                "timestamp": Date().ISO8601Format(),
                                "user_name": viewModel.userName,
                                "offering_id": offering.identifier,
                                "entitlements": customerInfo.entitlements.active.keys.map { $0 }
                            ]
                        )
                        
                        if let entitlement = customerInfo.entitlements.active.values.first,
                           let package = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == entitlement.productIdentifier }) {
                            let price = Double(truncating: package.storeProduct.price as NSNumber)
                            let currency = package.storeProduct.currencyCode ?? "USD"
                            if entitlement.periodType == .trial {
                                AdsTracker.trackStartTrial(
                                    productId: package.storeProduct.productIdentifier,
                                    price: price,
                                    currency: currency
                                )
                            } else {
                                AdsTracker.trackSubscribe(
                                    productId: package.storeProduct.productIdentifier,
                                    price: price,
                                    currency: currency
                                )
                                AdsTracker.trackPurchase(
                                    productId: package.storeProduct.productIdentifier,
                                    productName: package.storeProduct.localizedTitle,
                                    price: price,
                                    currency: currency
                                )
                            }
                        }
                        
                        didCompletePurchase = true
                        
                        NotificationManager.shared.resetPaywallTracking()
                        
                        showingRevenueCatPaywall = false
                        viewModel.nextStep()
                    }
                    .onRestoreCompleted { customerInfo in
                        if customerInfo.entitlements["Pro Acess"]?.isActive == true {
                            didCompletePurchase = true
                            NotificationManager.shared.resetPaywallTracking()
                            showingRevenueCatPaywall = false
                            viewModel.nextStep()
                        }
                    }
            } else {
                PaywallView()
                    .onAppear {
                        print("❌ ERROR: Showing fallback paywall - currentOffering is nil!")
                        NotificationManager.shared.markPaywallViewedWithoutPurchase()
                    }
                    .onPurchaseCompleted { customerInfo in
                        if let entitlement = customerInfo.entitlements.active.values.first {
                            Task {
                                let products = await Purchases.shared.products([entitlement.productIdentifier])
                                if let product = products.first {
                                    let price = Double(truncating: product.price as NSNumber)
                                    let currency = product.currencyCode ?? "USD"
                                    if entitlement.periodType == .trial {
                                        AdsTracker.trackStartTrial(
                                            productId: product.productIdentifier,
                                            price: price,
                                            currency: currency
                                        )
                                    } else {
                                        AdsTracker.trackSubscribe(
                                            productId: product.productIdentifier,
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
                                }
                            }
                        }
                        
                        didCompletePurchase = true
                        NotificationManager.shared.resetPaywallTracking()
                        showingRevenueCatPaywall = false
                        viewModel.nextStep()
                    }
                    .onRestoreCompleted { customerInfo in
                        if customerInfo.entitlements["Pro Acess"]?.isActive == true {
                            didCompletePurchase = true
                            NotificationManager.shared.resetPaywallTracking()
                            showingRevenueCatPaywall = false
                            viewModel.nextStep()
                        }
                    }
            }
        }
        .onChange(of: navigationModel.shouldDismissPaywall) { oldValue, newValue in
            if newValue {
                print("[FreeTrialReminderView] 🚪 Received dismiss signal, closing paywall")
                showingRevenueCatPaywall = false
            }
        }
        .onAppear {
            // Trigger the animations when the view appears
            showTitle = true
            showBellIcon = true
            showPaymentStatus = true
            showButton = true
            showSubscriptionDetails = true
            
            // Load offering
            loadCurrentOffering()
        }
    }
    
    // MARK: - Restore Purchases
    private func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }
        
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
                
                // Show success message
                DispatchQueue.main.async {
                    self.restoreSuccessMessage = "Your purchases have been restored successfully!"
                }
                
                // Continue onboarding flow
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Continue to next page in onboarding flow
                    self.viewModel.nextStep()
                }
            } else {
                print("ℹ️ Restore completed but no active entitlements found")
                DispatchQueue.main.async {
                    self.restoreErrorMessage = "No previous purchases found to restore."
                }
            }
        } catch {
            print("❌ Restore purchases error: \(error)")
            DispatchQueue.main.async {
                self.restoreErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func requestNotificationPermission() {
        isRequestingPermission = true
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                isRequestingPermission = false
                
                if let error = error {
                    print("🔔 Notification permission error: \(error)")
                } else {
                    print("🔔 Notification permission granted: \(granted)")
                }
                
                // Show the RevenueCat paywall after notification permission
                if currentOffering != nil || !isLoadingOffering {
                    showingRevenueCatPaywall = true
                } else {
                    print("⚠️ Offering not loaded yet, waiting...")
                    // Wait a bit for offering to load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingRevenueCatPaywall = true
                    }
                }
            }
        }
    }
    
    private func loadCurrentOffering() {
        Purchases.shared.getOfferings { offerings, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ RevenueCat Offerings Error: \(error.localizedDescription)")
                    self.isLoadingOffering = false
                    return
                }
                
                if let offerings = offerings {
                    print("✅ Available offerings: \(offerings.all.keys)")
                    print("🔍 Current offering: \(offerings.current?.identifier ?? "none")")
                    
                    // Use the default/current offering (can be changed in RevenueCat dashboard)
                    self.currentOffering = offerings.current
                    self.isLoadingOffering = false
                    
                    if let current = offerings.current {
                        print("✅ Using default offering: \(current.identifier)")
                        print("📦 Available packages: \(current.availablePackages.map { $0.identifier })")
                    } else {
                        print("⚠️ No current offering set - check RevenueCat dashboard")
                    }
                } else {
                    print("❌ No offerings available - check RevenueCat configuration")
                    self.currentOffering = nil
                    self.isLoadingOffering = false
                }
            }
        }
    }
}

#Preview {
    FreeTrialReminderView()
        .environmentObject(OnboardingViewModel())
}

