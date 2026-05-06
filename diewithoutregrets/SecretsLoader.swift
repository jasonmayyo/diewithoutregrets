//
//  SecretsLoader.swift
//  diewithoutregrets
//
//  Typed accessor for build-time secrets injected via xcconfig → Info.plist.
//
//  Add a new secret in three places:
//    1. Define the key in `Secrets.xcconfig` with an env-var fallback,
//       e.g.  MY_NEW_SECRET = $(MY_NEW_SECRET)
//    2. Define the same key in `Secrets.local.xcconfig.example` (and your
//       own `Secrets.local.xcconfig` for local dev).
//    3. Add an `Info.plist` entry whose value is `$(MY_NEW_SECRET)`.
//    4. Add a static accessor here that reads the Info.plist key.
//
//  The OpenAI key was historically read inline in AutoGenerateFlashcardSheet
//  via Bundle.main.object(forInfoDictionaryKey:). Don't introduce a parallel
//  pattern — extend this enum instead.
//

import Foundation

enum SecretsLoader {

    /// Public Sentry DSN. Sentry treats DSNs as public (they only allow
    /// writing events, not reading), but we still keep it out of source
    /// control so each app/environment can be swapped without a code edit.
    ///
    /// **xcconfig stores the host-only portion** of the DSN — i.e. everything
    /// after `https://`. This is because Xcode 26's xcconfig parser treats
    /// `//` as a line comment, and the `$()//` escape trick used on older
    /// Xcode versions silently truncates the value at build time. We prepend
    /// the `https://` scheme here so the value handed to SentrySDK is a
    /// complete, parseable URL.
    ///
    /// Sentry DSNs are always HTTPS, so hardcoding the scheme is safe.
    static var sentryDSN: String {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !host.isEmpty,
              host != "REPLACE_ME_SENTRY_DSN" else {
            // assertionFailure trips in DEBUG so we notice locally; in
            // Release we swallow it and Sentry init will be a no-op below.
            assertionFailure("SENTRY_DSN missing from Info.plist — did you set it in Secrets.local.xcconfig?")
            return ""
        }
        // Defensive: if someone pastes a full URL anyway (with scheme), use
        // it as-is. Otherwise prepend the scheme.
        if host.hasPrefix("https://") || host.hasPrefix("http://") {
            return host
        }
        return "https://" + host
    }
}
