# Tutor Monster — Feature Plan

Status: proposal (2026-10-27). Author: Jason + Claude.
Working title only. The monster has no name yet (see §9). "The monster" / "your tutor"
are placeholders.

> Inspiration note: the chat screenshots that kicked this off were from a different app
> ("Clema"). We are using the *idea* only. The name "Clema", its theme, its colors and its
> style are off-limits. Our name, palette, and look are entirely our own and will be
> authored deliberately (see §6h).

A conversational reshaping of the Study Guard unlock loop. Instead of tapping into a bare
flashcard quiz, the user is intercepted by a **tutor monster** with a personality they
chose in onboarding. It interrogates them, sets a toll of flashcards (weighted to what
they keep getting wrong and to the nearest exam), reacts live to every answer, and only
then hands back their apps. It gets stricter and sassier the more the user has been
hammering the lock.

Grounded in the current codebase; file pointers are real. Written to run through
`/plan-ceo-review`, `/plan-eng-review`, and `/plan-design-review`.

---

## 1. The one-liner

> You don't "pass a quiz" to unlock Instagram. You have to get past your monster, and it
> remembers what you're bad at, knows your exams, has receipts on how many times you've
> tried to scroll today, and talks back in a voice you picked.

Four things make this more than a reskin of the quiz:

1. **It's a live conversation, not a screen.** The monster talks (streaming AI), reacts
   per answer, and sends you off with attitude. Flashcards live inside the chat.
2. **It has a personality you chose.** Multiple selectable characters, each a distinct
   voice (see §6a). Switchable any time.
3. **It targets your weak spots and your nearest exam.** Needs a mastery/topic model and a
   real multi-exam model, neither of which exists yet.
4. **It escalates with your behavior.** The more you hit the wall, the bigger the toll, the
   less time you get back, the harder the pass bar, and the sassier the monster.

---

## 2. Where the code stands today (grounded)

### Reusable as-is
- **Quiz engine + earn economy.** `QuizV2View` renders cards; grading is `AnswerGrading`;
  the economy is a pure, testable contract in `Shared/SGContract.swift`
  (`completedQuizMinutes`, `defaultPerCardSeconds = 30`, `maxEarnedMinutes = 60`, round up,
  no floor). The grant is `StudyGuardManager.grantFreshBudget(...)`, the only exit from
  `.locked`. The monster **wraps** this; we do not rebuild it.
- **Unlock routing.** Shield "Study to unlock" → `StudyGuardShieldActionExtension` →
  `PrivateAppLauncher` opens the host → `diewithoutregretsApp.consumeShieldTapIfFresh()`
  navigates to `.regretView` with `unlockMethodOverride = "flashcards"`. Deep link
  `diewithoutregrets://unlock` and the lock notification converge on the same screen.
  120s honor window. We land the monster chat on these existing rails.
- **The mascot.** `MascotView` + `enum MascotPose { idle, lookingDown, clipboard,
  teaching }` (Lottie in `mascot-animations/`), angry stills, and a usage-driven 1 to 5
  mood ladder already shipping in the Live Activity (`MonsterActivityManager.moodLadder`).
  The voice is already "a gently-menacing accountability monster".
- **Design system.** `SGTheme` ("Meadow"): white + green home world; a `night` + `ember`
  dark scene exists today as the locked/punishment state. Light-locked by design (Night is
  authored, not system dark mode). Lottie, a rich haptic grammar, the `SG*` components.
- **AI backend.** Cloudflare Worker `studyguard-ai` (`backend/src/index.js`), App Attest
  hardened, already generates 50 flashcards as JSON via `gpt-4o-mini` (`/v1/flashcards`).
  Single-turn only today; multi-turn/streaming chat is an extension of it.
- **Streak.** `sg_streakCount` / `sg_streakLastDay`. **Analytics.** PostHog.

### Net-new (nothing to build on)
1. **Mastery / spaced repetition.** No per-card history, ease, due queue, or wrong-answer
   memory. Selection is a random shuffle (default 3 cards), one draw per lock.
2. **Topic dimension.** `Regret` (the card) and `Deck` have no subject/topic/tag, no link
   to an exam.
3. **Real multi-exam model + calendar.** Onboarding captures one `examDate` + a free-text
   `subject`, both **write-only after onboarding**. We need multiple exams, surfaced,
   editable, read in the loop, with a dedicated calendar page.
4. **Chat UI.** No message list, two-way bubbles, typing indicator, or input. Seeds only:
   `SGV5QuizSpeechBubbleShape` + a typewriter reveal.
5. **Persona system.** No selectable characters, no per-persona voice, no system prompts.
6. **Live multi-turn AI chat** (streaming) with a local fallback brain.
7. **An app-observable "pressure" signal** to drive escalation (see the hard constraint).

### The hard constraint: screen time is not readable in-process
iOS gives the **app process no live usage feed**. The budget "used" counter is a coarse
step function from DeviceActivity threshold callbacks. Real per-app duration and pickup
counts (`totalActivityDuration`, `numberOfPickups`) exist **only inside the Report
extension's sandbox**; the host gets rendered pixels, never values, so they can be shown
but never used in logic. **Consequence:** "opened Instagram 42 times" must come from a
counter the app owns to drive the monster's mood (see §6g).

---

## 3. Decisions locked with Jason (2026-10-27)

| # | Decision | Call |
|---|----------|------|
| D1 | How literal is "it talks"? | **Live AI chatbot** (streaming), with a local scripted fallback so the gate never depends on the network. |
| D2 | Replace or A/B the quiz | **Full rollout behind a QA flag, no A/B.** Legacy `RegretView` stays as the deep fallback. |
| D3 | What drives escalation | **App-owned pressure signal** (gate encounters/unlock attempts today + burn rate + study recency + exam proximity + weak-card load). Not DeviceActivity minutes. |
| D4 | Tone / meanness | **Sassy, not cruel. Tone fixed per persona** (no meanness dial); too mean → switch monster. Reaction GIFs/memes curated, later (§6f). |
| D5 | Mastery algorithm | **Leitner boxes (5)** to start, clear path to FSRS later. |
| D6 | Toll under pressure | **All three:** more questions, less time back, and a harder pass bar as mood escalates. |
| D7 | Exams | **Multiple exams + a dedicated calendar tab** with a prominent next-exam countdown. |
| D8 | AI service | **Extend the existing Worker** (reuse App Attest + rate limiting). |

---

## 4. The new unlock loop (state machine)

```
[Blocked app tapped]
     → Shield "Study to unlock"  (existing ShieldAction + PrivateAppLauncher)
     → Host opens on MonsterChatView  (replaces bare QuizV2View at the .regretView route)

1. GREET / INTERROGATE  (live AI, scripted fallback)
   Monster opens in the user's chosen persona voice, using context: app name,
   gate-encounters-today, nearest exam + days, mood. Optional interrogation beat.

2. DEMAND
   "Answer N on {topic}." N from mood (§6c). {topic} from the selection engine:
   weak cards first, weighted by nearest-exam proximity, varied so it isn't the same
   topic every time.

3. QUIZ-IN-CHAT  (grading + grant always local)
   Each card is a chat message (tap-tiles or typed, reusing Regret rendering +
   AnswerGrading). Monster reacts per answer in persona: hype on correct; roast + the
   correct answer + the "Why" on wrong. Missed cards re-queue within the session so you
   must actually get them right.

4. SETTLE
   Pass → grantEarnedBudget (time scaled down by mood) → shields drop → persona sign-off
   → UnlockAppReturn opens the app. Fail / quit → stays locked (emergency unlock remains).

5. RECORD
   Per-card mastery, per-topic weakness, streak, pressure response → PostHog.
```

**Gate rule (non-negotiable):** steps 3 and 4 (grading + grant) are 100% local. The AI
only drives the *talking* in steps 1, 2, and the per-answer reactions. If the network is
slow or down, the monster falls back to scripted persona lines and the unlock still works.

---

## 5. System designs

### 6a. Persona system (the selectable monsters)
The user picks their tutor's personality in onboarding and can switch any time. Each
persona is a distinct **voice**: energy, humor, speech rhythm, catchphrases, emoji usage,
a system prompt for the live AI, a matching scripted fallback bank, a pose/expression
style, and (proposed) its own accent color.

**How we build these so they land as fun, not offensive:** a persona is a *personality*
(attitude and speech style) with a character name and a monster look. It is never a
real-world demographic caricature. That keeps the cast inclusive and keeps a teen-facing
app clear of stereotype risk. The tone archetypes below cover the range Jason described.

The starting cast (4 personas; names coined here, open to change). Each is the same base
creature in a different color, accessory, and motion energy:

| Name | Vibe | Accent | Sample miss line |
|---|---|---|---|
| **Zaza** (the Diva) | sassy hype bestie, slays, roasts with love, emoji-heavy | hot magenta + sparkle | "bestie, we're gonna pretend that didn't happen. run it back." |
| **Willow** (the Nurturer) | warm, patient, calm, encouraging, never harsh; the gentle default (Gran + Sage merged into one) | soft sage + warm lavender | "Not to worry, love. Take a breath, once more." |
| **Sarge** (the Coach) | no-nonsense drill energy, tough-love hype | electric blue + steel | "Weak. Again. You don't quit on me." |
| **Gnash** (the Gremlin) | chaotic little menace, unhinged and funny | acid lime + purple | "WRONG hehehe feed me the right one 😈" |

- **Selection:** the user picks in onboarding; **Willow** is the safe fallback if skipped.
  Tone is **fixed per persona** (no dial) per D4; too mean means switch monster.
- **Gender:** user picks freely; we may suggest a default from onboarding, never force it.
- **Model:** `MonsterPersona { id, name, voice/systemPrompt, fallbackBank, accentColor,
  poseSet }`, persisted; selected id in `UserDefaults`, mirrored to the app group so shield
  copy matches the persona.

### 6b. Mastery substrate (Leitner)
Extend `Regret` (Codable; use the `decodeIfPresent` idiom at `RegretGuardApps.swift:84`,
so old saves load fine) with: `box` (1 to 5), `timesSeen`, `timesCorrect`,
`lastReviewedAt`, `nextDueAt`. Correct moves a card up a box and pushes the due date out;
wrong sends it to box 1, due now. Aggregate to a per-topic weakness score. This is what
lets the monster cover what you keep getting wrong and show real improvement.

### 6c. Pressure + mood engine
A pure, testable function (new contract-style file, mirrored to the app group).
- **Inputs (all app-observable):** `gateEncountersToday[app]` (the "42 times", see §6g),
  `unlocksGrantedToday`, `burnRate`, `studyRecencyHours`, `streak`, `nearestExamDays`,
  `weakCardLoad`.
- **Output:** a mood tier mapping to `questionsRequired`, `effectiveSecondsPerCard` (time
  back; lower when angry), `passThreshold` (higher when angry), `fallbackCopyBank`, `pose`.
  Per D6, escalation turns all three dials.
- Reuses the existing 1 to 5 mood frames / poses; the engine just picks the tier
  deliberately. All thresholds are tunable constants.

### 6d. Topic + multi-exam model + calendar page
- Add `topic: String?` to `Regret` (optionally `subject` on `Deck`); auto-tag generated
  cards (the LLM JSON gains a `topic` field).
- New `StudyExam { id, subject, date, topics: [String] (or deckIDs), color }`, stored as a
  list, migrating the onboarding exam into the first entry. Mirror a compact "next exam"
  summary into the app group so the shield and monster can reference it.
- **Dedicated calendar tab** (its own surface): a prominent **next-exam countdown** at the
  top, then a month view with exam markers, add/edit exams, and per-exam readiness
  (mastery % across its topics). Drives "cram mode" as a date nears.

### 6e. Selection engine
Replace the random shuffle in `QuizV2View.setup()` with a weighted draw:
`weight(card) = f(low-box/weakness, due-for-review, exam-proximity of its topic, variety)`.
Hits weak spots, respects spacing, leans into the nearest exam, varies topics across
sessions. Falls back to random on cold start (no mastery data yet).

### 6f. Dialogue: live AI brain + local fallback + reaction media
- **Live brain:** extend the Worker with a streaming multi-turn endpoint. Per-request it
  gets the persona system prompt + compact context (app, gate count, exam, topic, mastery,
  mood). Streams so the first words appear fast behind a typing indicator. Cheap model,
  short context, cost caps, content guardrails for minors, no PII.
- **Fallback brain:** the scripted persona banks from §6a. Used whenever offline/slow, and
  as the day-one experience before the live endpoint ships. The gate always has a brain.
- **Reaction GIFs/memes (curated, later):** a hand-picked, persona-flavored reaction
  library (in-house stickers and/or a vetted GIF set), expandable over time; the AI may
  *choose* from the curated set. We do **not** do live TikTok/open-Giphy search (moderation
  + licensing + staleness risk for a teen app). Scope: Phase 3+.

### 6g. The "42 times" number, precisely
- **Logic driver:** app-owned per-app, per-day gate-encounter / unlock-attempt counters in
  the app group, incremented by the shield extensions (which already stamp
  `sg_shieldTapAt`). Reliable, storable, usable.
- **Optional flavor:** a `DeviceActivityReport` scene can render the *real* system pickup
  count for display only. Stretch.

### 6h. Visual identity (our own, authored deliberately)
We will NOT inherit the reference's dark + orange, and we will NOT default to the existing
`night` + `ember` lock scene just because it resembles it. **Per-persona accent colors are
confirmed** (Zaza magenta, Willow sage/lavender, Sarge electric blue, Gnash acid lime), so
each character is visually distinct and the whole thing is unmistakably ours. Next step:
run `/design-shotgun` to author the monster-chat scene and overall identity in our own
palette. One mascot per screen; authored scene (not system dark mode).

### 6i. Chat UI
`MonsterChatView` + `MonsterMessage { id, sender, kind (text/card/result/system/media),
payload }`, scrollable transcript, animated typing indicator (extend the typewriter +
dots), a persona avatar header whose pose reflects mood, and an input area that morphs
between free text (interrogation) and card answering (tap-tiles / typed, reusing Regret
rendering).

---

## 6. Phased plan

Each phase is independently shippable and flag-gated. Phases 0 to 1 deliver a working,
offline, scripted version of the whole loop; the live AI arrives in Phase 2.

### Phase 0 — Foundations (invisible, behind a flag)
- Mastery fields on `Regret` (+ migration); per-topic weakness aggregation; `topic`
  tagging; `StudyExam` list model + migration; app-group gate-encounter counters written by
  the shield extensions; the pressure→mood pure function; the weighted selection engine;
  the `MonsterPersona` model + persona selection in onboarding.
- Ship dark. QA via unit tests (mastery transitions, selection weighting, mood tiers) +
  preview-harness seeds.
- Done when: mastery updates on completion, selection is weakness/exam driven, mood is
  computable from real counters, and a persona can be chosen and persisted.

### Phase 1 — Monster chat shell + scripted unlock (offline MVP, flagged)
- `MonsterChatView` (transcript, typing indicator, persona avatar + mood, morphing input);
  wrap the existing grading + `grantEarnedBudget`; scripted persona banks drive the voice;
  mood turns all three dials (D6); land on the existing `.regretView` route.
- Launch-arg QA variants mirroring `-sg-preview-quizv2` (greet / demand / correct / wrong /
  pass / fail / feral-mood, per persona).
- Done when: a user taps a blocked app, gets interrogated in their persona, clears a
  mood-scaled, weakness-weighted toll inside the chat, and unlocks, entirely offline. This
  is also the permanent fallback brain.

### Phase 2 — Live AI voice + exam calendar + adaptive, surfaced
- Streaming Worker chat endpoint; persona system prompts; context injection; typing
  indicator wired to the stream; scripted fallback on timeout/offline.
- Dedicated **exam calendar page** (add/edit, countdowns, per-exam readiness, cram mode).
- The monster *explains* its choices ("you keep missing cardiac, physio's in 3 days");
  post-session summary (missed, mastery gained, what's next); proactive persona nudges.
- Done when: the chat feels live and in-voice, exams are managed on their own page and read
  in the loop, and targeting is visible, with the gate still fully working offline.

### Phase 3 — Content enrichment
- Topic-targeted card generation from the student's subjects (extend `/v1/flashcards` with
  topic + difficulty); MC distractor generation; curated persona reaction GIFs/stickers;
  pre-generated/cached persona openers for instant feel.
- Done when: decks refill themselves on weak/near-exam topics and the monster has reactions
  with media, gate still offline-safe.

### Phase 4 — Depth, retention, monetization, polish
- More personas / persona unlocks / cosmetics; the meanness dial per persona; A/B on toll
  size and grant amount (PostHog); paywall interplay; Live Activity / Dynamic Island
  persona tie-in; accessibility + `/design-review`.

### Explicitly deferred
- FSRS (start Leitner). Live AI *on the gate dependency path* (talking only; gate stays
  local). Real DeviceActivity minutes as logic input (impossible; display only). Live
  TikTok/open-Giphy meme search (curated only). Multiplayer / voice.

---

## 7. Risks and guardrails
- **The gate must never depend on the network.** Live AI talks; local brain gates. Any
  network dependency on grading/grant is a bug.
- **Over-punishing hurts users and App Review.** Keep emergency unlock (3 / 7 days) + a
  visible escape hatch; cap cruelty; "sassy, not cruel". A stressed student must never be
  trapped from something urgent.
- **Persona safety.** Personalities, not demographic caricatures. LLM content guardrails
  for a minor audience; curated media only.
- **Live-AI cost.** Many unlocks/day × streaming chat adds up; short context, cheap model,
  caps, cache openers, monitor spend (there was a prior key-abuse incident; keep the proxy
  hardening).
- **Re-lock timing is callback-dependent** (no wall-clock timer). Don't assume precise
  timing in mechanics.
- **Migrations backward-compatible.** Decks are app-only; sync only compact summaries to
  the app group for extensions.
- **"Improve, not just comply"** needs real mastery feedback (the Leitner loop + progress
  surfacing), not just friction.

---

## 8. Decisions resolved (2026-10-27) + what's next
Resolved: persona names coined (Zaza / Willow / Sarge / Gnash); roster cut to 4 (Gran +
Sage merged into Willow); tone fixed per persona, switch monster if too mean; per-persona
accent colors confirmed; calendar is its own tab with a next-exam countdown; full rollout
behind a QA flag, no A/B.

Still open / next:
- **Run `/design-shotgun`** on the monster-chat scene + identity (Jason: soft yes). Go?
- **Creature/species name** (optional): do the four share a species name, or are they just
  four named monsters? (Leaning: four named monsters, no species label needed.)
- **Marketing hero persona** for the App Store / landing (likely Zaza for the hook, even
  though Willow is the in-app safe default).

---

## 9. File-level touchpoints (grounded)
- Economy / grant: `Shared/SGContract.swift`, `Features/StudyGuard/Services/StudyGuardManager.swift`.
- Card / deck / mastery + topic: `Features/RegretGuard/Models/RegretGuardApps.swift`, `.../RegretStore.swift`.
- Current quiz (what the monster wraps): `Features/RegretGuard/Views/QuizV2View.swift` (+ `QuizV2Kit`, `QuizV2Coins`, `QuizV2StreakView`).
- Unlock routing / landing: `diewithoutregretsApp.swift`, `StudyGuardShieldAction/StudyGuardShieldActionExtension.swift` + `PrivateAppLauncher.swift`, `Shared/ShieldReturnContext.swift`, `DesignSystem/UnlockAppReturn.swift`.
- Gate-encounter counters: `StudyGuardShield/StudyGuardShieldExtension.swift`, `StudyGuardShieldAction/…`, keyed via `SGContract`.
- Exam model today: `Features/Onboarding/V5/V5OnboardingProfile.swift`, `.../SGV5FlowModel.swift` (`sg_onbExamDate`).
- Mascot / poses / mood: `DesignSystem/MascotView.swift`, `MonsterActivityManager.swift`, `mascot-animations/`, `Assets.xcassets`.
- Design tokens / chat skin: `DesignSystem/SGTheme.swift`, `DESIGN-SPEC.md`; chat seeds in `Features/Onboarding/V5/QuizComponents.swift`.
- AI backend: `backend/src/index.js`, `backend/src/protocol.js`; client `Features/RegretGuard/Views/AutoGenerateFlashcardSheet.swift`.
- Preview harness: `DesignSystem/SGPreviewHarness.swift` (add `-sg-preview-monster*`).

---

## Appendix A — Escalation ladder (concrete starting numbers)

A pressure score (0 to ~12) is computed from app-observable signals and mapped to one of
five moods. The mood turns all three dials (D6): more questions, less time back, higher
pass bar. Numbers are starting points to tune in PostHog, and all fit today's economy
(30s/card default, 60-min cap, round up).

Pressure inputs (illustrative weights):
- Gate encounters today (this app): 0-2 → 0, 3-5 → 1, 6-15 → 2, 16-30 → 3, 31+ → 4
- Days since last completed study: today → 0, 1 → 1, 2-3 → 2, 4+ → 3
- Nearest exam proximity: >14d → 0, 7-14d → 1, 3-6d → 2, 1-2d → 3, today → 4
- Weak-card load (low-box cards due): none → 0, some → 1, lots → 2
- Burn rate (last grant spent fast): +1

| Mood | Score | Questions | Time back | Pass bar | Voice |
|---|---|---|---|---|---|
| Chill | 0-2 | 3 | 6 min | answer all (no re-queue) | easy, warm |
| Nudgy | 3-4 | 4 | 5 min | a miss re-queues once | light sass |
| Annoyed | 5-6 | 6 | 4 min | all correct (misses re-queue) | sassier |
| Fed up | 7-9 | 8 | 3 min | all correct, no skips | stern / roasty |
| Feral | 10+ | 10 | 2 min | all correct, a miss adds a card | max sass |

Effort-per-minute swings about 10x from Chill (2 min earned per question) to Feral (0.2).
That is the point: hammering the lock makes unlocking expensive. Guardrail: watch Feral for
rage-quits; emergency unlock (3 / 7 days) and switching to a gentler monster are always
available, and the time-back floor is 1 minute so a grant is never zero after a pass.

## Appendix B — A real unlock session (Zaza, "Annoyed" mood)

Context: user taps Instagram; 23 gate encounters today; anatomy exam in 4 days; weak on the
skeletal system. Pressure → Annoyed (6 questions, 4 minutes back, misses re-queue).

```
[Shield "Study to unlock" → app opens on the chat. Zaza: magenta, arms crossed, foot tapping.]

Zaza:  oh we're BACK 💅
Zaza:  that's 23 times you've knocked on instagram's door today bestie.
Zaza:  anatomy's in FOUR days and you still think the femur's in your arm. we're not doing this.
Zaza:  six cards. skeletal system. miss one and we run it back. go. 💀

[Card 1 — tiles]  "The longest bone in the body is the ___"   [Femur] Tibia Humerus Fibula
user → Femur
Zaza:  okAY maybe you're not cooked ✅ next.

[Card 2 — tiles]  "Which bone protects the brain?"   Cranium [Mandible] Clavicle Sternum
user → Mandible
Zaza:  the MANDIBLE?? that's your JAW 💀 it's the cranium.
       (Why: the cranium is the domed part of the skull that encloses the brain.)
Zaza:  putting that one back in the pile. you're seeing it again.

… cards 3-6, the missed card re-queued until correct …

Zaza:  fine. FINE. you did it 👑
[coin flight → grant: 4 minutes]
Zaza:  four minutes. that's it. go be unserious, then come back and we're doing cardiac.
[shields drop → Instagram opens]
```

Same instant, if the user had chosen Willow and pressure were low (Chill, 3 cards, 6 min):

```
Willow:  Back for a little scroll? That's alright, love.
Willow:  Just three quick ones first, to keep anatomy ticking over. Take your time.
[… 3 cards, gentle reactions, 6 minutes granted …]
Willow:  Lovely. Off you pop. I'll be here.
```

The talking is live AI in the chosen persona; the cards, grading, the 4-minute grant, and
the re-queue are all local, so this exact flow still works offline from the scripted banks.

## Appendix C — Onboarding: choosing your monster

A new screen in the V5 flow: "Who's keeping you honest?" Shows the four monsters (color +
pose + one sample line each). Tapping one previews its voice (a line + a reaction
animation); confirm to select, stored as the `MonsterPersona` id. We may pre-highlight a
suggestion from the onboarding gender answer, never forced. Switchable later from
profile/settings and from the chat header. Selecting a monster also seeds the accent color
used across the chat, the calendar, and the Live Activity.

## Appendix D — Calendar tab

Its own tab. Top: the next-exam countdown as the hero ("Anatomy in 4 days") with a
readiness ring (mastery % across that exam's topics) in the exam's color. Below: a month
grid with a colored dot per exam. Tap a day to add or edit an exam: subject, date, and the
topics or decks it covers (this link is what feeds the selection engine). Each exam row
shows its readiness and a "cram mode" badge when it is within a few days. Exams here drive
the monster: the nearest exam feeds the pressure score and the topic weighting, and the
monster references the exam by name.
