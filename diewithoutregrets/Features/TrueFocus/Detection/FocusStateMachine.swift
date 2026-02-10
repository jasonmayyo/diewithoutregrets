//
//  FocusStateMachine.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Foundation

/// The four states of the focus detection system.
enum TrueFocusState: Equatable {
    /// Pre-session setup: user is positioning their phone. Not yet started.
    case setup
    /// User is working. Timer counts down.
    case working
    /// Signals are failing, countdown before pausing. Timer paused.
    case grace(remaining: Int)
    /// Grace expired. Timer paused until signals restore.
    case notWorking

    var isWorking: Bool {
        self == .working
    }

    var graceRemaining: Int? {
        if case .grace(let r) = self { return r }
        return nil
    }

    var isSetup: Bool {
        self == .setup
    }
}

/// Manages transitions between focus states based on signal results.
final class FocusStateMachine {
    private(set) var state: TrueFocusState = .setup
    private let graceDuration: Int

    init(graceDuration: Int) {
        self.graceDuration = graceDuration
    }

    /// Called when setup completes (user held position for required duration).
    func setupComplete() {
        if state == .setup {
            state = .working
        }
    }

    /// Called every tick (1 second) with the result of signal evaluation.
    @discardableResult
    func tick(signalsPass: Bool) -> TrueFocusState {
        switch state {
        case .setup:
            // Setup is handled externally by the detection manager
            return state

        case .working:
            if signalsPass {
                return state
            } else {
                state = .grace(remaining: graceDuration)
                return state
            }

        case .grace(let remaining):
            if signalsPass {
                state = .working
                return state
            } else {
                let newRemaining = remaining - 1
                if newRemaining <= 0 {
                    state = .notWorking
                } else {
                    state = .grace(remaining: newRemaining)
                }
                return state
            }

        case .notWorking:
            if signalsPass {
                state = .working
            }
            return state
        }
    }

    func reset() {
        state = .setup
    }
}
