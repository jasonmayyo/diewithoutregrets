# Monster unlock release readiness — 2 November 2026

Candidate: **2.0.8 (75)**, working-tree changes based on `353e9c4`.
The original findings and baseline evidence remain in [MonsterUnlockReleaseAudit.md](MonsterUnlockReleaseAudit.md).

**Latest handoff — 3 November 2026: 2.0.8 (75), not uploaded or submitted.**
Use `build/StudyGuard-2.0.8-75.xcarchive`, also selected in Xcode Organizer.
Turning off Monster unlock now restores the saved Flashcards or True Focus flow
for the home button, shield handoff, cold/warm launches, deep links and automatic
unlock entry. The routing suite passed all 39 tests, and the old quiz was confirmed
through the home button and simulated shield handoff. The signed Release archive,
all seven extension versions, signature, media/catalog and client-secret checks
passed. Evidence: `outputs/unlock-preference-2.0.8-75/verification.json`.
The owner will upload and submit this archive.

**Previous handoff record — 2 November 2026: 2.0.7 (74).**
Use `build/StudyGuard-2.0.7-74.xcarchive`. This follow-up removes the permanent
saved-progress / AI & Privacy strip. Optional AI tutoring still uses the existing
first-use consent sheet; acceptance is saved and controls remain in Profile.
All 11 consent/network regression tests passed. Archive signing, all embedded
extension versions, media/catalog and client-secret checks passed.
Evidence: `outputs/consent-sheet-2.0.7-74/verification.json`.
The build 73 details below are the preceding media-removal verification.


**Status: final archive complete. The owner will upload and submit it.**
Archive: `build/StudyGuard-2.0.7-73.xcarchive`.
Build 73 has NOT been uploaded or submitted by the assistant. The owner took over
all uploading/submission on 2 November 2026. Build 72 was previously uploaded,
but is superseded and must not be submitted: the expanded scan found two older
meme-containing videos, including a duplicate embedded in the asset catalog.
Those are removed in build 73, and the welcome demo is replaced with text.

All reaction photos, GIFs, memes and animated monster attachments are removed from
chat, study-sheet feedback and onboarding conversations. The contact portrait,
animated typing dots and coin-flight effects are removed too. Existing branding
and character selection outside conversations remain. Saved progress survives
legacy media fields without repeating earned-time grants.

The final simulator suite passed: 183 executed, four optional live tests skipped,
zero failures, including the new retired-media packaging test. The signed archive,
all seven embedded extension versions, loose resources, compiled asset catalogs,
private-API checks and provider-key scan passed. The earlier backend and study
regression suites also passed; no backend logic changed during media removal.
App Store version 2.0.7 has prepared release/reviewer notes and manual release saved.
Physical unlock/re-lock testing remains unverified before public release.
Evidence: [build 73 verification](../outputs/text-only-2.0.7-73/verification.json).

The earlier moderation access correction is now verified: the follow-up recorded
**73 successful moderation responses and zero moderation 403s**, including a
**12/12 passing physical-iPhone matrix through the production Worker** (eight
screened replies and four blocked injections). The previously failing
coach/distress case also passed eight additional isolated-provider repetitions.
All four personas' generated scripts passed live input/output screening. Returned
synthetic text was reviewed. Offline regression suites passed again.

The original 12-case run had one intermittent denial after the key/model access
change. That failure remains preserved as historical evidence. The precise
provider-side reason is not established; delayed application of the access change
is plausible, not confirmed. No further permissions, spending changes, safety
bypass, credential change or production deployment were needed for the passing
follow-up. No support request was sent. The final production-path test passed in
18.852 seconds; an earlier attempt was interrupted while the phone was locked.

Follow-up evidence: [moderation recheck](../outputs/monster-moderation-recheck-2026-11-02/README.md).

## Remediation

| Original finding | Change and evidence |
| --- | --- |
| 1. Failed monitoring could still unlock apps | Register DeviceActivity before removing shields. Failure locks the budget and keeps a durable pending reward. Home exposes a retry. Stable grant IDs and a persisted commit marker prevent ordinary replay/reopen from granting twice. Emergency allowances are consumed only on successful registration. Injected failure/idempotency tests pass. Actual usage-triggered re-lock still needs device QA. |
| 2. Undisclosed AI sharing | Versioned consent defaults off for tutor and script requests. Declining retains local study. Saved name/pronouns/gender are no longer prefixed into tutor questions. Chat, onboarding and Profile expose AI privacy controls; network tests prove no request before consent. Public policy updated and published. App Store Other User Content declaration published and verified after owner approval. |
| 3. Private shield handoff | Removed `PrivateAppLauncher` and its target references. Use Apple's public `openParentalControlsApp` on iOS 26.5+; older iOS closes the shield with instructions to open Study Guard from Home. Built extension scan contains no retired private API names. |
| 4. Prompt-only response safety | Independent input/output moderation for tutor and script routes; explicit demeaning-reply check; bounded response parsing and timeouts; failure returns no generated text. Client requires `safetyChecked: true`. Safe local fallback and report/support route are available. Provider failures, flagged input/output and missing safety markers have regression tests. The follow-up live tutor/script evaluation passes. |
| 5. Extension version mismatch | One shared version/build source for all targets. Verified the final archived app and all seven embedded extensions are 2.0.7 (73). |
| 6. Unfinishable punctuation cards / retries | Meaningful punctuation survives normalization, usable typed answers accept themselves, and an incorrect card is retried at most once in a round. Regression tests pass. |
| 7. Stalled App Attest locks the AI client | A deadline covers the entire authenticated operation, including non-cooperative Apple callbacks. Cancellation releases the busy state, and late callbacks cannot submit a stale request. Tests cover key creation, enrollment, assertions and a later successful request. |
| 8. Closing chat loses earned progress | Persist unfinished chat/sheet rounds, frozen earning rate, question IDs and answers; write review outcomes as answers are accepted; settle by stable round ID. Reopen/sheet/idempotency tests pass. |
| 9. Simulator test pollutes shared preferences | PersonaStore test now injects isolated preferences without the real app group. Full simulator suite passes. |

Additional release changes: all third-party reaction photos/videos and their
rendering code have been removed. Sentry screenshots, view hierarchy and session
replay remain disabled to avoid recording chat/card content. Existing compiler
warnings remain; no build errors remain.

## Verification

| Check | Result |
| --- | --- |
| Backend unit/security/safety | 32 passed, 0 failures. |
| Worker runtime integration | 1 passed using actual local runtime/SQLite and mocked provider traffic. Added explicit input/output 403 coverage: no reply disclosure or automatic retry, replay rejected, quota retained, in-flight state cleaned up. |
| Swift study reliability | 87 executed: 83 passed, 4 opt-in live checks skipped, 0 failures. |
| Swift storage | 9 passed. |
| Shield/routing harness | 34 passed. |
| Countdown harness | 11 passed. |
| Full Xcode simulator suite | 183 executed: 179 passed, 4 opt-in live checks skipped, 0 failures. Fresh full simulator suite for the text-only candidate. |
| iOS Release / archive | Build 73 archive succeeded. Owner will perform upload and submission. Earlier distribution-profile/entitlement evidence remains historical. |
| Built artifact checks | Rechecked 2.0.7 (73), including all seven extensions and compiled asset catalogs; no retired meme media, reaction picker/renderer or private handoff API symbols; provider-key scan passed. |
| Apple upload | Build 73 is not uploaded. Owner will upload/submit. Previously uploaded build 72 is superseded and must not be submitted. |
| Earlier physical-device live tutor | Follow-up full 12-case matrix passed: 8 screened replies, 4 safely blocked injections, 0 failures. Basic screened reply also passed in the earlier run. |
| Earlier live provider follow-up | 9 direct moderation probes, a separate 12-case tutor matrix, 8 coach/distress repetitions and 4 persona scripts passed. Together with the iPhone run: 73 moderation responses, zero moderation 403s. |

These suites overlap; their counts are not independent coverage totals. Mocked
Screen Time tests establish logic, not actual iOS enforcement. No AI system can
be certified harmless from these tests alone.

## Live configuration and policy

- Worker: `https://studyguard-ai-staging.jason-749.workers.dev` (historical name,
  live service). Current deployment: `f74066e2-63e1-4277-a4ab-122687a53a3b`.
- Production App Attest remains required; development attestations stay disabled.
  Existing quotas and encrypted server credential are preserved. No client key,
  test bypass or quota increase was introduced.
- In the Study Guard Server OpenAI project, the existing
  **Study Guard production — 2026-10-19** key has only Chat completions Request
  and Moderations Request enabled. The latter was explicitly approved by the
  owner and verified after saving. **Expiry remains 18 November 2026**; arrange
  rotation before that date. The project limit was rechecked: $5 enforced spend limit and a 100% alert; neither was changed. The owner approved adding only `omni-moderation-latest` beside `gpt-4o-mini` in the model allowlist, and the saved list was verified.
- [Public privacy policy](https://studyguard.framer.website/legal/privacy-policy)
  updated in Framer and published, with date 02/11/2026 and section 12 covering
  AI generation/tutoring, consent, providers, retention, local snapshots,
  diagnostic capture and reporting. The live page was checked after publication.
- App Store Connect now has nine data categories. Published with explicit owner
  approval and verified: Other User Content, App Functionality, linked to the
  user, not used for tracking. Free-text content is not de-identified before
  collection. The eight existing declarations remain unchanged.

## Remaining release gates

The owner confirmed on 2 November that the physical unlock/re-lock cycle has
not yet been tested. The automated iPhone tutor run does not cover that cycle.

1. On the signed candidate, verify shield entry both cold/warm, a completed
   round unlocking selected apps, and actual usage-triggered re-lock without
   reopening Study Guard. Exercise 1-, 2- and 5-minute grants, offline study,
   interrupted/reopened rounds, emergency access and failed-monitoring recovery.
   Include background/force-quit/reboot, midnight rollover, revoked authorization,
   categories/websites, notifications denied, larger text and VoiceOver. Test
   the supported older-iOS manual handoff as well as iOS 26.5+ direct opening.
Install **2.0.7 (73)** once uploaded by the owner and available in TestFlight for the device QA above. The
owner has authorized App Store review submission with manual release; physical
sign-off remains a public-release gate, not a claim of completed testing.

Final archive for owner upload: `build/StudyGuard-2.0.7-73.xcarchive`, with evidence in
`outputs/text-only-2.0.7-73/`. Build 72 is superseded. Historical build 71 archive and evidence remain in
`build/StudyGuard-2.0.7-71.xcarchive` and `outputs/testflight-2.0.7-71/`. The earlier local archive
`build/StudyGuard-2.0.7-2.xcarchive` and IPA
`build/StudyGuard-2.0.7-2-export/diewithoutregrets.ipa` remain as historical
pre-upload artifacts. Their non-sensitive signing evidence is in
`outputs/monster-release-fixes-2026-11-02/distribution-verification.json`.
The archive uses development signing; its exported IPA is correctly re-signed
for App Store distribution. The simulator host and live device tests are not
included in the exported app.

Disk capacity is tight (under 1 GB during checks). The first build-72 simulator
attempt ran out of disk space before testing; only completed regenerable Study
Guard build intermediates/products were cleared, then all 183 simulator tests
completed successfully. Source packages, signed archives and test results were
preserved. The following notes describe the earlier device-build recovery.
 A physical Debug build first
failed generating optional dSYMs; completed task-generated intermediates were
removed and the device build succeeded with DWARF debug information. The verified
Release app was retained. Completed archive intermediates were removed after
export while preserving the archive and IPA. Do not delete user data
or unrelated build caches as a shortcut.

The historical [provider support draft](MonsterModerationSupportDraft.md) remains
unsent per owner instruction; the new verification did not require support. The
earlier failing provider request ID is
`req_1877ff18b2be436d898586e359ff2b38`, approximately 09:01 UTC on 2 November.
The original failure is in `outputs/monster-release-fixes-2026-11-02/live-safety-matrix.json`;
the passing recheck is in `outputs/monster-moderation-recheck-2026-11-02/`.
No raw device log is included in either evidence directory.

## Reproducible checks

From the repository root:

```sh
python3 scripts/test_study_reliability.py
python3 scripts/test_monster_shield.py
python3 scripts/test_countdown.py
python3 scripts/verify_monster_release.py build/buddy-onboarding/Build/Products/Release-iphoneos/diewithoutregrets.app
python3 scripts/verify_no_client_secrets.py build/buddy-onboarding/Build/Products/Release-iphoneos/diewithoutregrets.app
git diff --check
```

From `backend`: `npm test` and `npm run test:integration`.
Live Xcode test: `FlashcardAPIClientTests/testLiveProductionModeratedTutor`,
and `FlashcardAPIClientTests/testLiveProductionTutorSafetyMatrix`, physical
iPhone destination, `STUDY_GUARD_LIVE_GENERATION=1`. These use a separate
preferences namespace, synthetic card/question, and does not write decks or
grant time. The matrix makes at most twelve synthetic calls across four personas;
recorded replies require semantic review in addition to automated screening.
These tests must not be enabled for normal offline CI.

References: [Apple public shield response](https://developer.apple.com/documentation/managedsettings/shieldactionresponse/openparentalcontrolsapp),
[Apple privacy declarations](https://developer.apple.com/app-store/app-privacy-details/),
[OpenAI moderation response schema](https://developers.openai.com/api/reference/resources/moderations/methods/create),
[OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data).
