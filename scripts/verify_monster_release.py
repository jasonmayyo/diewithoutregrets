#!/usr/bin/env python3
"""Validate a built .app or .xcarchive: versions, text-only chat and private API."""
from pathlib import Path
import plistlib
import json
import subprocess
import sys

root = Path(sys.argv[1])
app = next((root / 'Products/Applications').glob('*.app')) if root.suffix == '.xcarchive' else root
with (app / 'Info.plist').open('rb') as handle:
    main = plistlib.load(handle)
expected = (main['CFBundleShortVersionString'], main['CFBundleVersion'])
errors = []
for extension in app.rglob('*.appex'):
    with (extension / 'Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    if (info.get('CFBundleShortVersionString'), info.get('CFBundleVersion')) != expected:
        errors.append(f'Version mismatch: {extension.name}')
    executable = extension / info['CFBundleExecutable']
    if executable.exists() and any(token in executable.read_bytes() for token in [b'LSApplicationWorkspace', b'openApplicationWithBundleID']):
        errors.append(f'Private handoff API: {extension.name}')
if list(app.rglob('MonsterReactions')):
    errors.append('Removed reaction media is present in the app bundle; clean and rebuild.')
removed_media = {
    'double-take', 'delighted-laugh', 'snack-break', 'side-eye-sip',
    'stunned-driver', 'awkward-smile', 'side-eye', 'facepalm', 'wide-eyes',
    'awkward-wave', 'unimpressed-dog', 'raised-finger-cat', 'holding-it-in',
    'thinking-monkey', 'grinning-dog', 'sleepy-dog', 'space-dog-shrug', 'rainbow-ride',
    'dog-side-eye', 'mockupvideo',
}
for path in app.rglob('*'):
    if path.is_file() and path.stem in removed_media and path.suffix.lower() in {'.jpg', '.jpeg', '.png', '.gif', '.mp4', '.mov'}:
        errors.append(f'Removed reaction asset: {path.name}')
for catalog in app.rglob('Assets.car'):
    result = subprocess.run(['xcrun', 'assetutil', '--info', str(catalog)], capture_output=True, text=True)
    if result.returncode:
        errors.append(f'Could not inspect asset catalog: {catalog.relative_to(app)}')
        continue
    for asset in json.loads(result.stdout):
        if asset.get('Name') in removed_media:
            errors.append(f'Removed asset in catalog: {asset["Name"]}')
executable = app / main['CFBundleExecutable']
if executable.exists():
    binary = executable.read_bytes()
    for token in [b'MonsterReactionView', b'MonsterReactionPicker']:
        if token in binary:
            errors.append(f'Retired reaction implementation: {token.decode()}')
for error in errors:
    print('error:', error)
print(f'Monster release check: {expected[0]} ({expected[1]}) — ' + ('FAILED' if errors else 'passed'))
sys.exit(bool(errors))
