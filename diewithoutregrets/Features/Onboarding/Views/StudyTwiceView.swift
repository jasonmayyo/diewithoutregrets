import SwiftUI

struct StudyTwiceView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // Animation state variables
    @State private var showTitle = false
    @State private var showCard = false
    @State private var showTagline = false
    @State private var showButton = false
    
    // Animation for comparison bars
    @State private var withoutStudyGuardBarHeight: CGFloat = 0
    @State private var withStudyGuardBarHeight: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: 0x184449)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                // Main content container
                VStack {
                    // Scrollable content area
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Title with animation
                            Text("Study twice as much with Study Guard vs on your own")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(showTitle ? 1 : 0)
                                .offset(y: showTitle ? 0 : 20)
                                .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                                .accessibilityLabel("Study twice as much with Study Guard vs on your own")
                                .padding(.top, 20)
                            
                            Spacer()
                                .frame(height: 30)
                            
                            // Comparison Card Container
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: 0xF9F9F9))
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                VStack(spacing: 25) {
                                    // Comparison bars
                                    HStack(alignment: .bottom, spacing: 30) {
                                        // Without Study Guard
                                        VStack(spacing: 15) {
                                            Text("Without\nStudy Guard")
                                                .font(.system(size: 16, weight: .medium))
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.black)
                                            
                                            ZStack(alignment: .bottom) {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.15))
                                                    .frame(width: 120, height: 120)
                                                
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 120, height: withoutStudyGuardBarHeight)
                                                    .overlay(
                                                        Text("20%")
                                                            .font(.system(size: 18, weight: .bold))
                                                            .foregroundColor(.black)
                                                            .opacity(withoutStudyGuardBarHeight > 20 ? 1 : 0)
                                                            .animation(.easeInOut(duration: 0.5), value: withoutStudyGuardBarHeight)
                                                    )
                                            }
                                        }
                                        
                                        // With Study Guard
                                        VStack(spacing: 15) {
                                            Text("With\nStudy Guard")
                                                .font(.system(size: 16, weight: .medium))
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.black)
                                            
                                            ZStack(alignment: .bottom) {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.15))
                                                    .frame(width: 120, height: 120)
                                                
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(hex: 0x184449))
                                                    .frame(width: 120, height: withStudyGuardBarHeight)
                                                    .overlay(
                                                        Text("2X")
                                                            .font(.system(size: 20, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .opacity(withStudyGuardBarHeight > 50 ? 1 : 0)
                                                            .animation(.easeInOut(duration: 0.5), value: withStudyGuardBarHeight)
                                                    )
                                            }
                                        }
                                    }
                                    .padding(.top, 20)
                                    
                                    // Tagline text
                                    Text("Study Guard makes it easy and holds\nyou accountable.")
                                        .font(.system(size: 16, weight: .medium))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.bottom, 20)
                                        .opacity(showTagline ? 1 : 0)
                                        .offset(y: showTagline ? 0 : 10)
                                        .animation(.easeInOut(duration: 0.8).delay(1.2), value: showTagline)
                                }
                                .padding(.horizontal)
                            }
                            .opacity(showCard ? 1 : 0)
                            .offset(y: showCard ? 0 : 20)
                            .animation(.easeInOut(duration: 0.8).delay(0.4), value: showCard)
                            .accessibilityLabel("Comparison showing Study Guard helps you study twice as much")
                            
                            // Add extra space at the bottom to ensure scrollability
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Fixed button container at the bottom
                    VStack {
                        Spacer()
                        
                        // Continue button with animation
                        Button(action: {
                            onboardingViewModel.nextStep()
                        }) {
                            Text("Continue")
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
                        .animation(.easeInOut(duration: 1).delay(1.0), value: showButton)
                        .accessibilityLabel("Continue")
                        .accessibilityHint("Tap to proceed to the next step")
                        .padding(.horizontal)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 20 : 30)
                    }
                    .background(
                        // Gradient background for button area
                        LinearGradient(
                            gradient: Gradient(
                                colors: [
                                    Color(hex: 0x184449).opacity(0.0),
                                    Color(hex: 0x184449).opacity(1.0)
                                ]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .offset(y: -50)
                        .opacity(showButton ? 1 : 0)
                    )
                }
                .frame(width: min(geometry.size.width, 500)) // Max width container for iPad
                .frame(maxWidth: .infinity) // Center on screen
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showTitle = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showCard = true
                
                // Animate the bars with delay
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                    withoutStudyGuardBarHeight = 40  // 20% of max height
                }
                
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                    withStudyGuardBarHeight = 100  // 2X the without bar
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showTagline = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showButton = true
            }
        }
    }
}

struct StudyTwiceView_Previews: PreviewProvider {
    static var previews: some View {
        StudyTwiceView()
            .environmentObject(OnboardingViewModel())
    }
}
