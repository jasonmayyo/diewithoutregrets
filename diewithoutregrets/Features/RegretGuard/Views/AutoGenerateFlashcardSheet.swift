import SwiftUI
import RevenueCat
import RevenueCatUI
import PDFKit
import UniformTypeIdentifiers

// Custom error enum for flashcard generation
enum FlashcardGenerationError: Error {
    case networkError(String)
    case timeout
    case fileTooLarge
    case invalidResponse
    case tokenLimitExceeded
    
    var userMessage: String {
        switch self {
        case .networkError(let message):
            return "Network error: \(message). Please check your internet connection and try again."
        case .timeout:
            return "Request timed out. The PDF might be too large to process. Try with a smaller document or break it into parts."
        case .fileTooLarge:
            return "This PDF is too large for processing. Please use a PDF with fewer than 30 pages for best results"
        case .invalidResponse:
            return "Unable to process the response from the AI model. Please try again."
        case .tokenLimitExceeded:
            return "The content exceeds the maximum size that we can process. Please try with a smaller document (less than 30 pages)."
        }
    }
}

struct AutoGenerateFlashcardsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var deck: Deck
    @State private var inputText: String = ""
    @State private var errorMessage: String?
    @State private var showingDocumentPicker = false
    @State private var pdfExtractedText: String = ""
    @State private var isProcessingError = false
    @State private var currentError: FlashcardGenerationError?
    
    // Enhanced loading states
    @State private var processingStep: ProcessingStep = .idle
    @State private var processingProgress: Double = 0
    @State private var currentPDFData: Data? = nil
    @State private var fileName: String = ""
    
    @AppStorage("freeAutoGenerateUses") private var freeAutoGenerateUses = 1
    @State private var showPaywall = false
    
    // Animation states
    @State private var showUploadAnimation = false
    @State private var cardScale: CGFloat = 0.9
    @State private var cardOpacity: Double = 0.8
    @State private var meshOffset: CGFloat = 0
    
    // Gradient animation timer
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    // Add new color constants
    private let primaryGradient = LinearGradient(
        colors: [
            Color(hex: 0x3FA4AE),
            Color(hex: 0x2BC391)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let grayGradient = LinearGradient(
        colors: [
            Color.gray.opacity(60),
            Color.gray.opacity(60)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let secondaryGradient = LinearGradient(
        colors: [
            Color(hex: 0x184449).opacity(0.8),
            Color(hex: 0x065961).opacity(0.8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Add new state variables
    @State private var showingGenerationView = false
    @State private var generationStatus = "Preparing to generate flashcards..."
    
    enum ProcessingStep: String, CaseIterable {
        case idle = "Ready to process"
        case uploading = "Uploading PDF..."
        case extracting = "Extracting text..."
        case analyzing = "Analyzing content..."
        case generating = "Generating flashcards..."
        case finalizing = "Finalizing flashcards..."
        
        var icon: String {
            switch self {
            case .idle: return "doc.text.magnifyingglass"
            case .uploading: return "arrow.up.doc.fill"
            case .extracting: return "doc.text.fill"
            case .analyzing: return "brain.head.profile"
            case .generating: return "flashcard.fill"
            case .finalizing: return "checkmark.square.fill"
            }
        }
        
        var progressWeight: Double {
            switch self {
            case .idle: return 0.0
            case .uploading: return 0.2
            case .extracting: return 0.3
            case .analyzing: return 0.1
            case .generating: return 0.3
            case .finalizing: return 0.1
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Enhanced background
                GeometryReader { geometry in
                    ZStack {
                        // Base gradient
                        LinearGradient(
                            colors: [
                                Color(hex: 0x3FA4AE).opacity(0.1),
                                Color(hex: 0x2BC391).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Animated mesh pattern
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color(hex: 0x3FA4AE).opacity(0.05))
                                .frame(width: geometry.size.width * 0.8)
                                .offset(x: meshOffset + CGFloat(index * 50), y: CGFloat(index * 30))
                                .blur(radius: 30)
                        }
                        
                        // Subtle pattern overlay
                        Image("dwr-background")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width)
                            .opacity(0.5)
                            .blur(radius: 2)
                    }
                }
                .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 15) {
                        premiumFeatureBadge
                            .padding(.top, 10)
                        
                        documentUploadSection
                        
                        if !pdfExtractedText.isEmpty || !inputText.isEmpty {
                            contentPreviewSection
                        }
                        
                        if let errorMessage = errorMessage {
                            errorView(errorMessage)
                        }
                        
                        if processingStep != .idle && processingStep != .generating {
                            processingStatusView
                        }
                        
                        generateButton
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("AI Flashcard Generator")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: 0x184449))
                }
            }
            .fullScreenCover(isPresented: $showingGenerationView) {
                GenerationView(
                    status: $generationStatus,
                    progress: $processingProgress,
                    onCancel: {
                        showingGenerationView = false
                        processingStep = .idle
                    }
                )
            }
        }
        .onAppear {
            resetState()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
    }
    
    // MARK: - View Components
    
    var premiumFeatureBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yellow)
                    
                    if freeAutoGenerateUses > 0 {
                        Text("\(freeAutoGenerateUses) Free Uses Left")
                            .font(.headline)
                            .foregroundColor(Color(hex: 0x184449))
                    } else {
                        Text("Premium Feature")
                            .font(.headline)
                            .foregroundColor(Color(hex: 0x184449))
                    }
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yellow)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color.white.opacity(0.9)
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.1),
                        Color.yellow.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            Capsule()
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
    }
    
    var documentUploadSection: some View {
        VStack(spacing: 16) {
            if currentPDFData == nil {
                uploadPromptCard
            } else {
                documentInfoCard
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    var uploadPromptCard: some View {
        VStack(spacing: 24) {
            Button {
                showingDocumentPicker = true
            } label: {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(primaryGradient)
                            .frame(width: 90, height: 90)
                            .shadow(color: Color(hex: 0x3FA4AE).opacity(0.3), radius: 15, x: 0, y: 8)
                        
                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(showUploadAnimation ? 1.1 : 1.0)
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            showUploadAnimation = true
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("Upload PDF")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: 0x184449))
                        
                        Text("or paste text below")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
            .buttonStyle(UploadButtonStyle())
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    if let url = url {
                        handlePDFSelection(url)
                    }
                }
            }
            
            // Enhanced divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: 0x3FA4AE).opacity(0.2))
                
                Text("OR")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: 0x184449))
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: 0x3FA4AE).opacity(0.2))
            }
            
            // Enhanced text input
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste your text")
                    .font(.headline)
                    .foregroundColor(Color(hex: 0x184449))
                
                TextEditor(text: $inputText)
                    .frame(height: 150)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x3FA4AE).opacity(inputText.isEmpty ? 0.2 : 0.5),
                                        Color(hex: 0x2BC391).opacity(inputText.isEmpty ? 0.2 : 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: inputText.isEmpty ? 1 : 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color.white
                
                // Subtle pattern overlay
                Color(hex: 0x3FA4AE)
                    .opacity(0.02)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 20,
            x: 0,
            y: 10
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: 0x3FA4AE).opacity(0.1), lineWidth: 1)
        )
    }
    
    var documentInfoCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                // Enhanced PDF icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(primaryGradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(hex: 0x3FA4AE).opacity(0.3), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(fileName.isEmpty ? "Document" : fileName)
                        .font(.headline)
                        .foregroundColor(Color(hex: 0x184449))
                        .lineLimit(1)
                    
                    Text("\(pdfExtractedText.count) characters extracted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    resetState()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                }
            }
            
            if !pdfExtractedText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: 0x184449))
                        .fontWeight(.medium)
                    
                    Text(pdfExtractedText)
                        .font(.system(.body, design: .serif))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(hex: 0x184449).opacity(0.05))
                        .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color.white
                
                // Subtle pattern overlay
                Color(hex: 0x3FA4AE)
                    .opacity(0.02)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 20,
            x: 0,
            y: 10
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: 0x3FA4AE).opacity(0.1), lineWidth: 1)
        )
    }
    
    var contentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: 0x184449))
                
                Text("Content Preview")
                    .font(.headline)
                    .foregroundColor(Color(hex: 0x184449))
            }
            
            ScrollView {
                Text(inputText.isEmpty ? pdfExtractedText : inputText)
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(height: 200)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x3FA4AE).opacity(0.2),
                                Color(hex: 0x2BC391).opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .padding(24)
        .background(
            ZStack {
                Color.white
                
                // Subtle pattern overlay
                Color(hex: 0x3FA4AE)
                    .opacity(0.02)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 20,
            x: 0,
            y: 10
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: 0x3FA4AE).opacity(0.1), lineWidth: 1)
        )
    }
    
    var processingStatusView: some View {
        VStack(spacing: 24) {
            // Progress bar with enhanced styling
            ProgressView(value: overallProgress)
                .progressViewStyle(CustomProgressViewStyle())
                .frame(height: 8)
            
            // Status steps with enhanced visuals
            ForEach(ProcessingStep.allCases, id: \.self) { step in
                if step != .idle {
                    HStack(spacing: 16) {
                        // Status icon with dynamic styling
                        ZStack {
                            Circle()
                                .fill(currentStepIndex >= stepIndex(step) ? primaryGradient : grayGradient)
                                .frame(width: 36, height: 36)
                            
                            if currentStepIndex > stepIndex(step) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            } else if currentStepIndex == stepIndex(step) {
                                if processingStep == .finalizing {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                            } else {
                                Image(systemName: step.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .shadow(color: currentStepIndex >= stepIndex(step) ? Color(hex: 0x3FA4AE).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                        
                        Text(step.rawValue)
                            .font(.subheadline)
                            .foregroundColor(currentStepIndex >= stepIndex(step) ? Color(hex: 0x184449) : .secondary)
                            .fontWeight(currentStepIndex == stepIndex(step) ? .medium : .regular)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .opacity(shouldShowStep(step) ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: shouldShowStep(step))
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                Color.white
                
                // Subtle pattern overlay
                Color(hex: 0x3FA4AE)
                    .opacity(0.02)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 20,
            x: 0,
            y: 10
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: 0x3FA4AE).opacity(0.1), lineWidth: 1)
        )
    }
    
    var generateButton: some View {
        Button {
            checkAuthAndGenerate()
        } label: {
            HStack {
                Spacer()
                
                HStack(spacing: 12) {
                    if processingStep != .idle {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Processing...")
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                        Text("Generate Flashcards")
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(primaryGradient)
            )
            .foregroundColor(.white)
            .font(.headline)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(
                color: Color(hex: 0x3FA4AE).opacity(0.3),
                radius: 15,
                x: 0,
                y: 8
            )
        }
        .buttonStyle(GenerateButtonStyle())
        .disabled(processingStep != .idle || (inputText.isEmpty && pdfExtractedText.isEmpty))
        .opacity((inputText.isEmpty && pdfExtractedText.isEmpty) ? 0.6 : 1.0)
    }
    
    private func checkAuthAndGenerate() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let error = error {
                print("🚀 RevenueCat Error: \(error.localizedDescription)")
            }
            
            if let customerInfo = customerInfo {
                print("🚀 Customer Info: \(customerInfo)")
                print("🚀 Entitlements: \(customerInfo.entitlements.all)")
            }
            
            DispatchQueue.main.async {
                if customerInfo?.entitlements["Pro Acess"]?.isActive == true {
                    print("🚀 User has Pro Access")
                    self.generateFlashcards(shouldDecrementFreeUse: false)
                } else {
                    print("🚀 No Pro Access found")
                    if self.freeAutoGenerateUses > 0 {
                        self.generateFlashcards(shouldDecrementFreeUse: true)
                    } else {
                        self.showPaywall = true
                    }
                }
            }
        }
    }
    
    private func generateFlashcards(shouldDecrementFreeUse: Bool) {
        // Show generation view
        showingGenerationView = true
        processingStep = .generating
        processingProgress = 0
        generationStatus = "Analyzing text content..."
        
        // Use fresh text every time
        let processingText = inputText.isEmpty ? pdfExtractedText : inputText
        let combinedInput = flashcardPrompt + "\n\n" + processingText
        
        // Clear previous results
        errorMessage = nil
        
        // Progress animation configuration
        let totalDuration: Double = 25.0 // Total animation duration in seconds
        let initialSteps = 94 // Steps until slow progress begins
        let slowProgressInterval: Double = 0.5 // Update slow progress every 0.5 seconds
        
        func updateProgress(at step: Int) {
            let progress = Double(step) / Double(initialSteps)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    processingProgress = min(0.94, progress)
                }
                
                // Update status messages at specific progress points
                switch progress {
                case 0..<0.2:
                    generationStatus = "Analyzing text content..."
                case 0.2..<0.4:
                    generationStatus = "Extracting key concepts..."
                case 0.4..<0.6:
                    generationStatus = "Generating questions..."
                case 0.6..<0.8:
                    generationStatus = "Creating answer options..."
                case 0.8..<0.95:
                    generationStatus = "Finalizing flashcards..."
                default:
                    break
                }
            }
        }
        
        // Initial fast progress up to 94%
        for step in 0..<initialSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (totalDuration * Double(step) / Double(initialSteps))) {
                updateProgress(at: step)
            }
        }
        
        // Start slow progress updates after 94%
        var slowProgressTimer: Timer?
        slowProgressTimer = Timer.scheduledTimer(withTimeInterval: slowProgressInterval, repeats: true) { timer in
            DispatchQueue.main.async {
                // Increment by a tiny amount (0.001) each time
                let newProgress = min(0.99, self.processingProgress + 0.001)
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.processingProgress = newProgress
                }
            }
        }
        
        // Make the API call
        generateFlashcardsAPI(with: combinedInput) { apiResponse in
            // Invalidate the slow progress timer
            slowProgressTimer?.invalidate()
            slowProgressTimer = nil
            
            DispatchQueue.main.async {
                if let flashcardsText = apiResponse {
                    let newFlashcards = self.parseRegrets(from: flashcardsText)
                    if newFlashcards.isEmpty {
                        self.errorMessage = "No valid flashcards were generated. Please check the format."
                        self.showingGenerationView = false
                        self.processingStep = .idle
                    } else {
                        // Show 100% completion
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.processingProgress = 1.0
                        }
                        self.generationStatus = "Flashcards generated successfully!"
                        
                        // Only decrement free use if generation was successful and user is not pro
                        if shouldDecrementFreeUse {
                            self.freeAutoGenerateUses -= 1
                        }
                        
                        // Clear input after successful generation
                        self.inputText = ""
                        self.pdfExtractedText = ""
                        self.currentPDFData = nil
                        
                        // Add cards to the deck
                        self.deck.cards.append(contentsOf: newFlashcards)
                        
                        // Dismiss the sheet after a short delay to show completion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.dismiss()
                        }
                    }
                } else {
                    self.errorMessage = "Failed to generate flashcards. Please try again."
                    self.showingGenerationView = false
                    self.processingStep = .idle
                }
            }
        }
    }
    
    func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(Color(hex: 0x184449))
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Button {
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: 0x184449).opacity(0.6))
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.white
                
                // Subtle pattern overlay
                Color.orange
                    .opacity(0.02)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: Color.orange.opacity(0.1),
            radius: 15,
            x: 0,
            y: 8
        )
    }
    
    // MARK: - Helper Functions
    
    private var currentStepIndex: Int {
        ProcessingStep.allCases.firstIndex(of: processingStep) ?? 0
    }
    
    private func stepIndex(_ step: ProcessingStep) -> Int {
        ProcessingStep.allCases.firstIndex(of: step) ?? 0
    }
    
    private func shouldShowStep(_ step: ProcessingStep) -> Bool {
        let stepIdx = stepIndex(step)
        let currentIdx = currentStepIndex
        return stepIdx <= currentIdx + 1 && stepIdx > 0
    }
    
    private var overallProgress: Double {
        let completedSteps = ProcessingStep.allCases[..<currentStepIndex]
        let completedWeight = completedSteps.reduce(0) { $0 + $1.progressWeight }
        let currentProgress = processingStep.progressWeight * processingProgress
        return completedWeight + currentProgress
    }
    
    private func resetState() {
        inputText = ""
        pdfExtractedText = ""
        currentPDFData = nil
        fileName = ""
        errorMessage = nil
        processingStep = .idle
        processingProgress = 0
    }
    
    private func checkPDFSize(_ pdfData: Data) -> Bool {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return false }
        // GPT-4o-mini has a context window limit
        // Assuming average page has 500 words (750 tokens)
        // Safe limit would be around 30 pages
        let maxPages = 30
        return pdfDocument.pageCount <= maxPages
    }

    private func handlePDFSelection(_ url: URL) {
        processingStep = .uploading
        processingProgress = 0
        fileName = url.lastPathComponent
        
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Check PDF size before processing
            if !checkPDFSize(data) {
                currentError = .fileTooLarge
                errorMessage = currentError?.userMessage
                processingStep = .idle
                return
            }
            
            currentPDFData = data
            
            simulateProgress(for: .extracting) {
                self.extractTextFromPDF(data) { extractedText in
                    DispatchQueue.main.async {
                        if let text = extractedText, !text.isEmpty {
                            pdfExtractedText = text
                            inputText = text
                            processingStep = .idle
                        } else {
                            currentError = .invalidResponse
                            errorMessage = """
                            Text extraction failed. Possible reasons:
                            1. PDF contains scanned images
                            2. PDF is password protected
                            3. Text layers are missing
                            """
                            processingStep = .idle
                        }
                    }
                }
            }
        } catch {
            currentError = .networkError(error.localizedDescription)
            errorMessage = currentError?.userMessage
            processingStep = .idle
        }
    }
    
    private func simulateProgress(for step: ProcessingStep, completion: @escaping () -> Void) {
        let duration = step == .uploading ? 1.0 : (step == .extracting ? 2.0 : 1.0)
        let totalSteps = 10
        let stepDuration = duration / Double(totalSteps)
        
        processingProgress = 0
        
        func performStep(_ step: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration, execute: {
                let newProgress = Double(step) / Double(totalSteps)
                withAnimation(.easeInOut(duration: stepDuration * 0.8)) {
                    processingProgress = newProgress
                }
                
                if step < totalSteps {
                    performStep(step + 1)
                } else {
                    completion()
                }
            })
        }
        
        performStep(1)
    }
    
    private func extractTextFromPDF(_ pdfData: Data, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdfDocument = PDFDocument(data: pdfData) else {
                completion(nil)
                return
            }
            
            let fullText = (0..<pdfDocument.pageCount).compactMap { index in
                pdfDocument.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.joined(separator: "\n\n")
            
            completion(fullText.isEmpty ? nil : fullText)
        }
    }
    
    private func loadOpenAIKey() -> String? {
        guard
          let key = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String,
          !key.isEmpty
        else {
          assertionFailure("🔑 Missing OpenAIAPIKey in Info.plist")
          return nil
        }
        return key
    }
    
    // MARK: - API Helpers
    
    func generateFlashcardsAPI(with inputText: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            DispatchQueue.main.async {
                currentError = .invalidResponse
                errorMessage = currentError?.userMessage
            }
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let apiKey = loadOpenAIKey(), !apiKey.isEmpty else {
            DispatchQueue.main.async {
                currentError = .networkError("API key configuration error")
                errorMessage = "API key configuration error. Please contact support."
            }
            completion(nil)
            return
        }
        
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let jsonBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": flashcardPrompt],
                ["role": "user", "content": inputText]
            ],
            "max_tokens": 4000,
            "temperature": 0.7
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: []) else {
            DispatchQueue.main.async {
                currentError = .invalidResponse
                errorMessage = currentError?.userMessage
            }
            completion(nil)
            return
        }
        
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    switch error.code {
                    case NSURLErrorTimedOut:
                        currentError = .timeout
                    case NSURLErrorNotConnectedToInternet:
                        currentError = .networkError("No internet connection")
                    default:
                        currentError = .networkError(error.localizedDescription)
                    }
                    errorMessage = currentError?.userMessage
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    currentError = .invalidResponse
                    errorMessage = currentError?.userMessage
                    completion(nil)
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    if let data = data,
                       let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let choices = (jsonResponse["choices"] as? [[String: Any]])?.first,
                       let message = choices["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(content)
                    } else {
                        currentError = .invalidResponse
                        errorMessage = currentError?.userMessage
                        completion(nil)
                    }
                case 413:
                    currentError = .fileTooLarge
                    errorMessage = currentError?.userMessage
                    completion(nil)
                case 429:
                    currentError = .networkError("Rate limit exceeded")
                    errorMessage = "Rate limit exceeded. Please try again in a few minutes."
                    completion(nil)
                case 400:
                    if let data = data,
                       let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let error = jsonResponse["error"] as? [String: Any],
                       let message = error["message"] as? String,
                       message.contains("maximum context length") {
                        currentError = .tokenLimitExceeded
                        errorMessage = currentError?.userMessage
                    } else {
                        currentError = .invalidResponse
                        errorMessage = currentError?.userMessage
                    }
                    completion(nil)
                default:
                    currentError = .networkError("Server error (Status \(httpResponse.statusCode))")
                    errorMessage = "Server error (Status \(httpResponse.statusCode)). Please try again."
                    completion(nil)
                }
            }
        }.resume()
    }
    
    // MARK: - Parser Helpers
    
    func parseRegrets(from input: String) -> [Regret] {
        var regrets: [Regret] = []
        // Split the input by occurrences of "Regret(" and re-add the prefix to each block.
        let blocks = input.components(separatedBy: "Regret(")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for block in blocks {
            let flashcardText = "Regret(" + block  // Prepend the missing "Regret(" removed during splitting.
            guard let prompt = extractField("regretPrompt", from: flashcardText),
                  let regretText = extractField("regret", from: flashcardText),
                  let explanation = extractField("backgroundExplanation", from: flashcardText),
                  let correctAnswerIndexStr = extractField("correctAnswerIndex", from: flashcardText),
                  let correctAnswerIndex = Int(correctAnswerIndexStr),
                  let choices = extractChoices(from: flashcardText)
            else { continue }
            
            let newRegret = Regret(
                regretPrompt: prompt,
                regret: regretText,
                choices: choices,
                correctAnswerIndex: correctAnswerIndex,
                backgroundExplanation: explanation
            )
            regrets.append(newRegret)
        }
        return regrets
    }
    
    func extractField(_ field: String, from text: String) -> String? {
        let quotedPattern = "\(field):\\s*\"([^\"]+)\""
        if let result = matchRegex(quotedPattern, in: text) {
            return result
        }
        if field == "correctAnswerIndex" {
            let numberPattern = "\(field):\\s*([0-9]+)"
            return matchRegex(numberPattern, in: text)
        }
        return nil
    }
    
    func matchRegex(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsText = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if let match = results.first, match.numberOfRanges > 1 {
            return nsText.substring(with: match.range(at: 1))
        }
        return nil
    }
    
    func extractChoices(from text: String) -> [String]? {
        let pattern = "choices:\\s*\\[([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsText = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if let match = results.first, match.numberOfRanges > 1 {
            let choicesContent = nsText.substring(with: match.range(at: 1))
            let choicePattern = "\"([^\"]+)\""
            guard let choiceRegex = try? NSRegularExpression(pattern: choicePattern, options: []) else { return nil }
            let choiceMatches = choiceRegex.matches(in: choicesContent, options: [], range: NSRange(location: 0, length: (choicesContent as NSString).length))
            var choices: [String] = []
            for choiceMatch in choiceMatches {
                if choiceMatch.numberOfRanges > 1 {
                    let choice = (choicesContent as NSString).substring(with: choiceMatch.range(at: 1))
                    choices.append(choice)
                }
            }
            return choices
        }
        return nil
    }
    
    // MARK: - Prompt
    
    var flashcardPrompt: String {
        return """
You are provided with text (extracted from a PDF) that contains technical or conceptual material. I need you to generate a set of flashcards based on that text. The flashcards should meet the following requirements:

1. **Flashcard Format:**
    - Use the following object format for each flashcard:
        
        ```
        Regret( regretPrompt: "Question text here", regret: "A brief statement or context for the question.", choices: [ "Option A", "Option B", "Option C", "Option D" ], correctAnswerIndex: X, backgroundExplanation: "Detailed explanation of the answer." ),
        ```
        
    - The flashcards should be output in plain text that can be copy/pasted directly into code.
2. **Question Types:**
    - Create a mix of True/False questions and multiple-choice questions.
    - True/False questions should have two options: "True" and "False".
    - Multiple-choice questions should include four options.
3. **Answer Consistency:**
    - The correct answer index (the value for `correctAnswerIndex`) should not be the same for every flashcard; vary its position among the answer options.
    - For multiple-choice questions, ensure that the correct answer option has the same number of words as the other options. (Reword options if needed without changing their meaning.)
4. **Content Requirements:**
    - Base the questions on key concepts, definitions, examples, and explanations found in the provided text.
    - Make sure each flashcard includes a clear question (`regretPrompt`), a brief statement or context (`regret`), a list of answer choices (`choices`), the index of the correct answer option has the same number of words as the other options. (Reword options if needed without changing their meaning.)
4. **Content Requirements:**
    - Base the questions on key concepts, definitions, examples, and explanations found in the provided text.
    - Make sure each flashcard includes a clear question (`regretPrompt`), a brief statement or context (`regret`), a list of answer choices (`choices`), the index of the correct answer (`correctAnswerIndex`), and a detailed explanation (`backgroundExplanation`).
5. **Quantity:**
    - Create 50 flashcards unless otherwise specified.
6. **Output:**
    - Output exactly 50 flashcards in plain text. Each flashcard must be formatted exactly as shown below and each flashcard should be on its own line.
    
Example:

Regret( regretPrompt: "Why are heuristic functions considered 'weak' knowledge in search algorithms?", regret: "Heuristic functions are deemed 'weak' because they provide only an approximate estimate of the true cost to reach the goal, guiding the search without guaranteeing perfect accuracy.", choices: [ "Because they always overestimate the actual cost.", "Because they guarantee the shortest path.", "Because they offer only approximate guidance without always being accurate, and thus do not replace complete information.", "Because they are based entirely on random guessing." ], correctAnswerIndex: 2, backgroundExplanation: "While heuristics significantly improve search efficiency, their approximate nature means they cannot ensure an optimal solution unless they are carefully designed (i.e., admissible and consistent)." ),

Only output flashcards in the above format with one flashcard per line.
"""
    }
    
    // MARK: - ChatGPT API Integration
    func generateFlashcards(with inputText: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Replace with your actual API key.
        guard let apiKey = loadOpenAIKey(), !apiKey.isEmpty else {
          assertionFailure("Missing API key")
          return
        }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let jsonBody: [String: Any] = [
            "model": "gpt-4o-mini", // Change to your desired model.
            "messages": [
                ["role": "system", "content": flashcardPrompt],
                ["role": "user", "content": inputText]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody, options: []) else {
            completion(nil)
            return
        }
        
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
               let responseDict = jsonResponse as? [String: Any],
               let choices = (responseDict["choices"] as? [[String: Any]])?.first,
               let message = choices["message"] as? [String: Any],
               let content = message["content"] as? String {
                completion(content)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    
}

// MARK: - DocumentPicker
struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var completion: (URL?) -> Void
        
        init(completion: @escaping (URL?) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls.first)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil)
        }
    }
}

struct CustomProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: SwiftUI.ProgressViewStyleConfiguration) -> some View {
        let progress = configuration.fractionCompleted ?? 0.0
        
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: 0x184449).opacity(0.1))
                    .frame(height: 12)
                
                // Progress bar
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x3FA4AE),
                                Color(hex: 0x2BC391)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, CGFloat(progress) * geometry.size.width), height: 12)
                    .overlay(
                        // Shimmer effect
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: -geometry.size.width)
                        .animation(
                            Animation
                                .linear(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: progress
                        )
                    )
                    // Glow effect
                    .shadow(
                        color: Color(hex: 0x2BC391).opacity(0.3),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                
                // Progress percentage
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(width: 40)
                    .opacity(progress > 0.1 ? 1 : 0)
                    .offset(x: max(0, CGFloat(progress) * geometry.size.width - 40))
            }
        }
        .frame(height: 12)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: progress)
    }
}

// Add at bottom of your file
extension PDFPage {
    var smartString: String? {
        guard let content = string else { return nil }
        // Remove excessive whitespace and line breaks
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

#Preview {
    DeckListView()
        .environmentObject(DeckStore.shared)
}

// Custom button style for upload button
struct UploadButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
        configuration.label
            .background(Color.white)
            .cornerRadius(20)
            .shadow(
                color: Color.black.opacity(0.1),
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 5
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Custom button style for generate button
struct GenerateButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: SwiftUI.ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Add new GenerationView
struct GenerationView: View {
    @Binding var status: String
    @Binding var progress: Double
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            GeometryReader { geometry in
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            Color(hex: 0x3FA4AE),
                            Color(hex: 0x2BC391)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Background image
                    Image("dwr-background2")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width)
                        .opacity(0.15)
                        .blur(radius: 3)
                }
            }
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 30) {
                Spacer()
                
                // Status icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
                
                // Status text
                Text(status)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Progress percentage
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(Color(hex: 0x184449))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.bottom, 50)
            }
        }
    }
}
