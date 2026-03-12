import SwiftUI

struct TheFeelingView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showOptions = false
    @State private var showButton = false
    
    private let feelings = [
        ("Stressed before exams", "bolt.heart.fill"),
        ("Guilty after hours of scrolling", "hand.raised.fill"),
        ("Falling behind on coursework", "clock.badge.exclamationmark.fill"),
        ("Overwhelmed by everything you need to learn", "brain.head.profile"),
        ("Anxious about your future", "exclamationmark.triangle.fill"),
        ("Stuck in a cycle you can't break", "arrow.triangle.2.circlepath")
    ]
    
    private var canContinue: Bool {
        !onboardingViewModel.selectedFeelings.isEmpty
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Be honest.\nHow often do you feel like this?")
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
                            ForEach(Array(feelings.enumerated()), id: \.element.0) { index, feeling in
                                FeelingSelectionCard(
                                    text: feeling.0,
                                    icon: feeling.1,
                                    isSelected: onboardingViewModel.selectedFeelings.contains(feeling.0),
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if onboardingViewModel.selectedFeelings.contains(feeling.0) {
                                                onboardingViewModel.selectedFeelings.remove(feeling.0)
                                            } else {
                                                onboardingViewModel.selectedFeelings.insert(feeling.0)
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
                        Text("That's me")
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

struct FeelingSelectionCard: View {
    let text: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? Color(hex: 0x184449) : Color(hex: 0x184449).opacity(0.4))
                    .frame(width: 24)
                
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449))
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: 0x184449) : Color.gray.opacity(0.3))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(hex: 0x184449).opacity(0.08) : Color(hex: 0xF5F7FA))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: 0x184449).opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TheFeelingView()
        .environmentObject(OnboardingViewModel())
}
