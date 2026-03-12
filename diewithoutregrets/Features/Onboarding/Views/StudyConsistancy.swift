import SwiftUI

struct StudyConsistancy: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showAnimation = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading) {
                    Text("Imagine being as consistent with studying as you are with scrolling")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                    Spacer()
                    
                    VStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("If you scroll 20 times a day.")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.7))
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(0.6), value: showAnimation)

                            Text("And we help you study for just 5 minutes before each scroll")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 16))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(0.8), value: showAnimation)
                        }
                        .padding(.horizontal)

                        ConsistencyGraph(showAnimation: $showAnimation)
                        
                        VStack(spacing: 8) {
                            Text("That's 11 extra hours of study per week.")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 26 : 20, weight: .bold))
                                .foregroundColor(Color(hex: 0x184449))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(2.0), value: showAnimation)
                            
                            Text("Without changing your routine.")
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 18 : 14, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(showAnimation ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(2.2), value: showAnimation)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(showAnimation ? 1 : 0)
                    .offset(y: showAnimation ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: showAnimation)
                    
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Show me how")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(2.0), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showAnimation = true
            showButton = true
        }
    }
}

struct ConsistencyGraph: View {
    @Binding var showAnimation: Bool
    @State private var animatedValue: CGFloat = 0
    @State private var showNumber: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(Color(hex: 0x184449).opacity(0.08), lineWidth: 8)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0, to: animatedValue)
                    .stroke(
                        Color(hex: 0x184449),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("11")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .opacity(showNumber ? 1 : 0)
                        .scaleEffect(showNumber ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.2), value: showNumber)
                    
                    Text("hours/week")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .opacity(showNumber ? 1 : 0)
                        .offset(y: showNumber ? 0 : 10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.4), value: showNumber)
                }
            }
            
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("20")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                    Text("scrolls/day")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.45))
                }
                .opacity(showNumber ? 1 : 0)
                .offset(y: showNumber ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.6), value: showNumber)
                
                Text("×")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.3))
                    .opacity(showNumber ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(1.8), value: showNumber)
                
                VStack(spacing: 4) {
                    Text("5")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                    Text("min/study")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.45))
                }
                .opacity(showNumber ? 1 : 0)
                .offset(y: showNumber ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(2.0), value: showNumber)
            }
        }
        .onAppear {
            if showAnimation {
                withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
                    animatedValue = 0.65
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
