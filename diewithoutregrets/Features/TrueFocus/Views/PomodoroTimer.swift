//
//  PomodoroTimer.swift
//  Attent
//
//  Created by Jason Mayo on 2026/02/06.
//

import Combine
import Foundation

final class PomodoroTimer: ObservableObject {
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var isComplete: Bool = false

    private let duration: Int
    private var timerCancellable: AnyCancellable?
    private var isFocused: Bool = false

    /// Called when the timer reaches zero.
    var onSessionComplete: (() -> Void)?

    init(durationMinutes: Int = 25) {
        self.duration = durationMinutes * 60
        self.remainingSeconds = duration
    }

    func setFocused(_ focused: Bool) {
        isFocused = focused
    }

    func start() {
        guard timerCancellable == nil else { return }
        isComplete = false
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func reset() {
        remainingSeconds = duration
        isComplete = false
    }

    private func tick() {
        guard isFocused, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            isComplete = true
            stop()
            onSessionComplete?()
        }
    }
}
