import Foundation

enum QuizletDelimiter: String, CaseIterable {
    case tab = "Tab"
    case comma = "Comma"
    case semicolon = "Semicolon"
    case custom = "Custom"
    
    var character: String {
        switch self {
        case .tab: return "\t"
        case .comma: return ","
        case .semicolon: return ";"
        case .custom: return ""
        }
    }
}

struct TermDefinitionPair: Identifiable, Equatable {
    let id = UUID()
    let term: String
    let definition: String
}

enum QuizletImportError: Error {
    case emptyInput
    case noValidPairs
    case tooFewCardsForDirectImport
    case parsingFailed
    
    var userMessage: String {
        switch self {
        case .emptyInput:
            return "Please paste your Quizlet export text."
        case .noValidPairs:
            return "No valid term/definition pairs found. Make sure each line has a term and definition separated by the selected delimiter."
        case .tooFewCardsForDirectImport:
            return "Direct import requires at least 4 cards to generate multiple-choice options. Use AI Enhanced mode or add more cards."
        case .parsingFailed:
            return "Failed to parse the imported text. Check the delimiter and format."
        }
    }
}

class QuizletImportService {
    
    static let shared = QuizletImportService()
    private init() {}
    
    func parseExport(text: String, delimiter: String) -> [TermDefinitionPair] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var pairs: [TermDefinitionPair] = []
        
        for line in lines {
            let components = line.components(separatedBy: delimiter)
            guard components.count >= 2 else { continue }
            
            let term = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let definition = components[1...].joined(separator: delimiter).trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !term.isEmpty, !definition.isEmpty else { continue }
            
            pairs.append(TermDefinitionPair(term: term, definition: definition))
        }
        
        return pairs
    }
    
    func detectDelimiter(in text: String) -> QuizletDelimiter {
        let firstLines = text.components(separatedBy: .newlines)
            .prefix(5)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard !firstLines.isEmpty else { return .tab }
        
        let tabCount = firstLines.filter { $0.contains("\t") }.count
        let semicolonCount = firstLines.filter { $0.contains(";") }.count
        let commaCount = firstLines.filter { $0.contains(",") }.count
        
        // Tab is the default Quizlet export delimiter
        if tabCount >= firstLines.count / 2 { return .tab }
        if semicolonCount >= firstLines.count / 2 { return .semicolon }
        if commaCount >= firstLines.count / 2 { return .comma }
        
        return .tab
    }
    
    func buildFlashcardsDirectly(from pairs: [TermDefinitionPair]) -> Result<[Regret], QuizletImportError> {
        guard !pairs.isEmpty else { return .failure(.noValidPairs) }
        guard pairs.count >= 4 else { return .failure(.tooFewCardsForDirectImport) }
        
        var flashcards: [Regret] = []
        
        for (index, pair) in pairs.enumerated() {
            let otherDefinitions = pairs.enumerated()
                .filter { $0.offset != index }
                .map { $0.element.definition }
                .shuffled()
            
            let wrongAnswers = Array(otherDefinitions.prefix(3))
            
            var allChoices = [pair.definition] + wrongAnswers
            allChoices.shuffle()
            
            let correctIndex = allChoices.firstIndex(of: pair.definition) ?? 0
            
            let flashcard = Regret(
                regretPrompt: pair.term,
                regret: pair.term,
                choices: allChoices,
                correctAnswerIndex: correctIndex,
                backgroundExplanation: pair.definition
            )
            flashcards.append(flashcard)
        }
        
        return .success(flashcards)
    }
    
    func formatForAI(pairs: [TermDefinitionPair]) -> String {
        pairs.map { "Term: \($0.term)\nDefinition: \($0.definition)" }
            .joined(separator: "\n\n")
    }
}
