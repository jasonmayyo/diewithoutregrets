//
//  PayWallView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/06/01.
//

import SwiftUI
import AVKit
import PostHog

struct PayWallView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @State private var showTitle = false
    @State private var showVideo = false
    @State private var showCheckmark = false
    @State private var showButton = false
    
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
                        Text("Invest in your future self.")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28, weight: .bold))
                            .foregroundColor(Color(hex: 0x184449))
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 20)
                            .animation(.easeInOut(duration: 0.8).delay(0.2), value: showTitle)
                        
                        Text("Less than a coffee a day. More valuable than a tutor.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .animation(.easeInOut(duration: 0.8).delay(0.4), value: showTitle)
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
                            onboardingViewModel.triggerHapticFeedback()
                            // Move to next step (FreeTrialReminderView)
                            onboardingViewModel.nextStep()
                        }) {
                            Text("Try for $0.00")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 70 : 55)
                                .background(Color(hex: 0x184449))
                                .cornerRadius(50)
                        }
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
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    PayWallView()
        .environmentObject(OnboardingViewModel())
}
