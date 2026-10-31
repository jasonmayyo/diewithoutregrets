#!/usr/bin/env python3
"""Run production study code without launching the FamilyControls iOS host.

Uses a temporary macOS Swift package and fakes only persistence/Screen Time side
 effects. All HTTP/attestation in tests is injected; no paid API calls are made.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='studyguard-reliability-') as work:
    work = Path(work)
    source = work / 'Sources' / 'StudyReliability'
    tests = work / 'Tests' / 'StudyReliabilityTests'
    source.mkdir(parents=True)
    tests.mkdir(parents=True)
    (work / 'Package.swift').write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "StudyReliability", platforms: [.macOS(.v14)],
    targets: [.target(name: "StudyReliability"),
              .testTarget(name: "StudyReliabilityTests", dependencies: ["StudyReliability"],
                          resources: [.copy("MonsterReactions")]),
              .target(name: "StudyStorage"),
              .testTarget(name: "StudyStorageTests", dependencies: ["StudyStorage"])])
''')
    for relative in [
        'diewithoutregrets/Shared/SGContract.swift',
        'diewithoutregrets/Shared/MonsterPersona.swift',
        'diewithoutregrets/Features/RegretGuard/Models/RegretGuardApps.swift',
        'diewithoutregrets/Features/RegretGuard/Services/FlashcardAPIClient.swift',
        'diewithoutregrets/Features/TutorMonster/MonsterAI.swift',
        'diewithoutregrets/Features/TutorMonster/MonsterScript.swift',
        'diewithoutregrets/Features/TutorMonster/MonsterMessage.swift',
        'diewithoutregrets/Features/TutorMonster/MonsterReaction.swift',
        'diewithoutregrets/Features/TutorMonster/MonsterSession.swift',
        'diewithoutregrets/Features/TutorMonster/MonsterStudyRound.swift',
        'tests/reliability/Infrastructure.swift',
    ]:
        path = root / relative
        if path.name == 'SGContract.swift':
            # This SDK exposes DeviceActivity to canImport on macOS even though
            # its scheduling types are iOS-only. Exclude only those adapter blocks;
            # the production mood and reward calculations remain unchanged.
            content = path.read_text().replace('#if canImport(DeviceActivity)', '#if os(iOS) && canImport(DeviceActivity)')
            (source / path.name).write_text(content)
        else:
            shutil.copyfile(path, source / path.name)
    client_tests = (root / 'diewithoutregretsTests/FlashcardAPIClientTests.swift').read_text()
    client_tests = client_tests.replace('@testable import diewithoutregrets', '@testable import StudyReliability')
    (tests / 'FlashcardAPIClientTests.swift').write_text(client_tests)
    shutil.copyfile(root / 'tests/reliability/MonsterSessionTests.swift', tests / 'MonsterSessionTests.swift')
    shutil.copyfile(root / 'tests/reliability/MonsterStudySheetTests.swift', tests / 'MonsterStudySheetTests.swift')
    shutil.copyfile(root / 'tests/reliability/MonsterPresentationTests.swift', tests / 'MonsterPresentationTests.swift')
    shutil.copyfile(root / 'tests/reliability/MonsterReactionTests.swift', tests / 'MonsterReactionTests.swift')
    shutil.copyfile(root / 'tests/reliability/MonsterOpeningTests.swift', tests / 'MonsterOpeningTests.swift')
    shutil.copyfile(root / 'tests/reliability/StudyCalendarTests.swift', tests / 'StudyCalendarTests.swift')
    shutil.copyfile(root / 'tests/reliability/StudyLinkSessionTests.swift', tests / 'StudyLinkSessionTests.swift')
    shutil.copytree(root / 'diewithoutregrets/Resources/MonsterReactions', tests / 'MonsterReactions')
    # Exercise the real UserDefaults stores separately from the chat's focused fakes.
    storage = work / 'Sources' / 'StudyStorage'
    storage_tests = work / 'Tests' / 'StudyStorageTests'
    storage.mkdir(parents=True)
    storage_tests.mkdir(parents=True)
    for name in ['RegretGuardApps.swift', 'RegretStore.swift']:
        shutil.copyfile(root / 'diewithoutregrets/Features/RegretGuard/Models' / name, storage / name)
    shutil.copyfile(root / 'tests/storage/Infrastructure.swift', storage / 'Infrastructure.swift')
    shutil.copyfile(root / 'tests/storage/StudyLinksTests.swift', storage_tests / 'StudyLinksTests.swift')
    env = dict(os.environ)
    # Live smoke tests are opt-in in Xcode only, never in this offline runner.
    env.pop('STUDY_GUARD_LIVE_GENERATION', None)
    env.pop('STUDY_GUARD_LIVE_ATTESTATION', None)
    raise SystemExit(subprocess.run(['swift', 'test', '--package-path', str(work)], env=env).returncode)
