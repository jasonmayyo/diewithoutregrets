"""Capture the current native flow on a dedicated, disposable review simulator.

Install the Debug app first and dismiss its initial tracking prompt. Chat phases
use read-only sample fixtures; no purchase, permission, guarding or reward occurs.
Usage: python3 capture-screens.py --simulator UUID [--only welcome name ...]
"""
import argparse
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
SCREENS = [
    ('welcome', 'Welcome + unlock recording', 'intro', 800, 'Existing recording placeholder.'),
    ('how-guard', 'Block the scroll', 'intro', 824, 'Original phone animation + real app icons.'),
    ('how-study', 'Get past your study buddy', 'intro', 825, 'Meme first → exam reminder → 3 questions before scrolling.'),
    ('personalize', 'Let’s personalize Study Guard', 'intro', 822, 'Your study buddy that never rests.'),
    ('gender', 'Your gender', 'intro', 828, 'Regular selection screen. Includes “Prefer not to say”.'),
    ('age', 'How old are you?', 'intro', 819, 'Choose an age range before chat.'),
    ('phone-hours', 'Daily phone time', 'intro', 810, 'Choose an estimated daily range.'),
    ('phone-cost', 'What that adds up to', 'intro', 827, '3 hours/day → 1,095 hours/year.'),
    ('monster', 'Pick your buddy', 'intro', 821, 'Willow, Zaza, Sarge or Gnash.'),
    ('name', 'Hello, meme + your name', 'chat', 'name', 'First name or nickname.'),
    ('level', 'Your study level', 'chat', 'level', 'School, university or professional exams.'),
    ('materials', 'Bring your study material', 'chat', 'materials', 'Upload a PDF (main option), a Quizlet export or a YouTube lecture. The subject is detected from the notes.'),
    ('exam', 'Upcoming test or exam?', 'chat', 'exam', 'An optional date, asked after the upload and tied to the detected subject.'),
    ('practice', 'Try one card together', 'chat', 'practice', 'A practice answer, before setup.'),
    ('practiceReview', 'The aha moment', 'chat', 'practiceReview', 'Get feedback or ask for an explanation.'),
    ('offer', 'Your plan is ready', 'chat', 'offer', '1 minute per correct card. Continue to subscription options.'),
    ('paywall', 'Subscription', 'purchase', 506, 'Existing paywall; purchase or restore to continue.'),
    ('permission', 'Screen Time permission', 'setup', 'permission', 'Allow access, or set up later.'),
    ('apps', 'Choose apps to guard', 'setup', 'apps', 'Native picker → confirm and start guarding.'),
    ('firstRound', 'Earn your first break', 'setup', 'firstRound', 'Opens a real study round with the saved cards.'),
    ('notifications', 'Optional reminders → Home', 'setup', 'notifications', 'Enable reminders or continue to Home.'),
]

def is_launch_screen(path):
    """Some simulator launches outlast the normal six-second settling delay."""
    with Image.open(path) as image:
        colors = image.convert('RGB').resize((32, 32)).getcolors(1024)
    teal = sum(count for count, (red, green, blue) in colors
               if red < 110 and green > 140 and blue > 140 and abs(green - blue) < 25)
    return teal > 700

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', required=True)
    parser.add_argument('--only', nargs='+')
    args = parser.parse_args()
    shots = ROOT / 'screenshots'
    shots.mkdir(exist_ok=True)
    manifest_path = ROOT / 'screenshots.json'
    existing = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    active_keys = {screen[0] for screen in SCREENS}
    captured = {item['id']: item for item in existing if item['id'] in active_keys}
    for index, (key, title, section, target, note) in enumerate(SCREENS, 1):
        if args.only and key not in args.only:
            continue
        command = ['xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator,
                   'com.jasonmayo.diewithoutregrets', '-hasCompletedOnboarding', 'NO']
        command += ['-sg-onboarding-screen-capture', str(target)] if isinstance(target, int) else ['-sg-buddy-capture', target]
        subprocess.run(command, check=True, stdout=subprocess.DEVNULL, timeout=45)
        time.sleep(13 if key == 'how-study' else 10 if key == 'paywall' else 6)
        filename = f'screenshots/{index:02d}-{key}.png'
        for attempt in range(9):
            subprocess.run(['xcrun', 'simctl', 'io', args.simulator, 'screenshot', str(ROOT / filename)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
            if not is_launch_screen(ROOT / filename):
                break
            time.sleep(2)
        else:
            raise RuntimeError(f'{key} stayed on the launch screen; no completed capture recorded.')
        captured[key] = dict(id=key, number=index, title=title, section=section, note=note,
                             file=filename, fixture=True,
                             capturedAt=datetime.now(timezone.utc).isoformat())
        manifest_path.write_text(json.dumps(sorted(captured.values(), key=lambda item: item['number']), indent=2) + '\n')
        print(f'{index:02d} / {len(SCREENS)} · {title}', flush=True)

if __name__ == '__main__':
    main()
