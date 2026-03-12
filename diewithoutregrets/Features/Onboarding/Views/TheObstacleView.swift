import SwiftUI

struct TheObstacleView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showOptions = false
    @State private var showButton = false
    
    private let obstacles = [
        ("I procrastinate until the last minute", "clock.arrow.circlepath"),
        ("My phone is my biggest distraction", "iphone.radiowaves.left.and.right"),
        ("I can't stay consistent with studying", "chart.line.downtrend.xyaxis"),
        ("I don't know how to study effectively", "questionmark.folder.fill"),
        ("I lose motivation quickly", "battery.25percent"),
        ("Test anxiety freezes me", "snowflake")
    ]
    
    private var canContinue: Bool {
        !onboardingViewModel.selectedObstacles.isEmpty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("What keeps getting\nin your way?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(2)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                    Text("Select all that apply")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .padding(.bottom, 12)
                        .opacity(showTitle ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.4), value: showTitle)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(Array(obstacles.enumerated()), id: \.element.0) { index, obstacle in
                                FeelingSelectionCard(
                                    text: obstacle.0,
                                    icon: obstacle.1,
                                    isSelected: onboardingViewModel.selectedObstacles.contains(obstacle.0),
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if onboardingViewModel.selectedObstacles.contains(obstacle.0) {
                                                onboardingViewModel.selectedObstacles.remove(obstacle.0)
                                            } else {
                                                onboardingViewModel.selectedObstacles.insert(obstacle.0)
                                            }
                                        }
                                    }
                                )
                                .opacity(showOptions ? 1 : 0)
                                .offset(y: showOptions ? 0 : 15)
                                .animation(.easeOut(duration: 0.6).delay(0.5 + Double(index) * 0.08), value: showOptions)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: 55)
                            .background(canContinue ? Color(hex: 0x184449) : Color(hex: 0x184449).opacity(0.3))
                            .cornerRadius(50)
                    }
                    .disabled(!canContinue)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showOptions = true
            showButton = true
        }
    }
}

#Preview {
    TheObstacleView()
        .environmentObject(OnboardingViewModel())
}
