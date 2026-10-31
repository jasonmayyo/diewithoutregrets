import SwiftUI

/// Standalone preview host: no analytics, app-group entitlement, or live
/// blocking. The shield appearance is read directly from its production source.
@main
struct ShieldPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            StudyGuardShieldDesignPreview(persona: selectedPersona)
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : .light)
        }
    }

    private var selectedPersona: MonsterPersona {
        let args = ProcessInfo.processInfo.arguments
        return MonsterPersona.with(id: args.first(where: { $0.hasPrefix("--persona=") })?
            .replacingOccurrences(of: "--persona=", with: ""))
    }
}
