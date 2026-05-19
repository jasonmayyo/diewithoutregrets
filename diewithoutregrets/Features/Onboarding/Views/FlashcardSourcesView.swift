import SwiftUI

struct FlashcardSourcesView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel

    @State private var showAnimation = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showCards = false
    @State private var showButton = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    DotLottieView(fileName: "scan-document", speed: 0.8)
                        .frame(height: min(180, geometry.size.height * 0.22))
                        .frame(maxWidth: .infinity)
                        .opacity(showAnimation ? 1 : 0)
                        .scaleEffect(showAnimation ? 1 : 0.85)
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: showAnimation)
                        .padding(.top, 10)

                    Spacer()
                        .frame(height: 20)

                    Text("Create flashcards\nin seconds.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: 0x184449))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: showTitle)

                    Text("Auto-generate or import, your choice.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                        .padding(.top, 8)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.5), value: showSubtitle)

                    Spacer()

                    VStack(spacing: 16) {
                        // Auto-generate section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("AUTO-GENERATE")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: 0x184449).opacity(0.35))

                            SourceRow(
                                icon: "doc.text.fill",
                                isSystemIcon: true,
                                title: "Paste any text",
                                subtitle: "Notes, articles, textbooks"
                            )

                            SourceRow(
                                icon: "youtube-icon",
                                isSystemIcon: false,
                                title: "YouTube videos",
                                subtitle: "Paste a link, get flashcards"
                            )
                        }
                        .padding(20)
                        .background(Color(hex: 0xF5F7FA))
                        .cornerRadius(16)

                        // Import section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("IMPORT")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(Color(hex: 0x184449).opacity(0.35))

                            SourceRow(
                                icon: "quizlet",
                                isSystemIcon: false,
                                title: "Quizlet",
                                subtitle: "Bring your existing decks"
                            )
                        }
                        .padding(20)
                        .background(Color(hex: 0xF5F7FA))
                        .cornerRadius(16)
                    }
                    .opacity(showCards ? 1 : 0)
                    .offset(y: showCards ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.7), value: showCards)

                    Spacer()

                    Button(action: {
                        onboardingViewModel.triggerHapticFeedback()
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
                    .animation(.easeOut(duration: 0.8).delay(1.1), value: showButton)
                }
                .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? geometry.size.width * 0.1 : 24)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            showAnimation = true
            showTitle = true
            showSubtitle = true
            showCards = true
            showButton = true
        }
    }
}

struct SourceRow: View {
    let icon: String
    let isSystemIcon: Bool
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            if isSystemIcon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: 0x184449))
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .cornerRadius(10)
            } else {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: 0x184449))

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.5))
            }

            Spacer()
        }
    }
}

#Preview {
    FlashcardSourcesView()
        .environmentObject(OnboardingViewModel())
}
