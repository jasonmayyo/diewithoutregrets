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
| `sg_emergencyUnlockTimestamps` | Data (JSON [Double]) | app | app | Rolling 7-day ledger, ≤3 per window; pruned on read. |
| `sg_needsReauth` | Bool | app | app | Authorization revoked; UI shows re-auth card; never quiz-blackmail. |
| `sg_lastRolloverDay` | Double | both | both | Start-of-day marker; makes rollover idempotent across processes; pre-written before every `startMonitoring` so the immediate `intervalDidStart` no-ops. |
| `sg_lockNotifThrottleAt` | Double | monitor, shield action | monitor | 30s lock-notification throttle. The shield action extension also stamps it when posting its instant unlock notification (same fixed id) so a monitor re-fire replaces rather than stacks. |
| `sg_shieldTapAt` | Double | shield action | app (consumes) | Epoch of the last "Open Study Guard" shield-button tap. App consumes on foreground; if fresh (<120s) and locked, it navigates straight to the unlock flow. |
| `sg_extLog` | [String] | monitor | app (Debug tab) | ≤200-entry ring buffer — the only extension observability on device. |
| `sg_pendingEvents` | Data (JSON array) | both enqueue, app drains | app | Analytics queue (PostHog can't run in extensions). App swaps to `sg_pendingEventsDraining` before reading to avoid the append/drain race. |
| `LegacyIntentFireCount` | Int | intents | app | Post-migration automation fires; flushed as `legacy_intent_noop`. |

### Legacy v1 keys (frozen after setup, deleted in 3.0)
`LastBreakTime`, `BreakDurationMinutes` (seeds `sg_intervalMinutes`, 5→10),
`UserAllowedBreak`, `LastGuardedApp`. Still written by the legacy quiz path
**only while `!sg_setupComplete`**.

## Activity / event naming
- Activity: `sg_daily` — daily repeating 00:01 → 23:59:59.
- `sg_limit` — lock trigger at N minutes, concrete tokens, `includesPastActivity: false`.
- `sg_used_p<m>` — progress events at m = step, 2·step, … < N with step = max(1, ⌈N/20⌉). The event with m ≥ ⌈0.8·N⌉ triggers the warning notification.
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
1. Only the app starts/stops monitoring — with ONE exception: the monitor's
   day-rollover normalization restart when `armed ≠ interval`.
2. `intervalDidEnd` and all warning callbacks are **log-only** (app-side
   `stopMonitoring` fires `intervalDidEnd`; keeping it empty deletes the
   whole suppression-flag class of bugs).
3. Never `startMonitoring` with an empty selection (empty-token events don't fire).
4. Shield exactly what the user picked — no `.all()` fallbacks.
5. Grant-epsilon: the monitor ignores `sg_limit` within 90s of a grant with
   used < 60s (stale delivery from the pre-grant monitoring generation).
6. `synchronize()` after every write the other process must observe.
7. Every locked user must always have ≥1 legitimate unlock path (empty deck →
   create-a-card flow; camera denied → flashcards; both methods always offered).

## Accepted escapes (documented, not bugs)
- Delete + reinstall the app (iOS clears shields, monitoring, and the app group).
- Revoking Screen Time authorization in Settings (reconcile forgives via `sg_needsReauth`).
- A deck of trivial cards (the quiz is the user's own commitment device).
- Manual clock jumps can grant one free meter reset per day (locks are never time-based, so a lock cannot be escaped this way).
