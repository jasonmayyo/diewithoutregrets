#!/usr/bin/env python3
"""Run isolated, offline characterization probes using the existing test harness.

PASS confirms the reported behavior, not that the release issue is fixed.
No live attestation/provider calls. No production source files are modified.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
probe = Path(__file__).with_name('MonsterReleaseAuditTests.swift')
runner = (root / 'scripts/test_study_reliability.py').read_text()
runner = runner.replace('root = Path(__file__).resolve().parents[1]', 'root = Path(' + repr(str(root)) + ')')
runner = runner.replace('    env = dict(os.environ)',
    '    shutil.copyfile(' + repr(str(probe)) + ", tests / 'MonsterReleaseAuditTests.swift')\n    env = dict(os.environ)")
runner = runner.replace("['swift', 'test', '--package-path', str(work)]",
    "['swift', 'test', '--package-path', str(work), '--filter', 'MonsterReleaseAuditTests']")
exec(compile(runner, str(root / 'scripts/test_study_reliability.py'), 'exec'))
