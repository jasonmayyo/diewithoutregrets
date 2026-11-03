# Draft support request — not sent

Owner instruction: keep this draft; do not send it on the owner's behalf.

Historical draft: subsequent verification on 2 November passed 73 moderation
responses with zero 403s, including the complete physical-iPhone matrix. This
draft has not been sent; its description below preserves the earlier failure.

Destination: OpenAI API support.

Subject: Intermittent Moderations API HTTP 403 after verifying project/key access

We are validating a Study Guard release using the Moderations API from a
Cloudflare Worker. Some requests succeed, while other requests return HTTP 403.
Our app withholds unchecked replies; we have not disabled screening or added
automatic retries/failover for these denials.

Project: Study Guard Server (`proj_vEpsQHUd2zEz0SAgrbzqC3BW`).
Endpoint: `POST https://api.openai.com/v1/moderations`.
Model: `omni-moderation-latest`.
Affected request ID: `req_1877ff18b2be436d898586e359ff2b38`.
Date/time: 2 November 2026, approximately 09:01 UTC.

The existing restricted production key has Chat completions Request and
Moderations Request permissions. The project allowlist permits `gpt-4o-mini`
and `omni-moderation-latest`; both settings were saved and rechecked. The key
expires 18 November 2026. The project UI shows an enforced $5 spend limit with
no recorded spend against the new month's limit.

A bounded synthetic evaluation produced seven screened educational/supportive
replies, four correctly blocked card-injection attempts, and one moderation 403.
The failed case asked for a calm next step after a wrong study answer. No real
student data was used. Error bodies and credentials were not logged; our
classified diagnostics recorded an access denial, with no recognized error code.

Please identify the reason for the 403 using the request ID and advise the
smallest required correction. We want to keep the current least-privilege model
and key restrictions, spending limit, and safety checks.

This draft contains no API secret, device identifier or real student content.
