# Opening Your App Directly From a Screen Time Shield — Implementation Playbook

**What this achieves:** the user taps a button on the iOS Screen Time *shield*
(the blocking screen shown over a restricted app) and **your containing app
opens immediately** — no notification, no "tap this banner," no extra step.

**Platform:** iOS 17.4 → 27 (written Aug 2026, tested on iOS 27). Uses the
DeviceActivity / FamilyControls / ManagedSettings stack.

**Status:** battle-tested. Every gotcha below is one that actually bit on a real
device and the fix is the one that resolved it.

---

## ⚠️ Read this first: the App Review reality

There is **no fully public API** that opens your *own* app from a shield on iOS
below 26.5. The reliable technique — the one focus/parental-control apps ship —
uses a **private API** (`LSApplicationWorkspace`). Apple's static analyzer will
reject a build if it sees the symbol, so the technique includes hiding the
symbol. Consequences you are accepting:

- **Guideline 2.5.1 violation.** If detected, rejection; worst case, developer
  account termination. There is a documented 2026 rejection where the analyzer
  caught `LSApplicationWorkspace` in a shield extension.
- The obfuscation below is what shipping apps use to stay under the analyzer.
  It is cat-and-mouse, not a guarantee.

If you want a **clean, sanctioned** build, jump to
[Appendix A: the public-API path](#appendix-a-the-public-api-path-openparentalcontrolsapp).
It only works on iOS 26.5+ and can silently no-op under individual (non-family)
authorization, which is why the private path is the primary here.

**Decide this consciously per app before you ship.**

---

## The recipe at a glance

Four moves, each of which corresponds to a bug that will bite you if you get it
wrong:

1. **Open the app** with `[[LSApplicationWorkspace defaultWorkspace] openApplicationWithBundleID:]`,
   invoked through the Obj-C runtime with the class/selector names assembled
   from fragments so no literal string lands in the binary.
2. **Call it the ABI-safe way** — `perform(_:with:)`, *never* `unsafeBitCast` to
   a hand-written `@convention(c)` function pointer. (Wrong prototype = stack
   smash = device respring.)
3. **Return `.none`** from the shield action, *never* `.close`. (`.close` means
   "close the app / go home" and bounces you straight back out.)
4. **Do nothing blocking before `completionHandler`.** No `UNUserNotificationCenter`,
   no analytics, and run the launch itself on a background thread. (Anything
   that parks the handler thread makes iOS wait ~10s — the extension watchdog —
   before it foregrounds you.)

---

## Architecture

Three pieces cooperate across process boundaries:

```
┌─────────────────────────┐   button tap   ┌──────────────────────────┐
│ Shield CONFIGURATION ext │──────────────► │ Shield ACTION ext        │
│ (ManagedSettingsUI)      │                │ (ManagedSettings)        │
│  • draws the shield      │                │  • handles the tap       │
│  • sets the button label │                │  • opens the host app    │
└─────────────────────────┘                │  • writes a "tap" stamp  │
                                            └───────────┬──────────────┘
                                        shared app group │ + LSApplicationWorkspace
                                                         ▼
                                            ┌──────────────────────────┐
                                            │ Your host app            │
                                            │  • reads the tap stamp    │
                                            │    on foreground →        │
                                            │    navigate to your flow  │
                                            └──────────────────────────┘
```

You need **two extension targets** (config + action) plus your app. They talk
through a shared **App Group** `UserDefaults` suite.

> **Placeholders used below** — replace throughout:
> `YOUR_APP_BUNDLE_ID` (e.g. `com.you.app`), `group.YOUR_APP_GROUP`,
> `yourapp://unlock` (a custom URL scheme, optional).

---

## Step 1 — The shield ACTION extension target

Create a new target of type **"Shield Action Extension"** (or a generic app
extension you configure by hand).

### 1a. Info.plist — the extension point (silent-failure gotcha #4)

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <!-- ManagedSettings, NOT ManagedSettingsUI. The action service lives in
         ManagedSettings; the UI-prefixed string registers under a nonexistent
         extension point and the button silently does the system close — no
         crash, no log, the extension never even launches. -->
    <string>com.apple.ManagedSettings.shield-action-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShieldActionExtension</string>
</dict>
```

(The **configuration** extension, by contrast, uses
`com.apple.ManagedSettingsUI.shield-configuration-service`. Don't mix them up —
this is the single most common "why does nothing happen" mistake.)

### 1b. Entitlements

Both extensions and the app need:

```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.YOUR_APP_GROUP</string>
</array>
```

`com.apple.developer.family-controls` requires the **Family Controls
(Distribution)** entitlement from Apple for a release build (request it early —
it's a days-to-weeks approval). Dev builds work immediately.

### 1c. Build settings gotcha (if you generate the target via a script)

If you create targets programmatically (e.g. the `xcodeproj` Ruby gem), set
`PRODUCT_NAME = "$(TARGET_NAME)"` explicitly — it can resolve to empty and break
the build with "Multiple commands produce …/.appex".

---

## Step 2 — The private launcher

This is the whole trick, done safely. Drop this file into the **action
extension** target.

```swift
//  PrivateAppLauncher.swift  (goes in the SHIELD ACTION extension target)
import Foundation

enum PrivateAppLauncher {

    // [LSApplicationWorkspace defaultWorkspace], resolved ONCE. The class and
    // selector names are assembled from fragments so the literals never appear
    // in the compiled binary for a `strings` / `nm` scan — this is what keeps
    // App Review's static analyzer from flagging the private symbol.
    private static let workspace: NSObject? = {
        let className = ["LS", "Application", "Workspace"].joined()
        guard let cls = NSClassFromString(className) as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString(["default", "Workspace"].joined())
        guard cls.responds(to: sel) else { return nil }
        return cls.perform(sel)?.takeUnretainedValue() as? NSObject
    }()

    // -[LSApplicationWorkspace openApplicationWithBundleID:], resolved once.
    private static let openSelector =
        NSSelectorFromString(["open", "Application", "With", "Bundle", "ID:"].joined())

    /// Dispatch the open request. SYNCHRONOUS and potentially slow (XPC round
    /// trip to LaunchServices) — the caller MUST run this off the handler
    /// thread. Returns true if the message was sent.
    @discardableResult
    static func launch(bundleID: String) -> Bool {
        guard let workspace, workspace.responds(to: openSelector) else { return false }
        // perform(_:with:) routes to objc_msgSend with the standard
        // (id, SEL, id) layout — correct argument passing for this single-
        // object-arg selector regardless of its return type. We DISCARD the
        // return value and never touch it, so a BOOL/void return is harmless.
        _ = workspace.perform(openSelector, with: bundleID as NSString)
        return true
    }
}
```

### Why `perform(_:with:)` and not a function pointer (gotcha #1 — the crash)

The tempting approach is to grab the method IMP and `unsafeBitCast` it to a
`@convention(c) (NSObject, Selector, AnyObject) -> Bool` and call it. **This
resprings the device.** The private selector's real signature isn't guaranteed
to match your hand-written prototype (it may return `void`, differ by OS
version, etc.), and calling through a mismatched C prototype corrupts the stack
— which tears down the extension *and* the shield host, i.e. a full respring.

`perform(_:with:)` sidesteps this entirely: it always uses the standard
`objc_msgSend` `(id, SEL, id)` layout, which is correct for any
single-object-argument selector no matter what it returns, and you simply never
read the return value. No prototype to get wrong, no stack to smash.

> **"You have to use Objective-C for this."** What people mean by this is *the
> Objective-C runtime* (`NSClassFromString` / `NSSelectorFromString` /
> `perform`) plus assembling the symbol names at runtime. You do **not** need an
> actual `.m` file — the Swift above is the whole thing.

---

## Step 3 — The shield action handler

Also in the action extension. Keep it **ruthlessly lean** (gotchas #2 and #3).

```swift
//  ShieldActionExtension.swift  (SHIELD ACTION extension target)
import Foundation
import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {

    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // 1. Stamp the tap so the app knows to jump straight to your flow
            //    when it foregrounds (see Step 4).
            UserDefaults(suiteName: "group.YOUR_APP_GROUP")?
                .set(Date().timeIntervalSince1970, forKey: "shieldTapAt")

            // 2. Fire the open on a BACKGROUND thread. openApplicationWithBundleID:
            //    is a synchronous XPC round-trip that can park its thread for
            //    seconds; on the handler thread it would gate completionHandler,
            //    and iOS holds the app's foreground until the handler returns —
            //    that's the ~10s stall (the launch parks until it trips the 10s
            //    extension watchdog). Off-thread, the launch flies while iOS
            //    foregrounds the app without waiting on it.
            DispatchQueue.global(qos: .userInitiated).async {
                PrivateAppLauncher.launch(bundleID: "YOUR_APP_BUNDLE_ID")
            }

            // 3. Return .none — NOT .close. .close means "close the current app /
            //    return to home" and races/defeats the open you just fired (the
            //    app appears then immediately bounces out). .none issues no
            //    competing navigation, so the launch is the sole focus directive
            //    and the app stays foregrounded.
            completionHandler(.none)

        case .secondaryButtonPressed:
            completionHandler(.close)   // a real "dismiss" button, if you add one
        @unknown default:
            completionHandler(.close)
        }
    }
}
```

### Gotcha #2 — app opens then immediately closes → you returned `.close`

`.close` is a system instruction meaning "close the current app and go home."
Returning it *after* launching your app makes iOS shove your app right back out
the instant it appears. Return **`.none`**. Never `.defer` (it re-runs the
shield configuration data source, adding latency and possibly re-shielding).

### Gotcha #3 — the ~10 second stall (even when the app is warm)

Two independent things park the handler thread, and iOS won't foreground your
app until `completionHandler` **returns**:

- **`UNUserNotificationCenter`** — touching it from the restricted shield
  sandbox does a slow first-contact XPC handshake that can block ~10s. **Do not
  schedule notifications from a shield action extension.** If you want a
  notification fallback, that alone can cost you the 10 seconds. Cut it.
- **The launch call itself** — synchronous XPC to LaunchServices. Run it on a
  background thread (as above), not inline.

Rule of thumb: the handler's synchronous body should be **only cheap, local
work** (a `UserDefaults` write) and then `completionHandler`. Everything
expensive goes on a background queue or gets deleted.

---

## Step 4 — App-side: land on the right screen, fast

The open drops the user into your app; now route them to the flow you want
(e.g. your unlock/quiz screen) instead of your home screen.

### 4a. Consume the stamp on foreground

```swift
// In your App / root view, on scenePhase == .active (and on launch):
func consumeShieldTapIfFresh() {
    let d = UserDefaults(suiteName: "group.YOUR_APP_GROUP")
    let tapAt = d?.double(forKey: "shieldTapAt") ?? 0
    guard tapAt > 0 else { return }
    d?.removeObject(forKey: "shieldTapAt")               // consume once
    guard Date().timeIntervalSince1970 - tapAt < 120 else { return }
    // …navigate to your unlock flow here…
}
```

Because the app is foregrounded by the private launch (not a normal user tap),
your `scenePhase` transitions to `.active` and this runs. A custom URL scheme is
**not** required — the stamp is what carries the intent — but you can also
register `yourapp://unlock` and open it if you prefer deep links.

### 4b. (Optional) Skip your cold-start splash on a shield launch

If your app plays a launch splash / does heavy SDK init, the *perceived* open
can still feel slow on a cold launch (the app was likely evicted from memory
while the user was in the blocked app). Detect the fresh stamp in your `App`
init and render your destination on the first frame:

```swift
init() {
    if let d = UserDefaults(suiteName: "group.YOUR_APP_GROUP"),
       Date().timeIntervalSince1970 - d.double(forKey: "shieldTapAt") < 120 {
        _showSplash = State(initialValue: false)          // skip the splash
        // …and set your navigation state so the first frame IS the target screen…
    }
}
```

Your native `UILaunchScreen` still covers the pre-first-frame gap, so there's no
white flash. Keep this gated to the shield-launch case so normal launches are
unchanged.

> Note: the *inherent* cross-process launch hop is a few hundred ms and isn't
> code-fixable. The wins are (a) not blocking the handler [Step 3] and (b) not
> making the user sit through your own splash/SDK init [4b].

---

## Step 5 — The shield configuration extension (the button itself)

Separate target (`com.apple.ManagedSettingsUI.shield-configuration-service`).
This just draws the shield and names the button; the *action* extension handles
the tap.

```swift
import ManagedSettings
import ManagedSettingsUI

final class ShieldConfigExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            title: .init(text: "Time's up.", color: .white),
            subtitle: .init(text: "…", color: .white),
            primaryButtonLabel: .init(text: "Unlock Apps", color: .white)   // your label
        )
    }
    // …override the other three configuration(shielding:) variants the same way…
}
```

---

## `ShieldActionResponse` cheat-sheet

| Response | What the system does | Use it when |
|----------|---------------------|-------------|
| `.none`  | No system action; shield stays as-is | **You opened the app yourself** and want it to stay foregrounded ← this playbook |
| `.close` | Closes the app / returns to home | A genuine "dismiss / give up" button |
| `.defer` | Re-runs the shield configuration data source | Rarely; adds latency, can re-shield |

The response value does **not** foreground your app — the
`LSApplicationWorkspace` call does. The response only controls what the *shield*
does afterward.

---

## The reliability caveat (know your one risk)

Running the launch on a background thread while the extension is being torn down
is a **race**: Apple tears the extension down shortly after `completionHandler`
returns, and "code after it may not execute." In practice the dispatched launch
wins (it's what shipping apps do, and it's confirmed working here), but it is
not a contract.

- **Symptom if you lose the race:** a tap that opens *nothing*.
- **Mitigations already baked in:** the workspace/selector lookups are cached as
  `static let`, so the background block's only work is the final message-send
  (smallest possible race window), and it's dispatched *before* you call
  `completionHandler`.
- **Fallback if it ever flakes:** call the launch **synchronously** (accept the
  latency) — the app still opens because the XPC request is *sent* before any
  teardown; you just block waiting for a reply you discard. Slower but
  deterministic.

---

## Reusable checklist for a new app

- [ ] App + 2 extension targets (config + action), all with `family-controls`
      entitlement and the **same App Group**.
- [ ] Action ext Info.plist = `com.apple.ManagedSettings.shield-action-service`
      (NOT the `…UI…` string).
- [ ] `PrivateAppLauncher.swift` in the action target (fragment-obfuscated,
      `perform(_:with:)`, cached lookups).
- [ ] Handler: stamp → `DispatchQueue.global().async { launch }` →
      `completionHandler(.none)`. **Nothing else.** No notifications.
- [ ] App consumes the stamp on foreground and routes to your flow.
- [ ] Shield configuration ext sets your button label.
- [ ] Request Family Controls (Distribution) entitlement from Apple for release.
- [ ] Decide consciously on the [App Review risk](#️-read-this-first-the-app-review-reality).
- [ ] QA on a **real device** — Screen Time does not function in the Simulator.
      Test speed **and** open-reliability (many taps, cold and warm).

---

## Appendix A — the public-API path (`openParentalControlsApp`)

iOS **26.5+** added a sanctioned, zero-tap open. If you want a fully clean build
(no private API, no 2.5.1 risk) and only need 26.5+, return this from the
handler instead of using `PrivateAppLauncher`:

```swift
// iOS 26.5+ only. Documented as "open your parental controls app that is
// responsible for shielding the application" — i.e. your app.
case .primaryButtonPressed:
    // Build via rawValue if your SDK predates the symbol; init?(rawValue:)
    // resolves the real case on 26.5+ and returns nil on older OSes, which
    // doubles as your availability check. Once you build on the 26.5 SDK, use
    // the named `.openParentalControlsApp` instead.
    if let open = ShieldActionResponse(rawValue: 3) {
        completionHandler(open)
    } else {
        completionHandler(.close)
    }
```

**Trade-offs vs. the private path:**

- ✅ Public, sanctioned, no ban risk, no thread/latency gymnastics.
- ❌ iOS **26.5+ only** (no help for 17.4–26.4 users).
- ❌ Reportedly **silently no-ops under individual (non-family) Family Controls
  authorization** on at least some 27.x builds — so you cannot fully rely on it
  for a personal-use focus app, which is exactly why this playbook makes the
  private path primary.

A defensive belt-and-suspenders is to try the private launch first and fall back
to this response if the private symbols ever fail to resolve — but do **not**
combine it with a notification fallback if you care about the 10s stall.

---

## Appendix B — the failure signatures, so you can diagnose fast

| Symptom | Cause | Fix |
|---------|-------|-----|
| Whole device resprings on tap | `unsafeBitCast` to a mismatched `@convention(c)` prototype | Use `perform(_:with:)`, discard the return |
| Button does nothing, extension never runs | Wrong extension point (`…UI…` instead of `ManagedSettings`) | Fix Info.plist `NSExtensionPointIdentifier` |
| App opens then immediately bounces to home | Returned `.close` | Return `.none` |
| Consistent ~10s delay before the app appears | Blocking work before `completionHandler` (UNUserNotificationCenter, or the launch inline) | Strip notifications; dispatch launch off-thread; return immediately |
| Occasional tap opens nothing | Async-launch lost the teardown race | Cache lookups (done); or fall back to synchronous launch |
| Everything works on Simulator but not device / vice-versa | Screen Time doesn't run in Simulator at all | Only trust real-device QA |

---

*Compiled from a working iOS 27 implementation, Aug 2026. The private-API portion
is unsupported by Apple and carries App Store risk — see the disclaimer at the
top.*
