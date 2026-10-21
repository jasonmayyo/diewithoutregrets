import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Shared by earned and emergency unlocks. This only opens an app: it never
/// grants time or spends an emergency unlock. Dependencies make lifecycle and
/// retry behaviour testable without pretending a simulator runs Instagram.
@MainActor
final class UnlockAppReturn: ObservableObject {
    @Published private(set) var isOpening = false
    @Published var showFallback = false

    private let openURL: (URL, @escaping (Bool) -> Void) -> Void
    private let isActive: () -> Bool
    private let isBackground: () -> Bool
    private let schedule: (TimeInterval, @escaping @MainActor () -> Void) -> Void
    private let now: () -> Date
    private let record: (String) -> Void
    private var requestID: UUID?
    private var openSucceeded = false
    private var leftApp = false
    private var onReturned: (() -> Void)?

    init(openURL: @escaping (URL, @escaping (Bool) -> Void) -> Void,
         isActive: @escaping () -> Bool,
         isBackground: @escaping () -> Bool,
         schedule: @escaping (TimeInterval, @escaping @MainActor () -> Void) -> Void,
         now: @escaping () -> Date = Date.init,
         record: @escaping (String) -> Void = { _ in }) {
        self.openURL = openURL
        self.isActive = isActive
        self.isBackground = isBackground
        self.schedule = schedule
        self.now = now
        self.record = record
    }

    func open(_ destination: ShieldReturnDestination?, onReturned: @escaping () -> Void) {
        guard !isOpening else { return }
        guard let destination else {
            record("no destination")
            showFallback = true
            return
        }
        let id = UUID()
        requestID = id
        self.onReturned = onReturned
        openSucceeded = false
        leftApp = false
        showFallback = false
        isOpening = true
        record("start \(destination.name)")
        // ManagedSettings has no shield-removal completion callback. Allow a
        // short settling window, especially for the immediate emergency path.
        schedule(0.35) { [weak self] in
            self?.attempt(destination, number: 1, id: id)
        }
    }

    private func attempt(_ destination: ShieldReturnDestination, number: Int, id: UUID) {
        guard requestID == id else { return }
        // Never bring another app forward after the user has left this flow.
        guard isActive(), !leftApp else { cancel(); return }
        let started = now()
        openURL(destination.url) { [weak self] opened in
            guard let self, self.requestID == id else { return }
            let elapsed = self.now().timeIntervalSince(started)
            self.record("attempt \(number): \(opened ? "accepted" : "rejected") (\(Int(elapsed * 1000))ms)")
            self.leftApp = self.leftApp || self.isBackground()
            if opened {
                self.openSucceeded = true
                self.finishIfReturned()
                // An accepted request without a background transition must
                // not leave the button spinning forever.
                self.schedule(2) { [weak self] in
                    guard let self, self.requestID == id else { return }
                    self.fail("no app switch observed")
                }
            } else if number == 1, elapsed < 0.5, self.isActive(), !self.leftApp {
                // Retry only an immediate refusal, once. A slower rejection
                // may be the user cancelling an iOS prompt: don't reopen it.
                self.schedule(0.65) { [weak self] in
                    self?.attempt(destination, number: 2, id: id)
                }
            } else {
                self.fail("return unavailable")
            }
        }
    }

    func didEnterBackground() {
        guard isOpening else { return }
        leftApp = true
        finishIfReturned()
    }

    func cancel() {
        requestID = nil
        onReturned = nil
        isOpening = false
    }

    private func fail(_ reason: String) {
        record(reason)
        let canPresent = isActive() && !leftApp
        cancel()
        showFallback = canPresent
    }

    private func finishIfReturned() {
        guard isOpening, openSucceeded, leftApp else { return }
        record("app switch observed")
        let completion = onReturned
        cancel()
        completion?()
    }

    static func fallbackMessage(for destination: ShieldReturnDestination?) -> String {
        if let destination {
            return "Couldn't open \(destination.name) automatically. Switch back to it from your Home Screen or app switcher. Your unlocked time is ready."
        }
        return "Switch back to the app you were using from your Home Screen or app switcher. Your unlocked time is ready."
    }
}

#if canImport(UIKit)
extension UnlockAppReturn {
    convenience init() {
        self.init(
            openURL: { url, completion in
                // Diagnostic only: don't gate the real open on this query.
                // The supported schemes are declared in Info.plist.
                Self.recordDiagnostic("handler available: \(UIApplication.shared.canOpenURL(url))")
                UIApplication.shared.open(url, options: [:], completionHandler: completion)
            },
            isActive: { UIApplication.shared.applicationState == .active },
            isBackground: { UIApplication.shared.applicationState == .background },
            schedule: { delay, action in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    action()
                }
            },
            record: Self.recordDiagnostic
        )
    }

    private static func recordDiagnostic(_ event: String) {
        // Bounded, on-device diagnostics, available in the existing debug
        // state dump. No app destinations are sent to analytics.
        let key = "sg_appReturnLog"
        var log = UserDefaults.standard.stringArray(forKey: key) ?? []
        log.append("\(Date().formatted(date: .omitted, time: .standard)): \(event)")
        UserDefaults.standard.set(Array(log.suffix(12)), forKey: key)
    }
}
#endif
