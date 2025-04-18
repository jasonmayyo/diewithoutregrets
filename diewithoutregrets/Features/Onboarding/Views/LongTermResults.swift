import SwiftUI

struct LongTermResultsView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // Animation state variables
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showGraph = false
    @State private var showText = false
    @State private var showButton = false
    
    // Animation for graph paths
    @State private var traditionPathProgress: CGFloat = 0
    @State private var studyGuardPathProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: 0x184449)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                // Outer VStack to control container width on iPad
                VStack {
                    // Main content container with scrolling capability
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Title with animation
                            Text("Study Guard creates long term results")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(showTitle ? 1 : 0)
                                .offset(y: showTitle ? 0 : 20)
                                .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                                .accessibilityLabel("Study Guard creates long-term results")
                                .padding(.top, 20)
                            
                            Spacer()
                                .frame(height: 30)
                            
                            // Graph Container
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: 0xF9F9F9))
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                    .opacity(showTitle ? 1 : 0)
                                    .offset(y: showTitle ? 0 : 20)
                                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                                
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Flashcards studied over time")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.top, 20)
                                        .padding(.leading, 20)
                                        .opacity(showText ? 1 : 0)
                                        .offset(y: showText ? 0 : 10)
                                        .animation(.easeInOut(duration: 1).delay(0.8), value: showText)
                                    
                                    // Graph component
                                    GraphView(
                                        traditionalPathProgress: $traditionPathProgress,
                                        studyGuardPathProgress: $studyGuardPathProgress
                                    )
                                    .frame(height: min(200, geometry.size.height * 0.25))
                                    .padding(.horizontal, 20)
                                    .opacity(showGraph ? 1 : 0)
                                    .animation(.easeInOut(duration: 1).delay(0.4), value: showGraph)
                                    
                                    HStack {
                                        Text("Month 1")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                            .opacity(showText ? 1 : 0)
                                            .offset(y: showText ? 0 : 10)
                                            .animation(.easeInOut(duration: 1).delay(0.8), value: showText)
                                        Spacer()
                                        Text("Month 6")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                            .opacity(showText ? 1 : 0)
                                            .offset(y: showText ? 0 : 10)
                                            .animation(.easeInOut(duration: 1).delay(0.8), value: showText)
                                    }.padding(.horizontal)
                                    
                                    // Legend & stats text
                                    Text("80% of Study Guard users maintain their\nstudy habits even 6 months later")
                                        .font(.system(size: 16, weight: .medium))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.bottom, 20)
                                        .opacity(showText ? 1 : 0)
                                        .offset(y: showText ? 0 : 10)
                                        .animation(.easeInOut(duration: 1).delay(0.8), value: showText)
                                }
                            }
                            
                            // Add extra space at the bottom to ensure scrollability
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Fixed button container at the bottom
                    VStack {
                        Spacer()
                        
                        // Continue button with animation - now in a fixed position
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
                showGraph = true
                
                // Animate graph paths with a delay
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) {
                    traditionPathProgress = 1.0
                }
                
                withAnimation(.easeInOut(duration: 2.0).delay(0.7)) {
                    studyGuardPathProgress = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                showText = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showButton = true
            }
        }
    }
}

struct GraphView: View {
    @Binding var traditionalPathProgress: CGFloat
    @Binding var studyGuardPathProgress: CGFloat
    
    var body: some View {
        ZStack {
            // Background grid lines
            VStack(spacing: 0) {
                Divider()
                    .background(Color.gray.opacity(0.2))
                Spacer()
                Divider()
                    .background(Color.gray.opacity(0.2))
                Spacer()
                Divider()
                    .background(Color.gray.opacity(0.2))
            }
            
            GeometryReader { geometry in
                // Traditional diet path (green)
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    path.move(to: CGPoint(x: 0, y: height * 0.3))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.1),
                        control1: CGPoint(x: width * 0.3, y: height * 0.7),
                        control2: CGPoint(x: width * 0.7, y: height * 0.1)
                    )
                }
                .trim(from: 0, to: traditionalPathProgress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Study Guard path (black)
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    path.move(to: CGPoint(x: 0, y: height * 0.3))
                    path.addCurve(
                        to: CGPoint(x: width, y: height * 0.9),
                        control1: CGPoint(x: width * 0.4, y: height * 0.4),
                        control2: CGPoint(x: width * 0.6, y: height * 0.9)
                    )
                }
                .trim(from: 0, to: studyGuardPathProgress)
                .stroke(Color.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                // Start circle
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: geometry.size.height * 0.3)
                
                // End circle for Study Guard path
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                    .position(x: geometry.size.width, y: geometry.size.height * 0.9)
                    .opacity(studyGuardPathProgress == 1.0 ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: studyGuardPathProgress)
                
                // Labels
                HStack {
                    VStack(alignment: .leading) {
                        Spacer()
                        VStack {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.green)
                                Text("Study Guard")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            Text("Traditional study")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .padding(.bottom, 5)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 5)
            }
        }
    }
}

struct LongTermResultsView_Previews: PreviewProvider {
    static var previews: some View {
        LongTermResultsView()
            .environmentObject(OnboardingViewModel())
    }
}
