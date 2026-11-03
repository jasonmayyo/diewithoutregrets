# Moderation recheck — 2 November 2026

The earlier provider access correction now passes the live checks. No additional
key/model permissions, spend-limit changes, credential rotation, safety bypass,
or production deployment were needed during this follow-up. No support request
was sent. The exact provider-side cause of the earlier intermittent denial is
not established; delayed application of the access change is a plausible
explanation, not a confirmed diagnosis.

- Nine direct moderation probes succeeded with the existing production secret.
- Isolated live-provider tutor matrix: 12/12 expected results (8 screened replies,
  4 blocked injections); the previously failing coach/distress case passed eight
  additional repetitions.
- Live generated scripts for all four personas passed input/output moderation.
- Physical iPhone through production App Attest and the live Worker: 12/12 expected
  results (8 screened replies, 4 blocked injections), 18.852 seconds.
- Total: 73 successful moderation responses, zero moderation 403s. A provider
  success may correctly flag unsafe text; it does not mean all content passed.
- Offline checks passed again: backend 32, Worker integration 1, Swift study
  99 (4 opt-in skips), storage 9, shield/routing 34, countdown 11.
- Integration now explicitly injects input/output moderation 403s and verifies
  no reply disclosure, no retry, replay rejection, quota retention and cleanup.
- Existing signed archive rechecked: version 2.0.7 (2), retired media/private API
  checks pass, no client OpenAI key. App sources and distribution IPA unchanged.

`provider-verification.json` contains only synthetic fixture results from an
isolated remote preview using the production provider helper functions and
existing encrypted secret binding. It did not alter production HTTP routes,
App Attest, quotas or database records. `device-safety-matrix.json` records the
separate real app-to-production check. Returned synthetic text was reviewed.
The preview and log tail were stopped after verification.

Current sign-off and remaining manual/device/distribution gates are in
[MonsterUnlockReleaseReadiness.md](../../Docs/MonsterUnlockReleaseReadiness.md).
Prior failures remain preserved in the original release evidence directory.
