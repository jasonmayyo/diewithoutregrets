//
//  AIFlashcardDemo.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/06/09.
//

import SwiftUI

struct AIFlashcardDemo: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // Animation state variables
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showDemo = false
    @State private var showButton = false
    
    // Demo animation states
    @State private var uploadProgress: CGFloat = 0
    @State private var aiProcessing = false
    @State private var showFlashcards = false
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var showStats = false
    @State private var currentCardIndex = 0
    @State private var cardRotation: Double = 0
    @State private var cardOffset: CGFloat = 0
    @State private var sparkleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                // Title with animation
                Text("AI creates unlimited flashcards from study notes")
                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 32 : 24))
                    .bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 30)
                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                
                // Subtitle with animation
                Text("Just upload your notes, textbook pdfs. We will do the rest")
                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 0.8).delay(0.4), value: showSubtitle)
                    .accessibilityLabel("Just upload your notes, textbook photos, or lecture recordings")
                
                Spacer()
                
                // Demo Animation Section
                VStack(spacing: 20) {
                    demoVisualization
                    
                }
                .opacity(showDemo ? 1 : 0)
                .offset(y: showDemo ? 0 : 30)
                .animation(.easeInOut(duration: 0.8).delay(0.6), value: showDemo)
                
                Spacer()
                
                // Continue button with animation
                Button(action: {
                    onboardingViewModel.triggerHapticFeedback()
                    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 22 : 18))
                        .foregroundColor(Color(hex: 0x184449))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 70 : 55)
                        .background(.white)
                        .cornerRadius(50)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)
                .animation(.easeInOut(duration: 0.8).delay(2.5), value: showButton)
                .accessibilityAddTraits(.isButton)
            }
            .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20)
            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20)
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showDemo = true
            showButton = true
            startDemoAnimation()
        }
    }
    
    private var demoVisualization: some View {
        VStack(spacing: 24) {
            // Step 1: Upload Document
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(uploadProgress > 0 ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: uploadProgress)
                }
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(uploadProgress > 0.3 ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: uploadProgress)
                
                // Step 2: AI Processing
                ZStack {
                    Circle()
                        .fill(aiProcessing ? Color(hex: 0x64FFDA) : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .animation(.easeInOut(duration: 0.8), value: aiProcessing)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(aiProcessing ? Color(hex: 0x184449) : .white)
                        .scaleEffect(aiProcessing ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: aiProcessing)
                }
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showFlashcards ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: showFlashcards)
                
                // Step 3: Flashcards
                ZStack {
                    Circle()
                        .fill(showFlashcards ? Color(hex: 0x64FFDA) : Color.white.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .animation(.easeInOut(duration: 0.8), value: showFlashcards)
                    
                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(showFlashcards ? Color(hex: 0x184449) : .white)
                        .scaleEffect(showFlashcards ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showFlashcards)
                }
            }
            .padding(.horizontal)
            
            // Process Labels
            HStack {
                VStack(spacing: 4) {
                    Text("Upload")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("PDF/Notes")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("AI Process")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(aiProcessing ? Color(hex: 0x64FFDA) : .white)
                        .animation(.easeInOut(duration: 0.3), value: aiProcessing)
                    Text("Analyze")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("Generate")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showFlashcards ? Color(hex: 0x64FFDA) : .white)
                        .animation(.easeInOut(duration: 0.3), value: showFlashcards)
                    Text("Flashcards")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Enhanced Flashcard Preview Stack
            if showFlashcards {
                ZStack {
                    // Background sparkles
                    ForEach(0..<8, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: 0x64FFDA).opacity(sparkleOpacity))
                            .offset(
                                x: CGFloat.random(in: -100...100),
                                y: CGFloat.random(in: -50...50)
                            )
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: sparkleOpacity
                            )
                    }
                }
                .padding(.top, 20)
            }
        }
    }
    
    private func premiumFlashcardPreview(for index: Int) -> some View {
        let cardData = getCardData(for: index)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Premium header with gradient
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x64FFDA), Color(hex: 0x3FA4AE)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Generated")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: 0x64FFDA))
                    
                    Text("Study Card #\(index + 1)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: 0x64FFDA).opacity(0.7))
                }
                
                Spacer()
                
                // Premium indicator
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.yellow)
                    
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(8)
            }
            
            // Question section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                    
                    Text("Question")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Text(cardData.question)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: 0x184449))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Answer preview
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green.opacity(0.7))
                    
                    Text("Answer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Text(cardData.answer)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .background(
            ZStack {
                // Base white background
                Color.white
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color(hex: 0x64FFDA).opacity(0.03),
                        Color.clear,
                        Color(hex: 0x3FA4AE).opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Premium border glow
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x64FFDA).opacity(0.3),
                                Color(hex: 0x3FA4AE).opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .cornerRadius(16)
        .shadow(
            color: Color(hex: 0x64FFDA).opacity(0.15),
            radius: 20,
            x: 0,
            y: 8
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 6,
            x: 0,
            y: 2
        )
        .frame(maxWidth: .infinity)
        .overlay(
            // Shimmer effect
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .blur(radius: 0.5)
        )
    }
    
    private func getCardData(for index: Int) -> (question: String, answer: String) {
        let cardData = [
            (
                question: "What is the process by which plants make their own food?",
                answer: "Photosynthesis - plants use sunlight, carbon dioxide, and water to create glucose and oxygen."
            ),
            (
                question: "What is the powerhouse of the cell called?",
                answer: "Mitochondria - organelles that produce ATP energy through cellular respiration."
            ),
            (
                question: "What are the three types of chemical bonds?",
                answer: "Ionic bonds (electron transfer), covalent bonds (electron sharing), and metallic bonds."
            )
        ]
        
        return cardData[index % cardData.count]
    }
    
    private var exampleStats: some View {
        VStack(spacing: 16) {
            // Example stat
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x64FFDA).opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text("47")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: 0x64FFDA))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uploaded: Chapter 5 Biology")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Generated: 47 flashcards in 10 seconds")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            .opacity(showStats ? 1 : 0)
            .offset(x: showStats ? 0 : 30)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(2.0), value: showStats)
            
            // Benefit highlight
            Text("Study smarter, not harder with AI-powered learning")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: 0x64FFDA))
                .multilineTextAlignment(.center)
                .opacity(showStats ? 1 : 0)
                .animation(.easeInOut(duration: 0.8).delay(2.3), value: showStats)
        }
        .padding(.horizontal)
    }
    
    private func startDemoAnimation() {
        // Step 1: Upload animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.8)) {
                uploadProgress = 1.0
            }
        }
        
        // Step 2: AI Processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.6)) {
                aiProcessing = true
            }
        }
        
        // Step 3: Show flashcards
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                showFlashcards = true
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
        
        // Step 4: Show stats and start card cycling
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation {
                showStats = true
                sparkleOpacity = 0.8
            }
            startCardCycling()
        }
    }
    
    private func startCardCycling() {
        // Cycle through cards with premium animations
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                cardRotation = 15
                cardOffset = 20
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentCardIndex = (currentCardIndex + 1) % 3
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    cardRotation = 0
                    cardOffset = 0
                }
            }
        }
    }
}

#Preview {
    AIFlashcardDemo()
        .environmentObject(OnboardingViewModel())
}
