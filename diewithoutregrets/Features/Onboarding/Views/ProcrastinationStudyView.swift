import SwiftUI

struct ProcrastinationStudyView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showLabel = false
    @State private var showHeadline = false
    @State private var showSource = false
    @State private var showReframe1 = false
    @State private var showReframe2 = false
    @State private var showButton = false
    @State private var showAnimation = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    DotLottieView(fileName: "sademotion", speed: 0.8)
                        .frame(height: min(180, geometry.size.height * 0.22))
                        .frame(maxWidth: .infinity)
                        .opacity(showAnimation ? 1 : 0)
                        .scaleEffect(showAnimation ? 1 : 0.85)
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: showAnimation)
                        .padding(.top, 10)
                    
                    Spacer()
                        .frame(height: 24)
                    
                    Text("Here's what the science says.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .opacity(showLabel ? 1 : 0)
                        .offset(y: showLabel ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: showLabel)
                        .padding(.bottom, 16)
                    
                    Text("86% of students say procrastination negatively affects their grades.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(4)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.6), value: showHeadline)
                        .padding(.bottom, 12)
                    
                    HStack(spacing: 10) {
                        Image("steel-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 22)
                        
                        Text("Steel, 2007. Psychological Bulletin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                    }
                    .opacity(showSource ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(0.9), value: showSource)
                    .padding(.bottom, 32)
                    
                    Text("But it's not a willpower problem.\nIt's a system problem.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.8))
                        .lineSpacing(4)
                        .opacity(showReframe1 ? 1 : 0)
                        .offset(y: showReframe1 ? 0 : 15)
                        .animation(.easeOut(duration: 0.8).delay(1.5), value: showReframe1)
                        .padding(.bottom, 12)
                    
                    Text("You don't need more discipline.\nYou need a better system.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .lineSpacing(3)
                        .opacity(showReframe2 ? 1 : 0)
                        .offset(y: showReframe2 ? 0 : 15)
                        .animation(.easeOut(duration: 0.8).delay(2.0), value: showReframe2)
                    
                    Spacer()
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Show me the system")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.5 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(2.5), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showLabel = true
            showHeadline = true
            showSource = true
            showReframe1 = true
            showReframe2 = true
            showButton = true
            showAnimation = true
        }
    }
}

#Preview {
    ProcrastinationStudyView()
        .environmentObject(OnboardingViewModel())
}
