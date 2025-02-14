//
//  RegretGuard.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretGuard: View {
    @EnvironmentObject var regretStore: RegretStore
    @StateObject private var viewModel = RegretGuardViewModel()
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                // Background image
                Image("dwr-background")
                    .resizable()
                    .frame(height: 130)
                    .edgesIgnoringSafeArea(.all)
                    .accessibilityHidden(true) // Hide decorative background image
                
                VStack {
                    VStack {
                        // Page Title - Limits
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Regret Guard")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                    .accessibilityLabel("Regret Guard")
                                Text("Protect Your Time, Protect Your Goals.")
                                    .foregroundColor(.white)
                                    .accessibilityLabel("Protect your time, protect your goals")
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine) // Combine title and subtitle for VoiceOver
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(regretStore.regrets) { regret in
                                        Button(action: {
                                            regretStore.selectRegret(regret)
                                            viewModel.showEditRegret = true
                                        }, label: {
                                            VStack {
                                                VStack {
                                                    Spacer()
                                                    Text(regret.regret)
                                                        .bold()
                                                        .accessibilityLabel("Regret: \(regret.regret)")
                                                    Spacer()
                                                    Text("Tap to edit")
                                                        .foregroundColor(.gray)
                                                        .font(.caption)
                                                        .accessibilityLabel("Tap to edit this regret")
                                                }
                                                .padding()
                                            }
                                            .frame(width: 300, height: 150)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 0)
                                            .padding(.bottom)
                                            .accessibilityElement(children: .combine) // Combine regret and edit text
                                        })
                                        .foregroundColor(.black)
                                        .accessibilityAddTraits(.isButton)
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.leading)
                            }
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Regret-Proof Your Phone")
                                            .font(.title3)
                                            .bold()
                                            .accessibilityLabel("Regret-Proof Your Phone")
                                        Text("Select the apps that may hold you back from your goals.")
                                            .font(.caption)
                                            .accessibilityLabel("Select the apps that may hold you back from your goals")
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 5)
                                .accessibilityElement(children: .combine) // Combine heading and description
                                
                                let columns = [
                                    GridItem(.flexible(), spacing: 15),
                                    GridItem(.flexible(), spacing: 15)
                                ]
                                
                                LazyVGrid(columns: columns, spacing: 15) {
                                    ForEach(viewModel.apps) { app in
                                        Button(action: {
                                            viewModel.selectApp(app)
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(app.iconName)
                                                    .resizable()
                                                    .frame(width: 25, height: 25)
                                                    .accessibilityHidden(true) // Hide decorative icon
                                                Text(app.name)
                                                    .font(.system(size: 14))
                                                    .accessibilityLabel(app.name)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .shadow(color: .gray.opacity(0.2), radius: 5, x: 2, y: 2)
                                        }
                                        .foregroundColor(.black)
                                        .accessibilityAddTraits(.isButton)
                                        .accessibilityHint("Select this app to restrict")
                                    }
                                }
                                
                                HStack {
                                    Spacer()
                                    Text("Can't find what you are looking for? We are adding more everyday!")
                                        .font(.system(size: 10))
                                        .padding(.top, 5)
                                        .accessibilityLabel("Can't find what you are looking for? We are adding more everyday!")
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showInstructions) {
                if let app = viewModel.selectedApp {
                    RegretGuardInstructionSheet(app: app)
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                }
            }
            .sheet(isPresented: $viewModel.showEditRegret) {
                if let regret = regretStore.selectedRegret {
                    RegretEditorSheet(regret: regret)
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                        .environmentObject(regretStore)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    RegretGuard()
}
