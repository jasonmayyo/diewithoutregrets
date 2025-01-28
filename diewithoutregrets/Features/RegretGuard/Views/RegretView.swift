//
//  RegretView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretView: View {
    @State private var showRegret: Bool = false
    @State private var showFinalMessage: Bool = false
    
    @State private var regretMessage: String = "This is the regret the user has put in :)"
    
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
                
                if !showRegret && !showFinalMessage {
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
                                    showRegret = true
                                }
                            }
                        }
                } else if showRegret && !showFinalMessage {
                    Text(regretMessage)
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
                                    showFinalMessage = true
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
                            .transition(.opacity.animation(.easeIn(duration: 3.0)))
                        
                        Spacer()
                        
                        VStack {
                            // Take you to "instagram"
                            Button(action: {
                                showRegret = false
                                showFinalMessage = false
                                if let url = URL(string: "instagram://") {
                                    UIApplication.shared.open(url, options: [:]) { success in
                                        if !success {
                                            print("Failed to open Instagram")
                                        }
                                    }
                                } else {
                                    print("Invalid URL for Instagram")
                                }
                            }) {
                                Text("Continue anyway")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(10)
                            }
                            // Take you to the home screen of the app or close the app
                            Button(action: {
                                showRegret = false
                                showFinalMessage = false
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
