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

**AI generation remains disabled while OpenAI billing/access is blocked.**
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

Current initial limits remain 10 attempts per installation per UTC day, three
per minute, 20 globally per UTC day, and 100 globally per UTC month. One call per
installation and eight globally may be in flight. Failed or timed-out upstream
calls remain counted; paid calls are never retried automatically. These request
ceilings supplement the $5 enforced OpenAI project budget. Review capacity before
wider rollout; do not silently raise spend or request limits.

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

When billing is restored, change AI_ENABLED to true in wrangler.jsonc and deploy.
Verify health, then a real-device generation. Health only reports configuration;
it does not authenticate the key with OpenAI or verify billing.

## OpenAI account state

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

## Verification and release

- Nine backend unit/security tests pass.
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
- Live Apple enrollment, successful OpenAI generation, signed Release provisioning,
  TestFlight testing, and App Store upload remain unverified.

Before submission:

1. Restore OpenAI billing/access, enable the Worker, and test actual generation.
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
