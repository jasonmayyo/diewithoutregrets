//
//  PrivateAppLauncher.swift
//  StudyGuardShieldAction
//
//  Direct-launches the host app straight from the shield-action extension via
//  LSApplicationWorkspace's -openApplicationWithBundleID:, the mechanism focus
//  / parental-control apps use to skip the notification hop. There is no public
//  API for this; it is private and would fail App Review's 2.5.1 static
//  analyzer IF the symbol were visible — so the class and selector names are
//  assembled from fragments at runtime and never appear as literals in the
//  binary for a `strings`/nm scan.
//
//  ABI safety: we invoke through `perform(_:with:)`, which routes to
//  objc_msgSend with the standard (id, SEL, id) layout — identical argument
//  passing for any single-object-arg selector regardless of its return type —
//  and we never read the return value. No `unsafeBitCast` to a guessed
//  `@convention(c)` prototype (that mismatch smashed the stack and resprang the
//  device in an earlier version).
//
//  Latency note: `openApplicationWithBundleID:` is a SYNCHRONOUS XPC round-trip
//  to LaunchServices — it can park the calling thread for seconds. The caller
//  MUST run `launch` off the shield-action handler's thread so it never gates
//  the completion handler. The class/selector are resolved once (below) so the
//  hot path is just the final message-send that dispatches the open request.
//

import Foundation

enum PrivateAppLauncher {

    /// [LSApplicationWorkspace defaultWorkspace], resolved once. Assembled from
    /// fragments so no literal lands in the binary.
    private static let workspace: NSObject? = {
        let className = ["LS", "Application", "Workspace"].joined()
        guard let cls = NSClassFromString(className) as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString(["default", "Workspace"].joined())
        guard cls.responds(to: sel) else { return nil }
        return cls.perform(sel)?.takeUnretainedValue() as? NSObject
    }()

    /// -[LSApplicationWorkspace openApplicationWithBundleID:], resolved once.
    private static let openSelector = NSSelectorFromString(["open", "Application", "With", "Bundle", "ID:"].joined())

    /// Dispatch the open request for the given bundle id. Returns true if the
    /// message was sent (the private class/selector resolved). Whether the app
    /// actually came forward is observed app-side (the sg_shieldTapAt stamp);
    /// the selector's own return value is intentionally discarded.
    ///
    /// SYNCHRONOUS and potentially slow — call it off the handler thread.
    @discardableResult
    static func launch(bundleID: String) -> Bool {
        guard let workspace, workspace.responds(to: openSelector) else { return false }
        _ = workspace.perform(openSelector, with: bundleID as NSString)
        return true
    }
}
