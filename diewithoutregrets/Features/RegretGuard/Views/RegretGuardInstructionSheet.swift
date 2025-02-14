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
                // Title Section
                Text("Setup Instructions")
                    .bold()
                    .font(.title2)
                    .accessibilityLabel("Setup Instructions")
                Text("2 min setup process to save thousands")
                    .font(.subheadline)
                    .accessibilityLabel("Two-minute setup process to save thousands")
                
                // Step 1
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
                            .accessibilityLabel("Step 1")
                        VStack(alignment: .leading) {
                            Text("Copy Custom Shortcut")
                                .font(.headline)
                                .accessibilityLabel("Copy Custom Shortcut")
                            Text("Click the button below to copy the custom shortcut")
                                .font(.caption)
                                .accessibilityLabel("Click the button below to copy the custom shortcut")
                        }
                        Spacer()
                    }
                    Button(action: {
                        UIApplication.shared.open(app.shortcutLink)
                    }, label: {
                        HStack {
                            Image(systemName: "button.angledtop.vertical.right")
                                .accessibilityHidden(true) // Hide decorative icon
                            Text("Copy Shortcut")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
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
                    })
                    .accessibilityLabel("Copy Shortcut")
                    .accessibilityHint("Tap to copy the custom shortcut for \(app.name)")
                    .accessibilityAddTraits(.isButton)
                    .padding(.top)
                }
                .padding()
                
                // Step 2
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
                            .accessibilityLabel("Step 2")
                        VStack(alignment: .leading) {
                            Text("Open Shortcuts App")
                                .font(.headline)
                                .accessibilityLabel("Open Shortcuts App")
                            Text("Click the button below to open the Shortcuts app")
                                .font(.caption)
                                .accessibilityLabel("Click the button below to open the Shortcuts app")
                        }
                        Spacer()
                    }
                    Button(action: {
                        if let shortcutsURL = URL(string: "shortcuts://") {
                            UIApplication.shared.open(shortcutsURL)
                        }
                    }, label: {
                        HStack {
                            Image(systemName: "link")
                                .accessibilityHidden(true) // Hide decorative icon
                            Text("Open Shortcut App")
                        }
                        .foregroundColor(Color(hex: 0x184449))
                    })
                    .accessibilityLabel("Open Shortcut App")
                    .accessibilityHint("Tap to open the Shortcuts app")
                    .accessibilityAddTraits(.isButton)
                    .padding(.top)
                }
                .padding()
                
                // Step 3
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
                            .accessibilityLabel("Step 3")
                        VStack(alignment: .leading) {
                            Text("Create a new Automation")
                                .font(.headline)
                                .accessibilityLabel("Create a new Automation")
                            Text("Create a new automation by clicking the automation tab")
                                .font(.caption)
                                .accessibilityLabel("Create a new automation by clicking the automation tab")
                        }
                        Spacer()
                    }
                    
                    // Images Section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Find Shortcuts")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .accessibilityLabel("Step 1: Find Shortcuts")
                                    Image("create-automation-1")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200)
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .accessibilityHidden(true) // Hide decorative image
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("2. Create Automation")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .accessibilityLabel("Step 2: Create Automation")
                                    Image("create-automation-2")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200)
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .accessibilityHidden(true) // Hide decorative image
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                }
                .padding()
                
                // Step 4
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
                            .accessibilityLabel("Step 4")
                        VStack(alignment: .leading) {
                            Text("Select \"Open App\" Automation")
                                .font(.headline)
                                .accessibilityLabel("Select Open App Automation")
                            Text("Choose the App automation and follow the steps below")
                                .font(.caption)
                                .accessibilityLabel("Choose the App automation and follow the steps below")
                        }
                        Spacer()
                    }
                    
                    // Images Section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Find \"App\" Automation")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .accessibilityLabel("Step 1: Find App Automation")
                                    Image("open-app-automation")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200)
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .accessibilityHidden(true) // Hide decorative image
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("2. Choose the app you may regret")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .accessibilityLabel("Step 2: Choose the app you may regret")
                                    Image("chose-app")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200)
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .accessibilityHidden(true) // Hide decorative image
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                }
                .padding()
                
                // Step 5
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
                            .accessibilityLabel("Step 5")
                        VStack(alignment: .leading) {
                            Text("Configure Automation Settings")
                                .font(.headline)
                                .accessibilityLabel("Configure Automation Settings")
                            Text("Select \"Is Opened\" and \"Run Immediately\"")
                                .font(.caption)
                                .accessibilityLabel("Select Is Opened and Run Immediately")
                        }
                        Spacer()
                    }
                    
                    // Images Section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Select \"Is Opened\" and \"Run Immediately\"")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .accessibilityLabel("Step 1: Select Is Opened and Run Immediately")
                                    Image("is-opened")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200)
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .accessibilityHidden(true) // Hide decorative image
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                }
                .padding()
                
                // Step 6
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
                            .accessibilityLabel("Step 6")
                        VStack(alignment: .leading) {
                            Text("Select the dwr. custom shortcut")
                                .font(.headline)
                                .accessibilityLabel("Select the dwr. custom shortcut")
                            Text("Ensure you select the correct shortcut for the app you chose. e.g., Instagram")
                                .font(.caption)
                                .accessibilityLabel("Ensure you select the correct shortcut for the app you chose, such as Instagram")
                        }
                        Spacer()
                    }
                    
                    // Images Section
                    VStack(alignment: .leading) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Select custom shortcut you just copied")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .accessibilityLabel("Step 1: Select custom shortcut you just copied")
                                    Image("select-custom-shortcut")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200)
                                        .padding(.horizontal)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        .accessibilityHidden(true) // Hide decorative image
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                }
                .padding()
                
                // Step 7
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
                            .accessibilityLabel("Step 7")
                        VStack(alignment: .leading) {
                            Text("Setup Complete")
                                .font(.headline)
                                .accessibilityLabel("Setup Complete")
                            Text("Return home or create another automation. Make sure to test it out :)")
                                .font(.caption)
                                .accessibilityLabel("Return home or create another automation. Make sure to test it out")
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
