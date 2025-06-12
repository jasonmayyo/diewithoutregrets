//
//  PayWallView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/06/01.
//

import SwiftUI
import AVKit
import RevenueCat
import RevenueCatUI
import PostHog

struct PayWallView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var showTitle = false
    @State private var showVideo = false
    @State private var showCheckmark = false
    @State private var showButton = false
    @State private var showingFinalSalePitch = false
    @State private var showingRevenueCatPaywall = false
    @State private var currentOffering: Offering?
    @State private var isLoadingOffering = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color matching onboarding theme
                Color.white
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                VStack(spacing: 0) {
                    // Title section
                    VStack(spacing: 8) {
                        
                        Text("We want you to try Study")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 20)
                            .animation(.easeInOut(duration: 0.8).delay(0.2), value: showTitle)
                        
                        Text("Guard for FREE")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 20)
                            .animation(.easeInOut(duration: 0.8).delay(0.3), value: showTitle)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Video section
                    VStack {
                        
                        // Video player
                        LoopingVideoPlayer(videoName: "mockupvideo", videoExtension: "mp4")
                            .frame(height: min(600, geometry.size.height * 0.7))
                            .cornerRadius(16)
                            .opacity(showVideo ? 1 : 0)
                            .scaleEffect(showVideo ? 1 : 0.9)
                            .animation(.easeInOut(duration: 0.8).delay(0.5), value: showVideo)
                            .accessibilityLabel("Video demonstration of Study Guard app")
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Bottom section
                    VStack(spacing: 5) {
                        // Checkmark with "No payment due now"
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: 0x184449))
                                .frame(width: 24, height: 24)
                             
                            
                            Text("No payment due now")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449))
                        }
                        .opacity(showCheckmark ? 1 : 0)
                        .offset(y: showCheckmark ? 0 : 20)
                        .animation(.easeInOut(duration: 0.8).delay(0.6), value: showCheckmark)
                        .accessibilityLabel("No payment due now")
                        
                        // Try for $0.00 button
                        Button(action: {
                            guard currentOffering != nil else {
                                print("⚠️ Button tapped but offering not loaded yet")
                                return
                            }
                            onboardingViewModel.triggerHapticFeedback()
                            showingFinalSalePitch = true
                        }) {
                            HStack {
                                if isLoadingOffering {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoadingOffering ? "Loading..." : "Try for $0.00")
                            }
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 70 : 55)
                            .background(isLoadingOffering ? Color.gray : Color(hex: 0x184449))
                            .cornerRadius(50)
                        }
                        .disabled(isLoadingOffering || currentOffering == nil)
                        .opacity(showButton ? 1 : 0)
                        .offset(y: showButton ? 0 : 20)
                        .animation(.easeInOut(duration: 0.8).delay(0.7), value: showButton)
                        .accessibilityLabel("Try for free")
                        .accessibilityHint("Start your 3-day free trial")
                        .accessibilityAddTraits(.isButton)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            // Track paywall viewed
            PostHogSDK.shared.capture(
                "paywall_viewed",
                properties: [
                    "timestamp": Date().ISO8601Format(),
                    "user_name": onboardingViewModel.userName,
                    "selected_age": onboardingViewModel.selectedAge,
                    "screen_time": onboardingViewModel.screenTime
                ]
            )
            
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showTitle = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showVideo = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showCheckmark = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                showButton = true
            }
            
            loadCurrentOffering()
        }
        .fullScreenCover(isPresented: $showingRevenueCatPaywall) {
            if let offering = currentOffering {
                PaywallView(offering: offering)
                    .onAppear {
                        print("🎯 Showing paywall with offering: \(offering.identifier)")
                        print("📦 Offering packages: \(offering.availablePackages.map { $0.identifier })")
                    }
                    .onPurchaseCompleted { customerInfo in
                        // Track successful purchase
                        PostHogSDK.shared.capture(
                            "onboarding_purchase_completed",
                            properties: [
                                "timestamp": Date().ISO8601Format(),
                                "user_name": onboardingViewModel.userName,
                                "offering_id": offering.identifier,
                                "entitlements": customerInfo.entitlements.active.keys.map { $0 }
                            ]
                        )
                        
                        // Handle successful purchase
                        showingRevenueCatPaywall = false
                        onboardingViewModel.nextStep()
                    }
                    .onRestoreCompleted { customerInfo in
                        // Handle restore
                        if customerInfo.entitlements["Pro Acess"]?.isActive == true {
                            showingRevenueCatPaywall = false
                            onboardingViewModel.nextStep()
                        }
                    }
            } else {
                // This should not happen now with the loading state
                PaywallView()
                    .onAppear {
                        print("❌ ERROR: Showing fallback paywall - currentOffering is nil!")
                        print("❌ isLoadingOffering: \(isLoadingOffering)")
                    }
                    .onPurchaseCompleted { customerInfo in
                        showingRevenueCatPaywall = false
                        onboardingViewModel.nextStep()
                    }
                    .onRestoreCompleted { customerInfo in
                        if customerInfo.entitlements["Pro Acess"]?.isActive == true {
                            showingRevenueCatPaywall = false
                            onboardingViewModel.nextStep()
                        }
                    }
            }
        }
        .preferredColorScheme(.light)
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
                    print("🌍 Environment: \(offerings.all.isEmpty ? "UNKNOWN" : "FETCHED")")
                    
                    // Try to find the 3-Day-Free offering
                    if let threeDayOffering = offerings.offering(identifier: "3-Day-Free") {
                        print("✅ Found 3-Day-Free offering")
                        print("📦 3-Day-Free packages: \(threeDayOffering.availablePackages.map { $0.identifier })")
                        self.currentOffering = threeDayOffering
                        self.isLoadingOffering = false
                        print("🎯 3-Day-Free offering set as currentOffering")
                    } else if let threeDayOffering = offerings.all["3-Day-Free"] {
                        print("✅ Found 3-Day-Free offering (alternative lookup)")
                        self.currentOffering = threeDayOffering
                        self.isLoadingOffering = false
                        print("🎯 3-Day-Free offering set as currentOffering (alt)")
                    } else {
                        print("⚠️ 3-Day-Free offering not found")
                        print("📋 Available offering identifiers: \(Array(offerings.all.keys))")
                        print("📋 Using current offering: \(offerings.current?.identifier ?? "none")")
                        self.currentOffering = offerings.current
                        self.isLoadingOffering = false
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
    PayWallView()
        .environmentObject(OnboardingViewModel())
}
