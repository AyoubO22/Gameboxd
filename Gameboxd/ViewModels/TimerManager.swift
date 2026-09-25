//
//  TimerManager.swift
//  Gameboxd
//
//  Manages a live play-session timer that tracks elapsed time for an active game.
//

import SwiftUI

/// Tracks a live play-session for a single game.
///
/// Elapsed time is computed from timestamps, not by counting ticks, so time spent
/// with the app in the background (or suspended while you play) still counts.
/// The session is persisted, so it also survives the app being killed.
@MainActor
@Observable
final class TimerManager {

    // MARK: - State

    /// Whether a session is currently active (running or paused).
    private(set) var isRunning = false

    /// Whether the active session has been paused by the user.
    private(set) var isPaused = false

    /// Total seconds elapsed in the current session (refreshed every second).
    private(set) var elapsedSeconds: Int = 0

    /// The game being tracked in the current session.
    private(set) var activeGame: Game?

    // MARK: - Private

    /// Seconds banked before the current running stretch (i.e. before the last resume).
    private var accumulatedSeconds: TimeInterval = 0
    /// Start of the current running stretch; nil while paused.
    private var runningSince: Date?
    private var timer: Timer?

    private static let storageKey = "gameboxd_active_play_session"

    private struct SavedSession: Codable {
        let game: Game
        let accumulatedSeconds: TimeInterval
        let runningSince: Date?
    }

    init() {
        restore()
    }

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
    func start(game: Game) {
        activeGame = game
        accumulatedSeconds = 0
        runningSince = Date()
        isRunning = true
        isPaused = false
        refresh()
        startTimer()
        persist()
    }

    /// Pauses the running timer without discarding elapsed time.
    func pause() {
        guard isRunning, !isPaused, let runningSince else { return }
        accumulatedSeconds += Date().timeIntervalSince(runningSince)
        self.runningSince = nil
        isPaused = true
        stopTimer()
        refresh()
        persist()
    }

    /// Resumes a paused timer, continuing from the current elapsed time.
    func resume() {
        guard isPaused else { return }
        runningSince = Date()
        isPaused = false
        startTimer()
        persist()
    }

    /// Stops the session and returns the total elapsed minutes (minimum 1, so a
    /// session is never recorded as an empty diary entry).
    @discardableResult
    func stop() -> Int {
        refresh()
        let minutes = elapsedMinutes
        stopTimer()
        isRunning = false
        isPaused = false
        elapsedSeconds = 0
        accumulatedSeconds = 0
        runningSince = nil
        activeGame = nil
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        return max(minutes, 1)
    }

    // MARK: - Private Helpers

    private func refresh() {
        let running = runningSince.map { Date().timeIntervalSince($0) } ?? 0
        elapsedSeconds = Int(accumulatedSeconds + running)
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func persist() {
        guard let activeGame else { return }
        let saved = SavedSession(game: activeGame, accumulatedSeconds: accumulatedSeconds, runningSince: runningSince)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let saved = try? JSONDecoder().decode(SavedSession.self, from: data) else { return }
        activeGame = saved.game
        accumulatedSeconds = saved.accumulatedSeconds
        runningSince = saved.runningSince
        isRunning = true
        isPaused = saved.runningSince == nil
        refresh()
        if !isPaused { startTimer() }
    }
}
