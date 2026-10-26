# Study Guard v2 — App Group Contract

The main app and the Screen Time extensions are separate processes that share
no runtime code. They communicate exclusively through the app group
`group.com.jasonmayo.diewithoutregrets` and the constants in
`diewithoutregrets/Shared/SGContract.swift` — a single source file compiled
into **all six targets** (app, StudyGuardMonitor, StudyGuardShield,
StudyGuardShieldAction, RegretGuardIntent, OpenGuardIntent). Never introduce
a raw key/name string literal outside SGContract; a single mismatch silently
breaks blocking.

## The model

Apps are **unlocked by default**. One daily repeating DeviceActivity
(`sg_daily`, 00:01–23:59:59) meters the user's selected apps with a usage
threshold event (`sg_limit`, N minutes). When it fires, the monitor extension
shields the selection on `ManagedSettingsStore(named: "studyGuardLock")` and
the apps stay locked until the user earns a fresh budget in Study Guard
(flashcard quiz / True Focus session / emergency unlock). A grant clears the
store and stop+starts monitoring with fresh events (`includesPastActivity:
false`) — the only reliable way to reset the usage accumulator. A fresh free
N-minute budget arrives each new day; a lock always survives midnight.

Completed Screen Time quizzes grant `ceil(correct answers × per-card seconds / 60)`
minutes, capped at 60. Mistakes do not cancel earnings, including a wrong final
answer. Incomplete, empty, and zero-correct quizzes grant nothing. The quiz counter
shows earned seconds and the receipt explains any rounding up (150 seconds earns
a 3-minute budget). Whole-minute rounding is our metering policy, not an Apple
minimum unlock duration; the usage threshold is separate from the daily schedule.
The grant happens synchronously at the final answer, before result animations.

## Keys

| Key | Type | Writer | Reader | Semantics |
|---|---|---|---|---|
| `sg_setupComplete` | Bool | app | all | Migration kill switch. Written **only after** `startMonitoring` verifiably succeeded. Never un-set (except debug reset). When true, both legacy intents no-op. |
| `sg_guardEnabled` | Bool | app | app, monitor | Guard toggle. Toggling OFF is refused while locked. |
| `sg_selection` | Data | app | app, monitor | JSON `FamilyActivitySelection`. Only token hand-off. ≤50 tokens. Edits refused while locked; re-baselined while metering. |
| `sg_intervalMinutes` | Int | app | all | N ∈ {10,15,20,30,45,60}, default 15. Single source of truth. |
| `sg_state` | String | both | all | `"metering"` / `"locked"`. Written by whichever process performs the transition. |
| `sg_lockedAt` | Double | both | app | Epoch of current lock; absent while metering. |
| `sg_budgetGrantedAt` | Double | both | both | Budget start (grant or rollover). Same-day read-guard anchor. |
| `sg_budgetTotalSeconds` | Double | app (+monitor at rollover) | both | Armed budget in seconds (re-baselined after selection edits). |
| `sg_budgetUsedSeconds` | Double | monitor (app resets on grant) | both | max(current, m×60) at each progress event. Drives UI + missed-lock fallbacks. |
| `sg_warnedThisBudget` | Bool | monitor (app clears on grant) | monitor | "Almost out" notification sent once per budget. |
| `sg_armedThresholdMinutes` | Int | app (+monitor at rollover) | all | Threshold actually armed at last start. Normalized back to `sg_intervalMinutes` by the monitor at day rollover (the ONE sanctioned extension-side restart). Also feeds shield copy. |
| `sg_monitoringGeneration` | String (UUID) | app (+monitor at normalization) | monitor | Every registration gets a new identity, included in event names. Events from previous registrations cannot debit, warn, or lock a new budget. |
| `sg_emergencyUnlockTimestamps` | Data (JSON [Double]) | app | app | Rolling 7-day ledger, ≤3 per window; pruned on read. |
| `sg_needsReauth` | Bool | app | app | Authorization revoked; UI shows re-auth card; never quiz-blackmail. |
| `sg_lastRolloverDay` | Double | both | both | Start-of-day marker; makes rollover idempotent across processes; pre-written before every `startMonitoring` so the immediate `intervalDidStart` no-ops. |
| `sg_lockNotifThrottleAt` | Double | monitor, shield action | monitor | 30s lock-notification throttle. The shield action extension also stamps it when posting its instant unlock notification (same fixed id) so a monitor re-fire replaces rather than stacks. |
| `sg_shieldTapAt` | Double | shield action | app (consumes) | Epoch of the last "Open Study Guard" shield-button tap. App consumes on foreground; if fresh (<120s) and locked, it navigates straight to the unlock flow. |
| `sg_shieldReturnCandidates` | Data (JSON dictionary) | shield configuration | shield action | Up to 50 opaque-token-to-supported-app mappings. Rendering a shield caches its identity; it does not select a return destination. |
| `sg_pendingShieldReturn` | Data (JSON object) | shield action | app (consumes) | Bundle ID and tap timestamp, selected by matching the actual tapped application token. Website/category/unknown-token taps clear it. Consumed once within 120 seconds. |
| `sg_extLog` | [String] | monitor | app (Debug tab) | ≤200-entry ring buffer — the only extension observability on device. |
| `sg_pendingEvents` | Data (JSON array) | both enqueue, app drains | app | Analytics queue (PostHog can't run in extensions). App swaps to `sg_pendingEventsDraining` before reading to avoid the append/drain race. |
| `LegacyIntentFireCount` | Int | intents | app | Post-migration automation fires; flushed as `legacy_intent_noop`. |

### Legacy v1 keys (frozen after setup, deleted in 3.0)
`LastBreakTime`, `BreakDurationMinutes` (seeds `sg_intervalMinutes`, 5→10),
`UserAllowedBreak`, `LastGuardedApp`. Still written by the legacy quiz path
**only while `!sg_setupComplete`**.

## Activity / event naming
- Activity: `sg_daily` — daily repeating 00:01 → 23:59:59.
- `sg_limit:<generation>` — lock trigger at N minutes, concrete tokens, `includesPastActivity: false`.
- `sg_used_p<m>:<generation>` — progress events below N with step = max(1, ⌈N/20⌉), plus terminal progress at N and recovery progress at N+1. Either terminal event can lock if `sg_limit` is missed. Below N, the event with m ≥ ⌈0.8·N⌉ triggers the warning notification. Exhausted budgets lock before considering a warning.
- Generationless events are accepted only for an existing pre-upgrade registration; foreground reconciliation upgrades it without adding back used minutes. Each grant and restart invalidates the previous generation before publishing its new allowance.
- Notifications: `sg_lock_notification` (fixed id, replace + 30s throttle, deeplink `diewithoutregrets://unlock`), `sg_warning_notification`. The shield action extension reuses `sg_lock_notification` (unthrottled — explicit user intent) for its pre-iOS 26.5 fallback so the existing tap route applies.

## Shield buttons
The shield's primary button is handled by StudyGuardShieldAction
(`com.apple.ManagedSettings.shield-action-service` — ManagedSettings prefix,
NOT ManagedSettingsUI like the configuration service; the UI-prefixed string
registers under a nonexistent extension point and the button silently does
the system close). On every tap it posts the unlock notification (the
reliable way in) and stamps `sg_shieldTapAt`; on iOS 26.5+ it additionally
responds `ShieldActionResponse.openParentalControlsApp` (built via
`rawValue: 3` until we compile with SDK ≥ 26.5) — best-effort: silently
ignored in the only public individual-authorization test so far
(FB18997699). If the direct open lands, the app clears the redundant
notification while consuming `sg_shieldTapAt`. Queues `shield_button_tapped`
analytics (`method: direct|notification`). The secondary button just closes.

## Rules
The app captures a fresh return destination in `NavigationModel` when consuming
the shield tap and clears it on leaving the unlock flow. The success screen
plays `Lock.lottie`'s opening segment on a green canvas, then the user can
return through a known app URL scheme. Unsupported apps and failed launches
leave the earned grant intact and offer a manual return. No application is
guessed from the last rendered shield or the legacy `LastGuardedApp` value.
Screen Time capture and actual third-party app launches require device QA.

Return attempts allow 350ms for shield removal to settle, then use the known
app's URL. An immediate refusal (under 500ms) gets one retry after 650ms while
Study Guard is still active. A slower refusal, which could be a cancelled iOS
prompt, is not automatically retried. An accepted URL request must also be
followed by Study Guard backgrounding before navigation is cleared; a two-second
watchdog releases the button if that transition never arrives. Leaving the flow
invalidates pending callbacks. None of these steps grants time or spends an
emergency unlock. The existing debug dump includes the app version and the last
12 local return events; these are not uploaded to analytics.

The grant is persisted before clearing shields so callbacks starting during the
transition can observe the new allowance. The settling delay is best effort:
ManagedSettings does not provide a shield-removal completion notification.

1. Only the app starts/stops monitoring — with ONE exception: the monitor's
   day-rollover normalization restart when `armed ≠ interval`.
2. `intervalDidEnd` and all warning callbacks are **log-only** (app-side
   `stopMonitoring` fires `intervalDidEnd`; keeping it empty deletes the
   whole suppression-flag class of bugs).
3. Never `startMonitoring` with an empty selection (empty-token events don't fire).
4. Shield exactly what the user picked — no `.all()` fallbacks.
5. Validate event generation before any usage, warning, or lock mutation.
   Elapsed wall time cannot identify which registration delivered an event.
   The old timing check is retained only for generationless upgrade callbacks.
6. `synchronize()` after every write the other process must observe.
7. Every locked user must always have ≥1 legitimate unlock path (empty deck →
   create-a-card flow; camera denied → flashcards; both methods always offered).

## Accepted escapes (documented, not bugs)
- Delete + reinstall the app (iOS clears shields, monitoring, and the app group).
- Revoking Screen Time authorization in Settings (reconcile forgives via `sg_needsReauth`).
- A deck of trivial cards (the quiz is the user's own commitment device).
- Manual clock jumps can grant one free meter reset per day (locks are never time-based, so a lock cannot be escaped this way).

## Regression checks for earned time and missing cards

The October 2026 report describes a one-minute remaining allowance that never
re-locks apps, plus flashcards disappearing. The report contains no app/iOS
version or device logs, so the code paths below are confirmed weaknesses, not
a confirmed diagnosis of that user's installation.

- Old event names were reused across grants. A delayed progress callback could
  pass the elapsed-time heuristic and debit a newer allowance. Generation IDs
  now distinguish registrations directly.
- Progress previously stopped below N, making the `used >= total` missed-lock
  fallback unreachable without the primary lock callback. Terminal and N+1
  recovery events now provide independent usage-based paths. They still require
  iOS to deliver a callback; there is no wall-clock countdown while apps are idle.
- The selected deck was a separate value copy. Direct card bindings could save
  cards without updating that copy; the rescue-card flow could then write the
  outdated copy back over the stored deck. Selection now stores an ID and reads
  the current deck. This prevents that overwrite path; it does not recover cards
  already lost or prove that it caused the user's report.

Run `StudyGuardEngineTests` and `DeckStoreTests` for regression coverage. On a
physical iPhone, earn 1, 3, and 15 minutes; use a selected app until it shields;
repeat immediately after the prior lock and after leaving Study Guard in the
background. Pause usage partway through to verify idle time is not charged.
Also verify a selection edit, day rollover, and an upgrade with an existing
generationless registration. Inspect `monitoringGeneration`, `budgetUsed`,
`monitoringActive`, and the extension log if it fails.

For cards, add a manual card and an AI/imported batch to the active deck, enter
the unlock quiz immediately, then relaunch. Confirm card IDs/counts persist and
that adding a rescue card preserves all earlier cards. A decode failure in the
existing `SavedDecks` payload is a separate possible cause of an empty library
and is not established by this report.

Validation on 2026-10-26: all five new baseline tests failed before the fixes
(four deck tests and one missing-lock-recovery test). After the fixes, the
Simulator app and extensions built and 58 tests passed across the engine, deck,
flashcard, shield-return, and app-return suites. Two opt-in live App Attest/AI
tests were skipped because they require a physical device. Physical Screen Time
enforcement has not been verified in this investigation.

The monitoring design uses Apple's documented
[event identity callback](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/eventdidreachthreshold(_:activity:))
and [`includesPastActivity`](https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity)
semantics. Adding recovery events reduces reliance on a single callback; it does
not guarantee delivery if the system stops reporting all activity.
