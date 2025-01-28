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
                    .frame(height: 125)
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
                                Text("Select apps that you may regret using")
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    
                    ScrollView {
                        VStack {
                            HStack {
                                ForEach(viewModel.apps) { app in
                                    Button(action: {
                                        viewModel.selectApp(app)
                                    }) {
                                        HStack(spacing: 15) {
                                            Image(app.iconName)
                                                .resizable()
                                                .frame(width: 25, height: 25)
                                            Text(app.name)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(.black)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .shadow(color: .gray.opacity(0.5), radius: 5, x: 2, y: 2)
                                    }
                                }
                            }
                            HStack {
                                Text("Can't find what you are looking for?")
                                    .font(.system(size: 10))
                                    .padding(.top)
                                Button(action: {
                                    
                                }, label: {
                                    Text("Click Here")
                                        .font(.system(size: 10))
                                        .padding(.top)
                                        .foregroundColor(Color(hex: 0x184449))
                                })
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
    }
}

#Preview {
    RegretGuard()
}


