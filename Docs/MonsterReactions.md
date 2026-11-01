# Monster chat reactions

The monster can attach one local reaction beneath a spoken message. Attachments
use a 136-point width, preserve the original aspect ratio, and have 6-point
corners. They arrive with the message's existing animation and single haptic.

`MonsterReactionPicker` gives every monster a 60% chance of attaching a GIF or
sticker directly beneath the first spoken message in a new study chat. Each
persona has a small pool of suitable opening reactions, and its last displayed
reaction is saved so consecutive attachments do not repeat across app restarts.
**Profile → Creator Toolkit → Monster chat** has an **Always send an
opening GIF or sticker** toggle. It is off by default; turning it on guarantees
media after the first message for every monster in either study mode. The choice
persists across launches and applies to new chats, including a fresh round after
finishing the previous chat. Turning it off restores the 60% chance.

This probability is independent of the completion cooldown. Otherwise the
picker considers celebration media after a completed round with at least 75%
correct answers and an earned time grant. An opening attachment replaces the
completion reaction. At least three eligible strong rounds separate completion
celebrations. That gap is saved across sessions; it does not restrict openings.

Four consecutive wrong answers always send the animated double-take reaction,
even when the opening already included media. Continued misses trigger again at
eight, twelve, and so on; a correct answer resets the count. This is tracked
locally across pausing, ongoing deck changes and study-sheet follow-ups, and resets
for a fresh chat. Only accepted, graded answers count. Invalid or duplicate
sheet submissions and tutor questions do not affect it. In chat the GIF follows
the wrong-answer feedback; in the study sheet it appears below that question's
answer feedback and stays attached when resuming. It never changes earned time.

Deck prompts, questions, other individual answer feedback, tutor explanations
and study-sheet recaps have no automatic media.
The rainbow, delighted laugh and grinning dog celebrate completion; the snack loop accompanies
the sendoff to an earned break. Opening pools mix double-take/laugh loops with
surprise, side-eye, awkward-smile or facepalm stickers suited to each monster.
The ten additional photo stickers also rotate through persona-appropriate opening
pools: softer awkward/thinking reactions for Willow, dry skeptical reactions for
Sarge, playful chaos for Gnash and expressive side-eye reactions for Zaza.
Study-sheet completion reactions wait until the user claims their time.
Attachments stay fixed when returning to an existing chat; reopening it neither
rerolls the 60% decision nor attaches another reaction.

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

All assets live in `diewithoutregrets/Resources/MonsterReactions` and are bundled
only with the main app. There are no remote URLs or media-service requests.

| Asset | User-supplied source |
| --- | --- |
| wide-eyes.jpg | IMG_0054.jpg |
| rainbow-ride.jpg | IMG_0052.jpg |
| awkward-smile.jpg | IMG_0051.jpg |
| side-eye.jpg | IMG_0049.jpg |
| facepalm.jpg | IMG_0048.jpg |
| delighted-laugh.mp4 | ScreenRecording_10-30-2026 10-01-51_1.mov |
| double-take.mp4 | ScreenRecording_10-30-2026 10-03-39_1.mov |
| snack-break.mp4 | ScreenRecording_10-30-2026 10-04-20_1.mov |
| stunned-driver.jpg | IMG_0071.jpg |
| awkward-wave.jpg | IMG_0070.jpg |
| raised-finger-cat.jpg | IMG_0068.jpg |
| unimpressed-dog.jpg | IMG_0067.jpg |
| space-dog-shrug.jpg | IMG_0066.jpg |
| thinking-monkey.jpg | IMG_0065.jpg |
| grinning-dog.jpg | IMG_0064.jpg |
| side-eye-sip.jpg | IMG_0063.jpg |
| sleepy-dog.jpg | IMG_0062.jpg |
| holding-it-in.jpg | IMG_0061.jpg |

The stills are original copies. The recordings were exported locally through
AVFoundation's medium-quality MP4 preset, keeping only the video track; each has
a JPEG poster. The snack loop is re-exported from the supplied recording using
only its first 4.3 seconds, removing the Control Center footage at the end. The
three loops total about 850 KB. Playback is muted, can be
paused by tapping, and releases its player when scrolled away, covered, or
backgrounded. Reduce Motion displays the poster instead. VoiceOver describes
every reaction and exposes the pause/play action for animated ones.

Validation: `python3 scripts/test_study_reliability.py` checks the library's
posters, aspect ratios, silent video tracks, completion cadence, stable session attachments,
arrival feedback, and reward isolation. The isolated native preview supports
`--state=reactions`, `--state=reaction-still`, `--state=snack-break`, and
`--state=reaction-library`. The library fixture deliberately displays every
asset; it is not the automatic sending policy.
