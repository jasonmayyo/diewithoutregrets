# OneThing V5 → Study Guard

The app entry point now uses `SGV5RootView`. The previous container is retained as `LegacyOnboardingView` for reference. The imported views live in `diewithoutregrets/Features/Onboarding/V5`.

## Source

Copied from `/Users/jasonmayo/Desktop/OneThing` on 20 October 2026, including its uncommitted V5 profile, V5 screens, and personalized-plan changes. The baseline commit is `f287864`. `design/onboarding-v5/source-manifest.json` records the hashes of those working files; the native module's `source-map.json` maps imported files.

The active order is:

`800 → 813 → 803 → 804 → 805 → 806 → 820 → 807 → 810 → 819 → 818 → 808 → 817 → 821 → 812 → 801 → 814 → 815 → 816 → 506 → 601 → 602 → 606 → 604`

The current 24-step flow includes the monster picker (`821`) after the method and before the study rule. It offers the approved Willow, Zaza, Sarge and Gnash artwork. The numbered descriptions in the historical Round 1 section below predate this insertion. Fresh 29 October screenshots, including the picker and new monster unlock states, are in `design/studyguard-flow-review/index.html`.

Round 1 replaces the original priority question with separate study-level and exam-subject screens, and the habit question with the next exam date. The age question remains; screen 18 now uses a three-chapter illustrated student journey. The phone-time projection uses the exam horizon. Screen 14 sets the actual flashcard earning rate.

## Round 1 — 20 October 2026

- **01 / 800:** “Scroll Less. Study More.” uses the original bundled `mockupvideo.mp4` from Study Guard's earlier onboarding. The video loops silently and pauses when inactive or Reduce Motion is enabled.
- **02 / 813:** Biology (10 correct flashcards) earns 5 minutes; Criminal Law (20 correct flashcards) earns 10. Rewards use `SGContract.defaultPerCardSeconds`, currently 30 seconds per correct card. The 22 October pacing update shortens the pause between the two count animations from 1.9 seconds to 0.3 seconds and keeps their shared headline visible during the handoff.
- **03 / 803:** Required study level (high school, college/university, postgraduate, professional exams).
- **06 / 806:** An automatic visual demo inspired by the earlier Study Guard onboarding (`AIFlashcardDemo`, commit `7a2e2b6`): a scanning note sheet → animated card stack → automatic answer flip. Copy is reduced to “Your notes. Instant flashcards.” and “Less prep. More studying.” Continue is always available and advances immediately. The loop pauses when inactive, cancels on navigation, and shows a static finished card with Reduce Motion. It does not call the generation service or create a real deck.
- **07 / 820:** Required exam subject on its own screen, immediately before the exam date. Whitespace-only subjects cannot continue. Existing screen IDs remain stable.
- **08 / 807:** The next exam date, accepting today or a future day. The selected subject appears above the calendar.
- **11 / 818:** OneThing’s rounded-dot reveal now shows one dot per calendar day until the exam. Scrolling fills the equivalent number of 24-hour days, including a fractional final dot (30 days × 3 hours/day = 90 hours = 3.75 highlighted dots). The bottom headline reads “That’s 90 hours.” followed by the requested study-related typewriter sequence, ending with “Just… scrolling.” Continue stays enabled. The grid fits longer exam horizons without dropping days; today shows a dedicated same-day message. Reduced Motion shows the completed grid and a static sentence, and inactive scenes/navigation cancel the animation.
- **12 / 808:** “It’s not your fault” follows the exam-time calculation.
- **13 / 817:** The method follows reassurance, before the study-to-scroll rule.
- **14 / 812:** “Take your time back.” OneThing’s open tick-mark dial emphasizes estimated extra study hours before the selected subject’s exam. The 5 / 10 / 20-card slider updates the hours and the five-minute earning rule; the default is 10. The mascot sits inside the dial, and “Make this my goal” applies the rule to earning and quiz settings. The small estimate button opens the assumptions. Today shows zero full-day hours and “Your exam is today. Every card counts.”
- **15 / 801:** Study / Learn / Remember More headlines, study icons, and three short attributed excerpts from Study Guard’s actual App Store reviews. Cards link to the corresponding storefront. The OneThing numeric rating and user-count badges are removed. Source details are in `design/onboarding-v5/review-sources.md`.
- **16 / 814:** A generated transparent fist-bump pose replaces the idle mascot. A pulse marks the offered fist; tapping the mascot confirms the selected rule, plays a short bump/celebration and haptic, then advances once to the plan checklist. Reduce Motion uses a brief confirmation. Completion cancels on leaving the screen. The generated asset and exact prompt are in `design/onboarding-v5/assets/fistbump-generation.md`.
- **16–18 / 814–816:** The commitment, checklist, and student journey use the selected card count and subject. Screen 18 replaces the seven-day list with three generated illustrations: a first deck, a study-and-unlock rhythm, and walking into the exam. The student and mascot stay consistent across chapters. Users can swipe or tap chapter stops; the selected rule and floating CTA stay available. The exam countdown handles today and singular days. Reduce Motion suppresses the gentle artwork float. Asset provenance and exact prompts are in `design/onboarding-v5/assets/student-journey-generation.md`.

## Branding and integration

- Uses Study Guard's existing Meadow theme and mascot animations. Older static poses use multiply blending to remove their white matte; the generated fist-bump, student journey, and reading mascot assets use their real alpha channels.
- Specialized ghost illustrations use existing Study Guard poses. The welcome uses Study Guard’s own original video.
- The founder story is removed from the active flow. Page 15 now uses Study Guard App Store review excerpts with source links. Research copy remains source content for the requested phased revision and has not been newly verified.
- Screen 506 presents the Superwall `onboarding_paywall` placement directly. The hosted Study Guard flow includes its own introduction, so the extra local offer introduction is removed. RevenueCat still handles purchases, restores, subscription access, and the existing buyback offer.
- Answers persist under `studyguard.onboarding.v5.profile`. Study level, subject, exam date, age, baseline, and scrolling moment also update the existing preference keys. The exam date also updates the existing app-group key used by the report.
- Screen 14 models potential study time within the existing self-reported phone-time window: `days × daily phone hours × studyMinutes / (studyMinutes + 5)`, where `studyMinutes = cards × 30 / 60`. The 30 seconds per correct card is an explicit assumption, not a measured pace or a promised saving. At 30 days and 3 hours/day, 5 / 10 / 20 cards project 30 / 45 / 60 study hours. The remaining time stays scrolling, so the projection never adds time beyond the original window. This display does not change the real reward calculation.
- The selected rule writes 60, 30, or 15 seconds per correct answer to the existing app-group `sg_perCardSeconds` key. It also sets `flashcardCount` to 5, 10, or 20 and turns off `useAllCards`, so a full correct round earns five minutes. Smaller decks still use the available cards. Existing partial-reward rounding, unfinished/incorrect-answer handling, and the 60-minute reward cap remain in the shared engine. Old drafts without a choice display 10 cards and apply that default when confirmed.
- Screen Time authorization, app selection limits, notification permission, and setup completion call existing Study Guard services.
- Ordinary navigation cannot advance past the purchase step. Completion verifies an active entitlement. Permission or app-selection deferrals continue to the existing Guard setup checklist.

## Review

Open `design/onboarding-v5/index.html` in a browser. It works directly from disk and needs no build or remote service. The board uses actual iOS Simulator captures for every screen, with original OneThing screenshots alongside. Any additional state without a native capture is explicitly labeled as an HTML preview. Older source captures are labeled. Phase filters, state selectors, image enlargement, and a separate clickable HTML companion support discussion.

For a local HTTP preview:

```sh
python3 -m http.server 4174 --bind 127.0.0.1 --directory design/onboarding-v5
```

The HTML companion simulates purchase and permission steps. It is not the source of the native layout.

## Progress bar styling

Onboarding uses the flashcard quiz’s 16-point capsule progress bar: `SGTheme.inkHigh` track, mint fill, and a 4.5-point white shine inset from the top. The four setup steps share the same continuous bar and retain their step counter. Progress values and navigation are unchanged. The native component clamps its fraction and exposes a spoken percentage; Reduced Motion disables its fill animation. The HTML walkthrough matches the styling and progress semantics.

## Floating CTAs

Every primary onboarding CTA now uses `SGV5QuizContinueButton`: a solid mint capsule with no gradient or outline and a soft external shadow. The shared floating spacing is 24 points horizontally and 24 points above the safe-area bottom, with no footer panel. Welcome puts restore above Get Started; the plan uses the same primary treatment; screens 20–23 now enclose their actions inside the expanded rounded white card, with 22-point internal horizontal and bottom padding. Existing choice, fist-bump, automatic progression, purchase and permission behavior is preserved. The hosted Superwall paywall is configured separately from these local onboarding pages. The HTML walkthrough mirrors the button treatment and setup-card containment.

## Setup artwork and card layout — screens 20–23

The protection circle now contains a newly generated transparent reading pose of the Study Guard mascot. The small tile at the circle’s base and both notification examples use an unchanged copy of the current iOS app icon (`AppIcon.appiconset/Frame 11 (4).png`), displayed without multiply blending. The new illustration and exact prompt are recorded in `design/onboarding-v5/assets/setup-artwork-generation.md`.

The white card now wraps its progress header, scrollable content, footer copy, secondary action and primary button. Buttons stay solid mint and sit inside the card with consistent padding. The body can scroll on shorter screens while the actions remain available. Remaining OneThing wording in these four pages and their notification examples now refers to studying. The existing Screen Time, app picker, notification authorization, deferral and completion callbacks are retained.

## Haptic feedback — 22 October 2026

The native V5 flow uses a shared, foreground-only haptic vocabulary in `SGTheme.swift`. The exam-cost screen clicks softly for each non-whitespace typed character, marks the grid fill with up to ten beats, and punctuates the total and completed sentences. Continue/back actions, question choices, study level, exam date, subject focus, rule-slider stops, estimate details, journey chapters, restore outcomes, and setup controls also provide feedback. The notes-to-cards demo marks the stack, ready state, and answer flip. Existing earning, fist-bump, and plan-checklist feedback uses the same generators.

Generators are reused and closely overlapping callbacks are coalesced, so a CTA and its navigation callback produce one pulse. Decorative feedback follows Reduce Motion; action confirmations remain available. The typewriter and flashcard-demo tasks cancel on navigation or inactivity. The empathy reveals and plan checklist now use cancellable tasks, and the earning demo cancels its scheduled beats on backgrounding and restarts its current stage on return. Physical haptic strength and cadence require an iPhone; the Simulator can verify the flow but cannot reproduce the sensation.

## Validation

The 22 October haptic update passed the Simulator Debug build and all 14 `OnboardingV5Tests`. Native smoke checks verified the exam-cost typewriter, continuing before the sequence finished, the three empathy headline taps and completed statistics reveal, returning from the background, automatic checklist progression, and journey chapter selection. Physical haptic feel has not been tested on an iPhone.

The screens 20–23 artwork and card update passed a fresh Simulator Debug build and JavaScript syntax checks. All four native screenshots were refreshed and visually checked for readable content and contained actions. Native setup introduction forward/back navigation, HTML setup progression and app-selection deferral, and the refreshed notification screenshot in the review board were verified. Both logo copies match the actual app icon byte-for-byte, and the generated mascot retains its alpha channel. Existing permission services and earning logic were unchanged; live system permissions and the earlier unit-test suite were not rerun for this styling update.

The screen 18 student journey update passed a fresh Simulator Debug build and JavaScript syntax checks. Three new transparent illustrations were inspected and copied unchanged into the native asset catalog and HTML assets. Native chapter taps and immediate continuation into the existing offer screen were verified. Browser checks covered chapter taps, arrow keys, horizontal swipes, immediate continuation, the selected 20-card rule, and the enlarged native screenshot states on the review board. All three native chapter captures were refreshed. Earning and projection logic is unchanged; the earlier unit-test suite was not rerun for this visual update.

The flat floating CTA update passed a fresh Simulator Debug build and JavaScript syntax checks. Native welcome/setup placement, setup navigation, HTML required-answer disabled states, and the refreshed screenshot board were checked. All affected CTA captures were refreshed, including the offer, study-rule variants and scrolled plan states. The existing earning/navigation unit tests were not rerun for this styling change.

The progress-bar styling update passed a fresh Simulator Debug build, JavaScript syntax checks, browser forward/back checks, and visual checks at early, middle, and complete progress. All 15 affected native captures (including the three study-rule choices) were refreshed; the HTML board and walkthrough were checked. No earning or navigation logic changed.

The page 15/16 review and fist-bump update passed a fresh Simulator Debug build and HTML JavaScript syntax checks. Native and browser checks verified the new mascot, disabled repeat taps, confirmation feedback, and progression into plan setup. Both native captures were refreshed and verified in the HTML screenshot board. Reduced Motion suppresses the celebration and exposes reviews as a manually scrollable row; decorative particles are hidden from accessibility. The prior 33-test result below covers the unchanged earning and projection logic and was not rerun for this visual-only update.

The iOS Simulator Debug build succeeds. All 14 `OnboardingV5Tests` and 19 `StudyGuardEngineTests` pass (33 total). Coverage includes the study-hours scenario across all card choices and baselines, conservation of the original phone-time window, zero/past/missing exam dates, long horizons and DST, all three study rules and their exact five-minute rewards, default confirmation, persisted app-group rate and quiz size, old drafts, source order, exam calculations, same-day/past dates and daylight-saving boundaries, required answers, back navigation, double-tap behavior, and the purchase navigation boundary. Browser checks cover all three rule estimates, the calculation dialog, a same-day exam, the refreshed screenshot board, and the previously checked downstream commitment, checklist, and plan, plus the previously checked subject/date validation, automatic generation animation, filters, comparison, and enlargement.

The earlier exam-dot update passed all nine onboarding tests and was checked at 0, 1, 30, and 365 days, including partial-day coloring.

The 21 October visual demo update was checked with a successful Debug build, native scanning/ready captures, a live scan → question → answer loop, and immediate Continue in both the simulator and HTML companion.

Use a dedicated simulator for screenshots. Debug builds accept `-sg-v5-<screenID>` with sample answers and `-hasCompletedOnboarding NO`; these screen-jump arguments are omitted from Release builds. Additional Debug-only capture flags: `-sg-v5-exam-dots` (finished exam grid), `-sg-v5-exam-days <0–3650>` (preview horizon), `-sg-v5-scanning`, `-sg-v5-generated`, `-sg-v5-rule-cards <5|10|20>`, `-sg-v5-plan-middle` (journey chapter 2), `-sg-v5-plan-end` (journey chapter 3), `-sg-v5-demo-earned`, and `-sg-v5-demo-spent`. The `capture-native.py` helper refreshes this round’s screenshots on an already installed dedicated simulator; `--screens 812 814 815 816` limits it to the rule and dependent pages. A real purchase and production Screen Time authorization were not performed as part of screenshot generation.

## Superwall onboarding — phase 3, 21 October 2026

- Campaign: **Study Guard Onboarding** (`114163`) in Superwall app `58386`. The active `onboarding_paywall` placement targets unsubscribed users, with **Study Guard | Study First** (`283322`) receiving 100% of traffic and no holdout.
- `SGSuperwallBilling` supplies Superwall's purchase controller. Purchases and restores still run through RevenueCat. The existing RevenueCat entitlement **`Pro Acess`** maps to Superwall **`pro`**; both identifiers are deliberately preserved.
- `SGOnboardingPaywallCoordinator` checks RevenueCat before presentation and after a purchase, restore, skipped placement, or external buyback completion. Only the exact active entitlement permits setup. Missing campaigns, network failures, empty restores, and non-gated dashboard variants cannot bypass the app's purchase boundary.
- Presentation errors offer Retry and Restore. Retrying refreshes Superwall configuration. Duplicate callbacks are ignored, and a late presentation cannot replace a buyback offer that has already taken over. The existing decline survey and buyback ladder remain available.
- Existing subscribers continue directly into setup. Welcome restores and final setup completion use the same exact RevenueCat entitlement check. Foreground refreshes and RevenueCat's customer-info stream keep Superwall's access status synchronized.
- The main entry point is `SGV5RootView` → screen 506 → `HardPaywallView` → `onboarding_paywall`. Verified access advances to the existing Screen Time and app-selection setup.

Phase 3 validation: the Debug Simulator build and all 32 selected tests passed (13 presentation/access-flow tests, 5 billing-bridge tests, and 14 existing onboarding tests). On the dedicated review simulator, tapping **Let's start my journey** on screen 816 opened the hosted Superwall flow. The intro, reminder, annual/weekly pricing, and founder exit drawer were visually checked. Restore returned **No Subscription Found** and stayed on the paywall. No purchase was completed; a sandbox/TestFlight purchase and successful restore on a device remain release checks. Screenshots are in `outputs/superwall-phase3/`. No App Store or TestFlight build was uploaded.
