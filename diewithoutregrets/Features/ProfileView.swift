//
//  ProfileView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/02/12.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    @AppStorage("userName") private var userName: String = ""
    @AppStorage("userAge") private var userAge: Int = 0
    @State private var showEditName = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.16, blue: 0.22),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 20) {
                        // Profile Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.4, green: 0.7, blue: 0.6),
                                            Color(red: 0.3, green: 0.6, blue: 0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Text(userName.prefix(1).uppercased())
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.4), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 4) {
                            Text(userName.isEmpty ? "Faith Guardian" : userName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Guarding your heart with Scripture")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 40)
                    
                    // Stats Section
                    HStack(spacing: 16) {
                        StatCard(
                            value: "\(bibleVerseStore.bibleVerses.count)",
                            label: "Saved Verses",
                            icon: "bookmark.fill"
                        )
                        
                        StatCard(
                            value: "0",
                            label: "Days Guarded",
                            icon: "shield.fill"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Settings Sections
                    VStack(spacing: 16) {
                        SettingsSection(title: "ACCOUNT") {
                            SettingsRow(
                                icon: "person.fill",
                                iconColor: Color(red: 0.4, green: 0.7, blue: 0.6),
                                title: "Edit Name",
                                subtitle: userName.isEmpty ? "Not set" : userName
                            ) {
                                showEditName = true
                            }
                            
                            SettingsRow(
                                icon: "bell.fill",
                                iconColor: .orange,
                                title: "Notifications",
                                subtitle: "Daily verse reminders"
                            ) {
                                // TODO: Notification settings
                            }
                        }
                        
                        SettingsSection(title: "APP") {
                            SettingsRow(
                                icon: "paintbrush.fill",
                                iconColor: .purple,
                                title: "Appearance",
                                subtitle: "Dark mode"
                            ) {
                                // TODO: Appearance settings
                            }
                            
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                iconColor: .blue,
                                title: "Help & Support",
                                subtitle: "FAQs and contact"
                            ) {
                                // TODO: Help
                            }
                            
                            SettingsRow(
                                icon: "info.circle.fill",
                                iconColor: .gray,
                                title: "About",
                                subtitle: "Version 1.0.0"
                            ) {
                                // TODO: About
                            }
                        }
                        
                        SettingsSection(title: "FAITH") {
                            SettingsRow(
                                icon: "heart.fill",
                                iconColor: .red,
                                title: "Share Faith Guard",
                                subtitle: "Invite friends to guard their hearts"
                            ) {
                                // TODO: Share
                            }
                            
                            SettingsRow(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: "Rate the App",
                                subtitle: "Support us on the App Store"
                            ) {
                                // TODO: Rate
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Footer
                    VStack(spacing: 8) {
                        Image(systemName: "cross.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Faith Guard")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Guard your heart above all else,\nfor it determines the course of your life.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                        
                        Text("Proverbs 4:23")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.6))
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showEditName) {
            EditNameSheet(userName: $userName)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 4)
            
            VStack(spacing: 2) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edit Name Sheet
struct EditNameSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var userName: String
    @State private var tempName: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.12, green: 0.16, blue: 0.22)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    TextField("Enter your name", text: $tempName)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Button(action: {
                        userName = tempName
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.7, blue: 0.6),
                                        Color(red: 0.3, green: 0.6, blue: 0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                }
            }
            .toolbarBackground(Color(red: 0.12, green: 0.16, blue: 0.22), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            tempName = userName
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(BibleVerseStore())
}

