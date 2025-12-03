//
//  FaithVerseView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct FaithVerseView: View {
    @EnvironmentObject var bibleVerseStore: BibleVerseStore
    @StateObject private var viewModel: BibleVerseViewModel
    @State private var showBibleReader = false
    
    // Animation states
    @State private var introOpacity: Double = 0
    @State private var verseOpacity: Double = 0
    @State private var verseFadedIn: Bool = false
    @State private var verseFadingOut: Bool = false
    @State private var finalOpacity: Double = 0
    
    init() {
        // Use temporary store for preview
        let previewStore = BibleVerseStore()
        _viewModel = StateObject(wrappedValue: BibleVerseViewModel(bibleVerseStore: previewStore))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color #024349
                Color(hex: 0x024349)
                    .ignoresSafeArea()
                
                // Background image with gradient overlay (like home page)
                VStack {
                    ZStack {
                        Image("faith-gaurd-background-image")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 380)
                            .clipped()
                        
                        // Gradient overlay for smooth blend
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1),
                                Color(hex: 0x024349).opacity(0.95)
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
                VStack(alignment: .center) {
                    Spacer()
                    
                    if !viewModel.showVerse && !viewModel.showFinalMessage {
                        // Intro message
                        Text("Before you open this app, reflect on God's word...")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.horizontal, 30)
                            .opacity(introOpacity)
                            .accessibilityLabel("Prompt message")
                            .onAppear {
                                // Fade in
                                withAnimation(.easeIn(duration: 2.0)) {
                                    introOpacity = 1
                                }
                                // Wait then fade out and show verse
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    withAnimation(.easeOut(duration: 2.0)) {
                                        introOpacity = 0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        viewModel.showVerse = true
                                    }
                                }
                            }
                            
                    } else if viewModel.showVerse && !viewModel.showFinalMessage {
                        // Verse display with tap to continue at bottom
                        ZStack {
                            // Centered verse content
                            VStack(spacing: 20) {
                                // Translation chip
                                HStack {
                                    Text(BibleDataManager.shared.currentTranslation.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.15))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(Color(red: 0.4, green: 0.7, blue: 0.6).opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                .padding(.bottom, 10)
                                
                                Text(viewModel.verseText)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)
                                    .font(.system(size: 20, weight: .medium, design: .serif))
                                    .italic()
                                    .padding(.horizontal, 30)
                                    .lineSpacing(6)
                                
                                Text(viewModel.verseReference)
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 15, weight: .medium))
                                    .padding(.top, 8)
                            }
                            .opacity(verseOpacity)
                            
                            // Tap to continue at bottom (independent of verse layout)
                            VStack {
                                Spacer()
                                if verseFadedIn && !verseFadingOut {
                                    Text("Tap to continue")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.bottom, 50)
                                        .transition(.opacity.animation(.easeIn(duration: 0.5)))
                                }
                            }
                            .opacity(verseOpacity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Bible verse")
                        .accessibilityIdentifier("verseMessage")
                        .onTapGesture {
                            // Only respond to tap after fully faded in
                            guard verseFadedIn && !verseFadingOut else { return }
                            
                            verseFadingOut = true
                            // Fade out at same slow rate
                            withAnimation(.easeOut(duration: 2.0)) {
                                verseOpacity = 0
                            }
                            // Then show final message
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                viewModel.showFinalMessage = true
                            }
                        }
                        .onAppear {
                            // Reset states
                            verseOpacity = 0
                            verseFadedIn = false
                            verseFadingOut = false
                            
                            // Fade in
                            withAnimation(.easeIn(duration: 2.0)) {
                                verseOpacity = 1
                            }
                            // Mark as faded in after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                verseFadedIn = true
                            }
                        }
                        
                    } else {
                        // Final message with buttons
                        VStack {
                            Spacer()
                            Text("Let this verse guide your next moments. Is this app serving your higher purpose?")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(.horizontal, 30)
                                .accessibilityLabel("Reflection question")
                            
                            Spacer()
                            
                            VStack(spacing: 12) {
                                // Continue Reading button
                                Button(action: {
                                    if let verse = viewModel.currentVerse {
                                        BibleDataManager.shared.navigateTo(verse: verse)
                                    }
                                    showBibleReader = true
                                }) {
                                    HStack {
                                        Image(systemName: "book.fill")
                                        Text("Continue Reading")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(10)
                                }
                                .accessibilityLabel("Continue Reading")
                                .accessibilityHint("Open the Bible reader to continue reading")
                                .accessibilityAddTraits(.isButton)
                                
                                Button(action: {
                                    let currentTime = Date().timeIntervalSince1970
                                    let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.faithguard")
                                    sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
                                    sharedDefaults?.set(true, forKey: "UserAllowedBreak")
                                    sharedDefaults?.synchronize()
                                    
                                    if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                                        let urlScheme = getUrlScheme(for: appName)
                                        if let url = URL(string: urlScheme) {
                                            UIApplication.shared.open(url, options: [:]) { _ in }
                                        }
                                    }
                                    NavigationModel.shared.navigate(to: .regretReport)
                                }) {
                                    Text("Open Distracting App")
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red)
                                        .cornerRadius(10)
                                }
                                .accessibilityLabel("Proceed for 5 minutes")
                                .accessibilityHint("Temporarily access the app")
                                .accessibilityAddTraits(.isButton)
                            }
                            .padding(.horizontal, 30)
                            .padding(.bottom, 50)
                        }
                        .opacity(finalOpacity)
                        .onAppear {
                            finalOpacity = 0
                            withAnimation(.easeIn(duration: 2.0)) {
                                finalOpacity = 1
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showBibleReader) {
            BibleReaderView()
                .environmentObject(BibleDataManager.shared)
        }
        .onAppear {
            // Update with actual environment store
            viewModel.bibleVerseStore = bibleVerseStore
            // Reset view and fetch a new random verse from the Bible
            viewModel.resetView()
            
            // Reset animation states
            introOpacity = 0
            verseOpacity = 0
            verseFadedIn = false
            verseFadingOut = false
            finalOpacity = 0
        }
    }
    
    private func getUrlScheme(for appName: String) -> String {
        switch appName.lowercased() {
        case "instagram": return "instagram://"
        case "youtube": return "youtube://"
        case "tiktok": return "tiktok://"
        case "threads": return "threads://"
        case "snapchat": return "snapchat://"
        case "netflix": return "netflix://"
        case "facebook": return "facebook://"
        case "bereal": return "bereal://"
        case "reddit": return "reddit://"
        case "x": return "x://"
        case "safari": return "https://google.com"
        default: return "instagram://"
        }
    }
}

// Backward compatibility alias
typealias RegretView = FaithVerseView

#Preview {
    FaithVerseView()
        .environmentObject(BibleVerseStore())
}
