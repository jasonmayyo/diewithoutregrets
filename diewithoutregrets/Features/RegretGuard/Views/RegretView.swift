//
//  RegretView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretView: View {
    @StateObject private var viewModel = RegretViewModel()
    
    var body: some View {
        ZStack {
            Color(hex: 0x184449)
                .ignoresSafeArea()
            
            VStack(alignment: .center) {
                Text("dwr.")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
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
                        
                        Spacer()
                        
                        VStack {
                            Button(action: {
                                let currentTime = Date().timeIntervalSince1970
                                print("RegretView: Setting break time to:", currentTime)
                                
                                // Use shared UserDefaults
                                let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
                                sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
                                sharedDefaults?.set(true, forKey: "UserAllowedBreak")
                                sharedDefaults?.synchronize()
                                
                                print("RegretView: Break time set, attempting to open app")
                                
                                // Get the stored app name and determine the URL scheme
                                if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                                    print("RegretView: Opening app:", appName)
                                    let urlScheme: String
                                    switch appName.lowercased() {
                                    case "instagram":
                                        urlScheme = "instagram://"
                                    case "youtube":
                                        urlScheme = "youtube://"
                                    case "tiktok":
                                        urlScheme = "tiktok://"
                                    case "threads":
                                        urlScheme = "threads://"
                                    case "snapchat":
                                        urlScheme = "snapchat://"
                                    case "netflix":
                                        urlScheme = "netflix://"
                                    case "facebook":
                                        urlScheme = "facebook://"
                                    case "bereal":
                                        urlScheme = "bereal://"
                                    case "reddit":
                                        urlScheme = "reddit://"
                                    case "x":
                                        urlScheme = "x://"
                                    default:
                                        urlScheme = "instagram://"
                                    }
                                    
                                    if let url = URL(string: urlScheme) {
                                        UIApplication.shared.open(url, options: [:]) { success in
                                            if !success {
                                                print("RegretView: Failed to open \(appName)")
                                            } else {
                                                print("RegretView: Successfully opened \(appName)")
                                            }
                                        }
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
                            
                            Button(action: {
                                // take me to the home screen
                                NavigationModel.shared.navigate(to: .regretReport)
                               
                            }) { let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")
                                let appName = sharedDefaults?.string(forKey: "LastGuardedApp")
                                let buttonText = "Close \(appName)"
                                Text(buttonText)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.7))
                                    .cornerRadius(10)
                            }
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
            viewModel.resetView()
        }
    }
}

#Preview {
    RegretView()
}
