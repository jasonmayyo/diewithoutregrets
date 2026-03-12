import Foundation

enum YouTubeTranscriptError: Error {
    case invalidURL
    case networkError(String)
    case noTranscriptAvailable
    case parsingFailed
    
    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Please enter a valid YouTube URL (e.g. youtube.com/watch?v=... or youtu.be/...)"
        case .networkError(let message):
            return "Failed to fetch video data: \(message)"
        case .noTranscriptAvailable:
            return "No transcript found for this video. Try copying the transcript manually from YouTube (tap '...' > 'Show transcript' on the video)."
        case .parsingFailed:
            return "Could not extract the transcript from this video. Try copying it manually from YouTube."
        }
    }
}

class YouTubeTranscriptService {
    
    static let shared = YouTubeTranscriptService()
    private init() {}
    
    func extractVideoID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // youtu.be/VIDEO_ID
        if let url = URL(string: trimmed), url.host?.contains("youtu.be") == true {
            let id = url.lastPathComponent
            return id.isEmpty ? nil : id
        }
        
        // youtube.com/watch?v=VIDEO_ID
        if let url = URL(string: trimmed),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let vParam = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !vParam.isEmpty {
            return vParam
        }
        
        // youtube.com/embed/VIDEO_ID or youtube.com/v/VIDEO_ID
        if let url = URL(string: trimmed),
           url.host?.contains("youtube") == true {
            let pathComponents = url.pathComponents
            if let embedIndex = pathComponents.firstIndex(where: { $0 == "embed" || $0 == "v" }),
               embedIndex + 1 < pathComponents.count {
                return pathComponents[embedIndex + 1]
            }
        }
        
        // Bare video ID (11 characters, alphanumeric + dash/underscore)
        let bareIDPattern = "^[a-zA-Z0-9_-]{11}$"
        if trimmed.range(of: bareIDPattern, options: .regularExpression) != nil {
            return trimmed
        }
        
        return nil
    }
    
    func fetchTranscript(videoID: String, completion: @escaping (Result<String, YouTubeTranscriptError>) -> Void) {
        let urlString = "https://www.youtube.com/watch?v=\(videoID)"
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(.failure(.parsingFailed))
                }
                return
            }
            
            self?.extractCaptionsURL(from: html) { captionsResult in
                switch captionsResult {
                case .success(let captionsURL):
                    self?.fetchCaptionsXML(from: captionsURL, completion: completion)
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    private func extractCaptionsURL(from html: String, completion: @escaping (Result<String, YouTubeTranscriptError>) -> Void) {
        // Look for captions data in ytInitialPlayerResponse or playerCaptionsTracklistRenderer
        guard let captionsJSON = extractPlayerResponse(from: html) else {
            completion(.failure(.noTranscriptAvailable))
            return
        }
        
        guard let data = captionsJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            completion(.failure(.parsingFailed))
            return
        }
        
        // Navigate: captions > playerCaptionsTracklistRenderer > captionTracks > [0] > baseUrl
        guard let captions = json["captions"] as? [String: Any],
              let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
              let tracks = renderer["captionTracks"] as? [[String: Any]],
              !tracks.isEmpty else {
            completion(.failure(.noTranscriptAvailable))
            return
        }
        
        // Prefer English, fall back to first available track
        let englishTrack = tracks.first { track in
            guard let langCode = track["languageCode"] as? String else { return false }
            return langCode.lowercased().hasPrefix("en")
        }
        
        let selectedTrack = englishTrack ?? tracks[0]
        
        guard let baseURL = selectedTrack["baseUrl"] as? String else {
            completion(.failure(.noTranscriptAvailable))
            return
        }
        
        completion(.success(baseURL))
    }
    
    private func extractPlayerResponse(from html: String) -> String? {
        // Try ytInitialPlayerResponse first
        let patterns = [
            "var ytInitialPlayerResponse\\s*=\\s*",
            "ytInitialPlayerResponse\\s*=\\s*"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsHTML = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length))
            
            guard let match = matches.first else { continue }
            
            let startIndex = match.range.location + match.range.length
            if let jsonString = extractJSONObject(from: nsHTML, startingAt: startIndex) {
                return jsonString
            }
        }
        
        return nil
    }
    
    private func extractJSONObject(from nsString: NSString, startingAt index: Int) -> String? {
        var braceCount = 0
        var started = false
        var startPos = index
        
        for i in index..<nsString.length {
            let char = nsString.character(at: i)
            
            if char == UInt16(UnicodeScalar("{").value) {
                if !started {
                    started = true
                    startPos = i
                }
                braceCount += 1
            } else if char == UInt16(UnicodeScalar("}").value) {
                braceCount -= 1
                if started && braceCount == 0 {
                    let range = NSRange(location: startPos, length: i - startPos + 1)
                    return nsString.substring(with: range)
                }
            }
            
            // Safety: don't scan more than 2MB
            if i - index > 2_000_000 { break }
        }
        
        return nil
    }
    
    private func fetchCaptionsXML(from urlString: String, completion: @escaping (Result<String, YouTubeTranscriptError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.parsingFailed))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error.localizedDescription)))
                }
                return
            }
            
            guard let data = data, let xmlString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(.failure(.parsingFailed))
                }
                return
            }
            
            let transcript = self.parseTimedTextXML(xmlString)
            
            DispatchQueue.main.async {
                if transcript.isEmpty {
                    completion(.failure(.noTranscriptAvailable))
                } else {
                    completion(.success(transcript))
                }
            }
        }.resume()
    }
    
    private func parseTimedTextXML(_ xml: String) -> String {
        // Extract text content from <text> tags in the timedtext XML
        let pattern = "<text[^>]*>([^<]*)</text>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return "" }
        
        let nsXML = xml as NSString
        let matches = regex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsXML.length))
        
        let segments = matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let text = nsXML.substring(with: match.range(at: 1))
            return decodeHTMLEntities(text)
        }
        
        return segments.joined(separator: " ")
    }
    
    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&#x27;", "'"),
            ("&#x2F;", "/"),
            ("&nbsp;", " ")
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Handle numeric entities like &#123;
        if let numericRegex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let nsResult = result as NSString
            let numericMatches = numericRegex.matches(in: result, options: [], range: NSRange(location: 0, length: nsResult.length))
            for match in numericMatches.reversed() {
                if match.numberOfRanges > 1 {
                    let codeStr = nsResult.substring(with: match.range(at: 1))
                    if let code = Int(codeStr), let scalar = Unicode.Scalar(code) {
                        result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                    }
                }
            }
        }
        return result
    }
}
