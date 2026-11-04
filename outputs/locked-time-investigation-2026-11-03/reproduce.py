#!/usr/bin/env python3
"""Reproduce the historical midnight display bug with production Swift code.

No device, network, real app-group data, or repository source edits are used.
The historical refresh calculation is extracted from git; current state/budget
code is compiled unchanged. Only iOS scheduling adapters are excluded on macOS.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
old_manager = subprocess.check_output([
    'git', 'show',
    '76a1b7c^:diewithoutregrets/Features/StudyGuard/Services/StudyGuardManager.swift'
], cwd=root, text=True)
old_budget = old_manager.split('        let total = d.double', 1)[1].split('        let ledger', 1)[0]
old_budget = '        let total = d.double' + old_budget
contract = (root / 'diewithoutregrets/Shared/SGContract.swift').read_text().replace(
    '#if canImport(DeviceActivity)', '#if os(iOS) && canImport(DeviceActivity)')
state = (root / 'diewithoutregrets/Features/StudyGuard/Models/StudyGuardState.swift').read_text()
historical = '''
func historicalRemaining(_ d: UserDefaults) -> Int {
    let intervalMinutes = 15
    var totalMinutes = 0
    var usedMinutes = 0
''' + old_budget + '''
    return max(0, totalMinutes - usedMinutes)
}
'''
harness = r'''
// Fake persistence only; all state/budget/grant calculations are production code.
final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func object(forKey key: String) -> Any? { values[key] }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func set(_ value: Bool, forKey key: String) { values[key] = value }
    override func set(_ value: Int, forKey key: String) { values[key] = value }
    override func set(_ value: Double, forKey key: String) { values[key] = value }
    override func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    override func integer(forKey key: String) -> Int { (values[key] as? NSNumber)?.intValue ?? 0 }
    override func double(forKey key: String) -> Double { (values[key] as? NSNumber)?.doubleValue ?? 0 }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func data(forKey key: String) -> Data? { values[key] as? Data }
    override func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    override func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    override func synchronize() -> Bool { true }
}
let d = MemoryDefaults()
let now = Date()
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
d.set(true, forKey: SGContract.Keys.setupComplete)
d.set(true, forKey: SGContract.Keys.guardEnabled)
d.set("locked", forKey: SGContract.Keys.state)
d.set(yesterday.timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
d.set(900.0, forKey: SGContract.Keys.budgetTotalSeconds)
d.set(900.0, forKey: SGContract.Keys.budgetUsedSeconds)

let oldRemaining = historicalRemaining(d)
precondition(oldRemaining == 15 && GuardState.derive(from: d) == .locked)
print("REPRODUCED historical midnight mismatch: locked=true, displayedRemaining=15")
let current = GuardBudgetSnapshot(from: d, state: GuardState.derive(from: d), now: now)
precondition(current.remainingMinutes == 0)
precondition(d.double(forKey: SGContract.Keys.budgetGrantedAt) == yesterday.timeIntervalSince1970)
print("PASS current snapshot: locked=true, displayedRemaining=0; no grant written")
precondition(GuardState.locked.offersStudyUnlock(remainingMinutes: 15))
precondition(GuardState.locked.offersStudyUnlock(remainingMinutes: 0))
print("PASS locked users retain manual unlock entry independent of displayed allowance")
d.removeObject(forKey: SGContract.Keys.budgetUsedSeconds)
d.removeObject(forKey: SGContract.Keys.budgetGrantedAt)
precondition(GuardBudgetSnapshot(from: d, state: .locked, now: now).remainingMinutes == 0)
print("PASS missing usage/grant timestamp still displays zero while locked")
d.set("metering", forKey: SGContract.Keys.state)
d.set(yesterday.timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
d.set(900.0, forKey: SGContract.Keys.budgetUsedSeconds)
precondition(GuardBudgetSnapshot(from: d, state: .metering, now: now).remainingMinutes == 15)
print("PASS stale metering allowance still resets for display")
d.set(now.timeIntervalSince1970, forKey: SGContract.Keys.budgetGrantedAt)
d.set(420.0, forKey: SGContract.Keys.budgetUsedSeconds)
precondition(GuardBudgetSnapshot(from: d, state: .metering, now: now).remainingMinutes == 8)
print("PASS same-day metering preserves real usage: 8 of 15 minutes remain")

let grant = PendingBudgetGrant(id: UUID(), minutes: 3, reason: .quiz)
var committed = 0
var failed = 0
precondition(!BudgetGrantLedger.attempt(grant, defaults: d, start: { false },
    commit: { committed += 1 }, fail: { failed += 1 }))
precondition(committed == 0 && failed == 1 && BudgetGrantLedger.pending(in: d).count == 1)
precondition(BudgetGrantLedger.attempt(grant, defaults: d, start: { true },
    commit: { committed += 1 }, fail: { failed += 1 }))
precondition(committed == 1 && BudgetGrantLedger.pending(in: d).isEmpty)
precondition(BudgetGrantLedger.attempt(grant, defaults: d,
    start: { preconditionFailure("Completed grant must not restart monitoring") },
    commit: { committed += 1 }, fail: { failed += 1 }))
precondition(committed == 1)
print("PASS pending reward survives registration failure, retries once, and cannot double-commit")
print("LIMITATION: pure Swift logic only; actual iOS shields and cross-process timing are not simulated")
'''
with tempfile.TemporaryDirectory(prefix='locked-time-repro-') as temp:
    temp = Path(temp)
    script = temp / 'main.swift'
    script.write_text(contract + '\n' + state + '\n' + historical + '\n' + harness)
    result = subprocess.run(['swift', '-module-cache-path', str(temp / 'module-cache'), str(script)],
                            cwd=root, capture_output=True, text=True)
    output = result.stdout + result.stderr
    (Path(__file__).parent / 'results.txt').write_text(output)
    print(output, end='')
    raise SystemExit(result.returncode)
