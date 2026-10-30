import Foundation
import Combine

// MARK: - Persona store (selected tutor monster)

/// Holds the user's chosen tutor-monster persona by id. Defaults to the safe
/// fallback until onboarding sets one.
final class PersonaStore: ObservableObject {
    static let shared = PersonaStore()
    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
    private let key = SGContract.Keys.selectedPersonaID

    @Published var selectedID: String {
        didSet { persistSelection() }
    }

    init(defaults: UserDefaults = .standard, sharedDefaults: UserDefaults? = SGContract.sharedDefaults) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        selectedID = MonsterPersona.with(id: defaults.string(forKey: key)
            ?? sharedDefaults?.string(forKey: key)).id
        // Migrate an existing app-local choice before any shield is rendered.
        persistSelection()
    }

    var persona: MonsterPersona { MonsterPersona.with(id: selectedID) }

    func select(_ persona: MonsterPersona) { selectedID = persona.id }

    private func persistSelection() {
        let id = MonsterPersona.with(id: selectedID).id
        defaults.set(id, forKey: key)
        sharedDefaults?.set(id, forKey: key)
        sharedDefaults?.synchronize()
    }
}

