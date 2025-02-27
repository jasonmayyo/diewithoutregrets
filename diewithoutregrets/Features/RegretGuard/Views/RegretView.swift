//
//  RegretView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretView: View {
    @EnvironmentObject var regretStore: RegretStore
    @StateObject private var viewModel: RegretViewModel
    
    init() {
        // Use temporary store for preview
        let previewStore = RegretStore()
        previewStore.regrets = Regret.regrets
        _viewModel = StateObject(wrappedValue: RegretViewModel(regretStore: previewStore))
    }
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .center) {
                Text("Regret Guard")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .accessibilityHidden(true) // Hide decorative title
                
                Spacer()
                
                if !viewModel.showRegret && !viewModel.showFinalMessage {
                    Text("You told us your biggest regret would be...")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding(.horizontal, 30)
                        .phaseAnimator([0.7, 1, 4]) { content, phase in
                            content
                                .scaleEffect(phase)
                                .opacity(phase == 1 ? 1 : 0)
                        } animation: { phase in
                                .easeIn(duration: 4)
                        }
                        .accessibilityLabel("Prompt message")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                withAnimation {
                                    viewModel.showRegret = true
                                    viewModel.updateRegretMessage()
                                }
                            }
                        }
                } else if viewModel.showRegret && !viewModel.showFinalMessage {
                    Text(viewModel.regretMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .font(.title2)
                        .padding(.horizontal, 30)
                        .bold()
                        .phaseAnimator([0.7, 1, 4]) { content, phase in
                            content
                                .scaleEffect(phase)
                                .opacity(phase == 1 ? 1 : 0)
                        } animation: { phase in
                                .easeIn(duration: 4)
                        }
                        .accessibilityLabel("Your stated regret")
                        .accessibilityIdentifier("regretMessage")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                withAnimation {
                                    viewModel.showFinalMessage = true
                                    viewModel.cycleRegret()
                                }
                            }
                        }
                } else {
                    VStack {
                        Spacer()
                        Text("Are you sure this is how you want to spend your time?")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.horizontal, 30)
                            .transition(.opacity.animation(.easeIn(duration: 4.0)))
                            .accessibilityLabel("Final reflection question")
                        
                        Spacer()
                        
                        VStack {
                            Button(action: {
                                let currentTime = Date().timeIntervalSince1970
                                let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
                                sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
                                sharedDefaults?.set(true, forKey: "UserAllowedBreak")
                                sharedDefaults?.synchronize()
                                
                                if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                                    let urlScheme = getUrlScheme(for: appName)
                                    if let url = URL(string: urlScheme) {
                                        UIApplication.shared.open(url, options: [:]) { _ in }
                                    }
                                }
                                NavigationModel.shared.navigate(to: .regretReport)
                            }) {
                                Text("Unlock for 5 Min")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(10)
                            }
                            .accessibilityLabel("Unlock for 5 minutes")
                            .accessibilityHint("Temporarily access the restricted app")
                            .accessibilityAddTraits(.isButton)
                            
                            Button(action: {
                                NavigationModel.shared.navigate(to: .regretReport)
                            }) {
                                let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
                                let appName = sharedDefaults?.string(forKey: "LastGuardedApp")
                                let buttonText = "Close \(appName ?? "")"
                                Text(buttonText)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.7))
                                    .cornerRadius(10)
                            }
                            .accessibilityLabel("Close app")
                            .accessibilityHint("Exit and view your usage report")
                            .accessibilityAddTraits(.isButton)
                        }
                        .padding(.horizontal, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeOut(duration: 5.0)))
                    }
                }
                
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            // Update with actual environment store
            viewModel.regretStore = regretStore
            viewModel.resetView()
            
            // Start with next regret when view appears
            if !regretStore.regrets.isEmpty {
                regretStore.cycleRegret()
                viewModel.updateRegretMessage()
            }
        }
    }
    
    private func getUrlScheme(for appName: String) -> String {
        switch appName.lowercased() {
        case "instagram": return "instagram://"
        case "youtube": return "youtube://"
        case "tiktok": return "tiktok://"
        case "threads": return "threads://"
        case "snapchat": return "snapchat://"
        case "netflix": return "netflix://"
        case "facebook": return "facebook://"
        case "bereal": return "bereal://"
        case "reddit": return "reddit://"
        case "x": return "x://"
        case "safari": return "https://google.com"
        default: return "instagram://"
        }
    }
}

#Preview {
    RegretView()
}
