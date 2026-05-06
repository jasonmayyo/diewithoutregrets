# Crash & Error Reporting

Study Guard uses **Sentry** for crash and error reporting and **PostHog** for product
analytics. The two run side-by-side and cross-reference each other via tags so you
can jump from a Sentry issue to the matching PostHog session replay.

## Architecture at a glance

```
┌──────────────────┐                       ┌──────────────────┐
│  Sentry          │ ←── crashes/errors ── │  Study Guard     │
│  (errors)        │ ── tags posthog_id ──→│                  │
└──────────────────┘                       │  iOS SwiftUI app │
                                           │                  │
┌──────────────────┐                       │                  │
│  PostHog         │ ←── analytics ─────── │                  │
│  (analytics)     │                       └──────────────────┘
└──────────────────┘
```

- **Sentry** initialised in `AppDelegate.didFinishLaunchingWithOptions` via
  `startSentry()` (defined in `AppDelegate.swift`). DSN comes from
  `Info.plist → SENTRY_DSN`, populated via `Secrets.xcconfig` build settings.
- **PostHog** initialised right after Sentry (Sentry must come first so its
  crash handlers install before anything else can crash).
- **Linking**: `posthog_distinct_id` is attached as a Sentry tag on every
  event (refreshed on every app foreground via a `didBecomeActive`
  observer). `posthog_session_id` will be added once we bump posthog-ios
  to 3.25.0+ — that's the version that introduced `getSessionId()`. We're
  on 3.24.0 currently. The TODO is in `attachPostHogIdentifiersToSentry()`.

## What Sentry captures automatically

You don't need to wire any of these — the SDK handles them:

- Mach exceptions, fatal signals (SIGSEGV, SIGABRT, SIGBUS, etc.)
- Unhandled Objective-C and C++ exceptions
- Swift `fatalError`, `assert`, `precondition`
- App Hang Detection (UI freezes ≥ 2s on the main thread)
- Watchdog Terminations (the iOS "0x8badf00d" kills)
- Start-up crashes (the SDK init waits up to 5s synchronously to flush events
  if the app crashes within 2s of init — that's why `startSentry()` runs
  before everything else in `didFinishLaunchingWithOptions`)
- HTTP Client Errors (4xx/5xx responses on URLSession)

## What you wire manually

- **Handled errors** inside `catch { }`: use `Telemetry.capture(error, …)`.
- **One-off concerns** that aren't `Error` types: `Telemetry.captureMessage(…)`.
- **User-action breadcrumbs**: `Telemetry.breadcrumb(…)`. Crumbs ride along
  with the next 100 events.

```swift
do {
    try saveDeck()
} catch {
    Telemetry.capture(error,
        tags: ["feature": "decks"],
        context: ["deck_id": deck.id])
}

Telemetry.captureMessage("Buyback notification scheduled twice",
    level: .warning)

Telemetry.breadcrumb("Opened paywall",
    category: "ui",
    data: ["surface": "profile"])
```

### When to use which

| Situation                                                | API                       |
| -------------------------------------------------------- | ------------------------- |
| `catch { }` block where we previously `print`ed          | `Telemetry.capture`       |
| "Shouldn't ever happen but let's not crash"              | `Telemetry.captureMessage` |
| User did a thing we want to see in the lead-up to crashes | `Telemetry.breadcrumb`    |

## Environments

`AppEnvironment.current` produces a three-way split that ends up as Sentry's
`environment` field and as a tag on every event:

| Build                       | Environment   |
| --------------------------- | ------------- |
| Run from Xcode (DEBUG)      | `debug`       |
| TestFlight or sandbox       | `testflight`  |
| App Store install           | `production`  |

Filter Sentry's issue list by `environment:production` to see only paying
users; `environment:testflight` for staging signal.

**Debug events never reach Sentry** — `beforeSend` drops them so local dev
doesn't pollute the dashboard.

## Tags on every event

`startSentry()` seeds the initial scope with these:

- `app_name = Study Guard` — so a future shared org-level view can filter
  per app (Study Guard vs One Thing vs etc.)
- `environment = debug | testflight | production`
- `posthog_distinct_id` — the RevenueCat anonymous user ID PostHog uses
- `posthog_session_id` — when the installed PostHog version exposes it

To add new always-present tags, edit the `initialScope` block in
`startSentry()`. To add per-event tags, pass them to `Telemetry.capture(...)`.

## Secrets

| Secret              | Where it lives                                | Committed? |
| ------------------- | --------------------------------------------- | ---------- |
| `SENTRY_DSN`        | `Secrets.local.xcconfig` → `Info.plist` (host-only, see below) | No |
| `SENTRY_AUTH_TOKEN` | `.sentryclirc` at repo root                   | No         |
| OpenAI key          | `Secrets.local.xcconfig` (existing)           | No         |

### Why `SENTRY_DSN` is stored host-only

Xcode 26's xcconfig parser treats `//` as a line comment and silently
truncates the value at build time, so we store everything *after* the
`https://` scheme:

```ini
# In Secrets.local.xcconfig
SENTRY_DSN = abc123@o123.ingest.us.sentry.io/456
```

`SecretsLoader.sentryDSN` prepends `https://` at runtime so SentrySDK
still receives a complete URL. Sentry DSNs are always HTTPS so this is
safe.

If you paste a full DSN (with `https://`) into the xcconfig anyway,
SecretsLoader detects the scheme and uses the value as-is — but you'll
hit the truncation bug and only `https:` will reach the SDK, producing a
"Host component of DSN is missing" error at app launch.

### Xcode Cloud env var: same host-only format

Set `SENTRY_DSN` in your Xcode Cloud workflow to the same host-only
value (no `https://` prefix). The xcconfig fallback `$(SENTRY_DSN)`
will pick the env var up at build time and write the host into Info.plist
exactly the same way as a local build.

`.sentryclirc` and `Secrets.local.xcconfig` are both in `.gitignore`. The
DSN is technically public (Sentry treats it as write-only), but we keep
it out of source control for the same reason any other config gets pulled
into xcconfig: easy to swap per environment, easy to rotate.

For Xcode Cloud / CI, set both `SENTRY_DSN` and `SENTRY_AUTH_TOKEN` as
environment variables in the workflow's "Environment Variables" pane (same
as `OPENAI_API_KEY` already is). The xcconfig fallback `$(SENTRY_DSN)`
picks the env var up automatically; the dSYM upload script reads
`SENTRY_AUTH_TOKEN` directly from the environment when `.sentryclirc` is
absent.

## dSYMs (debug symbols)

Stack traces only become readable when Sentry has the matching dSYM file
for the binary that crashed. The Run Script build phase **"Upload Debug
Symbols to Sentry"** uploads them automatically on every Release build.

### Verifying dSYM uploads

1. Archive the app (Product → Archive in Xcode).
2. Wait for the build to finish — the upload runs at the end of the Archive.
3. Open Sentry → **Project Settings → Debug Files**. Look for entries with
   the matching `MARKETING_VERSION` (currently 1.18) and `CURRENT_PROJECT_VERSION`.
4. If they're missing, check the Xcode build log for `sentry-cli` warnings.
   Common causes:
   - `sentry-cli not installed` — `brew install getsentry/tools/sentry-cli`.
   - `auth required` — `.sentryclirc` is missing or the token expired.
   - `For install builds only = YES` on the build phase — must be **off**.

## Test crash menu (DEBUG only)

There's a "Sentry — test crash menu" section inside the **Debug tab** (the
fourth tab, gated by `#if DEBUG`, in `ContentView.swift → DebugView`). It
emits one of every event type Sentry should capture. **Important: crashes
only get reported when the debugger is NOT attached.** Two extra subtleties:

- **Handled paths (`Capture handled error`, `Capture message`)** flow
  through `beforeSend`, which drops every event when
  `AppEnvironment.current == .debug`. So a normal Run-from-Xcode build will
  silently no-op on those buttons. Use TestFlight (env=`testflight`) or a
  Release build run without the debugger (env=`production`) to see them.
- **Crash paths (`fatalError`, `NSException`, `SIGSEGV`)** bypass
  `beforeSend` because the crash file is written by the signal handler
  before Sentry has any chance to filter. They DO reach Sentry from a
  Release build run from Xcode — but only if the debugger isn't catching
  the signal first.

To verify:

1. In Xcode: Edit Scheme → Run → Info → uncheck "Debug executable", **or**
2. Build a TestFlight or Release archive and install on device.

Then exercise each button:

| Button                          | Expected outcome on Sentry                                                       |
| ------------------------------- | -------------------------------------------------------------------------------- |
| Capture handled error           | New issue, mechanism `is_handled: true`, `app_name: Study Guard` tag             |
| Capture message                 | Separate event with the test message                                             |
| Crash (Swift `fatalError`)      | Crash reported on next launch with symbolicated `.swift` filename and line       |
| Crash (NSException)             | Crash reported with symbolicated frames                                          |
| Crash (SIGSEGV via null deref)  | Crash reported with symbolicated frames showing the null deref                   |

Every event should also have:
- The current `release` (e.g. `com.jasonmayo.diewithoutregrets@1.18+2`)
- `environment: testflight` or `production`
- `posthog_distinct_id` (and `posthog_session_id` if available)

## Jumping from Sentry → PostHog session replay

PostHog's session replays are the highest-bandwidth way to see what the
user did before a crash. To find the replay for a Sentry issue:

1. Open the issue detail in Sentry.
2. Scroll to the Tags panel; copy the `posthog_session_id` value.
3. In PostHog: Activity → Session Replay → search by session ID.

If `posthog_session_id` isn't present (older PostHog versions don't expose
it), fall back to `posthog_distinct_id` and filter PostHog's replays by
that user.

## Sample rates (current settings)

```swift
options.sessionReplay.sessionSampleRate = 0.0   // no random replays
options.sessionReplay.onErrorSampleRate = 1.0   // 100% replays on errors
options.tracesSampleRate                = 0.0   // no perf tracing yet
options.sendDefaultPii                  = false // no IP/user-agent
```

We're starting with errors-only. Once we know the error volume we can
revisit Performance / Tracing / Profiling separately.

## Adding a new tag or context

Edit `startSentry()` in `AppDelegate.swift`:

```swift
options.initialScope = { scope in
    scope.setTag(value: "Study Guard", key: "app_name")
    scope.setTag(value: AppEnvironment.current.rawValue, key: "environment")
    scope.setTag(value: "your_new_tag_value", key: "your_new_tag_key")  // ← add here
    return scope
}
```

For per-event tags, pass them through `Telemetry.capture(tags: …)` instead.
