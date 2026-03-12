import SwiftUI

struct AppSelectionOnboarding: View {
    @StateObject private var viewModel = AppSelectionViewModel()
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showGrid = false
    @State private var showButton = false
    @State private var showInstructionSheet = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Which apps distract you most?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: 0x184449))
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: showTitle)
                
                Text("Select the apps you want Study Guard to protect you from.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: 0x184449).opacity(0.5))
                    .padding(.bottom, 20)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.4), value: showSubtitle)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
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
                            .offset(y: showGrid ? 0 : 15)
                            .animation(.easeOut(duration: 0.6).delay(0.5), value: showGrid)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                    
                    Text("Can't find what you're looking for? We're adding more everyday!")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .opacity(showGrid ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: showGrid)
                }
                
                Spacer()
                
                Button(action: {
                    onboardingViewModel.selectedApps = viewModel.selectedApps
                    onboardingViewModel.nextStep()
                }) {
                    Text("Lock them down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(viewModel.selectedApps.isEmpty ? Color(hex: 0x184449).opacity(0.3) : Color(hex: 0x184449))
                        .cornerRadius(50)
                }
                .disabled(viewModel.selectedApps.isEmpty)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: showButton)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
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
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0xF5F7FA))
                        .frame(width: 44, height: 44)
                    
                    Image(app.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                
                Text(app.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449))
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: 0x184449) : Color.gray.opacity(0.3))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color(hex: 0x184449).opacity(0.08) : Color(hex: 0xF5F7FA))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: 0x184449).opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

class AppSelectionViewModel: ObservableObject {
    @Published var apps: [RegretApp] = []
    @Published var selectedApps: [RegretApp] = []
    @Published var currentInstructionApp: RegretApp?
    
    init() {
        apps = [
            RegretApp(name: "Instagram", iconName: "instagram-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b02dc82b30d24fd6bf688e1bc323d392")!),
            RegretApp(name: "YouTube", iconName: "youtube-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/60b648c638524630b3a733a004159a3e")!),
            RegretApp(name: "TikTok", iconName: "tiktok-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/3a93b551732745cd857b4a830a0287ef")!),
            RegretApp(name: "Facebook", iconName: "facebook-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/00ac004a93224ea78dd6c8627b7e2ccf")!),
            RegretApp(name: "Snapchat", iconName: "snapchat-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/db9ad920d0a84d69aef10a9c9874ff42")!),
            RegretApp(name: "Twitter (X)", iconName: "twitter-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/562c86386e44438580003de9c1057071")!),
            RegretApp(name: "Reddit", iconName: "reddit-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b736ac777fca4ee799d4573eff769657")!),
            RegretApp(name: "Netflix", iconName: "netflix-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/da0786ff8ea944aebaaaa82b0ff11dc4")!),
            RegretApp(name: "BeReal", iconName: "bereal-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/f4efae1b20294e358407f29b2e624a23")!),
            RegretApp(name: "Threads", iconName: "threads-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/41a6f82163e5463898af33ed3e7c5253")!),
            RegretApp(name: "Safari", iconName: "safari-icon", shortcutLink: URL(string: "https://www.icloud.com/shortcuts/b1074252da6148eda199e73109e7b0bc")!),
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

#Preview {
    AppSelectionOnboarding()
        .environmentObject(OnboardingViewModel())
}
