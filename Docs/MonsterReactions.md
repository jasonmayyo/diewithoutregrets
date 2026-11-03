# Text-only monster chat

As of 2.0.7 (73), chat and onboarding conversations contain no reaction photos,
GIFs, videos, stickers, or animated monster artwork. Study-sheet feedback is
also text-only. The reaction picker, creator override and media renderer were
removed, together with the original MonsterReactions source media and Xcode
references. The contact header uses the character name; allowance counters and
typing status use text without decorative images or coin-flight animations.

Existing saved conversations and accepted study answers still decode: obsolete
reaction fields are ignored, while message IDs, text, grading and earned progress
are preserved. New snapshots omit those fields. Local grading and time grants
continue through the existing tested engine.

Every monster's opening has three spoken beats: an actual exam reminder (or a greeting
when there is no upcoming exam), a scrolling call-out, and a challenge naming
the selected deck and actual flashcard count. Each beat draws from its own
12-line shuffle bag, persisted across app restarts. A full bag is exhausted
before any line is reused, with no immediate repeat at a cycle boundary.

Endings use separate perfect, mixed and zero-correct pools. A corrected retry
still counts as a miss for the tone. The reaction describes the completed round;
the sendoff uses only the actual local time grant. Zero earned time never receives
an invitation to scroll. Each result/sendoff pool rotates independently. Opening
and closing copy are local and available offline; the existing best-effort AI
still supplies individual answer reactions. All four have twelve lines per
opening, call-out, challenge, outcome and sendoff pool. The closing speech stays
together above the recap and unlock badge in both study modes.

Voice direction matches the monster, not an inferred student gender: Zaza and
Willow use feminine voices; Sarge and Gnash use masculine voices. Willow is a
calm Gen Z study friend with occasional "girl", "bestie" and "little W";
she no longer uses "love", "pet" or "darling" as forms of address. Sarge keeps
his direct coaching with "bro", "lock in", reps and earned wins. Gnash is the
chaotic gaming friend with "bro", "dude", quests, lore and loot. Slang stays
secondary to the actual study instructions. Picker samples, answer fallbacks,
study-sheet bridges and reminder copy follow the same voices.

Matching script/tutor AI voice instructions are maintained in
`backend/src/protocol.js`; a backend deployment is required for server-side
prompt changes to reach the live AI service.

The user chooses the deck in **Profile → Study Settings → Flashcards to study**,
the home active-deck card, or the deck selector beneath the monster's name in
chat. All use the same saved selection. Choosing within chat immediately replaces
unanswered questions while preserving existing verdicts and earned seconds.
Each deck receives its own review outcomes once; choosing a deck never grants
time. A completed chat can start a fresh round without replaying previous rewards.
Settings/home changes apply to the next chat.

Home shows a floating **Unlock apps** button above the tabs while blocked or when
the active allowance reaches zero. It opens the monster directly without a shield
handoff. It stays hidden while time remains or the guard is off/not set up.

Validation: `python3 scripts/test_study_reliability.py` includes legacy snapshot
migration and one-time grant checks for both study modes. The release artifact
check rejects the removed reaction assets and renderer symbols.

The legacy `dog-side-eye.mp4` and both bundled copies of `mockupvideo.mp4` were also removed. The welcome recording contained third-party meme content and is replaced with a text introduction. Release validation inspects all embedded extensions and asset catalogs, in addition to loose resources.

In build 74, the permanent saved-progress / AI & Privacy strip is removed from chat. The existing consent sheet opens only when a user first requests an optional AI follow-up without saved consent. Acceptance persists across chat sessions and onboarding; the sheet dismisses and the pending question continues. Permission can still be changed in Profile > AI tutoring & privacy. Dismissing the sheet clears the pending chat question without sending it.
