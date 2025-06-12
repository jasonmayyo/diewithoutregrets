//
//  RatingView.swift
//  studyguard
//
//  Created on 2025/04/10.
//

import SwiftUI
import StoreKit

import SwiftUI
import StoreKit

struct RatingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // State variables for animations
    @State private var showTitle = false
    @State private var showStars = false
    @State private var showTagline = false
    @State private var showUserImages = false
    @State private var showTestimonials = false
    @State private var showButton = false
    
    // State for star rating
    @State private var rating: Int = 0
    @State private var hoveringRating: Int? = nil
    
    @Environment(\.requestReview) private var requestReview
    
    // Mock testimonial data
    let testimonials = [
        Testimonial(
            name: "Sarah M.",
            image: "profile1",
            stars: 5,
            text: "\"I used to spend 6+ hours on TikTok daily and my grades were terrible. Now I can't scroll without answering flashcards first. Got a B+ on my calculus exam!\""
        ),
        Testimonial(
            name: "Alex R.",
            image: "profile1",
            stars: 5,
            text: "\"Finally something that actually stops me from mindlessly scrolling Instagram. The AI flashcards from my lecture notes are surprisingly good. Saved my chemistry grade.\""
        ),
        Testimonial(
            name: "Maya K.",
            image: "profile2",
            stars: 5,
            text: "\"I was failing organic chemistry and spending all day on my phone. This app literally forces me to study before I can scroll. Went from a D to a B in 6 weeks.\""
        )
    ]
    
    var body: some View {
        ZStack {
            // Background color to match your theme
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            VStack(spacing: 0) {
                
                ScrollView {
                    VStack(alignment: .center, spacing: 25) {
                        // Tagline
                        Text("Study Guard was made for\npeople like you")
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(.vertical, 20)
                            .opacity(showTagline ? 1 : 0)
                            .offset(y: showTagline ? 0 : 20)
                            .animation(.easeInOut(duration: 0.8).delay(0.6), value: showTagline)
                            .accessibilityLabel("Study Guard was made for people like you")
                        
                        // User profile images
                        HStack(spacing: -15) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        // Display different character images based on index
                                        Image("char\(index + 1)") // Assumes images are named "char1", "char2", "char3"
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(Circle())
                                    )
                                    .background(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .zIndex(Double(3 - index))
                            }
                        }
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 20)
                        .animation(.easeInOut(duration: 0.8).delay(0.6), value: showTagline)
                        
                        // User count
                        Text("Loved by over 5000+ students")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .opacity(showUserImages ? 1 : 0)
                            .offset(y: showUserImages ? 0 : 20)
                            .animation(.easeInOut(duration: 0.8).delay(0.8), value: showUserImages)
                            .accessibilityLabel("Loved by over 5000+ students")
                        
                        // Testimonials
                        VStack(spacing: 15) {
                            ForEach(testimonials) { testimonial in
                                TestimonialView(testimonial: testimonial)
                            }
                        }
                        .padding(.top, 5)
                        .opacity(showTestimonials ? 1 : 0)
                        .offset(y: showTestimonials ? 0 : 20)
                        .animation(.easeInOut(duration: 0.8).delay(1.0), value: showTestimonials)
                        .accessibilityLabel("User testimonials")
                    }
                    .padding(.horizontal)
                }
                
                // Continue button
                Button(action: {
                    // Request review when button is pressed
                    requestReview()
                    
                    // Since we can't detect when the review prompt is dismissed,
                    // we'll use a reasonable delay before continuing to the next step
                    // This gives users time to interact with the review prompt
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onboardingViewModel.nextStep()
                    }
                }) {
                    Text("Continue")
                        .foregroundColor(Color(hex: 0x184449))
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .cornerRadius(50)
                }
                .padding()
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 0.8).delay(1.2), value: showButton)
                .accessibilityLabel("Continue")
                .accessibilityHint("Tap to rate the app and continue")
            }
        }
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showTitle = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showStars = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTagline = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showUserImages = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                showTestimonials = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                showButton = true
            }
        }
    }
}

// Testimonial model
struct Testimonial: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let stars: Int
    let text: String
}

// Testimonial view component
struct TestimonialView: View {
    let testimonial: Testimonial
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile image
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Name and stars
                HStack {
                    Text(testimonial.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Star rating
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: testimonial.stars >= star ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                // Testimonial text
                Text(testimonial.text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.2))
        )
    }
}


struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        RatingView()
            .environmentObject(OnboardingViewModel())
    }
}
