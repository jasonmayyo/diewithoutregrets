import SwiftUI

struct FirstDeckView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @FocusState private var isDeckNameFocused: Bool
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showField = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("What do you need to study right now?")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: 0x184449))
                                .opacity(showTitle ? 1 : 0)
                                .offset(y: showTitle ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                            
                            Text("We'll help you learn and memorise the things you keep putting off.")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                                .opacity(showSubtitle ? 1 : 0)
                                .offset(y: showSubtitle ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.4), value: showSubtitle)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            onboardingViewModel.triggerHapticFeedback()
                            onboardingViewModel.skipToCompletion()
                        }) {
                            Text("Skip")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(hex: 0x184449).opacity(0.4))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(hex: 0x184449).opacity(0.06))
                                )
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Give your deck a name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: 0x184449))
                        
                        TextField("My First Deck", text: $onboardingViewModel.newDeckName)
                            .focused($isDeckNameFocused)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: 0x184449))
                            .padding()
                            .background(Color(hex: 0xF5F7FA))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: 0x184449).opacity(0.15), lineWidth: 1.5)
                            )
                    }
                    .opacity(showField ? 1 : 0)
                    .offset(y: showField ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: showField)
                    
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Create deck")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.6 : .infinity)
                            .frame(height: 55)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(50)
                    }
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showField = true
            showButton = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isDeckNameFocused = true
            }
        }
    }
}

#Preview {
    FirstDeckView()
        .environmentObject(OnboardingViewModel())
}
