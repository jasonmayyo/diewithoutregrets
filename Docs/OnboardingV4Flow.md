# Onboarding v4 — "Ace the Semester" flow map

Rocapine problem-first structure applied to Study Guard. Mapped screen by screen
against the live v3 flow (`OnboardingStep` in OnboardingViewModel.swift, flow
version "sg_v3"). Legend: **KEEP** (as is / copy polish), **UPGRADE** (same
screen, new job), **NEW**, **CUT**, **MOVE**.

The narrative: *I feel the pain → the app understands MY exam → it sees my real
screen time → it shows me the damage in days → it shows me the fix working → it
hands me a personal plan → I unlock the plan.*

---

## Phase 1 — Confront (v3 pain phase, mostly keeps)

| # | Screen | v3 | Status | Job / copy direction |
|---|--------|----|--------|----------------------|
| 1 | Hook | `hook` | KEEP | Confronting welcome. Sharpen headline to name the pain head-on ("You know you should be studying"). Restore path stays. |
| 2 | It's 11pm | `theFeeling` | KEEP | The emotional identification beat. Already the strongest screen — don't touch the choreography. |
| 3 | Not your fault | `notYourFault` | CUT (merge) | One job per screen: its line survives as the closing beat of willpowerLie. |
| 4 | The willpower lie | `willpowerLie` | KEEP | Failed-fixes strikethrough. Ends on "Every fix that relies on you breaks." |
| 5 | Quiz intro | `meetYourGuard` | UPGRADE | Mascot stays, but the job becomes the Quittr beat: "Answer honestly — this is about you, not us." Sets up the questionnaire. |

## Phase 2 — The quiz (personalization + confrontation)

Auto-advance style unchanged. Night sky throughout.

| # | Screen | v3 | Status | Job |
|---|--------|----|--------|-----|
| 6 | Name | — | NEW | "What should we call you?" One field, skippable. Powers "Jason, here's how you ace the semester" — the plan reveal needs a name to feel personal. Store as person property `first_name`. |
| 7 | Age | `quizAge` | KEEP | |
| 8 | Student type | `quizStudentType` | KEEP | |
| 9 | Screen time (self-report) | `quizScreenTime` | KEEP | Stays even with real data: it's the denial fallback AND the setup for the reality-check beat (their guess vs truth). |
| 10 | When do you scroll | `quizScrollTimes` | KEEP | |
| 11 | Symptom selection | — | NEW | Multi-select, Quittr symptom beat: "Grades slipping" / "Cramming at 2am" / "Can't focus 10 minutes" / "Promised myself I'd stop". Each selection later maps to a feature line in the demo phase. |
| 12 | Testimonial drop-in | — | NEW | One real quote mid-quiz (Rocapine: legitimacy from users, not cold proof). Full-bleed, 1 screen, auto-advance feel. |
| 13 | Exam date | `quizExamDate` | UPGRADE | From coarse buckets to an exact date picker: "When's your next big exam?" Calendar sheet; quick-picks (2 weeks / 1 month / 2 months) that pre-fill the date. "No exams, just deadlines" path defaults to +8 weeks and swaps copy from "exam" to "deadline season". Compute + persist `examDate` and `daysToExam`. Also write examDate to the app group (the report extension needs it — see Diagnosis). |
| 14 | Preparedness baseline | — | NEW | "Honestly — how ready are you for it right now?" Way behind / A bit behind / On track / Ahead. Feeds the verdict copy and the plan's intensity (recommended card count). |
| 15 | Reality check (Screen Time auth) | — | NEW / MOVE (from post-paywall step 22) | The confrontation permission ask: "Most people guess about 40% low. Want to see your real number?" CTA "Show my real screen time" fires `requestAuthorization()`. Secondary "Use my estimate" skips. Both paths advance. Analytics: `screen_time_auth_result(surface: "onboarding_diagnosis")`. v3's `screenTimeExplainer` + `screenTimePermission` post-paywall screens become conditional — shown only if this was skipped/denied. |

## Phase 3 — Diagnosis (the receipt, reworked around the exam)

| # | Screen | v3 | Status | Job |
|---|--------|----|--------|-----|
| 16 | Analyzing | `calculating` | UPGRADE | Loader micro-steps must reference real answers: "Reading your screen time…", "Counting the days to [exam date]…", "Comparing you to [student type]s…". Rocapine trick available: pause at 90% for one final question if we want a beat here. |
| 17 | The verdict | `semesterDrain` | UPGRADE | **The dependency-score peak.** Grid reworked from fixed 15-week semester to *days until their exam*: "47 days until your exam. Your phone is set to eat 14 of them." When authorized, the big number renders in a NEW DeviceActivityReport scene (real last-7-days average × daysToExam); fallback is the self-reported math. Preparedness answer sharpens the copy ("and you said you're already behind"). |
| 18 | Days lost cycle | `daysLost` | CUT | Its content folds into the verdict. Two screens of the same bad news dilutes the peak. |
| 19 | The imagine | `theImagine` | KEEP | The turn: grid heals, "half of that back is N full study days — enough to walk in ready." Tie to their preparedness answer. |
| 20 | Rating prompt | — | NEW | `SKStoreReviewController` at the emotional peak, right after theImagine (Quittr placement). Once per install. |

## Phase 4 — Show the fix (demonstrate, don't describe)

| # | Screen | v3 | Status | Job |
|---|--------|----|--------|-----|
| 21 | Try it (interactive demo) | `coreMechanic` | UPGRADE | **The aha inside onboarding.** A staged locked-Instagram moment → they answer ONE real flashcard (canned card, real QuizV2 components) → coin flock banks 30 seconds into the chip, live. Replaces three explainer screens: `science` (CUT — one stat line moves into the demo outro), `noWillpower` (CUT — its line becomes the demo caption: "No willpower needed. The lock does the work"), `moreFeatures` (CUT — symptom answers from #11 map to one feature line each on the plan reveal instead). |
| 22 | Social proof | `reviews` | KEEP | Tightened; sits directly before commitment. |

## Phase 5 — Commitment, plan, paywall

| # | Screen | v3 | Status | Job |
|---|--------|----|--------|-----|
| 23 | Commitment: your unlock rule | — | NEW | "How hard should we make it to open Instagram?" Card-count picker showing the real economy: 5 cards · 5 min, **10 cards · 5 min (recommended)**, 20 cards · 10 min. Writes `flashcardCount` + AppStorage; preparedness answer nudges the recommendation. This is the Rocapine commitment block AND the setting that feeds `grantEarnedBudget`. |
| 24 | Building your plan | — | NEW (reuse calculating chrome) | Final loader: "Locking in your unlock rule… Mapping [N] days to [exam date]… Writing Jason's plan…" |
| 25 | Plan reveal (pre-paywall) | — | NEW | **The key conversion screen.** "Jason, here's how you ace [Nov 4]." Recap card: Goal (walk in ready) · Blocker (phone, X days at stake) · Your rule (10 cards = 5 min of Instagram) · Day 1 (upload your study notes) · First milestone (7-day streak) · By exam day (N study days reclaimed). CTA "Unlock my plan". |
| 26 | Paywall | `paywall` | KEEP (iterate) | RC hard paywall + decline ladder stays. Headline now inherits from the plan ("Your plan is ready"). Rocapine deltas to test later in RC dashboard, not this build: per-day price display, 3-step arc, trial only on yearly. |

## Phase 6 — Post-purchase setup (shrinks)

| # | Screen | v3 | Status | Notes |
|---|--------|----|--------|-------|
| 27 | Screen Time explainer + permission | `screenTimeExplainer`, `screenTimePermission` | CONDITIONAL | Skipped entirely when auth was granted at step 15 (the common case). Kept as rescue for skip/deny. |
| 28 | Pick guarded apps | `guardedApps` | KEEP | FamilyActivityPicker stays post-purchase (heavy UI, and selection is a setup act, not a narrative one). |
| 29 | Usage interval | `usageInterval` | KEEP (recopy) | Reframe as "daily starter budget" per the new economy copy. `completeSetup()` unchanged. |
| 30 | Notifications | `notificationPrimer` | KEEP | |
| 31 | Unlock method | `unlockMethod` | CUT | The plan already prescribed flashcards (and step 23 configured them). True Focus remains discoverable in-app; this screen's persistence side-effect (`saveUserData()`) moves to completion. |
| 32 | Create first cards | `createFirstCards` | KEEP (reframe) | Framed as "Day 1 of your plan" to close the loop with the plan reveal. |
| 33 | Completion | `completion` | KEEP | Now owns `saveUserData()`. `onboarding_completed` gains `exam_date`, `days_to_exam`, `preparedness`, `flashcard_count`, `auth_in_onboarding` props. Flow version bumps to "sg_v4". |

---

## Build notes

**New report-extension scene (real-data verdict).** Add `OnboardingDiagnosisReport`
scene to StudyGuardReport with context `onboardingDiagnosis`. Host writes
`sg_examDate` (+ name if we want it rendered) to the app group before step 16;
extension filters last 7 days, computes avg daily minutes × daysToExam → days
lost, renders the verdict number + one-line comparison in onboarding chrome.
Host embeds `DeviceActivityReport` inside the verdict screen with the
self-reported layout as instant fallback beneath (extension renders nothing in
simulator and can be slow on first paint — fallback shows immediately, real
number replaces it when the report paints). Data never leaves the extension;
`phone_days` analytics keep using the self-reported figure.

**Step enum surgery.** `OnboardingStep` cases: remove `notYourFault`,
`daysLost`, `science`, `noWillpower`, `moreFeatures`, `unlockMethod`; add
`name`, `symptoms`, `testimonial`, `preparedness`, `realityCheck`,
`ratingPrompt`, `tryIt`, `commitment`, `planBuilding`, `planReveal`. Progress
bar fractions recompute. Every step keeps the `onboarding_step_viewed/completed`
pair; flow_version "sg_v4" everywhere so v3 vs v4 segments cleanly in PostHog.

**Economy tie-ins (already shipped).** Step 23 writes `flashcardCount`; the
earn labels reuse `SGContract.earnedMinutes(cardCount:perCardSeconds:)`. The
onboarding plan builder may later write `sg_perCardSeconds` per-user — the key
already exists.

**Risk watch.** The step-15 auth ask is the one real conversion gamble:
`screen_time_auth_result` + funnel drop between steps 15→16 tells us the cost
in the first test. If it hurts, the fallback design means we can move the ask
back post-paywall by flipping one step-order array without touching screens.

**Rocapine checklist state.** Personal question before money ✓ (name, exam,
preparedness). Social proof before paywall ✓ (mid-quiz testimonial + reviews).
Aha inside onboarding ✓ (step 21 live flashcard + coin bank). Natural paywall
lead-in ✓ (plan reveal). Remaining homework: walk Pose's onboarding on a real
device before locking screens.
