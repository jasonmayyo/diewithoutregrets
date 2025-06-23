//
//  StudyConsistancy.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/06/08.
//

import SwiftUI

struct StudyConsistancy: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showAnimation = false
    @State private var showButton = false
    @State private var animateScrollCount = 0.0
    @State private var animateStudyTime = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: 0x184449)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading) {
                    
                    
        
                        Text("Imagine being as consistent with studying as you are with scrolling")
                            .font(.system(size: 24))
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 30)
                            .animation(.easeInOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                
                    // Centered content
                    Spacer()
                    
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 4) {
                            Text("If you scroll 20 times a day.")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeInOut(duration: 0.8).delay(0.6), value: showAnimation)

                            Text("And we help you study for just 5 minutes before each scroll")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeInOut(duration: 0.8).delay(0.8), value: showAnimation)
                        }
                        .padding(.horizontal)

                        // Premium Graph
                        StudyProgressGraph(showAnimation: $showAnimation)
                        
                        // Bottom impact statement
                        VStack(spacing: 8) {
                            Text("That's 11 extra hours of study per week.")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 26 : 20, weight: .bold))
                                .foregroundColor(Color(hex: 0x64FFDA))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeInOut(duration: 0.8).delay(2.0), value: showAnimation)
                            
                            Text("Without changing your routine.")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeInOut(duration: 0.8).delay(2.2), value: showAnimation)
                        }
                    }
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : 30)
                    .animation(.easeInOut(duration: 0.8).delay(0.6), value: showAnimation)
                    
                    Spacer()
                    
                    // CTA Button
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.nextStep()
                    }) {
                        Text("YES! Give me 11 extra hours!")
                            .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18))
                            .foregroundColor(Color(hex: 0x184449))
                            .padding()
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 70 : 55)
                            .background(.white)
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 30)
                    .animation(.easeInOut(duration: 0.8).delay(2.0), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 20)
                .padding(.top, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.height * 0.05 : 2)
                .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.height * 0.05 : 20)
            }
        }
        .onAppear {
            showTitle = true
            showAnimation = true
            showButton = true
        }
        .preferredColorScheme(.light)
    }
}

struct StudyProgressGraph: View {
    @Binding var showAnimation: Bool
    @State private var animatedValue: CGFloat = 0
    @State private var showNumber: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Main focus: 11 hours per week
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 180, height: 180)
                
                // Animated progress circle
                Circle()
                    .trim(from: 0, to: animatedValue)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: 0x64FFDA).opacity(0.6),
                                Color(hex: 0x64FFDA)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(hex: 0x64FFDA).opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Center content
                VStack(spacing: 4) {
                    Text("11")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: 0x64FFDA))
                        .opacity(showNumber ? 1 : 0)
                        .scaleEffect(showNumber ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.2), value: showNumber)
                    
                    Text("hours/week")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(showNumber ? 1 : 0)
                        .offset(y: showNumber ? 0 : 10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4), value: showNumber)
                }
            }
            
            // Simple breakdown
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("20")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("scrolls/day")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(showNumber ? 1 : 0)
                .offset(y: showNumber ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.6), value: showNumber)
                
                Text("×")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(showNumber ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(1.8), value: showNumber)
                
                VStack(spacing: 4) {
                    Text("5")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x64FFDA))
                    Text("min/study")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(showNumber ? 1 : 0)
                .offset(y: showNumber ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(2.0), value: showNumber)
            }
        }
        .onAppear {
            if showAnimation {
                withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
                    animatedValue = 0.65 // ~11/17 hours (assuming 17-hour day)
                }
                showNumber = true
            }
        }
        .onChange(of: showAnimation) { newValue in
            if newValue {
                animatedValue = 0.65
                showNumber = true
            } else {
                animatedValue = 0
                showNumber = false
            }
        }
    }
}

#Preview {
    StudyConsistancy()
        .environmentObject(OnboardingViewModel())
}


//Screen 6: NEW - AI Flashcards Demo
//Show the AI flashcard generation in action
//Headline: "AI creates unlimited flashcards from any material"
//Subtext: "Just upload your notes, textbook photos, or lecture recordings"
//Visual: Animation showing PDF → AI processing → Flashcards
//Examples: "Uploaded: Chapter 5 Biology → Generated: 47 flashcards in 10 seconds"
//Screen 7: NEW - The Blocking Feature Demo
//Show how the scroll-blocking works
//Headline: "Want to scroll? Answer a flashcard first."
//Subtext: "We literally block your apps until you've earned your scroll time."
//Visual: Phone screen showing blocked Instagram with flashcard overlay
//Text: "Instagram locked. Answer 3 flashcards to unlock for 15 minutes."

//
//Screen 16: Enhanced Pricing/Trial
//Improve current pricing screen
//Headline: "Start your transformation for free"
//Value reframe:
//"Less than a daily coffee"
//"Cost of one failed exam: $500+"
//"Cost of Study Guard: $3.47/month"
//Urgency: "Limited time: 7-day free trial (usually 3 days)"
//CTA: "Start my free trial"
