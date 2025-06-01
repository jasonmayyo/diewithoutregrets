import Foundation

struct AppSecrets {
    private static let secrets: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            print("🔑 WARNING: Secrets.plist not found or invalid format - API features will be disabled")
            return nil
        }
        return plist
    }()

    static var openAIAPIKey: String? {
        guard let secrets = secrets,
              let key = secrets["OPENAI_API_KEY"] as? String else {
            print("🔑 WARNING: OPENAI_API_KEY not found in Secrets.plist - AI features will be disabled")
            return nil
        }
        return key
    }
}
