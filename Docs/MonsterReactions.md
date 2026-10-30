# Monster chat reactions

The monster can attach one local reaction beneath a spoken message. Attachments
use a 136-point width, preserve the original aspect ratio, and have 6-point
corners. They arrive with the message's existing animation and single haptic.

`MonsterReactionPicker` can attach an occasional double-take loop to Zaza's
opening scrolling call-out. Otherwise it considers celebration media after a
completed round with at least 75% correct answers and an earned time grant.
It sends at most one attachment per session; an opening loop replaces the
completion reaction. At least three successful rounds separate attachments.
The shared gap is saved across sessions; the initial offset and later gaps vary.

Exam reminders, deck prompts, questions, individual answer feedback,
corrections, tutor explanations and study-sheet recaps have no automatic media.
The rainbow and delighted laugh celebrate completion; the snack loop accompanies
the sendoff to an earned break. The double-take accompanies Zaza catching the
user trying to scroll. The other surprise, side-eye and facepalm stills stay in
the library. Study-sheet completion reactions wait until the user claims their
time. Attachments stay fixed when returning to an existing chat.

Zaza's opening has three spoken beats: an actual exam reminder (or a greeting
when there is no upcoming exam), a scrolling call-out, and a challenge naming
the selected deck and actual flashcard count. Each beat draws from its own
12-line shuffle bag, persisted across app restarts. A full bag is exhausted
before any line is reused, with no immediate repeat at a cycle boundary.

Endings use separate perfect, mixed and zero-correct pools. A corrected retry
still counts as a miss for the tone. The reaction describes the completed round;
the sendoff uses only the actual local time grant. Zero earned time never receives
an invitation to scroll. Each result/sendoff pool rotates independently. Opening
and closing copy are local and available offline; the existing best-effort AI
still supplies individual answer reactions. Other personas keep their own voices.

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
