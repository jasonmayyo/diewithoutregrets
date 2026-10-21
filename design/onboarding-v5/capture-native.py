"""Refresh round-one screenshots from an already installed Debug app.
Usage: python3 capture-native.py --simulator <dedicated simulator UUID>
Run only when no other task is interacting with that simulator.
"""
import argparse
import json
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--simulator', required=True)
parser.add_argument('--screens', type=int, nargs='+', help='Refresh only these stable screen IDs')
args = parser.parse_args()
root = Path(__file__).resolve().parent
manifest = root / 'captures.js'
captures = json.loads(manifest.read_text().split(' = ', 1)[1].strip().rstrip(';'))
shots = [(i, 0, '-sg-v5-scanning' if i == 806 else '-sg-v5-exam-dots' if i == 818 else '', f'{i}-native.png') for i in [800, 813, 803, 804, 805, 806, 820, 807, 810, 819, 818, 812, 817, 801, 814, 815, 816, 506, 601, 602, 606, 604]]
shots += [
    (813, 1, '-sg-v5-demo-earned', '813-native-earned.png'),
    (813, 2, '-sg-v5-demo-spent', '813-native-spent.png'),
    (806, 1, '-sg-v5-generated', '806-native-generated.png'),
    (812, 1, '-sg-v5-rule-cards 5', '812-native-five.png'),
    (812, 2, '-sg-v5-rule-cards 20', '812-native-twenty.png'),
    (816, 1, '-sg-v5-plan-middle', '816-native-middle.png'),
    (816, 2, '-sg-v5-plan-end', '816-native-end.png'),
]
if args.screens:
    shots = [shot for shot in shots if shot[0] in args.screens]
for screen, state, flag, filename in shots:
    command = ['xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator,
               'com.jasonmayo.diewithoutregrets', '-hasCompletedOnboarding', 'NO', f'-sg-v5-{screen}']
    if flag:
        command.extend(flag.split())
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, timeout=45)
    time.sleep(2.7 if screen == 815 else 6)
    name = 'screenshots/' + filename
    subprocess.run(['xcrun', 'simctl', 'io', args.simulator, 'screenshot', str(root / name)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    entries = captures.setdefault(str(screen), [])
    while len(entries) <= state:
        entries.append(None)
    entries[state] = name
    manifest.write_text('window.STUDY_GUARD_CAPTURES = ' + json.dumps(captures, indent=2) + ';\n')
    print(f'Captured {screen}, state {state}', flush=True)
