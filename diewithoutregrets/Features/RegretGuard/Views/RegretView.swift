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
                                }
                            }
                        }
                        .onDisappear {
                            // Cycle to the next regret
                            viewModel.currentRegretIndex = viewModel.getNextRegretIndex()
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
                                viewModel.resetView()
                                if let url = URL(string: "instagram://") {
                                    UIApplication.shared.open(url, options: [:]) { success in
                                        if !success {
                                            print("Failed to open Instagram")
                                        }
                                    }
                                }
                            }) {
                                Text("Continue anyway")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(10)
                            }
                            
                            Button(action: {
                                viewModel.resetView()
                            }) {
                                Text("Close Instagram")
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
    }
}

#Preview {
    RegretView()
}
