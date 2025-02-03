//
//  RegretGuard.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretGuard: View {
    @StateObject private var viewModel = RegretGuardViewModel()
    
    var body: some View {
        VStack {
            ZStack(alignment: .top) {
                // Background image
                Image("dwr-background")
                    .resizable()
                    .frame(height: 130)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    VStack {
                        // Page Title - Limits
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Regret Guard")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.white)
                                Text("Protect Your Time, Protect Your Goals.")
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    
                    
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(viewModel.regrets) { regret in
                                        Button(action: {
                                            viewModel.selectRegret(regret)
                                        }, label: {
                                            VStack {
                                                VStack {
                                                    Spacer()
                                                    Text(regret.regret)
                                                        .bold()
                                                    Spacer()
                                                    Text("Tap to edit")
                                                        .foregroundColor(.gray)
                                                        .font(.caption)
                                                }
                                                .padding()
                                            }
                                            .frame(width: 300, height: 150)
                                            .background(Color.white)
                                            .cornerRadius(12)
                                            .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 0)
                                            .padding(.bottom)
                                            
                                        })
                                        .foregroundColor(.black)
                                        
                                    }
                                    Spacer()
                                }.frame(maxWidth: .infinity)
                                    .padding(.leading)
                                
                                
                            }
                            VStack (alignment: .leading) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Regret-Proof Your Phone")
                                            .font(.title3)
                                            .bold()
                                        Text("Select the apps that may hold you back from your goals.")
                                            .font(.caption)
                                    }
                                    Spacer()
                                }.padding(.bottom,5)
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
                                                Text(app.name)
                                                    .font(.system(size: 14))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .shadow(color: .gray.opacity(0.2), radius: 5, x: 2, y: 2)
                                        }
                                        .foregroundColor(.black)
                                    }
                                }
                                
                                
                                HStack {
                                    Spacer()
                                    Text("Can't find what you are looking for? We are adding more everyday!")
                                        .font(.system(size: 10))
                                        .padding(.top, 5)
                                    Spacer()
                                }
                                
                                
                            }.padding(.horizontal)
                            
                            
                            
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
                if let regret = viewModel.selectedRegret {
                    RegretEditorSheet(regret: regret)
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                        .environmentObject(viewModel)
                }
                
            }
            
        }.preferredColorScheme(.light)
    }
}
#Preview {
    RegretGuard()
}


