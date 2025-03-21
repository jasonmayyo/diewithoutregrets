//
//  AutoGenerateFlashcardsSheet.swift
//  diewithoutregrets
//
//  Created by Jason Mayo on 2025/03/14.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct AutoGenerateFlashcardsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var deck: Deck
    @State private var inputText: String = ""
    @State private var errorMessage: String?
    @State private var showingDocumentPicker = false
    @State private var pdfExtractedText: String = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack {
                Text("Upload PDF or Paste Flashcard Text")
                    .font(.headline)
                    .padding(.top)
                
                // Button to show PDF upload option
                Button("Upload PDF") {
                    showingDocumentPicker = true
                }
                .padding(.horizontal)
                .sheet(isPresented: $showingDocumentPicker) {
                    DocumentPicker { url in
                        if let url = url, let text = extractText(from: url) {
                            pdfExtractedText = text
                            // Optionally, update inputText so the user can see the extracted text
                            inputText = pdfExtractedText
                        }
                    }
                }
                
                // TextEditor for manual paste or viewing extracted text
                TextEditor(text: $inputText)
                    .frame(height: 300)
                    .border(Color.gray, width: 1)
                    .padding()
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.bottom)
                }
                
                if isLoading {
                    ProgressView("Generating flashcards...")
                        .padding()
                }
                
                // Generate Flashcards Button
                Button("Generate Flashcards") {
                    isLoading = true
                    // Use inputText if available, otherwise use the extracted PDF text.
                    let userText = inputText.isEmpty ? pdfExtractedText : inputText
                    // Combine the detailed prompt and the user text.
                    let combinedInput = flashcardPrompt + "\n\n" + userText
                    generateFlashcards(with: combinedInput) { apiResponse in
                        DispatchQueue.main.async {
                            isLoading = false
                            if let flashcardsText = apiResponse {
                                let newFlashcards = parseRegrets(from: flashcardsText)
                                if newFlashcards.isEmpty {
                                    errorMessage = "No valid flashcards were generated. Please check the format."
                                } else {
                                    deck.cards.append(contentsOf: newFlashcards)
                                    dismiss()
                                }
                            } else {
                                errorMessage = "Failed to generate flashcards. Please try again."
                            }
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Auto Generate Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - PDF Extraction Helper
    func extractText(from pdfURL: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: pdfURL) else { return nil }
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText.append(pageText + "\n")
            }
        }
        return fullText
    }
    
    // MARK: - Flashcard Prompt
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
        request.timeoutInterval = 60 
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Replace with your actual API key.
        request.setValue("Bearer MY_API_KEY_HERE", forHTTPHeaderField: "Authorization")
        
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
    
    // MARK: - Parsing Helpers
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

