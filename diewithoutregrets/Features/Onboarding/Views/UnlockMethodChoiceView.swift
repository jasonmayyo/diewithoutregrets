import SwiftUI

struct UnlockMethodChoiceView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    @AppStorage("unlockMethod") private var unlockMethod: String = "flashcards"
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showCards = false
    @State private var showButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("How do you want to earn your scroll time?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .lineSpacing(3)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                    
                    Text("You can always change this later.")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .padding(.top, 6)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.4), value: showSubtitle)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        UnlockMethodCard(
                            icon: "rectangle.stack.fill",
                            title: "Flashcards",
                            subtitle: "Answer a few quick questions from your own study material before you can scroll.",
                            isSelected: unlockMethod == "flashcards"
                        ) {
                            unlockMethod = "flashcards"
                            onboardingViewModel.triggerHapticFeedback()
                        }
                        
                        UnlockMethodCard(
                            icon: "eye.fill",
                            title: "True Focus",
                            subtitle: "Prove you're studying with camera-verified focus sessions to earn your break.",
                            isSelected: unlockMethod == "trueFocus"
                        ) {
                            unlockMethod = "trueFocus"
                            onboardingViewModel.triggerHapticFeedback()
                        }
                    }
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: showCards)
                    
                    Spacer()
                    
                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
                        onboardingViewModel.nextStep()
                    }) {
                        Text("Continue")
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
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showTitle = true
            showSubtitle = true
            showCards = true
            showButton = true
        }
    }
}

struct UnlockMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: 0x184449).opacity(0.12) : Color(hex: 0xF5F7FA))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? Color(hex: 0x184449) : Color(hex: 0x184449).opacity(0.4))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: 0x184449))
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(hex: 0x184449) : Color.gray.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: 0x184449).opacity(0.06) : Color(hex: 0xF5F7FA))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: 0x184449).opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    UnlockMethodChoiceView()
        .environmentObject(OnboardingViewModel())
}
