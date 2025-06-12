//
//  StudyGuardReadyView.swift
//  diewithoutregrets
//
//  Created on 2025/04/10.
//

import SwiftUI

struct StudyGuardReadyView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // State variables to control the loading and animations
    @State private var isLoading = true
    @State private var progress: CGFloat = 0
    @State private var showCheckmark = false
    @State private var showTitle = false
    @State private var showDescription = false
    @State private var showButton = false
    
    // Timer to simulate loading
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true) // Hide decorative background color
            
            VStack(spacing: 30) {
                // Loading circle or complete icon
                ZStack {
                    // Gradient circle background
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: 0x184549).opacity(0.5), Color.green.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 15
                        )
                        .frame(width: 200, height: 200)
                    
                    // Loading progress circle
                    Circle()
                        .trim(from: 0, to: isLoading ? progress : 1)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.teal.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                    // Center circle with content
                    Circle()
                        .fill(Color.white)
                        .frame(width: 170, height: 170)
                    
                    if isLoading {
                        // Show clock-like dots
                        ForEach(0..<12) { i in
                            Circle()
                                .fill(Color.black)
                                .frame(width: 5, height: 5)
                                .offset(y: -75)
                                .rotationEffect(.degrees(Double(i) * 30))
                        }
                        
                        // Hand icon with heart
                        VStack {
                            
                            Image(systemName: "heart.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.red)
                                .offset(y: -15)
                        }
                    } else {
                        // Checkmark icon when loading is complete
                        Circle()
                            .fill(Color(hex: 0x184449))
                            .frame(width: 60, height: 60)
                            .opacity(showCheckmark ? 1 : 0)
                            .scaleEffect(showCheckmark ? 1 : 0.5)
                            .animation(.spring(), value: showCheckmark)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(showCheckmark ? 1 : 0)
                            .animation(.easeIn.delay(0.2), value: showCheckmark)
                    }
                }
                .padding(.top, 150)
                // Status text that changes after loading
                if isLoading {
                    Text("Getting Study Guard ready for you...")
                        .font(.title3)
                        .foregroundColor(.white)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityLabel("Getting Study Guard ready for you")
                } else {
                    VStack(spacing: 16) {
                        // "All done!" text with animation
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("All done!")
                                .foregroundColor(.green)
                                .bold()
                        }
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeInOut(duration: 0.6).delay(0.2), value: showTitle)
                        .accessibilityLabel("All done")
                        
                        // Title with animation
                        Text("Study Guard is all set!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(showTitle ? 1 : 0)
                            .offset(y: showTitle ? 0 : 20)
                            .animation(.easeInOut(duration: 0.6).delay(0.4), value: showTitle)
                            .accessibilityLabel("Study Guard is all set")
                        
                        // Description with animation
                        Text("Ready for you to use that phone addiction to motivate you to study.")
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .opacity(showDescription ? 1 : 0)
                            .offset(y: showDescription ? 0 : 20)
                            .animation(.easeInOut(duration: 0.6).delay(0.6), value: showDescription)
                            .accessibilityLabel("Ready for you to use that phone addiction to motivate you to study")
                    }
                }
                
                Spacer()
                
                // Continue button with animation
                // show paywall (skipable)
                Button(action: {
                    onboardingViewModel.nextStep()
                }) {
                    Text("Create First Flashcard")
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(.white)
                        .cornerRadius(50)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 0.6).delay(0.8), value: showButton)
                .accessibilityLabel("Create First Flashcard")
                .accessibilityHint("Tap to create your first flashcard")
                .accessibilityAddTraits(.isButton)
                .padding(.bottom)
            }
            .padding()
        }
        .onReceive(timer) { _ in
            if isLoading {
                // Increment progress to simulate loading
                if progress < 1.0 {
                    progress += 0.01
                } else {
                    isLoading = false
                    showCheckmark = true
                    showTitle = true
                    showDescription = true
                    showButton = true
                    timer.upstream.connect().cancel()
                }
            }
        }
    }
}




#Preview {
    StudyGuardReadyView()
        .environmentObject(OnboardingViewModel())
}
