# Release fix evidence — 2 November 2026

Historical results below are preserved. The subsequent [moderation recheck](../monster-moderation-recheck-2026-11-02/README.md) passes, including all 12 physical-iPhone cases and zero 403s across 73 moderation responses.

Final status and remaining gates are tracked in
[MonsterUnlockReleaseReadiness.md](../../Docs/MonsterUnlockReleaseReadiness.md).
The compact result files preserve actual test summaries without copying device
diagnostics, user identifiers, credentials or source content from runtime logs.

Current source/build checks:

- Backend: 32 passed; Worker integration: 1 passed.
- Final offline Swift harness: 99 study tests (95 passed, 4 opt-in live tests
  skipped) and 9 storage tests passed.
- Shield/routing: 34 passed; countdown: 11 passed.
- Full simulator: 180 tests (178 passed, 2 opt-in live tests skipped), before
  addition of two further opt-in device checks. The new test code also compiled
  in the final offline harness and signed physical-device test bundle.
- Unsigned Release build succeeded. Verified actual app/extensions at 2.0.7 (2),
  with no retired reaction-media directory/private handoff symbols/provider key.
- Signed archive and App Store distribution export also succeeded. See
  `distribution-verification.json` for the actual exported IPA's signature,
  provisioning and entitlement checks. No app upload was performed.
- Live health returned HTTP 200 with `enabled: true`; this is not a provider test.
- Framer policy and approved App Store user-content declaration published and
  visually verified through their respective UIs.

The basic live moderated tutor test now passes. The full persona matrix is not
green yet. Initial requests failed closed;
content-free Worker diagnostics reported upstream moderation HTTP 403. Both
the key's Moderations Request permission and the project's moderation-model
allowlist have now been enabled with explicit owner approval and verified in
the UI. Subsequent live requests demonstrated successful educational responses,
injection blocking and supportive distress responses, but intermittent upstream
403s still interrupt the four-persona evaluation. The final matrix completed all 12 cases: 7 screened
replies, 4 blocked injections, 1 provider failure. See `live-safety-matrix.json`.
The provider failure remains an open reliability gate.

Raw local logs are under `/tmp/monster-fixes-*.log`; the Xcode result bundles
remain under `build/buddy-onboarding/Logs/Test`. Do not publish device logs as
release evidence without removing runtime identifiers and diagnostics.
