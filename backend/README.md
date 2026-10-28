# Study Guard AI service

Study Guard uses the existing Cloudflare Worker at
https://studyguard-ai-staging.jason-749.workers.dev. It has been promoted to live
use, preserving the encrypted OpenAI key the user already installed. The
historical “staging” suffix is only the Worker's name. No second key is required.
The app contains this public hostname, never an OpenAI key or shared app token.

Promoted deployment: 9ebd0c70-1d8e-4ef4-a132-9164716ff71a (20 September 2026).
After deployment, Wrangler confirmed the existing OPENAI_API_KEY secret_text
binding remains present. Live health, challenge, forged-enrollment rejection,
and disabled-generation checks passed without any OpenAI calls.

The unused studyguard-ai Worker remains disabled and is no longer referenced by
the app or deployment configuration. OneThing's source and service are unchanged.
No end-user account or login has been added.

**AI generation is enabled.** On 19 October 2026, the production ledger reached
the shared 100-attempt monthly limit. The monthly limit is now configured as 300;
the existing usage counter is preserved. The daily limits and $5 OpenAI project
budget are unchanged. The OpenAI billing blockage described below is historical.
A deployed Worker and a successful build are not evidence of successful paid AI
requests or readiness for Apple submission.

## Security and request flow

1. The iPhone generates an Apple App Attest key and requests a one-time challenge.
2. The Worker validates Apple's certificate chain, validity dates, nonce, app
   identity, key identifier, initial counter, and production attestation environment.
3. Each generation signs the exact JSON bytes. The Worker verifies the signature,
   consumes the challenge, and advances the monotonic assertion counter.
   Challenges expire after five minutes and are bound to the key and operation.
4. A single SQLite-backed Durable Object reserves installation and global quotas
   atomically before a paid request. Replays cannot cause a second paid request.
5. Only study text, a supported language, challenge, UUID, and action are accepted.
   The server fixes the model to gpt-4o-mini, one completion, a 12,000 output-token
   ceiling, and a structured 50-card JSON schema. Input is capped at 100,000 UTF-8
   bytes, with an independent streamed-body limit.
6. At least 20 complete, validated cards must return before the app updates its deck;
   at most 50 are kept. Generated cards use a self-contained sentence in
   `regretPrompt` with exactly one `___` blank, four distinct short answer choices,
   and the correct choice verbatim in `regret`. The quiz replaces the explicit
   blank in place; existing ordinary questions remain question-style cards.
   Refusals, truncated answers, and invalid answer indexes fail without altering it.

Current limits are 10 attempts per installation per UTC day, three
per minute, 20 globally per UTC day, and 300 globally per UTC month. One call per
installation and eight globally may be in flight. Failed or timed-out upstream
calls remain counted; paid calls are never retried automatically. These request
ceilings supplement the $5 enforced OpenAI project budget. Review capacity before
wider rollout; do not silently raise spend or request limits.

Tutor Monster content enrichment (Phase 3) extends the same hardened path.
`/v1/flashcards` now also accepts an optional `topic`, `difficulty`
(easy/medium/hard) and `count`; a request must carry EITHER study text (>= 50
chars) OR a topic. Topic mode generates textbook-grounded cards for weak or
near-exam topics without a source document, and every card is returned with a
short `topic` label (document mode now labels each card too). Topic-mode top-ups
deliberately SHARE the flashcard generation budget above — there is no separate,
higher limit — so they cannot increase spend; a small `count` relaxes the
minimum-card floor proportionally. `/v1/distractors` is a new, cheaper endpoint
that returns three wrong options per typed card so the app can upgrade typed
cards to multiple choice. It reuses the same App Attest + reservation flow and
has its OWN deliberately low buckets (defaults: 3/min, 10 per installation/day,
50 globally/day, 500 globally/month), overridable only via the `DISTRACTOR_*`
env vars, never silently. Both share the `AI_ENABLED` gate. The unlock gate
never depends on either; the app falls back to existing cards when offline.

Promotion uses the studyguard-production-v1 Durable Object ledger. Old
studyguard-v1 registrations and development registrations are not accepted in
that ledger. The client's cached App Attest key namespace is also production
specific. The previous test data was not deleted. Never reset the production
ledger to work around an exhausted quota.

App Attest verifies an installation, not a human or a subscription. A genuine
installation can still be automated, and reinstalls can create a new key; global
quotas provide the backstop. Subscription/account quotas are a separate feature.

Study text and generated cards are not stored or logged by the Worker. Storage
contains public attestation keys, counters, short-lived challenges, and in-flight
metadata. IP rate-limit identifiers are hashed with a daily scope. Worker logs
and traces are disabled in the deployment configuration.

## Local checks and deployment

Requires Node 22+; unit tests use node:sqlite.

    cd backend
    npm ci
    npm test
    npm run test:integration

The integration test uses the actual local Cloudflare runtime and SQLite Durable
Objects. All outbound OpenAI traffic is intercepted and mocked. There is no
remote admin endpoint or simulator authentication bypass in production.

Use npm run dev for a local Worker. The default configuration enforces production
App Attest. There is one deploy target; the old deploy:staging command was removed
so it cannot accidentally restore development authentication on the live Worker.

    npm run deploy

Wrangler is bound to the existing Cloudflare account. Its saved deployment
credentials are encrypted with their encryption key in macOS Keychain. The
existing OPENAI_API_KEY Worker secret is preserved during normal deployments.
Never place it in source, Info.plist, xcconfig, chat, or command arguments.

AI_ENABLED is currently true in wrangler.jsonc and on the live Worker.
After changing configuration, verify health, then a real-device generation. Health only reports configuration;
it does not authenticate the key with OpenAI or verify billing.

API key rotation does not require an iOS release: the app calls the same public
Worker hostname, and only the Worker reads OPENAI_API_KEY. Create a replacement
with the required project/model permissions, update the existing Worker secret,
verify a real-device generation, then revoke the old key. Never put the key in
the iOS app. On 19 October 2026, the replacement key
`Study Guard production — 2026-10-19` was deployed in Worker version `1886f483`.
It retains only Chat Completions Request permission and expires on 18 November
2026. A real iPhone generation test passed on 19 October at 18:49 UTC,
returning 40 validated flashcards in 28.247 seconds through the live Worker.
OpenAI records the replacement key as used on 19 October. The previous
`Study Guard staging — server only` key was then revoked, completing the rotation.

## Historical OpenAI account state (20 September 2026)

- Project: Study Guard Server. Only gpt-4o-mini is allowed; enforced monthly limit $5.
- The existing key is active with only Chat Completions Request permission.
  Its display name still says “Study Guard staging — server only”; the name does
  not change its permissions or prevent live use.
- The key expires on **20 October 2026**. Its expiration can be changed in the
  existing key's settings without generating another key. Address this before
  that date to avoid interrupting service; it has not been extended automatically.
- Last observed API balance: -$51.05. Organization spend: $694.69 against an
  enforced $80 monthly limit. OpenAI explicitly reports API requests blocked.
  No payment was made, and hard-limit enforcement was not raised or disabled.

## Physical-device verification

Debug and Release both use production App Attest and the existing Worker.
Apple explicitly supports selecting production App Attest during development by
setting the entitlement to production. Distribution through TestFlight and the
App Store uses production regardless of that development setting.

The previous device attempt failed before installation because Xcode had no
signed-in Apple account and its old provisioning profile lacked App Attest.
Sign into the Apple Developer account in Xcode, enable App Attest on the app's
identifier if required, and refresh automatic provisioning. The signed app's
identifier prefix must match APP_ID_PREFIX in wrangler.jsonc.

The opt-in enrollment test verifies Apple enrollment and reuse of the same key
with a fresh challenge, without calling OpenAI. The shared scheme passes the
STUDY_GUARD_LIVE_ATTESTATION build setting to the test environment; default is 0.
From the repository root, with your physical iPhone connected:

    xcodebuild -project diewithoutregrets.xcodeproj -scheme diewithoutregrets \
      -configuration Debug -destination 'platform=iOS,name=Mayo' \
      -allowProvisioningUpdates STUDY_GUARD_LIVE_ATTESTATION=1 \
      -only-testing:diewithoutregretsTests/FlashcardAPIClientTests/testLiveProductionAppAttestEnrollment test

Simulator runs always skip this test. No paid generation is performed by it.

For a separate, explicit one-request generation check after rotating a key:

    xcodebuild -project diewithoutregrets.xcodeproj -scheme diewithoutregrets \
      -configuration Debug -destination 'platform=iOS,id=YOUR_DEVICE_UDID' \
      -allowProvisioningUpdates STUDY_GUARD_LIVE_GENERATION=1 \
      -only-testing:diewithoutregretsTests/FlashcardAPIClientTests/testLiveProductionFlashcardGeneration test

This opt-in test uses synthetic biology material, verifies a 20–50-card response
through production App Attest, and does not save cards or modify existing decks.
It consumes one generation attempt and a paid OpenAI request; do not enable
automatic retries. A missing opt-in or a simulator causes it to skip.

## Verification and release

- Eleven backend unit/security tests passed on 19 October 2026.
- A live generation test on an iPhone 17 Pro passed through production App Attest
  and the replacement OpenAI key, returning 40 valid cards in 28.247 seconds.
  This confirms the text-generation path; YouTube transcript extraction is a
  separate failure and was not fixed by rotating the key.
- The runtime integration test passes for valid signed requests, tampering,
  replay, quota exhaustion, and failed-request accounting. It also verifies that
  legacy/development registrations cannot authorize the production ledger.
- The iOS simulator run passes 16 tests, with the additional live enrollment test
  skipped (17 total, one skipped, zero failures).
- Version 2.0.2 build 62 is prepared. App Store Connect already contains build 61.
  Recheck for a build-number collision before upload.
- The updated unsigned Release build compiled and passed the full bundle secret
  scan. Its Info.plist confirms version 2.0.2 build 62 and the existing
  studyguard-ai-staging hostname, with no legacy OpenAI key entry.
- The simulator and build details above describe the earlier release checks.
  Signed Release provisioning, testing the actual TestFlight build, and App Store
  upload were not verified as part of the 19 October server repair.

Before submission:

1. Confirm the Worker remains enabled and verify generation with the release candidate.
2. Remove any old OPENAI_API_KEY from Xcode Cloud settings. Historical archives
   are incident evidence and must not be re-released.
3. Inspect a signed Release archive: production App Attest and the existing
   studyguard-ai-staging hostname. The build phase scans the complete app bundle
   and rejects likely OpenAI secrets, obsolete key entries, and missing endpoints.
4. Test first enrollment, a second generation, relaunch, and reinstall/restore
   recovery. Test the actual TestFlight build against the same live server.
5. Test pasted text, PDFs, YouTube transcripts, and AI-enhanced Quizlet; check
   non-English text, quotes, long inputs, offline/service-off errors, and quotas.
   Direct Quizlet import and existing/manual cards must remain usable without AI.
6. Review published privacy and App Store disclosures. The Generate screen
   discloses forwarding study text through Study Guard's server to OpenAI.
7. Complete the signed upload, export-compliance details, and App Review submission.

## Incident response

Set AI_ENABLED to false and deploy to pause AI requests. Existing decks remain
local and usable. Revoke or rotate the affected server key; keep OpenAI enforced
limits on. Never restore provider keys or direct OpenAI calls in the iOS app.

## References

- [Apple App Attest environments](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
- [Apple server verification](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Cloudflare SQLite storage](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/)
- [OpenAI key security](https://help.openai.com/en/articles/8304786)

OneThing was inspected as a reference. It keeps its provider key server-side,
but its shared client token, client-selected device ID, and eventually consistent
KV counters are weaker than this implementation. It was not changed.
