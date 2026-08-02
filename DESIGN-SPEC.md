# Study Guard Design Overhaul

Audit report, new design spec, and migration plan. 2026-07-26.

The reference for quality is Secure (`~/Desktop/Secure`). The goal is not to make Study Guard look like Secure. The goal is to steal Secure's discipline: one button, one motion vocabulary, one palette with real structure, and transitions that carry color from scene to scene so the whole app feels like one object. Study Guard keeps its own identity (warm white meadow, mint, the monster) and gets Secure's system underneath it.

---

## Part 1: Audit report. What is actually wrong today

The app has a real design system (SGTheme "Meadow" tokens) and the newer screens use it. The problem is that adoption is bimodal: token-pure screens sit next to screens that bypass the system entirely, the system itself is missing roles people needed (so they hardcoded), and the lock flow crosses five unrelated visual worlds. Numbers below come from a full sweep of all 91 app files plus the shield and widget extensions.

### 1.1 The raw numbers

| Deviation | Count outside DesignSystem | Worst offenders |
|---|---|---|
| Inline `.font(.system(size:))` bypassing type roles | 240 call sites in 42 files | FocusSessionView (34), AutoGenerateFlashcardSheet (32), RegretGuard (17), OnboardingV2Components (14), ProfileView (13) |
| Hardcoded color literals (`Color(hex:)`, `Color(red:)`) | 36 | OnboardingV2Components (21), FocusSessionView (5), shield extension (3), RegretGuard (3) |
| Raw `.white` / `.black` fills and foregrounds | 50 | OnboardingV2Components (16), RegretGuard (10) |
| Ad-hoc greys via `.opacity()` | 34 | RegretGuard (12), OnboardingV2Components (10) |
| Numeric corner radii bypassing the scale | 65 | AutoGenerateFlashcardSheet (14), NewFlashcardSheet (8), RegretEditorSheet (6). Radii in the wild: {6, 8, 10, 12, 16, 50} on top of the sanctioned {14, 20, 28} |
| Ad-hoc shadows | 22 | FocusSessionView (black 60%), TheFeelingView (black 50%), TheHookView (black 35%), four different mint CTA glows |
| Raw haptic generator calls | 29 | BreakdownView (10), TheFeelingView (5), HowItWorksView (5) |

### 1.2 Buttons (your first complaint, and the biggest one)

There is no signature button. There are at least **ten** distinct primary-button constructions across the lock flow, onboarding, and the paywall:

- `SGPrimaryButton`: mint capsule, padded (no fixed height), **no shadow**, label pure `.white`
- `OnbCTA` (onboarding): mint capsule, fixed height 56, **with** a tinted glow shadow
- Three hand-rolled clones of OnbCTA (ScreenTimePermissionView, NotificationPrimerView, CompletionView) that duplicate its code
- GuardedAppsOnboarding auth button: height 44, 15pt label, label colored `SGTheme.ink` instead of white
- BuyBackView claim button (ink label) and the paywall retry button (white label): height 56, no shadow
- `MeadowCTA` (home): solid white capsule, 17 bold, its own ad-hoc shadow
- `GlassPill` (home): white 94% capsule with its own shadow
- LockedHomeView CTA: ember capsule with an ember glow
- Focus "Done": a mint `RoundedRectangle(cornerRadius: 28)` with no press feedback at all
- RegretView rescue buttons: raw `Text().padding().background().cornerRadius(50)` with the default body font

Same story for secondary buttons (four ghost variants with fill opacity 0.06 vs 0.08, stroke vs no stroke, Capsule vs `cornerRadius(50)`), mint-outline buttons (stroke 0.5 vs 0.6 opacity), and press feedback (three ButtonStyles plus many buttons with none). Even the white on a mint fill is inconsistent: pure `.white` in some places, warm `#FDFDFB` in others.

Secure has exactly one signature: the chunky capsule on a hard darker ledge that physically presses down. Every CTA in that app is that button. That single fact is most of why it feels polished.

### 1.3 Text (shapes, weights, fonts, rounded)

- **Two competing display families.** The design system says big numerals are SF Rounded (`SGTheme.display`), and quiz titles, sheet titles, and the delta label follow it. But the three biggest numerals in the app (home hero 96pt, Focus countdown 96pt, Breakdown hammer numbers) are deliberately plain SF, and the celebration numeral is 88pt where the home hero it echoes is 96pt. The same "minutes" concept renders in two typefaces and four size/weight combos.
- **Ten distinct title treatments in onboarding alone**: display(34), display(32), display(30), display(28), display(26), display(24), headline, plus hardcoded 34 bold rounded, 34 heavy rounded, and 22 semibold rounded. Bold vs heavy flips with no pattern.
- **Missing roles caused the hardcoding.** SGTheme's scale jumps from micro (12) to cardTitle (17) with nothing at 14 to 15 semibold, so ProfileView inlines a 14 semibold row label ten times and four other files copy it. Button labels have no token at all, so every button hardcodes 15/16/17.
- **One-off fonts**: serif and monospaced body text inside AutoGenerateFlashcardSheet, Dynamic Type `.headline`/`.subheadline`/`.caption` mixed with fixed sizes in the flashcard sheets.

### 1.4 Color

- **Three unrelated dark palettes** for "night": onboarding's navy sky (#0B1C33 / #123A66 / #0B2444), the locked home's ember night (#1B0E0A), and the shield extension's retired Teal Ink (#0C1E22). The Live Activity adds pure black as a fourth.
- **The shield is a different app.** The screen users see most often at the lock moment (on Instagram itself) still ships the dead Teal Ink theme: dark teal background, pale teal text, and a MINT button, while the in-app lock language is ember on near-black.
- **True Focus is a visual island**: five colors ported from another app (neon green ≈ #38FA9E, red ≈ #FF616B, orange ≈ #FF9933, grey-blue, sky blue) that overlap none of the brand palette. Success in Focus is neon green; success everywhere else is mint.
- **The accent has no ramp.** Mint exists only as mint and mintDeep, so every screen inventing a tint writes `mint.opacity(0.12)`, `0.14`, `0.15`, `0.25`, `0.3`, `0.35`, `0.4` ad hoc (four different mint glows on onboarding CTAs alone). Secure's accents are 4-step ramps (deep, accent, soft, tint), and every component draws from fixed positions.
- Ad-hoc hexes leak between files: the navy night trio is copy-pasted into RegretGuard, the sun yellow #FFC83D lives in three files, `splashTeal #3DB8B5` sits outside the token file a few points away from `teal #3FA4AE`.

### 1.5 The lock flow (your second complaint, fully traced)

One lock-to-unlock loop today crosses:

- **5 base background colors**: warm white #FDFDFB (home) → ember #FF7A59 (wipe) → ember night #1B0E0A (stamp + locked home) → dark teal #0C1E22 (shield on the blocked app) → pure black (Dynamic Island) → white again (quiz, celebration)
- **~10 button constructions** (list above)
- **~9 animation vocabularies**: token springs, corner wipe, stamp drop + shockwave, three different full-screen circle reveals built three different ways, Duolingo slide, numeric tick rolls, three repeat-forever loops at different periods, `.snappy` (used only in Focus), DI crossfade
- **3 font designs** (rounded, plain, monospaced)

Specific seams, each verified against the code:

1. **The same stamp plays on opposite backgrounds.** MascotLockOverlay renders on near-black when the home locks, and on warm white minutes later when the quiz opens. Same moment, inverted scheme, different exit choreography (crossfade vs red/white mask eruption).
2. **Stamp and locked home claim to match and do not.** The comment says "the same hairline rings," but ring opacities are 0.16/0.08 on the stamp vs 0.22/0.10 on the home, blooms differ in center and radius, ring offsets differ.
3. **Failure vs locked home contradict each other.** "Your apps are still locked" renders as a light ember-tinted screen after a failed quiz but as a dark ember night on the home tab. The user bounces light → dark → light while in one emotional state.
4. **Two unlock celebrations.** Flashcards earn the meadow celebration (circle reveal, count-up, confetti). Focus earns a different overlay (looping mint pulse rings) followed by a third screen with a neon green checkmark. Same reward, three languages.
5. **The Focus flow truncates the stamp.** It kills the overlay on a fixed 1.5s timer, so the label barely lands and the exit never plays; the quiz lets the full 2.05s choreography run.
6. **The wipe runs at two speeds** (lock: 0.75/0.22/0.6, cold start: 0.6/0.22/0.36, and the component's own defaults, 0.4/0.09/0.36, are used by neither call site).
7. **Confetti includes near-black particles** (`SGTheme.paper` #14211D), a leftover from the dark era, falling on a white celebration screen.
8. **Ember means two things at once**: punishment (lock stamp, wrong answers) and the escape action (emergency unlock button) on adjacent screens.

### 1.6 Components and chrome

- **Six card treatments** for the same semantic card; the canonical SGCard (the only one with a shadow) is unused by the main tabs, which each re-implement their own shadowless copy (`blocksCard`, `sgRowCard`, `InputCard`, plus inlines).
- **Four settings-row implementations** of the identical title + caption + mint chevron row; the design-system SGListRow is never used.
- **Three sheet-header patterns**: system NavigationStack toolbars (flashcard sheets), SGSheetHeader (settings sheets), and a fully custom 120pt header (RegretEditorSheet). Cancel/Save weights differ within the same pattern.
- **The paywall** (HardPaywallView, 803 lines, seen by every user) carries ~12 inline fonts, a hand-rolled mint capsule, and ad-hoc radius-10 tiles on its backdrop, and then hands off to an unstyled RevenueCatUI cover: the single biggest visual discontinuity in the funnel.
- **Input fields use four radii** (10, 12, 14) and two active-stroke widths, sometimes within one screen.
- **Three haptic vocabularies**: SGTheme helpers, a parallel QuizHaptics enum, and 29 raw generator calls implementing a five-level "haptic grammar" that exists only as a code comment.
- Blocks and Profile duplicate the same settings surface with independently copy-pasted code.
- Dead styled files still shipping: FightingBackView, FounderStoryView, LoopingVideoPlayer, AvgScreenTime model/viewmodel, legacy SettingsView, plus the now-unused meme video files (AnimationOptionRow, AnimationType, MemeVideoView).

### 1.7 What Secure does that Study Guard will adopt

1. **One flat token enum with semantic layers on top.** All colors in one file; screens read roles, never hexes.
2. **Accent ramps, not single colors.** Every accent is deep / accent / soft / tint, and buttons, wipes, progress bars, and cards always draw from the same ramp positions.
3. **One signature button.** Chunky capsule on a hard zero-radius ledge shadow, pressing physically down, medium haptic, tap debounce. Used for every primary action in the app.
4. **Two surface poles only.** White canvas or near-black brand-hue night. Nothing in between. Both poles are tokens.
5. **One motion vocabulary.** A house step transition (fade + trailing slide in, fade out), a house mount beat (easeOut 0.4 rise + fade, staggered 0.08s), springs reserved for celebration, and press feedback at 0.1s.
6. **Wipes made of the destination's colors.** The corner wipe's bands are the theme ramp of where you are going, so transitions preview the destination and every landing is color-matched.
7. **Persistent chrome across flows.** One progress bar and close cluster stays mounted while step content transitions under it.
8. **A tiered haptic grammar** applied consistently: medium = commit, light = small tap, soft = content gesture, selection = picking, success = completing.
9. **A component gallery debug screen** so every control has one reference implementation you can see.

---

## Part 2: The spec. Study Guard design system v4

Everything below goes into SGTheme/SGComponents. The rule after migration: **no hex, no `.system(size:)`, no raw haptic generator, no ad-hoc shadow outside the DesignSystem folder.** A grep-based lint script (Part 4) enforces it.

### 2.1 Color

Keep the Meadow identity. Give it Secure-style structure. The naming trap (`ink` = white canvas, `paper` = dark text) stays for now to avoid a 700-site rename; the ramp names below are additive.

**Surfaces (light pole, unchanged)**

| Token | Value | Role |
|---|---|---|
| ink | #FDFDFB | Canvas |
| inkRaised | #F4F6F5 | Cards |
| inkHigh | #EAEFEC | Selected / elevated |
| hairline | black 7% | Card edges |

**Text (unchanged)**: paper #14211D with its named tiers paperSecondary (55%), paperTertiary (45%), paperDisabled (30%). The `glaze()` helper (a capped black wash used for ghost fills and progress tracks) also stays.

**Mint ramp** (mint and mintDeep already exist; soft and tint are new)

| Token | Value | Role |
|---|---|---|
| mintDeep | #1E8A67 | Button ledge, text on light |
| mint | #2BC391 | The accent. Fills, progress |
| mintSoft | #8CE0C4 | NEW. Gradient tops, soft highlights |
| mintTint | #E9F8F1 | NEW. Selected washes, pale chips |

`mint.opacity(0.12)` selected fills become `mintTint`. The four ad-hoc CTA glows become one token: `mintGlow` = mint 30%, radius 18, y 5.

**Ember ramp** (ember and emberDeep already exist; soft and tint are new)

| Token | Value | Role |
|---|---|---|
| emberDeep | #D9532F | Button ledge, text on light |
| ember | #FF7A59 | Lock accent, fills |
| emberSoft | #FFB59E | NEW. Highlights on night |
| emberTint | #FFF0EA | NEW. Wrong-answer washes |

**Night scene (the second pole, promoted to tokens)**

| Token | Value | Role |
|---|---|---|
| night | #1B0E0A | The locked-state canvas (ember-tinted near-black) |
| nightRaised | white 6% | Cards on night |
| nightHairline | white 10% | Strokes on night |
| nightText / nightTextSecondary / nightTextTertiary | white / white 65% / white 45% | Text on night |

**Sky scene (onboarding narrative only)**: skyTop #0B1C33, skyMid #123A66, skyDeep #0B2444, plus the OnbNight white-opacity ramp, all moved into SGTheme so RegretGuard and ProcrastinationStudyView stop copy-pasting hexes. The sky palette is allowed ONLY in the onboarding villain arc. It never appears in the main app.

**Support**: teal #3FA4AE (ring gradient partner), amber #FF9933 (warnings, adopted from Focus), sun #FFC83D (onboarding illustration), splashTeal #3DB8B5 (cold-start splash, moved into SGTheme). Focus's neon green, red, and sky blue are deleted; Focus uses mint / ember / amber / teal.

**Two poles rule (from Secure)**: every screen is either the ink canvas or the night canvas. The wipes and the sky arc are the only things allowed between them.

### 2.2 Typography

One family decision: **SF Rounded for display and all numerals, default SF for everything else.** The rounded display is the brand (it matches the soft monster); the plain-SF hero experiment ends. Weights: bold for display, semibold for controls and labels, medium/regular for body. Heavy is retired except the delta label.

| Role | Spec | Replaces |
|---|---|---|
| heroNumeral | rounded 96 semibold, units rounded 42 medium, monospacedDigit | Home hero (plain SF today), Focus countdown, celebration numeral (88 today, becomes 96) |
| numeral(size) | rounded semibold, monospacedDigit | display(42) countdown, display(68) mechanic readout |
| screenTitle | rounded 34 bold | Tab headers (SGScreenHeader), the Hook title |
| stepTitle | rounded 30 bold | ALL onboarding/overlay/lock titles. Kills the 34/32/28/26/24/22 spread and every heavy variant |
| sheetTitle | rounded 24 bold | Sheet headers, EmergencyUnlockSheet |
| cardTitle | SF 17 semibold | Unchanged; also the reference for section headers (kills `.headline` uses) |
| rowLabel | SF 14 semibold | NEW. The settings-row / pill-label role ProfileView inlined ten times |
| body | SF 15 regular | Unchanged. Subtitle variants (15/16/17 medium) collapse into body or cardTitle |
| caption | SF 13 regular | Unchanged; kills `.caption`, `.caption2`, and raw 12pt copies |
| micro | SF 12 semibold, tracking 1.5, uppercase | Unchanged (SGMicroLabel) |
| button | SF 17 semibold | NEW token. One label size for every full-size button |
| buttonSmall | SF 15 semibold | Compact/secondary buttons |

Serif and monospaced body text are removed (AutoGenerate previews become body; the Focus debug line may keep monospacedDigit numbers only).

### 2.3 Buttons: the signature

One component, `SGButton`, replacing all ten constructions. It is Secure's chunky ledge capsule tuned for the Meadow:

- Shape: `Capsule(style: .continuous)`, full width by default, label = button token (17 semibold), vertical padding 16 (≈ 56pt tall)
- **The ledge**: `.compositingGroup()` then `.shadow(color: ledge, radius: 0, x: 0, y: 6)`. No blur. The ledge IS the depth
- **The press**: face offsets down 6pt while the shadow collapses to y 2, `easeOut(0.12)`, tracked with `DragGesture(minimumDistance: 0)`
- Haptic: medium impact on fire. Debounce: 0.6s so double-taps never skip a step
- Disabled: opacity 0.4 + ledge removed (a flat button cannot look pressable)

Variants, all from the ramps:

| Variant | Face | Ledge | Label | Where |
|---|---|---|---|---|
| .mint (default) | mint | mintDeep | white | Every primary action on light |
| .ember | ember | emberDeep | white | Locked scene CTAs, emergency unlock |
| .white | white | black 25% | paper | CTAs on the onboarding sky arc only. Rule: ember owns lock-scene CTAs, white owns night narrative CTAs |
| .ghost | glaze 6% flat, hairline stroke, no ledge | none | paper | Secondary actions |
| .text | none | none | paperSecondary 15 semibold | Skip / dismiss |

Label color is always pure white on colored faces (the ink-vs-white split ends). SGPressStyle (scale 0.97 + light haptic) remains for cards, rows, chips, and icon buttons; SGButton handles its own press. Everything interactive gets one of the two: nothing ships `.buttonStyle(.plain)` without feedback.

All ten constructions from 1.2 are absorbed or deleted (full list in Part 4).

### 2.4 Shape, spacing, elevation

- Radii: **10** (icon tiles), **14** (tiles, option cards, input fields, chips-as-rects), **20** (cards), **28** (sheets, camera card), Capsule for buttons/pills. The {6, 8, 12, 16, 50} strays all migrate to this scale.
- Spacing: screenPadding 20, cardPadding 18, sectionSpacing 24, tabBarClearance 96 (unchanged). Onboarding CTA bottom padding: **12 everywhere** (kills the 12/16/24 jumps). Empty-state paragraph side padding: 32.
- Elevation scale (replaces 22 ad-hoc shadows): `shadowCard` (black 6%, r 12, y 4), `shadowFloat` (black 12%, r 18, y 8: tab bar, floating pills), `mintGlow` / `emberGlow` (accent 30%, r 18, y 5) for hero moments only. The 0.35 to 0.6 black shadows die.
- One input field component `SGField`: ink fill, radius 14, hairline stroke, mint 1.5pt when focused/filled.

### 2.5 Motion

- Springs: `spring` (0.45 / 0.8) for state changes, `springFast` (0.3 / 0.85) for micro, `springPop` (0.35 / 0.6) for celebration pops. The 0.5/0.55/0.58/0.6 damping strays converge on these three.
- House mount beat: `sgRiseIn(delay:)` modifier (promoted from onboarding's FadeRise): opacity 0→1 + 16pt rise, easeOut 0.45 (Secure's beat), siblings staggered 0.08s. Every screen entrance uses it.
- House step transition: insertion = fade + move from trailing, removal = fade, easeInOut 0.3. Already used by the quiz and onboarding; becomes universal.
- Press feedback: easeOut 0.12 (SGButton), springFast (SGPressStyle).
- **One corner wipe** (`SGCornerWipe`), one timing (cover 0.6, stagger 0.2, reveal 0.5: keeps the slower lock cadence you approved and applies it to every wipe), band presets built from ramps:
  - `.coldStart`: [white, splashTeal, ink]
  - `.lock`: [white, ember, night]
  - `.unlock`: [night, mint, ink] (new: leaving the locked scene into the quiz)
- The celebration keeps its circle-mask reveal (it is a reward, not a scene change). The stamp's red/white exit mask is retired; the stamp always hands off by crossfade into a matching background.
- Breathing loops standardize on one period (1.6s) for the quiz segment and ring.

### 2.6 Haptic grammar

One vocabulary in SGTheme (QuizHaptics folds in, raw generators banned):

| Call | Hardware | Meaning |
|---|---|---|
| tick | light | Small taps, per-item ticks |
| gain | soft 0.7 | Something good accrues |
| lock | rigid 0.9 | Something locks / drains |
| beat | medium | Committing, advancing, CTA fire |
| climax | heavy 1.0 | The big story moment (stamp landing) |
| success / error | notification | Completing / failing a whole exercise |
| Composed: correctBurst, wrongBuzz, lockSlam, celebrationLanding | sequences of the above | Quiz + lock choreography |

### 2.7 Iconography and mascot rules

- SF Symbols only, three sizes: 13 semibold (chevrons, sheet close, inline glyphs), 16 semibold (row icons, button icons), 20 medium (option-tile icons). Hero symbols (permission screens) are 56 medium inside the 140pt mintTint circle. The mint chevron (13 semibold) is the one disclosure treatment.
- Mascot: the Lottie poses (idle, lookingDown, clipboard, teaching) are the brand actor; the angry PNG is reserved for lock moments (stamp, locked home, shield icon, DI frames). Sizes: 148pt on the meadow crest, 180 to 190pt in overlays and the locked home, 88 to 160pt in cards/celebration, never below 62pt (quiz feedback panel). One mascot per screen, and permission/empty states use the mascot rather than bare SF symbols (fixes the three competing "permission" heroes in onboarding).

### 2.8 Platform and accessibility rules

- **Reduce Motion**: wipes become crossfades, `sgRiseIn` becomes a plain fade, the stamp holds its settled frame (already implemented), confetti and repeat-forever loops are disabled, count-ups snap to the final value (already implemented). Every new motion component ships with this branch.
- **Dynamic Type**: the app uses fixed sizes by design (dense, art-directed layouts). This is now an explicit decision instead of an accident; the flashcard sheets' `.headline`/`.caption` stragglers move to fixed tokens to match.
- **Dark mode**: the app is locked to Light (Info.plist). Night is an authored scene, not system dark mode. No token responds to the system appearance.

### 2.9 Component consolidation

- **SGCard** is the only card (parameters: shadow on/off, dashed accent border for checklist/migration). blocksCard, sgRowCard, InputCard, and the inline copies are deleted.
- **SGListRow** is the only settings row. Profile and Blocks consume it (and stop duplicating the same settings surface twice).
- **SGPickerRow / SGOptionTile** are the only selection rows. The inline clones in UsageIntervalSheet, BlocksView, and the five onboarding radio-card variants converge (24pt radio, radius 14, mintTint + mint 1.5pt stroke selected).
- **Sheets**: SGFittedSheet + SGSheetHeader everywhere, chrome applied internally (never at call sites). Editor sheets (New Deck, New Flashcard, Regret Editor, AutoGenerate) drop their NavigationStack toolbars for SGSheetHeader with a trailing Save action; one Cancel/Save styling.
- **SGChip** is the only pill; the Blocks selection chips and AutoGenerate source/delimiter chips adopt it.
- **One progress bar** component (capsule, height 8, glaze track, mint fill, easeInOut 0.35) with a thin variant (height 5) for cards; the four current implementations converge. Onboarding gets a REAL flow-wide progress bar (persistent chrome, 0 → 1 across the whole funnel) instead of the orphaned quiz bar that dies at 32%.
- **Component gallery**: a DEBUG screen (like Secure's ComponentGalleryView) rendering every SGButton variant, card, row, chip, field, sheet header, and haptic so there is exactly one visual reference.

---

## Part 3: The lock flow, redesigned

### 3.1 The scene rule (this is the fix)

The whole loop becomes a two-scene story:

- **Day** (ink canvas, mint): you are free. Metering home, celebration, return home.
- **Ember night** (night canvas, ember): you are caught. Stamp, locked home, shield, Dynamic Island.
- **Earning back** (ink canvas, ember accents): the quiz and failure states. Light, because you are working your way back to day, with ember carrying the "still locked" tension.

Every transition between poles is a corner wipe built from the destination's ramp. Nothing else changes background color mid-flow.

### 3.2 The journey, beat by beat

1. **Time runs out (on the home screen)**: countdown rolls to 0 (rounded numerals now), holds a beat. Unchanged.
2. **Lock wipe**: white → ember → night sweeps from the corner (the canonical `.lock` preset). Unchanged mechanics, tokenized colors.
3. **The stamp**: monster slams on the **night** background, always. Full choreography always (Focus no longer truncates it). `lockSlam` haptic sequence. One set of ring/bloom values shared as constants with the locked home so the crossfade into the home is pixel-continuous (this is currently claimed in a comment and false; it becomes true).
4. **Locked home**: the dark ember night screen (already built). CTA becomes SGButton .ember with the ledge. Deck card uses nightRaised/nightHairline tokens.
5. **The shield (on Instagram itself)**: re-themed to match the app's lock scene: background night #1B0E0A, title white, subtitle white 65%, button **ember** with white label. Same wording ("Caught you scrolling."). The user now sees the same scene on the blocked app and in the app.
6. **Dynamic Island / lock screen banner**: `activityBackgroundTint` becomes night #1B0E0A instead of pure black. The monster sits in the same world.
7. **Into the quiz**: from the locked home, "Study to unlock" fires the `.unlock` wipe (night → mint → ink) and lands directly on the quiz. **The stamp does not replay here** (the user was already stamped; re-slamming them on a white background was the loudest seam in the app). If the quiz is entered from a cold notification (no stamp seen this lock), the stamp plays once, on night, then wipes to the quiz.
8. **The quiz**: light aurora canvas (the ink canvas with the slow-drifting mint/teal blobs; it counts as the day pole, just warmed up for a working session). Tiles, progress, and feedback already follow the system; they pick up emberTint for wrong washes and the unified fonts/haptics.
9. **Failure**: stays light with ember accents (you are still in "earning back"), but its bloom/typography aligns with the quiz, and its give-up action returns you through the `.lock` wipe to the night home so the light → dark move is authored, not a jump cut.
10. **Celebration (the only one)**: the meadow celebration (circle reveal, count-up at heroNumeral size, confetti minus the black particles) is used by BOTH flashcards and True Focus. MascotUnlockOverlay and the neon-green "Session Complete" screen are deleted.
11. **Return home**: day scene, count-up roll. Unchanged.

Result: 2 scenes + 2 authored wipes instead of 5 unrelated backgrounds; 1 button system instead of 10; 1 stamp configuration instead of 2.5; 1 celebration instead of 3.

### 3.3 True Focus restyle (it joins the family)

- Palette: workingGreen → mint, notWorkingRed → ember, warningOrange → amber, setupReady → teal, setupWaiting → paperTertiary
- Titles: stepTitle (rounded 30) instead of plain 28; countdown/timer: heroNumeral / numeral(44)
- Done button → SGButton .mint; "Answer flashcards instead" → SGButton .ghost
- `.snappy` → springFast; camera card keeps radius 28 (now the sheet token) and its angular border, recolored to the ramp

---

## Part 4: Migration plan

Ordered so the lock flow (your priority) lands right after the foundation. Each phase builds and screenshots before the next. Sizes: S < half a day, M ≈ a day, L > a day.

### Phase 0: Foundation (L)
1. SGTheme v4: add ramps (mintSoft/mintTint, emberSoft/emberTint), night + sky scene tokens, amber/sun/splashTeal, type roles (heroNumeral, stepTitle, sheetTitle, rowLabel, button, buttonSmall), elevation tokens, haptic grammar (absorb QuizHaptics), springPop, `sgRiseIn`
2. Build `SGButton` (all variants), `SGField`, unified progress bar; parameterize SGCard (shadow, dashed)
3. `SGCornerWipe` presets + single timing; retire the stamp exit mask
4. DEBUG component gallery screen
5. `scripts/design-lint.sh`: greps that fail on `Color(hex:` / `.system(size:` / `UIImpactFeedbackGenerator` / numeric `cornerRadius` outside DesignSystem (with a small allowlist), wired into a build phase or run manually before ship

### Phase 1: Lock flow (L)
6. Shield extension → night/ember (small file, biggest visible win)
7. MonsterLiveActivity background → night
8. Stamp/LockedHome shared scene constants (rings, bloom); stamp always-on-night; Focus stops truncating it
9. Quiz entry: `.unlock` wipe from locked home, stamp only when unseen; failure exit wipe
10. One celebration: Focus adopts UnlockCelebrationView; delete MascotUnlockOverlay + sessionCompleteView; fix confetti palette; celebration numeral → heroNumeral
11. LockedHomeView + RegretView + QuizKit sweep onto v4 tokens (SGButton, emberTint, fonts)
12. True Focus restyle (palette, type, buttons, springs)

### Phase 2: Home + main tabs (M)
13. Home hero → heroNumeral (rounded); meadow pills → SGChip; MeadowCTA → SGButton
14. DeckListView/DeckView: SGScreenHeader in the pushed view, one AI-outline button, SGButton empty states
15. BlocksView + ProfileView: SGListRow everywhere, delete blocksCard/sgRowCard, single source for the shared settings rows; SGTabBar tokenized shadow + press feedback
16. Delete dead files: AnimationOptionRow, AnimationType, MemeVideoView, legacy SettingsView

### Phase 3: Onboarding + paywall (M)
Note: the live flow already implements ONBOARDING_V3_PLAN.md, so this phase restyles it in place; any future onboarding iterations build on the v4 system rather than forking it.
17. OnbCTA and all clones → SGButton (.mint / .white on night); one CTA bottom padding; secondary buttons → .text variant
18. Title sweep → stepTitle; radio/option cards → SGPickerRow spec; sky palette reads from SGTheme
19. Flow-wide persistent progress bar + chrome overlay (Secure pattern); DeclineSurveySheet gets the standard sheet chrome (`sgSheetChrome`: radius 28, hidden grabber)
20. Paywall: HardPaywallView backdrop onto tokens (SGButton, feature rows as SGListRow, fonts); BuyBackView onto tokens; restyle the RevenueCat paywall via its template/appearance configuration as far as the SDK allows, and note what it cannot match
21. Delete dead files: FightingBackView, FounderStoryView, LoopingVideoPlayer, AvgScreenTime model/viewmodel

### Phase 4: Editor sheets (L)
22. NewFlashcardSheet, RegretEditorSheet, NewDeckView/EditDeckView: SGSheetHeader + SGField + SGButton, radius scale, kill toolbars
23. AutoGenerateFlashcardSheet (the 2,358-line one): token sweep (fonts, radii 8/10/12 → 14, serif/mono out, chips → SGChip, progress → unified bar), remove dead animation state
24. PracticeView: quiz components reuse (it is a re-implementation of QuizKit today)

### Phase 5: Verification (S)
25. Lint clean; component gallery review; full simulator screenshot pass of the lock loop (metering → wipe → stamp → locked home → shield → quiz → celebration → home) and onboarding. The before/after screenshot set is the visual deliverable for "what the new version looks like"; the Docs/ screenshots get replaced with it

### What gets deleted (summary)
MeadowCTA, GlassPill, OnbCTA + 3 clones, SGPrimaryButton/SGGhostButton (absorbed), MascotUnlockOverlay, Focus sessionCompleteView + local palette, QuizHaptics (absorbed), blocksCard/sgRowCard/InputCard, stamp exit mask, rescue raw buttons, 6 dead files, all `cornerRadius(50)`, the plain-SF hero treatment, the shield's Teal Ink palette.

---

## Appendix: current vs new, at a glance

| Dimension | Today | After |
|---|---|---|
| Backgrounds in one lock loop | 5 (white, ember, #1B0E0A, #0C1E22, black) | 2 scenes (day, ember night) + authored wipes |
| Primary button implementations | 10+ | 1 (SGButton, 5 variants) |
| Title styles (onboarding) | 10 | 2 (screenTitle, stepTitle) |
| Numeral treatments | 4 | 1 (heroNumeral / numeral) |
| Dark palettes | 4 | 1 night + 1 onboarding sky |
| Haptic vocabularies | 3 | 1 grammar |
| Corner radii in the wild | {6,8,10,12,14,16,20,28,50} | {10,14,20,28} + Capsule |
| Unlock celebrations | 3 | 1 |
| Shadow recipes | 22 | 4 tokens |
| Press feedback styles | 3 + none | 2 (SGButton press, SGPressStyle) |
