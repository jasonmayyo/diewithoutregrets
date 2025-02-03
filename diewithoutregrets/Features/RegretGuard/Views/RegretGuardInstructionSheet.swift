//
//  RegretGuardInstructionSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretGuardInstructionSheet: View {
    @Environment(\.dismiss) var dismiss
    let app: RegretApp
    var body: some View {
        ScrollView {
            VStack {
                Text("Setup Instructions")
                    .bold()
                    .font(.title2)
                Text("2 min setup process to save thousands")
                    .font(.subheadline)
                /*Button(action: {
                                    dismiss()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.title2)
                                }
                                .padding([.top, .trailing], 16)
                */
                VStack {
                    HStack {
                        Text("1")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Copy Custom Shortcut")
                                .font(.headline)
                            Text("Click the button below to copy the custom shortcut 👇")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    Button(action: {
                        UIApplication.shared.open(app.shortcutLink)
                    }, label: {
                        HStack {
                            Image(systemName: "button.angledtop.vertical.right")
                            Text("Copy Shortcut")
                        }.frame(maxWidth: .infinity)
                            .foregroundColor(.black) // Changed to white for better contrast
                            .padding()
                            .background(
                                MeshGradient()
                                    .cornerRadius(10)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }).padding(.top)
                }.padding()
                
                VStack {
                    HStack {
                        Text("2")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Open Shortcuts App")
                                .font(.headline)
                            Text("Click the button below to open the  👇")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    Button(action: {
                        // Open the shortcut app
                        if let shortcutsURL = URL(string: "shortcuts://") {
                                UIApplication.shared.open(shortcutsURL)
                            }
                    }, label: {
                        HStack {
                            Image(systemName: "link")
                            Text("Open Shortcut App")
                        }.foregroundColor(Color(hex: 0x184449))
                    }).padding(.top)
                }
                .padding()
                
                VStack {
                    HStack {
                        Text("3")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Create a new Automation")
                                .font(.headline)
                            Text("Create a new automation by clicking the automation tab")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    
                    // Modified images section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                // Shortcuts List Image
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Find Shortcuts")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image("create-automation-1")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200) // Fixed size
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                                
                                // Automation Screen Image
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("2. Create Automation")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image("create-automation-2")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200) // Fixed size
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                    
                    
                }
                .padding()
                
                VStack {
                    HStack {
                        Text("4")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Select \"Open App\" Automation")
                                .font(.headline)
                            Text("Chose the App automation and follow the steps below")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    
                    // Modified images section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                // Shortcuts List Image
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Find \"App\" Automation")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image("open-app-automation")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200) // Fixed size
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                                
                                // Automation Screen Image
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("2. Chose the app you may regret")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image("chose-app")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200) // Fixed size
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                    
                    
                }
                .padding()
                
                VStack {
                    HStack {
                        Text("5")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Configue Automation Settings")
                                .font(.headline)
                            Text("Select is opened and run immediately")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    
                    // Modified images section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                // Shortcuts List Image
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Select \"Is Opended\" and \"Run Immediately\"")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image("is-opened")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200) // Fixed size
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                    
                    
                }
                .padding()
                
                VStack {
                    HStack {
                        Text("6")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Select the dwr. custom shortcut")
                                .font(.headline)
                            Text("Ensure you select the correct shortcut for the app you chose. ie. Instagram")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    
                    // Modified images section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                // Shortcuts List Image
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Select custom shortcut you just copied")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Image("select-custom-shortcut")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200) // Fixed size
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                    
                    
                }
                .padding()
                
                VStack {
                    HStack {
                        Text("7")
                            .frame(width: 30, height: 30)
                            .background(Color(hex: 0x184449))
                            .cornerRadius(5)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                        VStack (alignment: .leading){
                            Text("Setup Complete")
                                .font(.headline)
                            Text("Return home or create another automation, make sure it test it out :)")
                                .font(.caption)
                        }
                        Spacer()
                    }
                }
                .padding()
                Spacer()
            }
        }
        .padding(.top, 30)
        .preferredColorScheme(.light)
    }
}

#Preview {
    RegretGuardInstructionSheet(app: RegretApp(
            name: "Instagram",
            iconName: "instagram-icon",
            shortcutLink: URL(string: "https://www.icloud.com/shortcuts/your-instagram-shortcut")!
        ))
}
