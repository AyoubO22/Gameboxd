//
//  TimerManager.swift
//  Gameboxd
//
//  Manages a live play-session timer that tracks elapsed time for an active game.
//

import SwiftUI
import Combine

/// Tracks a live play-session for a single game.
///
/// All mutations happen on the `MainActor` so consumers can bind directly to
/// `@Observable` properties without extra dispatch.
@MainActor
@Observable
final class TimerManager {

    // MARK: - State

    /// Whether a session is currently active (running or paused).
    var isRunning = false

    /// Whether the active session has been paused by the user.
    var isPaused = false

    /// Total seconds elapsed in the current session.
    var elapsedSeconds: Int = 0

    /// The game being tracked in the current session.
    var activeGame: Game?

    // MARK: - Private

    private var timer: Timer?

    // MARK: - Computed Properties

    /// Human-readable elapsed time formatted as `HH:MM:SS`.
    var formattedTime: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// Elapsed time rounded down to whole minutes.
    var elapsedMinutes: Int {
        elapsedSeconds / 60
    }

    // MARK: - Public Interface

    /// Starts a new session for the given game, resetting any previous state.
    /// - Parameter game: The game whose play time should be tracked.
    func start(game: Game) {
        activeGame = game
        elapsedSeconds = 0
        isRunning = true
        isPaused = false
        startTimer()
    }

    /// Pauses the running timer without discarding elapsed time.
    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// Resumes a paused timer, continuing from the current elapsed time.
    func resume() {
        guard isPaused else { return }
        isPaused = false
        isRunning = true
        startTimer()
    }

    /// Stops the session and returns the total elapsed minutes to the caller.
    ///
    /// Returns at least `1` minute so zero-length sessions are never recorded
    /// as empty diary entries.
    /// - Returns: Elapsed minutes (minimum 1).
    @discardableResult
    func stop() -> Int {
        let minutes = elapsedMinutes
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        elapsedSeconds = 0
        activeGame = nil
        return max(minutes, 1)
    }

    // MARK: - Private Helpers

    private func startTimer() {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.elapsedSeconds += 1
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
