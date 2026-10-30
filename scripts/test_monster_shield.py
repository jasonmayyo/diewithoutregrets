#!/usr/bin/env python3
"""Test real shield handoff, persona storage and navigation without Screen Time."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='studyguard-monster-shield-') as work:
    work = Path(work)
    source = work / 'Sources' / 'MonsterShield'
    tests = work / 'Tests' / 'MonsterShieldTests'
    source.mkdir(parents=True)
    tests.mkdir(parents=True)
    (work / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MonsterShield", platforms: [.macOS(.v14)],
    targets: [.target(name: "MonsterShield"),
              .testTarget(name: "MonsterShieldTests", dependencies: ["MonsterShield"])])
''')
    for relative in [
        'diewithoutregrets/Shared/SGContract.swift',
        'diewithoutregrets/Shared/ShieldReturnContext.swift',
        'diewithoutregrets/Shared/MonsterPersona.swift',
        'diewithoutregrets/Features/StudyGuard/Models/StudyGuardState.swift',
        'diewithoutregrets/Features/TutorMonster/PersonaStore.swift',
        'diewithoutregrets/NavigationModel.swift',
    ]:
        path = root / relative
        content = path.read_text().replace('#if canImport(DeviceActivity)', '#if os(iOS) && canImport(DeviceActivity)')
        (source / path.name).write_text(content)
    for name in ['MonsterShieldTests.swift', 'ShieldReturnContextTests.swift']:
        content = (root / 'diewithoutregretsTests' / name).read_text()
        (tests / name).write_text(content.replace('@testable import diewithoutregrets', '@testable import MonsterShield'))
    raise SystemExit(subprocess.run(['swift', 'test', '--package-path', str(work)]).returncode)
