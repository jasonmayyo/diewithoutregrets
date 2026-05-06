//
//  RegretView.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/01/28.
//

import SwiftUI

struct RegretView: View {
    @EnvironmentObject var deckStore: DeckStore
    @StateObject private var viewModel = RegretViewModel()
    @State private var currentStep: Int = 0
    @State private var showFinalMessage = false
    @State private var selectedAnswer: Int?
    @State private var showLockAnimation = true
    @State private var showUnlockAnimation = false
    @State private var hasIncorrectAnswers = false
    @State private var questionResults: [Bool?] = []
    @State private var selectedRegrets: [Regret] = []
    @AppStorage("flashcardCount") private var flashcardCount: Int = 3
    @AppStorage("useAllCards") private var useAllCards: Bool = false
    @AppStorage("selectedAnimationType") private var selectedAnimationType: String = AnimationType.lockAnimation.rawValue
    @AppStorage("flashcardBreakDuration") private var flashcardBreakDuration: Int = 5

    /// Wall-clock start of the current attempt — used to measure how long
    /// users spend in the unlock flow before completing or rage-quitting.
    @State private var attemptStartTime: Date = Date()
    /// How many attempts (including retries) for this app open.
    @State private var attemptNumber: Int = 1
    /// Tracks which questions we've already emitted an "answered" event for
    /// so we don't double-count if the view re-renders.
    @State private var answeredQuestionIndices: Set<Int> = []

    let sharedDefaults = UserDefaults(suiteName: "group.com.jasonmayo.diewithoutregrets")

    private var currentAppName: String {
        sharedDefaults?.string(forKey: "LastGuardedApp") ?? "unknown"
    }
    
    var body: some View {
        ZStack {
            VStack {
                // Lock Icon and Progress Bar
                VStack {
                    Image(systemName: "lock.fill")
                        .font(.title)
                        .bold()
                        .foregroundColor(.black)
                        .padding(5)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 3) {
                            ForEach(0..<selectedRegrets.count, id: \.self) { index in
                                let segmentWidth = geometry.size.width / CGFloat(selectedRegrets.count)
                                
                                Rectangle()
                                    .frame(width: segmentWidth, height: 5)
                                    .foregroundColor(colorForQuestion(at: index))
                                    .cornerRadius(10)
                                    .animation(.easeInOut(duration: 0.3), value: questionResults)
                            }
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 20)
                }
                
                // Main Content
                Group {
                    if !showFinalMessage {
                        VStack(spacing: 0) {
                            // Guard against index out of range
                            if !selectedRegrets.isEmpty && currentStep/2 < selectedRegrets.count {
                                let currentRegret = selectedRegrets[currentStep/2]
                                
                                // Question
                                Text(currentRegret.regretPrompt)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .foregroundColor(.black)
                                    .font(currentStep % 2 == 1 ? .headline : .title3)
                                    .padding(.horizontal, 30)
                                    .padding(.top, currentStep % 2 == 1 ? 20 : 70)
                                    .padding(.bottom, currentStep % 2 == 1 ? 5 : 15)
                                    .scaleEffect(currentStep % 2 == 1 ? 0.95 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: currentStep)
                                
                                // Explanation View
                                if currentStep % 2 == 1 {
                                    ScrollView {
                                        Text(currentRegret.backgroundExplanation)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 30)
                                            .padding(.top, 5)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                    .frame(maxHeight: 150)
                                    .padding(.bottom, 10)
                                }
                                Spacer()
                                
                                // Answer Options
                                if currentStep % 2 == 0 {
                                    ScrollView {
                                        VStack(spacing: 16) {
                                            ForEach(Array(currentRegret.choices.enumerated()), id: \.offset) { index, choice in
                                                Button(action: {
                                                    selectedAnswer = index
                                                }) {
                                                    HStack {
                                                        Text(choice)
                                                            .foregroundColor(.black)
                                                            .multilineTextAlignment(.leading)
                                                            .lineLimit(nil)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                            .padding(.vertical, 16)
                                                            .padding(.horizontal, 20)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                            .background(
                                                                selectedAnswer == index ?
                                                                Color.gray.opacity(0.2) : Color.clear
                                                            )
                                                            .cornerRadius(12)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(
                                                                        selectedAnswer == index ?
                                                                        Color.gray : Color.gray.opacity(0.3),
                                                                        lineWidth: 2
                                                                    )
                                                            )
                                                    }
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                    }
                                    .frame(maxHeight: 300) // Limit height to prevent overflow
                                } else {
                                    // Answer Reveal
                                    ScrollView {
                                        VStack(spacing: 16) {
                                            ForEach(Array(currentRegret.choices.enumerated()), id: \.offset) { index, choice in
                                                HStack {
                                                    Text(choice)
                                                        .foregroundColor(
                                                            index == currentRegret.correctAnswerIndex ?
                                                                .white : .black
                                                        )
                                                        .multilineTextAlignment(.leading)
                                                        .lineLimit(nil)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .padding(.vertical, 16)
                                                        .padding(.horizontal, 20)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .background(
                                                            index == currentRegret.correctAnswerIndex ?
                                                            Color.green :
                                                                (index == selectedAnswer ? Color.red.opacity(0.2) : Color.clear)
                                                        )
                                                        .cornerRadius(12)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 12)
                                                                .stroke(
                                                                    index == currentRegret.correctAnswerIndex ?
                                                                    Color.green : Color.clear,
                                                                    lineWidth: 2
                                                                )
                                                        )
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 20)
                                    }
                                    .frame(maxHeight: 300) // Limit height to prevent overflow
                                }
                            } else {
                                // Fallback if no regrets or index out of range
                                Text("No questions available")
                                    .foregroundColor(.black)
                                    .padding()
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Final Screen
                        VStack {
                            Spacer()
                            
                            let appName = sharedDefaults?.string(forKey: "LastGuardedApp") ?? ""
                            
                            if hasIncorrectAnswers {
                                Text("Looks like you don't know what you're doing, let's pause \(appName) for now")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black)
                                    .font(.title2)
                                    .padding(.horizontal, 30)
                            } else {
                                Text("Successfully unlocked! You've earned access to \(appName)!")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black)
                                    .font(.title2)
                                    .padding(.horizontal, 30)
                            }
                            
                            Spacer()
                                
                            // Action Buttons
                            VStack(spacing: 15) {
                                if hasIncorrectAnswers {
                                    Button(action: retryQuestions) {
                                        Text("Retry Questions")
                                            .foregroundColor(.black)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.red.opacity(0.2))
                                            .cornerRadius(10)
                                    }
                                } else {
                                    Button(action: handleUnlock) {
                                        Text("Unlock \(appName)")
                                            .foregroundColor(.black)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.gray.opacity(0.3))
                                            .cornerRadius(10)
                                    }
                                }
                                
                                Button(action: navigateToReport) {
                                    Text(hasIncorrectAnswers ? "Close \(appName)" : "Close Anyway")
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red.opacity(0.7))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                }
                
                // Bottom Control
                if !showFinalMessage {
                    VStack {
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        Text(controlButtonText)
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.7))
                            .padding(.vertical, 35)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: handleTap)
                    }
                    .background(Color.gray.opacity(0.2))
                    .transition(.move(edge: .bottom))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x36B8C4).opacity(0.1),
                                Color(hex: 0x238A94).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 20)
                    .ignoresSafeArea()
            )
            
            if showLockAnimation {
                if selectedAnimationType == AnimationType.memeVideo.rawValue {
                    MemeVideoView()
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    LockView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            
            if showUnlockAnimation {
                UnlockView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            setupView()
            withAnimation(.easeInOut(duration: 0.3)) {
                showLockAnimation = true
            }
            // Different timing for meme video vs lock animation
            let dismissDelay = selectedAnimationType == AnimationType.memeVideo.rawValue ? 5.0 : 1.5
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLockAnimation = false
                }
            }
        }
    }
    
    private func colorForQuestion(at index: Int) -> Color {
        guard index < questionResults.count else { return .gray.opacity(0.2) }
        
        if let isCorrect = questionResults[index] {
            return isCorrect ? .green : .red
        }
        return .gray.opacity(0.2)
    }
    
    private var controlButtonText: String {
        if currentStep % 2 == 0 {
            return selectedAnswer == nil ? "Select an answer" : "Reveal Answer"
        }
        return "Next Question"
    }
    
    private func handleTap() {
        guard !selectedRegrets.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            // Guard against index out of range
            guard !selectedRegrets.isEmpty && currentStep < selectedRegrets.count * 2 else {
                showFinalMessage = true
                return
            }
            
            if currentStep % 2 == 0 {
                guard selectedAnswer != nil else { return }
            }
            
            let previousStep = currentStep
            currentStep += 1
            
            // Update progress bar when answering
            if currentStep % 2 == 1 {
                let questionIndex = (currentStep - 1) / 2
                guard questionIndex < selectedRegrets.count else { return }
                
                let currentRegret = selectedRegrets[questionIndex]
                let isCorrect = selectedAnswer == currentRegret.correctAnswerIndex
                
                // Ensure questionResults has enough elements
                while questionResults.count <= questionIndex {
                    questionResults.append(nil)
                }
                
                questionResults[questionIndex] = isCorrect
                
                if !isCorrect {
                    hasIncorrectAnswers = true
                }

                if !answeredQuestionIndices.contains(questionIndex) {
                    answeredQuestionIndices.insert(questionIndex)
                    Analytics.unlockQuestionAnswered(
                        appName: currentAppName,
                        questionIndex: questionIndex,
                        totalQuestions: selectedRegrets.count,
                        isCorrect: isCorrect
                    )
                }
            }
            
            if currentStep % 2 == 0 {
                selectedAnswer = nil
            }
            
            if currentStep >= selectedRegrets.count * 2 {
                showFinalMessage = true
            }
        }
    }
    
    private func setupView() {
        // Add debug prints
        print("RegretView setup started")
        defer { print("RegretView setup completed") }
        
        // Validate deck selection
        guard let deck = deckStore.selectedDeck else {
            print("🚨 Critical error: No deck selected in RegretView")
            // Track the broken state too — if this fires often it's a real bug.
            Analytics.capture("unlock_attempted_no_deck", properties: [
                "app_name": currentAppName
            ])
            showFinalMessage = true
            return
        }
        
        print("Processing deck: \(deck.name)")
        print("Deck contains \(deck.cards.count) cards")
        
        guard !deck.cards.isEmpty else {
            print("⚠️ Empty deck selected")
            Analytics.capture("unlock_attempted_empty_deck", properties: [
                "app_name": currentAppName,
                "deck_name": deck.name
            ])
            showFinalMessage = true
            return
        }

        Analytics.unlockAttempted(
            appName: currentAppName,
            unlockMethod: "flashcards",
            flashcardCount: flashcardCount,
            useAllCards: useAllCards,
            animationType: selectedAnimationType,
            deckId: deck.id.uuidString,
            deckName: deck.name,
            availableCards: deck.cards.count
        )
        Telemetry.breadcrumb("Unlock attempted", category: "core_product",
                             data: ["app_name": currentAppName,
                                    "deck_name": deck.name,
                                    "available_cards": deck.cards.count])
        attemptStartTime = Date()
        attemptNumber = 1

        DispatchQueue.main.async {
               self.selectedRegrets = useAllCards || flashcardCount >= deck.cards.count
                   ? deck.cards.shuffled()
                   : Array(deck.cards.shuffled().prefix(flashcardCount))
               self.resetView()
           }
    }
    
    private func resetView() {
            currentStep = 0
            showFinalMessage = false
            selectedAnswer = nil
            hasIncorrectAnswers = false
            questionResults = Array(repeating: nil, count: selectedRegrets.count)
            answeredQuestionIndices = []
            viewModel.reset() // Use viewModel's reset instead
        }
    
    private func retryQuestions() {
        guard let deck = deckStore.selectedDeck else { return }

        let correctSoFar = questionResults.compactMap { $0 }.filter { $0 }.count
        Analytics.unlockRetried(
            appName: currentAppName,
            correctCount: correctSoFar,
            totalQuestions: selectedRegrets.count,
            attemptNumber: attemptNumber
        )
        attemptNumber += 1

        // If useAllCards is true or if user selected more cards than available, use all cards
        if useAllCards || flashcardCount >= deck.cards.count {
            selectedRegrets = deck.cards.shuffled()
        } else {
            selectedRegrets = Array(deck.cards.shuffled().prefix(flashcardCount))
        }
        resetView()
    }
    
    private func handleUnlock() {
        showUnlockAnimation = true

        let correctCount = questionResults.compactMap { $0 }.filter { $0 }.count
        Analytics.unlockCompleted(
            appName: currentAppName,
            correctCount: correctCount,
            totalQuestions: selectedRegrets.count,
            hadRetries: attemptNumber > 1,
            durationSec: Date().timeIntervalSince(attemptStartTime),
            breakDurationMinutes: flashcardBreakDuration
        )

        // Wait for animation to complete before proceeding
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Match animation duration
            let currentTime = Date().timeIntervalSince1970
            sharedDefaults?.set(currentTime, forKey: "LastBreakTime")
            sharedDefaults?.set(true, forKey: "UserAllowedBreak")
            sharedDefaults?.set(flashcardBreakDuration, forKey: "BreakDurationMinutes")
            sharedDefaults?.synchronize()
            
            if let appName = sharedDefaults?.string(forKey: "LastGuardedApp") {
                UIApplication.shared.open(getAppURL(for: appName), options: [:])
            }
            NavigationModel.shared.navigate(to: .regretReport)
            
            // Hide unlock animation after transition
            withAnimation {
                showUnlockAnimation = false
            }
        }
    }
    
    private func navigateToReport() {
        Analytics.unlockCloseAnyway(
            appName: currentAppName,
            currentStep: currentStep,
            totalSteps: selectedRegrets.count * 2,
            hadIncorrectAnswers: hasIncorrectAnswers,
            durationSec: Date().timeIntervalSince(attemptStartTime)
        )
        NavigationModel.shared.navigate(to: .regretReport)
    }
    
    private func getAppURL(for appName: String) -> URL {
        let scheme = getUrlScheme(for: appName)
        return URL(string: scheme) ?? URL(string: "instagram://") ?? URL(string: "https://instagram.com") ?? URL(fileURLWithPath: "/")
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
        case "clash royale": return "clashroyale://"
        default: return "instagram://"
        }
    }
}



#Preview {
    let deckStore = DeckStore.shared
    let sampleDeck = Deck(
        name: "Sample Deck",
        cards: [
            Regret(
                regretPrompt: "Sample Question",
                regret: "Correct Answer",
                choices: ["Correct Answer", "Wrong 1", "Wrong 2", "Wrong 3"],
                correctAnswerIndex: 0,
                backgroundExplanation: "Sample explanation"
            )
        ]
    )
    deckStore.selectedDeck = sampleDeck
    
    return RegretView()
        .environmentObject(deckStore)
}
