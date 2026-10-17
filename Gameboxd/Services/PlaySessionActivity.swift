//
//  PlaySessionActivity.swift
//  Gameboxd
//
//  Live Activity shared between the app and the widget extension: the play-session
//  timer shown on the Lock Screen and in the Dynamic Island.
//
//  IMPORTANT – Xcode target membership:
//  This file belongs to BOTH the "Gameboxd" target and the "GameboxdWidgetExtension"
//  target (see the membership exceptions in project.pbxproj), so the widget can render
//  the attributes and its pause button can reference the intent.
//

#if os(iOS)
import ActivityKit
import AppIntents
import Foundation

/// Static data for a play session, plus its changing timer state.
/// `nonisolated` because the app target defaults to MainActor isolation, and
/// ActivityKit needs these to be plain Sendable/Codable values.
nonisolated struct PlaySessionAttributes: ActivityAttributes {

    nonisolated struct ContentState: Codable, Hashable {
        /// When the session would have started had it never been paused, so the
        /// system can count up on its own (`Text(timerInterval:)`) while running.
        var startDate: Date
        /// Seconds elapsed at the moment of pausing; `nil` while running.
        var pausedElapsed: Int?

        var isPaused: Bool { pausedElapsed != nil }
    }

    let gameTitle: String
    let platform: String
    /// Hex of the game's cover color, used to tint the activity.
    let coverColorHex: String
}

/// Hook the app installs so the Live Activity's pause button can reach the timer.
///
/// `LiveActivityIntent`s run in the app's process, but this file is also compiled
/// into the widget extension, which knows nothing about `TimerManager`. The app
/// registers its handler here; in the widget it simply stays `nil`.
enum PlaySessionControl {
    @MainActor static var togglePause: (() -> Void)?
}

/// Pauses or resumes the running session from the Lock Screen / Dynamic Island.
nonisolated struct TogglePlaySessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mettre en pause ou reprendre le chrono"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { PlaySessionControl.togglePause?() }
        return .result()
    }
}
#endif
