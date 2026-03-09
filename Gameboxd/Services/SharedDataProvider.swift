//
//  SharedDataProvider.swift
//  Gameboxd
//
//  Bridges app data to WidgetKit via a shared App Group UserDefaults store.
//
//  IMPORTANT – Xcode target membership:
//  Add this file to BOTH the "Gameboxd" target and the "GameboxdWidget" target
//  so that the widget extension can read the same type definitions without an
//  extra framework dependency.
//

import Foundation
import WidgetKit

/// Provides shared data between the main app and the widget extension via the
/// App Group UserDefaults suite `group.personal.Gameboxd`.
///
/// **Main app** calls ``updateWidgetData(currentGame:yearlyCompleted:yearlyTarget:backlogGames:totalPlayTimeMinutes:)``
/// whenever relevant state changes (e.g. after saving games).
///
/// **Widget extension** calls the individual read helpers (`getCurrentGame()`,
/// `getYearlyGoal()`, etc.) from inside its `TimelineProvider` implementations.
enum SharedDataProvider {

    // MARK: - App Group

    /// The App Group suite name shared between the main app and the widget extension.
    /// Must match the App Group identifier registered in both targets' entitlements.
    static let suiteName = "group.personal.Gameboxd"

    // MARK: - Storage Keys

    private enum Keys {
        static let currentGame           = "widget_current_game"
        static let yearlyGoalCompleted   = "widget_yearly_goal_completed"
        static let yearlyGoalTarget      = "widget_yearly_goal_target"
        static let backlogGames          = "widget_backlog_games"
        static let totalPlayTimeMinutes  = "widget_total_playtime"
    }

    // MARK: - Shared Model

    /// A lightweight, `Codable` snapshot of a game used exclusively by widgets.
    ///
    /// This type intentionally avoids importing `SwiftUI` or `SwiftData` so it
    /// compiles cleanly inside the widget extension sandbox.
    struct WidgetGame: Codable {
        /// Display title of the game.
        let title: String
        /// Remote cover image URL string, or `nil` if unavailable.
        let coverURL: String?
        /// Platform the game is played on (e.g. "PS5", "PC", "Switch").
        let platform: String
        /// Accumulated play time in minutes.
        let playTimeMinutes: Int
        /// Raw string value of ``GameStatus`` (e.g. "En cours", "À jouer").
        let status: String
    }

    // MARK: - Write (called from the main app)

    /// Serialises the current widget-relevant state into the shared App Group
    /// UserDefaults suite and asks WidgetKit to reload all widget timelines.
    ///
    /// Call this method after any mutation that changes the data widgets display:
    /// adding/removing a game, updating play time, or modifying the yearly goal.
    ///
    /// - Parameters:
    ///   - currentGame: The game currently being played, or `nil` if none.
    ///   - yearlyCompleted: Number of games completed this calendar year.
    ///   - yearlyTarget: The user's yearly completion goal (minimum 1).
    ///   - backlogGames: Up to 20 games from the user's backlog.
    ///   - totalPlayTimeMinutes: Grand total accumulated play time in minutes.
    static func updateWidgetData(
        currentGame: WidgetGame?,
        yearlyCompleted: Int,
        yearlyTarget: Int,
        backlogGames: [WidgetGame],
        totalPlayTimeMinutes: Int
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        // Current game — store only when present; clear the key when absent so
        // the widget shows the "no game" empty state rather than stale data.
        if let game = currentGame, let encoded = try? JSONEncoder().encode(game) {
            defaults.set(encoded, forKey: Keys.currentGame)
        } else {
            defaults.removeObject(forKey: Keys.currentGame)
        }

        defaults.set(yearlyCompleted,       forKey: Keys.yearlyGoalCompleted)
        defaults.set(yearlyTarget,          forKey: Keys.yearlyGoalTarget)
        defaults.set(totalPlayTimeMinutes,  forKey: Keys.totalPlayTimeMinutes)

        if let encoded = try? JSONEncoder().encode(backlogGames) {
            defaults.set(encoded, forKey: Keys.backlogGames)
        }

        // Ask WidgetKit to refresh all Gameboxd widgets immediately.
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (called from the widget extension)

    /// Returns the game currently being played, or `nil` if none is stored.
    static func getCurrentGame() -> WidgetGame? {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data     = defaults.data(forKey: Keys.currentGame),
            let game     = try? JSONDecoder().decode(WidgetGame.self, from: data)
        else { return nil }
        return game
    }

    /// Returns the user's yearly goal progress as a `(completed, target)` tuple.
    ///
    /// `target` is always at least 1 so callers can safely divide without
    /// guarding against division by zero.
    static func getYearlyGoal() -> (completed: Int, target: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return (0, 12) }
        return (
            defaults.integer(forKey: Keys.yearlyGoalCompleted),
            max(defaults.integer(forKey: Keys.yearlyGoalTarget), 1)
        )
    }

    /// Returns up to 20 backlog games, or an empty array when the backlog is empty.
    static func getBacklogGames() -> [WidgetGame] {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data     = defaults.data(forKey: Keys.backlogGames),
            let games    = try? JSONDecoder().decode([WidgetGame].self, from: data)
        else { return [] }
        return games
    }

    /// Returns the grand total accumulated play time in minutes, or 0 if unavailable.
    static func getTotalPlayTimeMinutes() -> Int {
        UserDefaults(suiteName: suiteName)?.integer(forKey: Keys.totalPlayTimeMinutes) ?? 0
    }
}
