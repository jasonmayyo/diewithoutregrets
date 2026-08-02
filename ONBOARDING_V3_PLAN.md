# Onboarding v3 ("sg_v3") — The Semester Comeback Flow

Full redesign plan. Emotional thesis, Hormozi offer mapping, screen-by-screen copy,
personalization math, and implementation plan.

---

## 1. The strategy

### The emotional thesis (what every screen serves)

The student we're talking to already knows the truth. They don't need convincing that
they should study more — they need someone to say out loud what they feel at 11pm:

> "I don't have enough time. I'm behind. I know exactly what I should be doing —
> and I still can't make myself do it."

The current v2 flow sells *lifetime* stakes ("14 years of your life"). That's abstract —
an 19-year-old cannot feel year 74. **v3 moves every number to the semester**, because the
semester is the unit of pain a student actually lives in: this exam, this GPA, these
15 weeks. "You'll lose 31 days of THIS semester to your phone" lands in the body.
"Imagine if just half of those were study days" is the hope beat.

The resolution is our unique mechanism: **we remove willpower from the equation
entirely.** Every other solution (deleting apps, timers, detoxes) relies on the user —
and the user is the problem. Study Guard is a lock, not a pact. That's the story spine:

**Pain → Absolution (not your fault) → Failed alternatives (willpower is a lie) →
Mechanism (the lock) → Proof → Offer.**

### Hormozi value equation, mapped

| Lever | How v3 pulls it |
|---|---|
| **Dream outcome** ↑ | "Win back 31 days of this semester." Better grades, finals you walk into prepared, free time that's actually free. Semester-scale, concrete, near. |
| **Perceived likelihood** ↑ | Personalized math from their own answers; peer-reviewed citations (Cepeda 2006, Steel 2007); 45,000+ students + 8 named reviews; the mechanism itself ("a lock can't lose to willpower — it doesn't use any"). |
| **Time delay** ↓ | "Works from tonight." The first scroll session after setup already becomes a study session. Reality-check math counts down to *their* next exam (new quiz question). |
| **Effort & sacrifice** ↓ | The core differentiator, given its own screen: keep your phone, keep your apps, no detox, no discipline. "Zero willpower required — that's the point." |

Plus the offer-craft pieces:

- **Named offer (MAGIC)**: the paywall sells "Your **[College] Comeback Plan**" —
  personalized from the student-type answer. Not "a subscription."
- **Value stack**: five outcome-first feature lines on the paywall backdrop.
- **Risk reversal**: "Try it free. Cancel in two taps. The lock goes on your apps —
  never your wallet."
- **Honest urgency** (no fake countdown timers — premium feel means no sleaze): the
  deadline already exists. "Finals don't move. Every week you wait ≈ 49 more hours
  scrolled." Powered by the new "when's your next exam?" question.

### Consultant note — option counts

Interpreting the consultant's advice as: **never more than 5 options per question**, and
cut options no real user would pick (nobody 65 is downloading a student app). Every quiz
question in v3 has 3–5 options. Age drops from 8 options to 5.

### What we keep (it's already premium)

The v2 build quality is the premium feel — we keep the machinery and re-aim the story:

- Night-sky → dawn-break arc (dawn = the "imagine" turn)
- The dot grid with phased fills, drains, heals + haptic choreography (re-scaled 80 → 105)
- The animated semester chart (already labeled Week 1 / Midterms / Finals — it was born for v3)
- The notification-bombardment mascot snap, the floating clipboard quiz-taker
- The 4-beat core-mechanic demo, review marquees, founder story, RevenueCat hard paywall
- All analytics patterns (step_viewed / step_completed / screen_action), re-versioned `sg_v3`

---

## 2. The v3 flow at a glance

30 steps, four phases. `~` marks screens that are copy-tweaks of existing builds;
`+` marks new/rebuilt screens.

```
PHASE 1 — THE PAIN (daylight → night falls)
 1  hook            ~  "You know you should be studying."
 2  theFeeling      +  It's 11pm. Again.               ← night falls here
 3  notYourFault    ~  attention economy (kept)
 4  willpowerLie    +  every self-reliant fix fails
 5  meetYourGuard   ~  the monster (kept, new pivot line)

QUIZ (night, clipboard mascot, ≤5 options each)
 6  quizAge         ~  5 options (was 8)
 7  quizStudentType ~  5 options (was 6)
 8  quizScreenTime  ~  4 options (kept)
 9  quizScrollTimes ~  3 options (kept)
10  quizExamDate    +  NEW — powers urgency + countdown math

PHASE 2 — THE SEMESTER RECEIPT (night)
11  calculating     ~  theater, semester-flavored messages
12  semesterDrain   +  105-day grid: your semester in days
13  studyVsScroll   ~  chart (kept, sharper caption)
14  daysLost        ~  "31 days, lost" + rotating endings
15  theImagine      +  THE TURN — half the days flip to study, dawn breaks
16  afterChart      ~  the "with Study Guard" chart (kept)

PHASE 3 — THE OFFER (daylight)
17  science         ~  method + citations (kept, reworded)
18  coreMechanic    ~  4 beats (kept, reworded)
19  noWillpower     +  effort-killer screen: keep your phone
20  moreFeatures    ~  reel: True Focus + AI cards (kept)
21  founderStory    ~  kept as-is
22  reviews         ~  kept, new headline
23  paywall         ~  the named offer + stack + risk reversal + honest urgency

PHASE 4 — SETUP (post-purchase, kept structure, voice pass)
24  screenTimeExplainer   25  screenTimePermission   26  guardedApps
27  usageInterval         28  notificationPrimer     29  unlockMethod
30  createFirstCards  → completion
```

---

## 3. Screen-by-screen copy

Personalized values shown for the 6–8h answer (7h/day midpoint); formulas in §4.
**Bold** = accent color (ember for pain, mint for hope). All CTAs are the existing
pill styles.

### Phase 1 — The Pain

#### 1 · hook (daylight, keep video mockup)
- **Headline:** You know you should be studying.
- **Subtitle:** Study Guard locks your distracting apps until you do. No willpower required.
- **CTA:** I'm ready
- **Secondary:** I already have an account · Terms · Privacy
- Visual: unchanged (looping mockup video card). The headline is the pattern-interrupt —
  it's the sentence they say to themselves every night.

#### 2 · theFeeling (NEW — night falls during this screen)
Word-by-word typographic beats over the darkening sky (reuse the notYourFault
reveal system). ~1.2s per beat, light haptic each, heavy haptic on the kicker.
- **Beat 1:** It's 11pm.
- **Beat 2:** The plan was to start after dinner.
- **Beat 3:** Then you opened your phone.
- **Kicker (ember, spring-scale):** Four hours. **Gone.** Again.
- **Settle line:** And tomorrow, you'll promise yourself the same thing.
- **CTA:** That's me
- Visual: sky crossfades daylight → night across the beats (the current flow's night
  starts one screen later; moving it here makes the mood shift *part of the story*).

#### 3 · notYourFault (kept — strongest v2 screen)
- **Headline:** It's not your fault.
- Evidence cards (kept verbatim): "Apps are engineered to be un-putdownable" /
  "Infinite feeds exploit the same loops as slot machines" / "Your attention is the
  product being sold"
- Stats cascade (kept): 10,000+ ENGINEERS · $100B+ IN FUNDING · PhDs IN BEHAVIORAL
  PSYCHOLOGY · "All working to make sure" → **you. can't. stop. scrolling.**
- **CTA (changed):** So what do I do?  ← turns the screen into a question the next
  screen answers, instead of a dead "Continue"

#### 4 · willpowerLie (NEW — replaces fightingBack's aspiration marquee)
The missing beat in v2: burn down the alternatives before selling ours (Hormozi:
"why everything else failed them"). Three strikethrough beats, then the reframe.
- **Headline:** You've already tried willpower.
- **Beat 1 (strikes through as it lands):** ~~Deleted the apps.~~ Reinstalled them by Friday.
- **Beat 2:** ~~Set a study timer.~~ Ignored it by 9pm.
- **Beat 3:** ~~"Just one quick check."~~ You know how that ends.
- **Reframe (mint, holds):** Every fix that relies on *you* breaks when you're tired.
  You need one that doesn't.
- **CTA:** Show me
- Visual: pure typography on night sky; each struck line gets a wrong-buzz haptic,
  the reframe gets the success haptic. (The 11-icon marquee + trust badges from
  fightingBack move to the reviews screen where social proof belongs.)

#### 5 · meetYourGuard (kept choreography, sharper pivot)
- **Headline:** Meet your Study Guard.
- Choreography kept: idle mascot → fake notification bombardment → angry snap +
  heavy haptic.
- Descriptors (kept): Distracted. Exhausted. Behind.
- **Pivot line (mint, replaces v2's):** He has the willpower you don't.
  He locks your apps — and only studying opens them.
- **CTA:** Set him up

### Quiz (night, floating clipboard mascot, auto-advance — all kept mechanics)

#### 6 · quizAge — 5 options (was 8)
- **Question:** 1. How old are you?
- **Subtitle:** We'll tune the plan to where you are in life.
- **Options:** Under 14 · 14–17 · 18–22 · 23–29 · 30 or over

#### 7 · quizStudentType — 5 options (was 6; "Learning for work" folds into "Something else")
- **Question:** 2. What best describes you?
- **Subtitle:** Different students need different plans.
- **Options:** 🎓 High school · 📚 College or university · 🧪 Grad school ·
  📝 Studying for an exam · ➕ Something else

#### 8 · quizScreenTime — 4 options (kept, subtext re-aimed at grades)
- **Question:** 3. How much time do you spend on your phone each day?
- **Subtitle:** Be honest — this stays between us.
- **Options:**
  - 2–4 hours — *About average*
  - 4–6 hours — *More than a part-time job*
  - 6–8 hours — *This is costing you grades*
  - 8+ hours — *Time to take it back*

#### 9 · quizScrollTimes — 3 options (kept)
- **Question:** 4. When do you scroll when you should be studying?
- **Subtitle:** So he knows when to guard hardest.
- **Options:** 🌞 While studying · 🌙 In bed · ♾️ Honestly, all day

#### 10 · quizExamDate — NEW, 4 options (powers urgency + countdown math)
- **Question:** 5. When's your next big exam?
- **Subtitle:** We'll build your comeback around it.
- **Options:**
  - Within a month  *(→ ~4 weeks)*
  - 1–2 months away  *(→ ~6 weeks)*
  - 3+ months away  *(→ ~12 weeks)*
  - No exams — just deadlines  *(→ semester fallback copy)*

### Phase 2 — The Semester Receipt

#### 11 · calculating (kept theater, new messages)
Status lines (~0.9s each, light haptic per swap):
1. Reading your answers...
2. Mapping your semester...
3. Counting the days your phone takes...
4. Preparing your reality check...

#### 12 · semesterDrain (REBUILT from lifeDrain — the grid becomes the semester)
Grid re-scales 80 → **105 squares (15 weeks × 7)**. Same phased fill/drain/haptic
engine, new captions:
- **Title:** Your semester in days
- **Subtitle:** 15 weeks. 105 days. Each square is one.
- **Phase 1 — obligations fill (caption swaps per group):**
  - **33 days** asleep *(blue)*
  - **18 days** in class *(purple)*
  - **17 days** eating, commuting, chores *(pink)*
- **Phase 2 — free-time pop (mint):** That leaves **37 days**. Actually yours.
- **Phase 3 — phone drain (ember, bottom-right, heavy haptic on the count):**
  - Lead-in: This semester, your phone will take
  - Count: **31 of them.**
  - Settle: 31 full days. Staring at a screen. **84% of your free time — gone.**
- **CTA:** This has to change

#### 13 · studyVsScroll (kept chart — it already says Week 1 / Midterms / Finals)
- **Headline:** Who gets your hours?
- **Subtitle:** Hours per day, from now to finals
- Chart choreography unchanged (study line → sleep line → phone line towers + chart
  compresses).
- **Caption:** **7 hours.** Every single day. Until finals.
- Fine print kept: Self-reported daily screen time vs typical study hours
  (Common Sense Media 2023)
- **CTA:** Not anymore

#### 14 · daysLost (reworded hoursLost — same rotating-endings engine)
- **Fixed line:** **31 days** of this semester, spent scrolling —
- **Rotating endings (2.8s blur-fade, kept engine):**
  1. while the exam gets closer either way.
  2. while your grades sit below what you're capable of.
  3. watching other people live their lives.
  4. and next semester, it happens again.
- **CTA:** I want those days back

#### 15 · theImagine (REBUILT reclaim — THE TURN, the user's exact frame)
Dawn breaks here (1.2s crossfade, kept). The drained grid carries over; **half** the
ember squares heal to mint one-by-one (kept heal choreography).
- **Headline (lands with the dawn):** Imagine if just **half** of those days went
  to studying.
- Stat beats (land as the heal completes, one per haptic):
  - **+368 hours** of studying this semester.
  - That's more prep than **nine finals** need.
  - Without giving up your phone.
- **Settle (mint):** Study Guard makes it automatic. Scroll time in, study time out.
- **CTA:** Let's do this

#### 16 · afterChart (kept — light copy pass)
- **Headline:** Put your hours where your grades are
- **Subtitle:** Less scrolling. Better grades. Same phone.
- Chart unchanged (dimmed old phone line, glowing "Phone with Study Guard" line
  draws in). Legend kept.
- **CTA:** Continue

### Phase 3 — The Offer

#### 17 · science (kept — reworded to serve the no-willpower mechanism)
- **Title:** The Study Guard Method
- **Body:** Friction when you reach for your phone. Spaced repetition when you study.
  Both backed by peer-reviewed research — and neither needs your willpower.
- Citations kept: Cepeda et al. 2006 (spaced repetition) · Steel 2007
  (procrastination research). Teaching mascot kept.
- **CTA:** How it works

#### 18 · coreMechanic (kept 4-beat demo — reworded beats)
1. **Set your limit** — Choose how long you can scroll each day.
2. **Apps lock. Automatically.** — Time's up. No snooze. No "five more minutes."
   The lock doesn't negotiate.
3. **Study to unlock** — Answer your flashcards correctly and your apps open again.
4. **Every scroll starts with studying** — Your earned time ticks down as you scroll.
   Only studying refills it. That's the whole trick.

#### 19 · noWillpower (NEW — the effort & sacrifice killer, Hormozi's ↓ denominator)
The single most important differentiator gets its own quiet, confident screen.
- **Headline:** You keep your phone. You keep your apps.
- **Body:** No deleting Instagram. No grayscale monk mode. No 30-day detox you'll
  quit by day three. You just study first.
- **Kicker (mint):** Zero willpower required. That's the point.
- **CTA:** Continue
- Visual: idle mascot holding the phone out toward the user (idle pose + phone-tile
  from the mechanic stage), calm, no choreography — the restraint IS the premium feel.

#### 20 · moreFeatures (kept reel)
- Slide 1: **That's not all.** — Study Guard verifies you're actually studying.
- Slide 2: **True Focus** — Camera-verified study sessions. No faking it.
- Slide 3: **AI flashcards** — Paste notes, a YouTube lecture, or a Quizlet set.
  He makes the cards. You just answer them.

#### 21 · founderStory (kept verbatim — it's already the credibility beat)

#### 22 · reviews (kept marquee + reviews; new headline; trust badges from old
fightingBack land here)
- **Trust badges:** 4.8★ · 45,000+ students
- **Headline:** 45,000 students stopped fighting themselves
- 8 review cards kept verbatim. Rating prompt kept.
- **CTA:** Continue

#### 23 · paywall (kept RevenueCat machinery — backdrop becomes the named offer)
- **Eyebrow (micro label):** YOUR [COLLEGE] COMEBACK PLAN  ← named offer,
  personalized from quizStudentType; fallback "YOUR COMEBACK PLAN"
- **Headline:** Win back **31 days** of this semester
- **Sub (urgency, personalized from quizExamDate):**
  - With exam date: Your exam is about **6 weeks** out. That's **294 hours** of
    scrolling between now and then — or your prep time. Your call.
  - Fallback: **49 hours** of scrolling every week from here to finals — or your
    study time. Your call.
- **Value stack (5 rows, outcome-first):**
  1. 🔒 Your apps lock themselves — willpower not required
  2. 📚 Every unlock is a real study session
  3. ✨ AI turns your notes into flashcards in seconds
  4. 👁 True Focus: camera-verified deep work
  5. 🆘 Emergency unlocks, because life happens
- **Risk reversal (replaces the lone "cancel anytime" line):**
  ✓ Try it free · ✓ Cancel in two taps in the App Store ·
  ✓ The lock goes on your apps — never your wallet
- **CTA:** Start my comeback
- Decline ladder, buyback flow, restore, re-verification: all kept as-is.

### Phase 4 — Setup (kept structure; voice pass so the lock story never drops)

#### 24 · screenTimeExplainer
- **Title:** This is the lock.
- **Body:** Study Guard uses Apple's Screen Time to hold your apps shut. Your
  activity stays on your device — we never see it.
- Footer kept: Private by design. Backed by Apple.
- **CTA:** Continue

#### 25 · screenTimePermission
- **Title:** Make it official
- **Body:** iOS will ask with a system dialog. Allow it, and willpower stops being
  your problem.
- **CTA:** Allow Screen Time access · Secondary: Set up later from the Guard tab
- (Both grant and deny still advance — unchanged.)

#### 26 · guardedApps
- **Headline:** Which apps steal your time?
- **Subtitle:** Pick the ones he locks when your scroll time runs out.
- **CTA:** Lock them in · Secondary: Skip for now

#### 27 · usageInterval
- **Headline:** How long until your apps lock?
- **Subtitle:** Scroll this long and he steps in. Answer your flashcards to earn
  the same amount again. Fresh start every morning.
- **CTA:** Start guarding

#### 28 · notificationPrimer
- **Title:** He'll give you a heads up
- **Body:** A warning before your apps lock, and a nudge to keep your streak alive.
  No spam — he's a monster, not a marketer.
- **CTA:** Enable notifications · Secondary: Not now

#### 29 · unlockMethod — kept verbatim (Flashcards / True Focus cards)

#### 30 · createFirstCards — kept verbatim (Paste text / YouTube / Quizlet)

#### completion
- **Headline:** He's on duty.
- **Body:** From now on, scrolling costs studying. Go make the semester count.
- **CTA:** Let's go
- Confetti, mascot spring-in, Pro re-verification: all kept.

---

## 4. Personalization math (OnboardingViewModel changes)

Replace the lifetime constants with semester constants. Midpoint `dailyHours`
derivation is kept (2–4→3, 4–6→5, 6–8→7, 8+→9).

```
semesterWeeks   = 15
semesterDays    = 105                              // the grid: 15 × 7
sleepDays       = 33                               // 7.5h/day
classDays       = 18                               // ~4h/day class + homework
choresDays      = 17                               // eat, commute, chores
freeDays        = 105 − 33 − 18 − 17 = 37

phoneDays       = min(round(dailyHours × 105 / 24), freeDays)
                  // 3h→13 · 5h→22 · 7h→31 · 9h→37 (capped)
phonePctOfFree  = round(phoneDays / freeDays × 100)         // 7h → 84%
reclaimDays     = round(phoneDays / 2)                      // 7h → 16 (grid heals this many)
halfStudyHours  = round(dailyHours / 2 × 105)               // 7h → 368
finalsPrepEquiv = round(halfStudyHours / 40)                // ~40h prep per final → 9

weeksToExam     = quizExamDate → 4 / 6 / 12 / nil
scrollHrsToExam = round(dailyHours × 7 × weeksToExam)       // 7h, 6wk → 294
scrollHrsPerWk  = round(dailyHours × 7)                     // 7h → 49
```

Keep `phoneMinutesPerDay` for the chart caption. Delete `lifeYears`, `freeYears`,
`phoneYears`, `reclaimYears` (paywall headline switches to `phoneDays`).

---

## 5. Implementation plan

Ordered so the app builds green after every stage.

**Stage 1 — Model (OnboardingViewModel.swift)**
1. Add `quizExamDate` step + `examTiming` published var; rename steps
   (`lifeDrain→semesterDrain`, `hoursLost→daysLost`, `reclaim→theImagine`,
   add `willpowerLie`, `noWillpower`, `theFeeling`); update `isNight` (night now
   starts at `theFeeling`, dawn still breaks at the turn) and `quizProgress`
   (5 questions: .08/.14/.20/.26/.32).
2. Swap the math block per §4. Flow version → `"sg_v3"` everywhere (analytics +
   person properties, `onboarding_flow_version`).

**Stage 2 — Quiz trims (AgeSelectView, NameView, YourScreenTimeView,
ProcrastinationStudyView + new QuizExamDateView)**
3. Age → 5 options; student type → 5; screen-time subtext rewrite; new exam-date
   question view (clone of the age question layout).

**Stage 3 — Phase 1 rebuilds**
4. `theFeeling`: new view using the word-reveal system from TheFeelingView.swift's
   cascade code + the sky crossfade from BreakdownView's dawn turn (inverted).
5. `willpowerLie`: new typography view (strikethrough beats, wrong-buzz haptics).
6. Copy passes: hook, notYourFault CTA, meetYourGuard pivot.

**Stage 4 — Phase 2 rebuild (BreakdownView.swift)**
7. Grid 80 → 105 dots (15×7), new group sizes/captions, drain count = `phoneDays`.
8. `theImagine`: heal `reclaimDays` dots (half, not 80%), add the three stat beats.
9. Copy passes: calculating messages, chart caption, daysLost endings.

**Stage 5 — Phase 3**
10. `noWillpower`: new static view (mascot + type, no choreography).
11. Copy passes: science, coreMechanic beats, moreFeatures slide 3, reviews headline
    (+ move trust badges here), paywall backdrop (eyebrow, headline, urgency sub,
    5-row stack, risk-reversal row, CTA).

**Stage 6 — Phase 4 voice pass + QA**
12. Copy-only edits across the six setup screens + completion.
13. Full run-through on device: haptic timing on the two new choreographed screens,
    night/dawn continuity, PostHog funnel fires with `sg_v3`, paywall decline ladder
    untouched.

**Analytics note:** keeping every step event shape identical (only names/version
change) means the existing PostHog funnels can be cloned to `sg_v3` for a clean
v2-vs-v3 comparison — worth shipping v3 behind a feature flag so the two flows can
run head-to-head.

---

## 6. Voice rules (so the premium feel survives edits)

1. **Second person, present tense, short sentences.** The reader is tired; don't make them work.
2. **Ember = pain, mint = hope.** Never mix within a line.
3. **One idea per screen.** If a screen needs two headlines, it's two screens.
4. **No fake urgency.** The exam date is real urgency; countdown timers and
   "50% off ends tonight" would cheapen the whole flow.
5. **The monster is an ally with teeth.** He's never cute-ified ("he's a monster,
   not a marketer") and never scolds the user — the apps are the villain.
6. **Numbers are theirs.** Every stat shown after the quiz must derive from their
   answers. Generic numbers go in fine print or citations only.
