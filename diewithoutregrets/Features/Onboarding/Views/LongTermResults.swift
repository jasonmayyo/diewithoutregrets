import SwiftUI

struct LongTermResultsView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showGraph = false
    @State private var showText = false
    @State private var showButton = false
    
    @State private var traditionPathProgress: CGFloat = 0
    @State private var studyGuardPathProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("The science behind it.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                .tracking(1.5)
                                .textCase(.uppercase)
                                .opacity(showTitle ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                                .padding(.top, 20)
                            
                            Text("Spaced repetition helps you remember 80% more than cramming.")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: 0x184449))
                                .lineSpacing(3)
                                .opacity(showTitle ? 1 : 0)
                                .offset(y: showTitle ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.3), value: showTitle)
                            
                            HStack(spacing: 10) {
                                Image("steel-logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 22)
                                
                                Text("Cepeda et al., 2006. Psychological Bulletin")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                            }
                            .opacity(showTitle ? 1 : 0)
                            .animation(.easeOut(duration: 0.8).delay(0.5), value: showTitle)
                            
                            Spacer().frame(height: 20)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: 0xF5F7FA))
                                    .opacity(showTitle ? 1 : 0)
                                    .animation(.easeOut(duration: 0.8).delay(0.4), value: showTitle)
                                
                                VStack(alignment: .leading, spacing: 20) {
                                    Text("Flashcards studied over time")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(hex: 0x184449))
                                        .padding(.top, 20)
                                        .padding(.leading, 20)
                                        .opacity(showText ? 1 : 0)
                                        .offset(y: showText ? 0 : 10)
                                        .animation(.easeOut(duration: 0.8).delay(0.8), value: showText)
                                    
                                    GraphView(
                                        traditionalPathProgress: $traditionPathProgress,
                                        studyGuardPathProgress: $studyGuardPathProgress
                                    )
                                    .frame(height: min(200, geometry.size.height * 0.25))
                                    .padding(.horizontal, 20)
                                    .opacity(showGraph ? 1 : 0)
                                    .animation(.easeOut(duration: 0.8).delay(0.4), value: showGraph)
                                    
                                    HStack {
                                        Text("Month 1")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                        Spacer()
                                        Text("Month 6")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                    }
                                    .padding(.horizontal)
                                    .opacity(showText ? 1 : 0)
                                    .animation(.easeOut(duration: 0.8).delay(0.8), value: showText)
                                    
                                    Text("Study Guard uses this science automatically.\nEvery flashcard is timed for maximum retention.")
                                        .font(.system(size: 15, weight: .medium))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color(hex: 0x184449).opacity(0.45))
                                        .frame(maxWidth: .infinity)
                                        .lineSpacing(2)
                                        .padding(.bottom, 20)
                                        .opacity(showText ? 1 : 0)
                                        .animation(.easeOut(duration: 0.8).delay(1.0), value: showText)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
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
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.0), value: showButton)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                .frame(width: min(geometry.size.width, 500))
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showTitle = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showGraph = true
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) { traditionPathProgress = 1.0 }
                withAnimation(.easeInOut(duration: 2.0).delay(0.7)) { studyGuardPathProgress = 1.0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showText = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showButton = true }
        }
    }
}

struct GraphView: View {
    @Binding var traditionalPathProgress: CGFloat
    @Binding var studyGuardPathProgress: CGFloat
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Divider().background(Color(hex: 0x184449).opacity(0.1))
                Spacer()
                Divider().background(Color(hex: 0x184449).opacity(0.1))
                Spacer()
                Divider().background(Color(hex: 0x184449).opacity(0.1))
            }
            
            GeometryReader { geometry in
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
                .stroke(Color(hex: 0x184449), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
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
                .stroke(Color(hex: 0x184449).opacity(0.25), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                
                Circle()
                    .fill(Color(hex: 0x184449))
                    .frame(width: 10, height: 10)
                    .position(x: 0, y: geometry.size.height * 0.3)
                
                Circle()
                    .fill(Color(hex: 0x184449))
                    .frame(width: 10, height: 10)
                    .position(x: geometry.size.width, y: geometry.size.height * 0.9)
                    .opacity(studyGuardPathProgress == 1.0 ? 1 : 0)
                    .animation(.easeIn(duration: 0.3), value: studyGuardPathProgress)
                
                HStack {
                    VStack(alignment: .leading) {
                        Spacer()
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: 0x184449)).frame(width: 8, height: 8)
                                Text("Study Guard")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: 0x184449))
                            }
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: 0x184449).opacity(0.25)).frame(width: 8, height: 8)
                                Text("Traditional study")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                            }
                        }
                        .padding(.bottom, 5)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

#Preview {
    LongTermResultsView()
        .environmentObject(OnboardingViewModel())
}
