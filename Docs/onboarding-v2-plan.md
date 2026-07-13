# Study Guard Onboarding v2 — Full Redesign Plan

Mirrors the **active OneThing V4 flow** (25 screens, `flowOrderV4`, hardcoded `shouldUseV4 = true` — the V1/V2/V3 flows in that repo are legacy and were excluded). Same formula, same screen anatomy, same choreography grammar — rebuilt in Study Guard's Meadow design system with the monster mascot carrying the emotional thread.

---

## The formula (what we're copying)

OneThing V4 is an emotional sales arc: **"sell the feeling, not the feature."**

1. **Discovery** — hook → absolution/villain → hope → mascot reveal → a fast 4-question quiz (auto-advance, floating clipboard mascot as "interviewer")
2. **Reality check** — fake "calculating" beat, then ~70 seconds of auto-choreographed, personalized pain: every number computed from the user's own quiz answers
3. **The turn** — the same visuals heal: "win back N years"
4. **Convert** — science → core-mechanic demo built from real home-screen components → feature reel → founder story → review wall + rating request → hard paywall
5. **Post-purchase** — explainer→request pairs for each permission, product setup, completion

Signature moves to replicate exactly:
- Heavy screens **auto-choreograph** on timelines; the CTA only fades in when the beat lands (the delay IS the pacing)
- **Haptic grammar**: rigid = lock, soft = gain, light = per-tick, medium = beat, heavy = climax (`SGTheme.tickDownHaptic` etc. already match)
- **Mascot as narrative thread**: villain phase (angry/sad) → quiz (clipboard interviewer) → teaching (mechanics) → idle/happy (completion)
- **Personalization callbacks**: screen-time hours drive the dot grid, "N years", "win back N years" (×0.8), the paywall headline; student type is echoed on the paywall subtitle
- **Micro-commitment CTAs** on pain screens: "I want my time back", "Let's do this" — never just "Continue"
- Social proof appears **three times**, escalating toward the paywall
- Permissions **after** purchase, each primed with a value explainer before the OS dialog
- Screen transitions are 0.3s opacity crossfades; quiz questions auto-advance ~0.3s after selection with no continue button

**Visual arc (Study Guard twist):** Discovery and Reality Check play on the **night-sky/dusk backdrop** (deep blues from the clouds Lottie + dusk gradient already in `RegretGuard.swift`; `Clouds 2.lottie` is bundled and unused — use it here). The Turn (screen 13) literally brings **dawn**: the backdrop crossfades to the daylight Meadow (warm white + green + `MeadowDotRipple`) and stays there through conversion and setup. Villain = night, Study Guard = daylight.

---

## PHASE 1 — DISCOVERY (screens 1–8)

### 1. `HookView` *(replaces TheHookView)*
- **Purpose:** first impression + housekeeping (restore path, legal links)
- **Layout:** top 55% = `LoopingVideoPlayer("mockupvideo")`; headline + subtext; full-width mint CTA pill; small "I already have an account" restore button; Terms/Privacy links (App Store requirement — keep)
- **Copy direction:** "Scroll less. Study more." / "Study Guard locks your distracting apps until you've studied." / CTA "Get started"
- **Choreography:** staged fade+rise entrance (headline 0.3s, subtext 0.8s, CTA 1.2s)
- **Keeps:** restore purchases (success → `completeOnboarding()` short-circuit, mirrors OneThing); `onboarding_step_viewed` fires from VM init
- **No progress bar**

### 2. `NotYourFaultView` *(new — OneThing 108)*
- **Purpose:** absolution + villain reveal
- **Layout:** night backdrop. Phase A: word-by-word 34pt reveal "It's not your fault." → user **taps 3×** to stack evidence cards (spring in, rotated ±3°). Phase B: crossfade to stats cascade — "10,000+ ENGINEERS / $100B+ IN FUNDING / PhDs IN BEHAVIORAL PSYCHOLOGY" → red kicker words popping one at a time: "you. can't. stop. scrolling."
- **Mascot:** none (the villain owns this screen)
- **Asset gap:** OneThing uses 3 news-headline photos (`law1-3`). Either export equivalents, or v1 ships typographic stat cards (works without photos)
- **Haptics:** medium per tap, heavy on final kicker word
- **CTA:** "Continue" fades in after cascade (~6s)

### 3. `FightingBackView` *(new — OneThing 110)*
- **Purpose:** hope pivot + first trust badges
- **Layout:** two opposing infinite icon marquees (study-life icons in 44pt circles, 35% opacity, edge-fade mask) sandwiching a rotating 40pt aspiration line over a fixed "Scroll less.": "Study more. / Sleep more. / Remember more. / Stress less. / Live more." Below: trust badges (star rating + "45,000+ students") and mint CTA "Let's go"
- **Trust badges:** render natively (stars + `char1-3` avatar stack) — no image assets needed
- **Choreography:** all auto within 1.5s; tagline rotates on a 2.5s timer with push-up transition

### 4. `MeetYourGuardView` *(new — OneThing 111, the mascot reveal)*
- **Purpose:** introduce the monster + emotional gut punch
- **Layout:** night backdrop, center `MascotView(pose: .idle)` at 220pt with a soft glow. Top overlay: fake iOS notification banners spawning every 1.2s (ultraThinMaterial, up to 3 stacked — Instagram "Someone liked your photo", TikTok, Snapchat, Duolingo streak, BeReal...). As the flood peaks, the mascot swaps to the **`angrey` still** (scale-pop + heavy haptic) — he hates what the notifications are doing to you. Three descriptor words pop in: "Distracted." "Exhausted." "Behind." Then the mint pivot line: "Your monster is done watching."
- **Copy direction:** "This is your study monster." → descriptors → "He's here to win your time back."
- **CTA:** "I'm ready"
- **Uses the new assets:** `angrey.png` (first use anywhere), notification-banner component is new + reusable

### 5–8. The Quiz *(OneThing 101/102/104/105 — auto-advance, persistent clipboard mascot)*

**Shared quiz scaffold** (new `QuizScreenContainer`):
- Top bar: 32pt back button + 5pt capsule progress bar (0.10 → 0.30 across the four questions)
- **Persistent floating `MascotView(pose: .clipboard)` (~100pt) rendered ONCE by the container as an overlay above all four question screens** — it floats continuously while questions crossfade beneath it, and `replayKey` bumps on every answer so the monster visibly "takes a note" per pick. This is the clipboard-animation centerpiece you asked for.
- Question anatomy: muted inline number ("1.") + question + one-line justification subtitle
- Option rows: existing `OnboardingOptionRow` upgraded — radio fills mint with checkmark, press-scale, **selection auto-advances after 0.3s, no continue button**
- Analytics: keep per-question events

| # | Screen | Question | Options | Data kept |
|---|--------|----------|---------|-----------|
| 5 | `QuizAgeView` | "How old are you?" — *"This helps us tailor your plan to your life stage."* | existing 8 age ranges | `selectedAge` + `onboarding_age_selected` |
| 6 | `QuizStudentTypeView` | "What best describes you?" — *"Different students need different strategies."* | 🎓 High school / 📚 College / 🧪 Grad school / 📝 Studying for exams / 💼 Learning for work / ➕ Other | **new** `studentType` — echoed verbatim on the paywall |
| 7 | `QuizScreenTimeView` | "How much time do you spend on your phone each day?" — *"Be honest, this is just between us."* | 2–4h "About average" / 4–6h "Higher than ideal" / 6–8h "This is affecting your grades" / 8+h "Time to take back control" | `screenTime` + `onboarding_screen_time_selected` — drives ALL downstream math |
| 8 | `QuizScrollTimesView` | "When do you scroll when you should be studying?" — *"This helps us protect your most vulnerable hours."* | While studying / In bed / Honestly, all day (image cards with mascot thumbnails) | **new** `peakScrollTime` |

**Cut from the current flow** (matching OneThing's deliberately tiny question load): `TheFeelingView`, `TheObstacleView`, `NameView`. Consequences: `selectedFeelings`/`selectedObstacles`/`userName` person properties retire; `StudyGuardReadyView`/`CompletionView` personalization switches from name to numbers/student type. *(If you want to keep name capture, it slots cleanest as question 0 — but OneThing V4 has no name question and personalizes via occupation instead. Recommend cutting.)*

---

## PHASE 2 — REALITY CHECK (screens 9–14, ~70s, fully auto-choreographed, night backdrop)

### 9. `CalculatingView` *(OneThing 200)*
- Clipboard mascot (110pt) inside an expanding pulsing ring; rotating status line every 0.9s: "Analyzing your screen time... / Calculating hours lost... / Mapping your semester... / Preparing your reality check..."
- **Auto-advances ~4s. No CTA, no back.** Pure anticipation theater.

### 10. `LifeDrainView` *(OneThing 210 — the centerpiece)*
- **80-dot "your life in years" grid** (8 columns, rounded squares). Three auto phases:
  1. Obligations fill with captions: "27 years sleeping / 18 years working / 7 years commuting / 5 years eating / 3 years on chores" (light haptic per group)
  2. Free time pops **green**: "20 years — of actual free time."
  3. Phone drains free dots **ember red** one-by-one using THEIR hours: "Your phone will steal **N** of them. That's **P%** of your free time, gone."
- Math (copy OneThing exactly): `phoneYears = dailyHours/24 × 80 × 0.6`, capped at free years
- Haptics: light every 3rd drained dot, heavy on drain start + percent reveal
- Phase-2/3 companion visual: `sademotion.lottie` (bundled, currently unused) beside the drain caption
- CTA fades in 2.5s after the drain: **"This needs to change"**

### 11. `StudyVsScrollChartView` *(adapts OneThing 214 to the student story)*
- Animated Bézier area chart, 300pt: hours/day curves across the semester — **"Who gets your hours?"** Study line and sleep line drawn first with cited sources (reuse `steel-logo` / `common-sense-media-logo` citation treatment), then the chart **rescales its Y-axis** as the phone line dwarfs both (red, glowing). Final subtitle: "**N minutes**. Every single day."
- Haptics: light per curve, heavy on rescale

### 12. `HoursLostCycleView` *(OneThing 212 — the typographic hammer)*
- Static 36pt header "That's **N years**" while four endings crossfade beneath (blur 6→0, 2.8s each): "of lectures sat through, distracted." / "of grades below what you're capable of." / "spent watching other people live." / "not becoming who you're meant to be."
- CTA after all four: **"I want my time back"**

### 13. `ReclaimView` *(OneThing 213 — THE TURN)*
- Same 80-dot grid pre-seeded in its drained state; red dots flip back to **glowing mint green** one-by-one (scale-pop 1.25). Title: "Study Guard helps you win back **N years** of your life" (`N = phoneYears × 0.8`)
- **The dawn beat:** backdrop crossfades night → daylight Meadow during the healing animation
- CTA: **"Let's do this"**

### 14. `AfterChartView` *(OneThing 215)*
- The chart from screen 11, curves pre-drawn; a green "**Phone (with Study Guard)**" line draws at 20% of their minutes while the red line dims. "Less scrolling. Better grades. More life."
- CTA: "Continue"

---

## PHASE 3 — CONVERT (screens 15–20, daylight Meadow)

### 15. `ScienceView` *(OneThing 225 + merges the current three science screens)*
- "**The Study Guard Method**" — floating `MascotView(pose: .teaching)` (bobbing), one line of method framing, gold/mint hairline divider, citation row (`steel-logo`, `common-sense-media-logo`, Cepeda 2006 spaced-repetition line from the current `LongTermResultsView`)
- Replaces `ScreenTimeStudyView` + `ProcrastinationStudyView` + `StudyConsistancy` + `LongTermResultsView` (four screens → one credibility beat)

### 16. `CoreMechanicView` *(OneThing 230 — the crown jewel, built from REAL home components)*
- Staged beats on the actual Meadow hill with `MeadowDotRipple`, `GlassPill`s, and the giant countdown numeral (reuse `CountdownReplayModel` roll mechanics + delta labels just built):
  1. **"When your scroll time runs out, your apps lock."** — app-icon row gets lock overlays (rigid haptic each), numeral rolls to 0m, mascot `.lookingDown`
  2. **"Answer your flashcards to earn time back."** — a flashcard flips, numeral rolls up +15m green with floating "+15" delta (soft haptic per tick), mascot `.clipboard` taking notes
  3. **"Scrolling spends your balance."** — numeral drains red, `angry-instagram` beat
  4. **"Studying is the only way back in."** — recap with mascot `.idle`, apps unlock (success haptic)
- Continue advances beat-by-beat (4 taps), exactly like OneThing
- **Asset gap:** social-app icons for the lock row were deleted from the catalog this branch — either re-add 4 icons or use SF-symbol app tiles

### 17. `MoreFeaturesView` *(OneThing 237 — auto-reel, zero interaction)*
- "That's not all." → **True Focus** card (camera-verified studying, `verified-focus-image`) → **AI flashcards** card (`scan-document.lottie` + YouTube/Quizlet icons)
- **Fully auto — no CTA**, advances itself ~14s with per-card haptics
- Replaces `HowItWorksView` + `AIFlashcardDemo` + `FlashcardSourcesView`

### 18. `FounderStoryView` *(OneThing 233)*
- Two circular headshots, sincere quote about building it because scrolling was eating your own study years, names block, indie mission card ("No investors. Just us.")
- **Asset:** reuse the same founder headshots from OneThing (same founders, your assets — copy `jason1`/`jude` over)
- CTA: "Continue"

### 19. `ReviewsView` *(OneThing 234 — replaces RatingView)*
- Trust badges + "Students are taking back their time" + **two opposing infinite review marquees** (reuse existing testimonials + `char1-3`, write 6–9 study-angle reviews)
- CTA fires `requestReview()` (keep the current **2s delay before advancing** so the system sheet lands) → paywall

### 20. `HardPaywallView` *(OneThing 506 — replaces PayWallView + FreeTrialReminderView)*
- Personalized backdrop: happy mascot, "**Win back your N years**" + "Your **[student type]** study plan is ready." + 4 feature rows + guarantee line; spinner/retry on offering-load failure
- Auto-presents `RevenueCatUI.PaywallView(offering:)` as fullScreenCover once offerings load
- **Keep every existing wire:** `paywall_viewed` (rename surface to `onboarding_v2`), `subscription_started` + AdsTracker trial/subscribe/purchase on entitlement, restore path, `NavigationModel.shouldDismissPaywall` escape hatch
- **Decline ladder:** dismiss #1 → decline-reason survey sheet (new, 4 options) → existing **`BuyBackOfferView`** (already mounted at App level); dismiss #2+ → buyback directly
- **No skip** — advancing requires Pro (current behavior, keep). Completion step re-verifies Pro like OneThing's final screen
- **Cut:** the `$0` pre-paywall marketing screen and the trial-reminder bell screen (V4 has neither; RC's template handles trial messaging). Notification permission moves post-purchase (screen 25)

---

## PHASE 4 — POST-PURCHASE SETUP (screens 21–28)

Explainer → request pairs, then product setup. All on daylight Meadow with `OnboardingScaffold`.

| # | Screen | What it does | Keeps |
|---|--------|-------------|-------|
| 21 | `ScreenTimeExplainerView` | Why Screen Time access (mascot `.clipboard`, privacy line "Your app activity stays on your device. We never see it.") | primes the scary dialog |
| 22 | `ScreenTimePermissionView` | `StudyGuardManager.requestAuthorization()`; **advances on grant AND deny** (never blocks) | `screen_time_auth_result`, deferred-setup path |
| 23 | `GuardedAppsView` | FamilyActivityPicker (existing `GuardedAppsOnboarding` restyled) | `updateSelection` refusal rules, `guarded_apps_selected` |
| 24 | `UsageIntervalView` | interval choice on `SGPickerRow`s + `completeSetup()` | `screen_time_setup_completed` / `setup_monitoring_failed` |
| 25 | `NotificationPrimerView` | "Stay on track" explainer + `UNUserNotificationCenter` request (moved from FreeTrialReminderView) | both `onboarding_notification_permission*` events |
| 26 | `UnlockMethodView` | Flashcards vs True Focus on `SGOptionTile`s | `onboarding_unlock_method_selected`, `saveUserData()` person properties |
| 27 | `CreateFirstCardsView` | existing source cards + `AutoGenerateFlashcardsSheet`, skippable | deck creation, `onboarding_create_cards_*` |
| 28 | `CompletionView` | mascot `.idle` celebration on the meadow hill, confetti, "You're all set." **Re-verifies Pro** (bounce to 20 if lapsed), sets `hasCompletedOnboarding` | `onboarding_completed`, `AdsTracker.trackCompleteRegistration()` |

---

## Infrastructure

- **`OnboardingViewModel` v2:** new 28-case step enum; keep `nextStep()` + the full analytics taxonomy (`onboarding_step_viewed/_completed` with names/indices — don't break the PostHog funnel); add `onboarding_screen_action` events for interactive beats (per OneThing); add `flow_version: "sg_v2"` to all events; quiz auto-advance helper; transient haptic on every step change
- **Container:** 0.3s opacity crossfade between steps (`.id(step)` + `.transition(.opacity)`); hosts the **persistent floating clipboard mascot overlay** pinned above quiz steps only; progress bar only within the quiz (each narrative screen paces itself)
- **New shared components:** `QuizScreenContainer` (back + progress + ghost placeholder), auto-advance option row, notification-banner overlay, `LifeDotsGrid` (drain/heal modes), `AnimatedAreaChart` (animatable yMax), marquee primitive, staged-entrance modifier (`fadeRise(delay:)`), night→dawn backdrop controller
- **Copy rules:** no em dashes, straight apostrophes, mascot voice ("he") — per the established conventions
- **Cleanup:** delete 11 superseded views (`TheFeelingView`, `TheObstacleView`, `NameView`, `ScreenTimeStudyView`, `ProcrastinationStudyView`, `StudyConsistancy`, `HowItWorksView`, `AIFlashcardDemo`, `FlashcardSourcesView`, `LongTermResultsView`, `RatingView`, `StudyGuardReadyView`, `PayWallView`, `FreeTrialReminderView` — the last two after their wiring moves into `HardPaywallView`)
- **Assets to add** (everything else is already bundled): founder headshots, optionally 3 villain-headline cards, optionally 4 social-app icons for lock rows, optionally 2 new mascot poses (phone-scrolling, celebrating) if you want pose-perfect beats 3/4 in `CoreMechanicView`

## Build order (5 PRs)

1. Infra: step enum + container + quiz scaffold + shared components (behind the existing `hasCompletedOnboarding` gate, no flag needed since it replaces wholesale)
2. Phase 1 (hook → quiz) + cut screens
3. Phase 2 (reality check choreography — the biggest lift: dots grid + chart)
4. Phase 3 (convert + paywall restructure — most care: RC wiring, decline ladder, analytics parity)
5. Phase 4 (post-purchase reorder) + QA pass on device + funnel-event diff against the old taxonomy
