
import Foundation

struct AppSecrets {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            fatalError("Secrets.plist not found or invalid format")
        }
        return plist
    }()

    static var openAIAPIKey: String {
        guard let key = secrets["OPENAI_API_KEY"] as? String else {
            fatalError("OPENAI_API_KEY not found in Secrets.plist")
        }
        return key
    }
}
