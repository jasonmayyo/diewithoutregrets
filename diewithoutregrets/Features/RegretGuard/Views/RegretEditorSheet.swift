
import SwiftUI

struct RegretEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var regret: Regret
    
    @State private var editedPrompt: String
    @State private var editedRegret: String
    @State private var editedExplanation: String
    @State private var editedChoices: [String]
    @State private var editedCorrectIndex: Int
    @State private var selectedTab = 0
    
    private let dwrGreen = Color(hex: 0x013B41)
    private let dwrGreen2 = Color(hex: 0x065961)
    private let tabs = ["Question", "Explanation", "Answers"]
    private let tabIcons = ["questionmark.circle", "text.bubble", "checklist"]
    
    // Custom initializer that creates state values from the binding's current value
    init(regret: Binding<Regret>) {
        self._regret = regret
        _editedPrompt = State(initialValue: regret.wrappedValue.regretPrompt)
        _editedRegret = State(initialValue: regret.wrappedValue.regret)
        _editedExplanation = State(initialValue: regret.wrappedValue.backgroundExplanation)
        _editedChoices = State(initialValue: regret.wrappedValue.choices)
        _editedCorrectIndex = State(initialValue: regret.wrappedValue.correctAnswerIndex)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                // Background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [dwrGreen, dwrGreen2.opacity(0.85)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(spacing: 8) {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        Text("Edit Flashcard")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { saveChanges() }) {
                            Text("Save")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    // Tab selector
                    HStack(spacing: 5) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: { selectedTab = index }) {
                                HStack(spacing: 4) {
                                    Image(systemName: tabIcons[index])
                                        .font(.system(size: 14))
                                    Text(tabs[index])
                                        .font(.subheadline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 5)
                                .background(
                                    selectedTab == index ?
                                    Color.white.opacity(0.15) :
                                    Color.clear
                                )
                                .cornerRadius(50)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(50)
                    
                    .padding(.bottom, 8)
                    .padding(.top, 8)
                }.padding(.horizontal, 10)
            }
            .frame(height: 120)
            
            // Content
            TabView(selection: $selectedTab) {
                // Question Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        textEditorSection(
                            title: "Question",
                            subtitle: "Write a clear question for your flashcard",
                            text: $editedPrompt
                        )
                    }
                    .padding()
                }
                .tag(0)
                
                // Explanation Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        textEditorSection(
                            title: "Explanation",
                            subtitle: "Provide details that help understand the answer",
                            text: $editedExplanation
                        )
                    }
                    .padding()
                }
                .tag(1)
                
                // Answers Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        answerOptionsSection
                    }
                    .padding()
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .background(Color(.systemGroupedBackground))
            
            // Bottom navigation
            HStack {
                Button(action: { selectedTab = max(0, selectedTab - 1) }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .foregroundColor(selectedTab > 0 ? dwrGreen : Color.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(20)
                }
                .disabled(selectedTab == 0)
                
                Spacer()
                
                // Progress indicators
                HStack(spacing: 6) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Circle()
                            .fill(selectedTab == index ? dwrGreen : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if selectedTab < tabs.count - 1 {
                        selectedTab += 1
                    } else {
                        saveChanges()
                    }
                }) {
                    HStack {
                        Text(selectedTab == tabs.count - 1 ? "Save" : "Next")
                        Image(systemName: selectedTab == tabs.count - 1 ? "" : "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(dwrGreen)
                    .cornerRadius(20)
                }
            }
            .padding()
            .background(Color.white)
        }
    }
    
    private func textEditorSection(title: String, subtitle: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(dwrGreen)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            TextEditor(text: text)
                .frame(minHeight: 180)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private var answerOptionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Answer Options")
                    .font(.headline)
                    .foregroundColor(dwrGreen)
                
                Text("Select the correct answer and add options")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                ForEach(0..<editedChoices.count, id: \.self) { index in
                    HStack {
                        Button(action: { editedCorrectIndex = index }) {
                            ZStack {
                                Circle()
                                    .stroke(editedCorrectIndex == index ? Color.green : Color.gray.opacity(0.5), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                
                                if editedCorrectIndex == index {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 16, height: 16)
                                }
                            }
                        }
                        
                        TextField("Option \(index + 1)", text: $editedChoices[index])
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if editedChoices.count > 2 {
                            Button(action: { removeOption(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                    }
                }
                
                Button(action: addNewOption) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Option")
                    }
                    .foregroundColor(dwrGreen)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(dwrGreen.opacity(0.5), lineWidth: 1)
                    )
                }
                .disabled(editedChoices.count >= 6)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func addNewOption() {
        if editedChoices.count < 6 {
            editedChoices.append("")
        }
    }
    
    private func removeOption(at index: Int) {
        if editedChoices.count > 2 {
            editedChoices.remove(at: index)
            if editedCorrectIndex >= editedChoices.count {
                editedCorrectIndex = 0
            }
        }
    }
    
    private func saveChanges() {
        // Update the binding's value directly
        regret.regretPrompt = editedPrompt
        regret.regret = editedRegret
        regret.backgroundExplanation = editedExplanation
        regret.choices = editedChoices
        regret.correctAnswerIndex = editedCorrectIndex
        dismiss()
    }
}
#Preview {
    DeckListView()
        .environmentObject(DeckStore.shared)
}

