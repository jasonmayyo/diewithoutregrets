import SwiftUI

/// Standalone preview host: no analytics, app-group entitlement, or live
/// blocking. The shield appearance is read directly from its production source.
@main
struct ShieldPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            StudyGuardShieldDesignPreview(minutes: 15)
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : .light)
        }
    }
}
