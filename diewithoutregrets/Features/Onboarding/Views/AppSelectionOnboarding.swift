import SwiftUI

struct AppSelectionOnboarding: View {
    @StateObject private var viewModel = AppSelectionViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    // Animation state variables
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showGrid = false
    @State private var showButton = false
    @State private var showInstructionSheet = false
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
                .accessibilityHidden(true) // Hide decorative background color
            
            VStack(alignment: .leading, spacing: 2) {
                // Title with animation
                Text("Study-Proof Your Phone")
                    .font(.title2)
                    .foregroundColor(.white)
                    .bold()
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.2), value: showTitle)
                    .accessibilityLabel("Study-Proof Your Phone")
                
                // Subtitle with animation
                Text("Select the apps that may hold you back from your goals.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.bottom, 25)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeInOut(duration: 1).delay(0.4), value: showSubtitle)
                    .accessibilityLabel("Select the apps that may hold you back from your goals.")
                
                // App selection grid
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(viewModel.apps) { app in
                            OnboardingAppButton(app: app) {
                                viewModel.selectApp(app)
                                if viewModel.selectedApps.contains(where: { $0.id == app.id }) {
                                    viewModel.currentInstructionApp = app
                                    showInstructionSheet = true
                                }
                            }
                            .environmentObject(viewModel)
                            .opacity(showGrid ? 1 : 0)
                            .offset(y: showGrid ? 0 : 20)
                            .animation(.easeInOut(duration: 1).delay(0.6 + 0.2), value: showGrid)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    
                    HStack {
                        Spacer()
                        Text("Can't find what you're looking for? We're adding more everyday!")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 5)
                            .opacity(showGrid ? 1 : 0)
                            .animation(.easeInOut(duration: 1).delay(0.8), value: showGrid)
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Continue button with animation
                Button(action: {
                    // Store selected apps in onboarding view model
                    onboardingViewModel.selectedApps = viewModel.selectedApps
                    onboardingViewModel.nextStep()
                }) {
                    Text("Continue")
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .cornerRadius(50)
                }
                .disabled(viewModel.selectedApps.isEmpty)
                .buttonStyle(DisabledOpacityButtonStyle())
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeInOut(duration: 1).delay(0.8), value: showButton)
                .accessibilityLabel("Continue")
                .accessibilityHint("Tap to proceed to next step")
                .accessibilityAddTraits(.isButton)
            }
            .padding()
        }
        .onAppear {
            // Trigger the animations when the view appears
            showTitle = true
            showSubtitle = true
            showGrid = true
            showButton = true
        }
        .sheet(isPresented: $showInstructionSheet) {
            if let app = viewModel.currentInstructionApp {
                RegretGuardInstructionSheet(app: app)
            }
        }
    }
}

struct OnboardingAppButton: View {
    let app: RegretApp
    let action: () -> Void
    @EnvironmentObject var viewModel: AppSelectionViewModel
    
    private var isSelected: Bool {
        viewModel.selectedApps.contains { $0.id == app.id }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Logo with white background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 45, height: 45)
                    
                    Image(app.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                
                Text(app.name)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                // Checkmark indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// ViewModel for the App Selection screen
class AppSelectionViewModel: ObservableObject {
    @Published var apps: [RegretApp] = []
    @Published var selectedApps: [RegretApp] = []
    @Published var currentInstructionApp: RegretApp?
    
    init() {
        // Initialize with default apps
        apps = [
            RegretApp(
                name: "Instagram",
                iconName: "instagram-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b02dc82b30d24fd6bf688e1bc323d392")!
            ),
            RegretApp(
                name: "YouTube",
                iconName: "youtube-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/60b648c638524630b3a733a004159a3e")!
            ),
            RegretApp(
                name: "TikTok",
                iconName: "tiktok-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/3a93b551732745cd857b4a830a0287ef")!
            ),
            RegretApp(
                name: "Facebook",
                iconName: "facebook-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/00ac004a93224ea78dd6c8627b7e2ccf")!
            ),
            RegretApp(
                name: "Snapchat",
                iconName: "snapchat-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/db9ad920d0a84d69aef10a9c9874ff42")!
            ),
            RegretApp(
                name: "Twitter (X)",
                iconName: "twitter-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/562c86386e44438580003de9c1057071")!
            ),
            RegretApp(
                name: "Reddit",
                iconName: "reddit-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b736ac777fca4ee799d4573eff769657")!
            ),
            RegretApp(
                name: "Netflix",
                iconName: "netflix-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/da0786ff8ea944aebaaaa82b0ff11dc4")!
            ),
            RegretApp(
                name: "BeReal",
                iconName: "bereal-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/f4efae1b20294e358407f29b2e624a23")!
            ),
            RegretApp(
                name: "Threads",
                iconName: "threads-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/41a6f82163e5463898af33ed3e7c5253")!
            ),
            RegretApp(
                name: "Safari",
                iconName: "safari-icon",
                shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b1074252da6148eda199e73109e7b0bc")!
            ),
        ]
    }
    
    func selectApp(_ app: RegretApp) {
        if let index = selectedApps.firstIndex(where: { $0.id == app.id }) {
            selectedApps.remove(at: index)
        } else {
            selectedApps.append(app)
        }
    }
}

// Preview provider
#Preview {
    AppSelectionOnboarding()
        .environmentObject(OnboardingViewModel())
}
