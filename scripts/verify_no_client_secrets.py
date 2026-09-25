#!/usr/bin/env python3
"""Fail a build/archive if a provider key or obsolete key plist entry ships.

Usage: python3 scripts/verify_no_client_secrets.py path/to/StudyGuard.app
Reports filenames only, never matching credentials.
"""
import plistlib
import re
import sys
from pathlib import Path

def check(app):
    failures = []
    info = app / 'Info.plist'
    if not info.is_file():
        return ['Missing built Info.plist']
    with info.open('rb') as handle:
        data = plistlib.load(handle)
    if 'OpenAIAPIKey' in data or 'OPENAI_API_KEY' in data:
        failures.append('Obsolete provider-key entry in Info.plist')
    host = data.get('StudyGuardAPIHost', '')
    if not host or '$(' in host or '/' in host:
        failures.append('Missing or invalid StudyGuardAPIHost')
    pattern = re.compile(rb'sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{40,}')
    for path in app.rglob('*'):
        if path.is_file() and not path.is_symlink():
            # Scan in chunks with overlap so large frameworks do not exhaust RAM.
            with path.open('rb') as handle:
                tail = b''
                while chunk := handle.read(1024 * 1024):
                    combined = tail + chunk
                    if pattern.search(combined):
                        failures.append(f'Possible provider key in {path.relative_to(app)}')
                        break
                    tail = combined[-512:]
    return failures

if __name__ == '__main__':
    problems = check(Path(sys.argv[1]))
    for problem in problems:
        print(f'error: {problem}')
    if problems:
        sys.exit(1)
    print('Client secret check passed: public endpoint configured; no OpenAI key found.')
