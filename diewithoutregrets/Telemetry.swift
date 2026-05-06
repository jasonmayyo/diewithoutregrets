//
//  Telemetry.swift
//  diewithoutregrets
//
//  Centralised wrapper over Sentry for handled errors, ad-hoc messages,
//  and breadcrumbs. Sentry's iOS SDK auto-captures unhandled crashes,
//  signals, app hangs, watchdog terminations, and HTTP 4xx/5xx responses
//  on its own — Telemetry is for the *handled* paths the SDK can't see
//  (everything inside a `catch { }`, every "this shouldn't happen but
//  let's not crash" branch, and the breadcrumb trail leading up to a
//  future event).
//
//  Use:
//
//      do {
//          try doRiskyThing()
//      } catch {
//          Telemetry.capture(error,
//              tags: ["feature": "sync"],
//              context: ["endpoint": url.path])
//      }
//
//      Telemetry.captureMessage("Unexpected nil deck", level: .warning)
//
//      Telemetry.breadcrumb("Opened paywall", category: "ui",
//          data: ["surface": "profile"])
//
//  Tags vs context vs data:
//    • tags    → low-cardinality, indexed, filterable in Sentry's search.
//                Use for things like feature, surface, source. Do NOT put
//                a user ID, session ID, or anything unbounded here.
//    • context → arbitrary structured data attached to a single event,
//                shown in the issue detail. Good for "here was the input
//                that caused this" diagnostic dumps.
//    • breadcrumb data → arbitrary structured data attached to the *crumb*
//                that precedes future events. The last 100 crumbs ride
//                along with every event Sentry sends.
//

import Foundation
import Sentry

enum Telemetry {

    /// Capture a caught Error. Use inside every `catch` block we care about.
    /// Source location is captured automatically via #file/#function/#line so
    /// we can find the catch site in the issue detail even after stripping.
    static func capture(
        _ error: Error,
        context: [String: Any] = [:],
        tags: [String: String] = [:],
        level: SentryLevel = .error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        SentrySDK.capture(error: error) { scope in
            scope.setLevel(level)
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
            var ctx = context
            ctx["source_file"] = (file as NSString).lastPathComponent
            ctx["source_function"] = function
            ctx["source_line"] = line
            scope.setContext(value: ctx, key: "handled_error")
        }
    }

    /// Capture a freeform string message. Use sparingly — prefer `capture`
    /// with a real Error so Sentry can group by error type.
    static func captureMessage(
        _ message: String,
        level: SentryLevel = .warning,
        tags: [String: String] = [:]
    ) {
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
        }
    }

    /// Add a breadcrumb. Crumbs ride along with the next event Sentry sends
    /// (capped at the last 100), giving you a trace of what the user was
    /// doing in the seconds before a crash.
    static func breadcrumb(
        _ message: String,
        category: String,
        level: SentryLevel = .info,
        data: [String: Any] = [:]
    ) {
        let crumb = Breadcrumb(level: level, category: category)
        crumb.message = message
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
    }
}
