import Foundation

// No network, analytics, or shared app-group writes in these persistence tests.
enum Telemetry {
    static func capture(_ error: Error, context: [String: Any], tags: [String: String]) {}
}
enum SGContract {
    static let sharedDefaults: UserDefaults? = nil
    enum Keys { static let onboardingExamDate = "sg_onboardingExamDate" }
}
