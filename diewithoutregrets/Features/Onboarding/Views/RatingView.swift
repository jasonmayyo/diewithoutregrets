import SwiftUI
import StoreKit

struct RatingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTagline = false
    @State private var showUserImages = false
    @State private var showTestimonials = false
    @State private var showButton = false
    
    @Environment(\.requestReview) private var requestReview
    
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
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {
                        Text("Loved by 45,000+ students.")
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(hex: 0x184449))
                            .padding(.top, 20)
                            .opacity(showTagline ? 1 : 0)
                            .offset(y: showTagline ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(0.3), value: showTagline)
                        
                        HStack(spacing: -15) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color(hex: 0xF5F7FA))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image("char\(index + 1)")
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(Circle())
                                    )
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: 2)
                                    )
                                    .zIndex(Double(3 - index))
                            }
                        }
                        .opacity(showTagline ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: showTagline)
                        
                        Text("Students report studying 2x more with Study Guard")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                            .multilineTextAlignment(.center)
                            .opacity(showUserImages ? 1 : 0)
                            .animation(.easeOut(duration: 0.8).delay(0.7), value: showUserImages)
                        
                        VStack(spacing: 12) {
                            ForEach(testimonials) { testimonial in
                                LightTestimonialCard(testimonial: testimonial)
                            }
                        }
                        .padding(.top, 4)
                        .opacity(showTestimonials ? 1 : 0)
                        .offset(y: showTestimonials ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.9), value: showTestimonials)
                    }
                    .padding(.horizontal, 24)
                }
                
                Button(action: {
                    requestReview()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        onboardingViewModel.nextStep()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: 0x184449))
                        .cornerRadius(50)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(1.1), value: showButton)
            }
        }
        .onAppear {
            showTagline = true
            showUserImages = true
            showTestimonials = true
            showButton = true
        }
    }
}

struct Testimonial: Identifiable {
    let id = UUID()
    let name: String
    let image: String
    let stars: Int
    let text: String
}

struct LightTestimonialCard: View {
    let testimonial: Testimonial
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(hex: 0x184449).opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(testimonial.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449))
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: testimonial.stars >= star ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Text(testimonial.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.65))
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: 0xF5F7FA))
        )
    }
}

#Preview {
    RatingView()
        .environmentObject(OnboardingViewModel())
}
