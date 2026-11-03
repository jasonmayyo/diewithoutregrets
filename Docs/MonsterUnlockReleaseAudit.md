# Monster unlock release audit

**Original audit; remediation is tracked in [MonsterUnlockReleaseReadiness.md](MonsterUnlockReleaseReadiness.md).**

**Original recommendation: hold the release.** The local grading design is sound, and the unsigned Release build compiles, but the current candidate has privacy, app-blocking, AI-safety and packaging issues that should be resolved before submission.

Reviewed on 2 November 2026 against commit `353e9c4`, with a clean starting worktree. Scope includes monster chat and study-sheet sessions, onboarding entry, answer grading and rewards, shield handoff and monitoring, tutor/script transport, backend authentication and quotas, privacy disclosure, and release packaging. Findings include shared infrastructure inherited from earlier versions because the new feature relies on it. No application/backend fixes or deployments were made.

## Findings requiring attention before release

### 1 P1 A failed monitoring restart still produces a successful unlock

[StudyGuardManager.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/StudyGuard/Services/StudyGuardManager.swift:158)

`grantFreshBudget` writes the new allowance and clears the shields before calling `restartMonitoring`, then discards its Boolean result. The restart stops the previous schedule before attempting the new one. If `startMonitoring` throws, the user has unshielded apps and no working usage schedule, while `grantEarnedBudget` still returns positive minutes and the monster announces success. Foreground reconciliation can attempt recovery only when Study Guard returns to the foreground; it cannot enforce the advertised allowance while the user remains in another app.

This is an inherited engine defect on the new feature's critical path. Evidence is the production control flow at lines 158–194 and 443–465; the automated monster suite substitutes a fake manager and does not exercise this failure.

**Required change:** make grant/monitoring success explicit, preserve a recoverable pending reward if registration fails, and expose a usable recovery path. Add an injected monitoring-failure test, followed by a real-device test that verifies both unlocking and subsequent re-locking.

### 2 P1 Personal chat data is sent to AI without an explicit sharing choice

[FlashcardAPIClient.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/RegretGuard/Services/FlashcardAPIClient.swift:176), [MonsterAI.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/TutorMonster/MonsterAI.swift:45), [MonsterSession.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/TutorMonster/MonsterSession.swift:189)

Every tutor request includes the card prompt, answer, explanation, question and up to four previous turns. If a name is saved, the client silently prefixes the question with the saved name, pronoun preference and optional gender. Opening an in-chat round also automatically requests a script using exam/topic context and gate-encounter count. Neither path checks a consent preference. The existing Generate screen's disclosure concerns generating cards from study text; users can reach the monster using manual/imported cards without that screen.

The [published privacy policy](https://studyguard.framer.website/legal/privacy-policy), fetched successfully during this audit, describes general service providers but does not identify OpenAI or this tutor-sharing flow. Apple's current guideline 5.1.2(i) calls for disclosure and explicit permission before sharing personal data with third-party AI. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)

**Required change:** add an informed AI-sharing choice before either network path, keep local study available when declined, minimize identity fields sent to the provider, and align the policy and App Store disclosures with the actual payloads. A nickname entered during onboarding is not an AI-sharing permission.

### 3 P1 The shield entry point depends on an undocumented private API

[PrivateAppLauncher.swift](/Users/jasonmayo/Desktop/diewithoutregrets/StudyGuardShieldAction/PrivateAppLauncher.swift:30), [StudyGuardShieldActionExtension.swift](/Users/jasonmayo/Desktop/diewithoutregrets/StudyGuardShieldAction/StudyGuardShieldActionExtension.swift:67)

The extension assembles `LSApplicationWorkspace` and `openApplicationWithBundleID:` at runtime. The caller ignores the result and always completes with `.none`; if the class, selector or launch request stops working, the primary shield button provides no alternate route. This predates the monster feature, but it is the feature's normal entry point.

Apple requires public APIs under guideline 2.5.1 and prohibits hiding undocumented features under 2.5.19. Runtime construction of the names does not make this a supported API. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/#software-requirements)

**Required change:** use a supported handoff, with a clear manual/notification fallback where direct opening is unavailable. Test it with notifications denied and with Study Guard cold-launched. Successful execution on one iOS release is not a compatibility guarantee.

### 4 P1 Live response safety currently depends on the model following its prompt

[protocol.js](/Users/jasonmayo/Desktop/diewithoutregrets/backend/src/protocol.js:375), [protocol.js tutor validator](/Users/jasonmayo/Desktop/diewithoutregrets/backend/src/protocol.js:433)

The system prompts correctly instruct the model to be kind and appropriate for minors, and the provider refusal field is handled. However, the application's response validators check only shape, length and nonempty strings. A synthetic demeaning response passes both the script and tutor validators and would be displayed. There is no separate content-screening decision, and no chat-specific reporting action was found.

This is a verified missing application safeguard, **not evidence that the deployed model actually produced that response or that a jailbreak succeeded**. The audit made no paid model calls. Prompt-injection attempts cannot directly grant time because the model has no grading or unlocking authority; the remaining risk is what the user is shown.

**Required change:** add a safety check and safe local fallback before displaying live responses, provide a reporting route, and evaluate all personas with adversarial card text and questions, including distress disclosures and multilingual inputs. Until that is verified, the existing local script banks offer a safer release path. Filtering must not prevent legitimate educational discussion.

### 5 P1 The packaged extensions have different versions from the app

[project.pbxproj main Release settings](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets.xcodeproj/project.pbxproj:2277), [shield-action Release settings](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets.xcodeproj/project.pbxproj:2369)

The freshly built Release app is **2.0.7 (1)**. Its four embedded extensions—MonsterWidget, ShieldAction, Shield and Monitor—are **2.0.6 (66)**. Xcode reports that the extension bundle version must match the containing app. The successful unsigned compilation does not clear this packaging warning or establish that an App Store upload will validate.

**Required change:** synchronize release/build versions across every shipped target, inspect the actual signed archive, and validate it before upload. Use one shared version source to prevent recurrence.

## Additional reliability findings

### 6 P2 A typed punctuation card can make the chat impossible to finish

[RegretGuardApps.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/RegretGuard/Models/RegretGuardApps.swift:80), [answer normalization](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/RegretGuard/Models/RegretGuardApps.swift:270), [miss requeue](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/TutorMonster/MonsterSession.swift:414)

A typed card whose correct answer is `?` passes `isUsableForStudy`. Normalization removes all trailing `.?!`, making the expected answer empty; `matches("?", "?")` is therefore false. At annoyed mood or above, every miss is requeued without a limit. The audit reproduced twenty submissions of the exact saved answer with the question still active and no settlement. Users can leave chat, but cannot finish that round by answering correctly.

**Change:** require the saved typed answer to be gradeable, preserve meaningful punctuation where appropriate, and provide a bounded recovery path for a broken card. Add the invariant that every usable typed card accepts its own saved answer. This also protects manually created/imported decks, not just generated cards.

### 7 P2 Cancelling a stalled Apple call can leave all AI requests blocked

[FlashcardAPIClient.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/RegretGuard/Services/FlashcardAPIClient.swift:191), [onboarding tutor](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/Onboarding/V5/BuddyOnboardingView.swift:331)

The client holds `isGenerating` until the signed request finishes. Its HTTP timeout does not bound Apple's asynchronous key/enrollment/assertion calls. A controlled attestation dependency that ignores cancellation reproduced the problem: cancel the script task, then ask the tutor, and the second request is rejected as `alreadyGenerating` until the Apple operation returns. The 20-second monster-session deadline restores local answering but does not release this shared client. Onboarding uses the client directly and has no equivalent overall deadline, so its `busy` state can also remain stuck.

**Change:** bound the complete operation, recover the shared client without permitting assertion-counter races, and give onboarding the same bounded fallback behavior. Test with a deliberately non-cooperative attestation implementation, not only a cancellable HTTP mock.

### 8 P2 Closing chat silently discards an unfinished round

[ContentView.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/ContentView.swift:166), [MonsterSession.stop](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregrets/Features/TutorMonster/MonsterSession.swift:355)

The root route creates a new `MonsterSession` each time chat is entered. The back button destroys the route, while `stop()` cancels tasks without saving the round or its pending review outcomes. A five-card audit round showed 120 earned seconds after two correct answers; after closing and recreating the session, it showed zero earnings, five questions remaining, and no recorded review outcomes. Force termination has the same persistence limitation. Ordinary backgrounding of the retained view is handled separately and is covered by existing tests.

**Change:** retain/persist the pending round with idempotent settlement, or clearly warn that leaving forfeits unclaimed progress. Persist completed review outcomes safely. Do not restore an already-claimed grant twice.

### 9 P2 One existing simulator test depends on real shared preferences

[StudyGuardEngineTests.swift](/Users/jasonmayo/Desktop/diewithoutregrets/diewithoutregretsTests/StudyGuardEngineTests.swift:427)

The full simulator suite has one failure: `testPersonaStoreDefaultsToFallbackAndPersists` expects Willow but reads Zaza. It supplies fresh app-local defaults while leaving `PersonaStore`'s `sharedDefaults` argument pointing at the real app-group preferences. Migration from those preferences is intentional production behavior, so the test is not isolated and also writes its selected persona back there.

**Change:** inject `sharedDefaults: nil` or a separate temporary suite in both test constructors and clean it up. This is a test-isolation issue, not proof that real users receive the wrong persona. The release suite is nevertheless not green as checked in.

## Verification results

| Check | Result and scope |
| --- | --- |
| Backend unit and security tests | 26 passed. Request validation, cryptographic assertions, replay protection, quotas, failure accounting and generation fallbacks. |
| Local Worker integration | 1 passed using actual local runtime/SQLite with mocked provider traffic; includes authenticated tutor request, replay rejection and shared script quotas. |
| Swift study and storage harness | 98 executed: 96 passed, 2 live-device tests skipped. Includes local grading, settlement idempotence, deck switching, sheet follow-ups, transcript lifecycle and media resources. |
| Shield and routing harness | 34 passed. These test contract/navigation logic, not actual iOS shield presentation. |
| Countdown harness | 11 passed. |
| Full iOS simulator suite | 175 executed: 172 passed, 2 live tests skipped, 1 failed as described in finding 9. Some cases overlap the standalone harnesses. |
| Focused audit characterization probes | 3 passed, reproducing findings 6–8. A passing characterization probe confirms the defect's current behavior. |
| Response safety probe | Both validators accepted the synthetic demeaning text. No model request was made. |
| Unsigned iOS Release build | Passed, with extension-version warnings. |
| Built app provider-key scan | Passed across the Release bundle; public endpoint is configured and no matching OpenAI key pattern was found. |
| Live service health | HTTP 200, `enabled: true`. This checks configuration, not provider billing or successful AI generation. |
| Public privacy policy | HTTP 200; tutor/provider disclosure gap described above. |

Evidence and runnable audit probes are in [the audit output folder](/Users/jasonmayo/Desktop/diewithoutregrets/outputs/monster-unlock-audit-2026-11-02/evidence.txt). Run the additional probes from the repository root:

```sh
python3 outputs/monster-unlock-audit-2026-11-02/run_probes.py
node outputs/monster-unlock-audit-2026-11-02/check_response_safety.mjs
```

The initial build/test attempts encountered sandbox cache restrictions and then insufficient disk space during a duplicate dependency download. The audit's duplicate dependencies were removed, existing dependencies were reused, and the checks above were rerun. Those environmental failures are not counted as application defects.

## Protections that are working

The AI cannot mark answers, choose a model, execute tools, change decks or grant minutes. Only local verdicts feed the existing reward calculation. Questions and script enrichment use separate paths from grading; malformed or failed AI responses fall back locally. The active chat has a separate deadline to restore answering after a slow tutor request, and late replies are ignored.

The backend verifies App Attest signatures over the request bytes, rejects replay, uses atomic quota reservations, and counts failed paid work. Provider redirects are rejected; response/body sizes are bounded; arbitrary client roles, system prompts and model choices are disallowed. The Worker code does not log study text, replies or provider credentials. Reactions come from a closed local resource list, not model-supplied URLs.

## Remaining release checks

These checks are necessary for release sign-off after the findings are resolved; simulator success cannot establish them:

- On a physical iPhone using the actual signed candidate, test cold/warm shield entry, first enrollment and subsequent tutor calls, then correct/mixed/wrong rounds and an offline round. Verify both the unlock and the next usage-triggered re-lock without reopening Study Guard.
- Exercise 1-, 2- and 5-minute grants, backgrounding, force termination, reboot, midnight rollover, authorization revocation, category/web selections, notifications denied, and interrupted monitoring. Confirm stale callbacks cannot debit a new grant.
- Test empty/invalid decks and urgent access with emergency allowances available and exhausted. The chat currently requires returning Home to reach the emergency control; make that route clear. Confirm recovery remains practical with larger text and VoiceOver.
- Inspect the signed archive's App Attest environment and Family Controls/app-group entitlements, synchronize versions, and validate the archive. Neither signing nor TestFlight/App Store validation was performed here.
- Run live safety evaluations for all personas and verify the reporting/fallback behavior. Validate Sentry screenshot/replay masking on the chat and onboarding on supported iOS versions; the app explicitly enables replay in an environment the SDK labels unreliable, so code inspection alone is insufficient to establish redaction there.
- Confirm the commercial rights for the bundled reaction media. The repository records user-supplied file names and screen recordings, which are provenance rather than proof of redistribution rights.
- Check provider key expiry and budget settings in the live account. The backend README records an 18 November 2026 expiry; that is a documentation warning to verify, not a fresh observation of the credential. Script/tutor traffic has a separate default ceiling of 20,000 daily and 400,000 monthly requests; these are request limits, not a dollar cap.

A physical phone was detected, but this audit did not replace its installed app, change its Screen Time selections, or run paid live-provider tests. The result is a source/build/automated-test audit with explicit remaining device and service checks, not production release certification.
