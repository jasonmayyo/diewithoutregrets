import SwiftUI

struct BreakdownView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showTabView = false
    @State private var showQuestion = false
    @State private var showButton = false
    
    private var lifetimeYears: Int {
        calculateLifetimeYears()
    }
    
    private var annualDays: Int {
        calculateAnnualDays()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Here's the truth, \(onboardingViewModel.userName).")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                    Text("Based on what you told us...")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .padding(.bottom, 25)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.4), value: showSubtitle)
                    
                    Spacer()
                    
                    TabView {
                        VStack(spacing: 8) {
                            Text("\(lifetimeYears.formattedWithCommas)")
                                .font(.system(size: 80, weight: .black))
                                .foregroundColor(Color(hex: 0x184449))
                            
                            Text("YEARS")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.35))
                                .tracking(6)
                            
                            Text("on your phone. In your lifetime.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                .padding(.top, 8)
                        }
                        
                        VStack(spacing: 8) {
                            Text("\(annualDays.formattedWithCommas)")
                                .font(.system(size: 80, weight: .black))
                                .foregroundColor(Color(hex: 0x184449))
                            
                            Text("DAYS")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.35))
                                .tracking(6)
                            
                            Text("this year alone.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                .padding(.top, 8)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle())
                    .opacity(showTabView ? 1 : 0)
                    .offset(y: showTabView ? 0 : 20)
                    .animation(.easeOut(duration: 1.0).delay(0.6), value: showTabView)
                    
                    Spacer()
                    
                    Text("What could you do with that time?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.35))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(showQuestion ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(1.4), value: showQuestion)
                        .padding(.bottom, 16)
                    
                    Button(action: {
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.5 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(1.0), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showTabView = true
            showQuestion = true
            showButton = true
        }
    }
    
    private func calculateLifetimeYears() -> Int {
        let lifeExpectancy = 90.0
        let currentAge = parseAge(onboardingViewModel.selectedAge)
        let remainingYears = max(lifeExpectancy - currentAge, 0)
        let dailyHours = parseScreenTime(onboardingViewModel.screenTime)
        
        let totalHours = dailyHours * 365 * remainingYears
        let totalYears = totalHours / (24 * 365)
        return Int(totalYears.rounded())
    }
    
    private func calculateAnnualDays() -> Int {
        let dailyHours = parseScreenTime(onboardingViewModel.screenTime)
        let annualHours = dailyHours * 365
        return Int((annualHours / 24).rounded())
    }
    
    private func parseAge(_ ageRange: String) -> Double {
        let components = ageRange.components(separatedBy: "-")
            .compactMap { Double($0.filter { $0.isNumber }) }
        guard components.count == 2 else { return 30 }
        return (components[0] + components[1]) / 2
    }
    
    private func parseScreenTime(_ screenTime: String) -> Double {
        let components = screenTime.components(separatedBy: "-")
            .compactMap { Double($0.filter { $0.isNumber }) }
        guard components.count == 2 else { return 5 }
        return (components[0] + components[1]) / 2
    }
}

extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

#Preview {
    BreakdownView()
        .environmentObject(OnboardingViewModel())
}
