#!/usr/bin/env python3
"""Run the production countdown regression tests without an iOS app host."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="studyguard-countdown-") as work:
    work = Path(work)
    source = work / "Sources" / "CountdownReliability"
    tests = work / "Tests" / "CountdownReliabilityTests"
    source.mkdir(parents=True)
    tests.mkdir(parents=True)
    (work / "Package.swift").write_text('''// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CountdownReliability", platforms: [.macOS(.v14)],
    targets: [.target(name: "CountdownReliability"),
              .testTarget(name: "CountdownReliabilityTests", dependencies: ["CountdownReliability"])])
''')
    shutil.copyfile(root / "diewithoutregrets/DesignSystem/CountdownReadout.swift", source / "CountdownReadout.swift")
    shutil.copyfile(root / "tests/countdown/Infrastructure.swift", source / "Infrastructure.swift")
    content = (root / "diewithoutregretsTests/CountdownReplayTests.swift").read_text()
    (tests / "CountdownReplayTests.swift").write_text(
        content.replace("@testable import diewithoutregrets", "@testable import CountdownReliability"))
    raise SystemExit(subprocess.run(["swift", "test", "--package-path", str(work)]).returncode)
