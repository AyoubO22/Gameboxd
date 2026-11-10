//
//  GameStore+Widget.swift
//  Gameboxd
//
//  What the home-screen widgets show.
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - Widget Sync

    func makeWidgetGame(from game: Game) -> SharedDataProvider.WidgetGame {
        SharedDataProvider.WidgetGame(
            title: game.title,
            coverURL: game.artURL?.absoluteString,
            platform: game.platform,
            playTimeMinutes: game.playTimeMinutes,
            status: game.status.rawValue
        )
    }

    /// Pushes the latest widget-relevant snapshot into the shared App Group store
    /// and asks WidgetKit to reload its timelines.
    ///
    /// Note: the GameboxdWidget extension is not a build target yet and there is no
    /// App Group entitlement, so today this writes to an app-local suite that no
    /// widget reads. It starts working once the target + App Group are added.
    func syncWidgetData() {
        let currentWidgetGame = myGames.first { $0.status == .playing }.map(makeWidgetGame)
        let backlogWidgetGames = backlog.prefix(20).map(makeWidgetGame)

        SharedDataProvider.updateWidgetData(
            currentGame: currentWidgetGame,
            yearlyCompleted: completedThisYear,
            yearlyTarget: max(userProfile.yearlyGoal, 1),
            backlogGames: Array(backlogWidgetGames),
            totalPlayTimeMinutes: totalPlayTimeMinutes
        )
    }
}
