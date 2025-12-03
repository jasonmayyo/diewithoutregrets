//
//  FaithGuard.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct FaithGuard: View {
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    @EnvironmentObject var bibleDataManager: BibleDataManager
    @EnvironmentObject var navigationModel: NavigationModel
    @StateObject private var viewModel = FaithGuardViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Premium dark gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.16, blue: 0.22),
                        Color(red: 0.08, green: 0.10, blue: 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Background image with gradient overlay
                VStack {
                    ZStack {
                        Image("faith-gaurd-background-image")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 380)
                            .clipped()
                        
                        // Premium gradient overlay for depth
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1),
                                Color(red: 0.12, green: 0.16, blue: 0.22).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(height: 380)
                    Spacer()
                }
                .ignoresSafeArea()
                
                // Main content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 8) {
                        HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("FAITH GUARD")
                                        .font(.system(size: 26, weight: .bold))
                                        .tracking(3)
                                    .foregroundColor(.white)
                                }
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 120)
                        
                        // Featured Verse Section
                        VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                Text("Recent Verses")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                    .tracking(1)
                                                    Spacer()
                                
                                if bibleVerseStore.hasRecentVerses {
                                    Text("\(bibleVerseStore.recentVerses.count) recent")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Scripture Cards or Empty State
                            if bibleVerseStore.hasRecentVerses {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(Array(bibleVerseStore.recentVerses.enumerated()), id: \.element.id) { index, verse in
                                            Button(action: {
                                                // Navigate to Bible reader at this verse
                                                bibleDataManager.navigateTo(verse: verse)
                                                navigationModel.switchToTab(.bible)
                                            }) {
                                                PremiumVerseCard(verse: verse, isFirst: index == 0)
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                                }
                            } else {
                                // Empty State
                                EmptyVersesCard()
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                            }
                        }.padding(.top, 2)
                        
                        // Apps Section
                        VStack(alignment: .leading, spacing: 20) {
                            // Section Header
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PROTECTED APPS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(2)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Select apps to guard")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 24)
                            
                            // App Grid
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                    ForEach(viewModel.apps) { app in
                                        Button(action: {
                                            viewModel.selectApp(app)
                                        }) {
                                        PremiumAppCard(app: app)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            // Footer text
                                HStack {
                                    Spacer()
                                VStack(spacing: 4) {
                                    Text("More apps coming soon")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                        Text("Request an app")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                                }
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        .padding(.top, 25)
                        .padding(.bottom, 24)
                    }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showInstructions) {
                if let app = viewModel.selectedApp {
                FaithGuardInstructionSheet(app: app)
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                }
            }
        .sheet(isPresented: $viewModel.showEditVerse) {
            if let verse = bibleVerseStore.selectedVerse {
                BibleVerseEditorSheet(verse: verse)
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                    .environmentObject(bibleVerseStore)
            }
        }
    }
}

// MARK: - Premium Verse Card
struct PremiumVerseCard: View {
    let verse: BibleVerse
    let isFirst: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top accent bar
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.7, blue: 0.6),
                                Color(red: 0.3, green: 0.6, blue: 0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 40, height: 3)
                Spacer()
                
                Image(systemName: "quote.opening")
                    .font(.system(size: 16, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            // Verse text
            Text(verse.verse)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .lineSpacing(4)
            
            Spacer()
            
            // Reference and edit hint
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verse.reference)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Read More")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(20)
        .frame(width: 280, height: 200)
        .background(
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Empty Verses Card
struct EmptyVersesCard: View {
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "book.closed")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
            }
            
            VStack(spacing: 8) {
                Text("No Recent Verses")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Verses shown before you open guarded apps will appear here")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Premium App Card
struct PremiumAppCard: View {
    let app: GuardedApp
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            Image(app.iconName)
                .resizable()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(app.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        )
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Backward compatibility alias
typealias RegretGuard = FaithGuard

#Preview {
    FaithGuard()
        .environmentObject(BibleVerseStore())
        .environmentObject(BibleDataManager.shared)
        .environmentObject(NavigationModel.shared)
}
