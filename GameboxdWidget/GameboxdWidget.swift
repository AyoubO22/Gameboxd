//
//  GameboxdWidget.swift
//  GameboxdWidget
//
//  WidgetKit extension providing three home-screen widgets for Gameboxd:
//
//  • CurrentGameWidget  (small)  – currently played game + play time
//  • YearlyGoalWidget   (small)  – circular progress toward the yearly goal
//  • BacklogPickWidget  (medium) – a random backlog game, refreshed daily
//
//  IMPORTANT – Xcode setup required before building:
//  1. Add a new "Widget Extension" target named "GameboxdWidget" in Xcode.
//  2. Add SharedDataProvider.swift to the GameboxdWidget target membership.
//  3. Enable the "App Groups" capability (group.personal.Gameboxd) for both
//     the main app target and this widget target.
//  4. Set the minimum deployment target to iOS 17.0+ (uses containerBackground).
//

import WidgetKit
import SwiftUI

// MARK: - Helpers

private func formatPlayTime(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins  = minutes % 60
    return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
}

// MARK: - Current Game Widget

// MARK: Provider

/// Feeds timeline entries for ``CurrentGameWidget``.
struct CurrentGameProvider: TimelineProvider {

    func placeholder(in context: Context) -> CurrentGameEntry {
        CurrentGameEntry(
            date: Date(),
            game: SharedDataProvider.WidgetGame(
                title: "The Witcher 3",
                coverURL: nil,
                platform: "PC",
                playTimeMinutes: 2700,
                status: "En cours"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentGameEntry) -> Void) {
        completion(CurrentGameEntry(date: Date(), game: SharedDataProvider.getCurrentGame()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentGameEntry>) -> Void) {
        let entry    = CurrentGameEntry(date: Date(), game: SharedDataProvider.getCurrentGame())
        // Refresh every 30 minutes — frequent enough to react to mid-session
        // game switches without draining the widget timeline budget.
        let nextDate = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextDate)))
    }
}

// MARK: Entry

struct CurrentGameEntry: TimelineEntry {
    /// The date WidgetKit uses to render this entry.
    let date: Date
    /// The game currently being played, or `nil` when no game is active.
    let game: SharedDataProvider.WidgetGame?
}

// MARK: View

struct CurrentGameWidgetView: View {
    let entry: CurrentGameEntry

    var body: some View {
        if let game = entry.game {
            filledView(game: game)
        } else {
            emptyView
        }
    }

    // MARK: Filled state

    private func filledView(game: SharedDataProvider.WidgetGame) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header badge
            HStack(spacing: 4) {
                Image(systemName: "gamecontroller.fill")
                    .font(.caption2)
                Text("En cours")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            // Game title – allow two lines so long titles remain readable
            Text(game.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            // Play time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(formatPlayTime(game.playTimeMinutes))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)

            // Platform label
            Text(game.platform)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Empty state

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Aucun jeu en cours")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Widget

/// Small widget displaying the game currently being played.
struct CurrentGameWidget: Widget {
    let kind = "CurrentGameWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentGameProvider()) { entry in
            CurrentGameWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Jeu en cours")
        .description("Affiche ton jeu actuel et le temps de jeu.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Yearly Goal Widget

// MARK: Provider

/// Feeds timeline entries for ``YearlyGoalWidget``.
struct YearlyGoalProvider: TimelineProvider {

    func placeholder(in context: Context) -> YearlyGoalEntry {
        YearlyGoalEntry(date: Date(), completed: 8, target: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (YearlyGoalEntry) -> Void) {
        let goal = SharedDataProvider.getYearlyGoal()
        completion(YearlyGoalEntry(date: Date(), completed: goal.completed, target: goal.target))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<YearlyGoalEntry>) -> Void) {
        let goal  = SharedDataProvider.getYearlyGoal()
        let entry = YearlyGoalEntry(date: Date(), completed: goal.completed, target: goal.target)
        // Yearly progress changes infrequently; refresh every hour is ample.
        let nextDate = Date().addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextDate)))
    }
}

// MARK: Entry

struct YearlyGoalEntry: TimelineEntry {
    let date: Date
    let completed: Int
    let target: Int

    /// Clamped [0, 1] progress fraction for the ring stroke.
    var progress: Double { min(Double(completed) / Double(target), 1.0) }
}

// MARK: View

struct YearlyGoalWidgetView: View {
    let entry: YearlyGoalEntry

    var body: some View {
        VStack(spacing: 8) {
            ringView
            Text("Objectif annuel")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Circular ring

    private var ringView: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

            // Progress arc — starts at 12 o'clock
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: entry.progress)

            // Numeric label
            VStack(spacing: 0) {
                Text("\(entry.completed)")
                    .font(.title2.weight(.bold).monospacedDigit())
                Text("/\(entry.target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: Widget

/// Small widget showing circular progress toward the user's yearly completion goal.
struct YearlyGoalWidget: Widget {
    let kind = "YearlyGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: YearlyGoalProvider()) { entry in
            YearlyGoalWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Objectif annuel")
        .description("Suis ta progression vers ton objectif de jeux terminés.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Backlog Pick Widget

// MARK: Provider

/// Feeds timeline entries for ``BacklogPickWidget``.
struct BacklogPickProvider: TimelineProvider {

    func placeholder(in context: Context) -> BacklogPickEntry {
        BacklogPickEntry(
            date: Date(),
            game: SharedDataProvider.WidgetGame(
                title: "Hollow Knight",
                coverURL: nil,
                platform: "Switch",
                playTimeMinutes: 0,
                status: "À jouer"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BacklogPickEntry) -> Void) {
        let games = SharedDataProvider.getBacklogGames()
        completion(BacklogPickEntry(date: Date(), game: games.randomElement()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BacklogPickEntry>) -> Void) {
        let games = SharedDataProvider.getBacklogGames()
        let entry = BacklogPickEntry(date: Date(), game: games.randomElement())
        // Refresh once a day at the next calendar midnight so users see a fresh
        // pick each morning without burning unnecessary timeline budget.
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: Entry

struct BacklogPickEntry: TimelineEntry {
    let date: Date
    /// A randomly chosen backlog game, or `nil` when the backlog is empty.
    let game: SharedDataProvider.WidgetGame?
}

// MARK: View

struct BacklogPickWidgetView: View {
    let entry: BacklogPickEntry

    var body: some View {
        if let game = entry.game {
            filledView(game: game)
        } else {
            emptyView
        }
    }

    // MARK: Filled state

    private func filledView(game: SharedDataProvider.WidgetGame) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header badge
            HStack(spacing: 4) {
                Image(systemName: "dice.fill")
                    .font(.caption2)
                Text("Pick du jour")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            // Game title
            Text(game.title)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Platform
            Text(game.platform)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            // Footer row
            HStack {
                Text("Depuis ton backlog")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Empty state

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Backlog vide")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Widget

/// Medium widget that surfaces a random game from the user's backlog each day.
struct BacklogPickWidget: Widget {
    let kind = "BacklogPickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BacklogPickProvider()) { entry in
            BacklogPickWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pick du backlog")
        .description("Un jeu aléatoire de ton backlog, renouvelé chaque jour.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

/// Entry point for the GameboxdWidget extension.
///
/// All three widgets are declared here so WidgetKit registers them as a bundle
/// under a single extension process.
@main
struct GameboxdWidgets: WidgetBundle {
    var body: some Widget {
        CurrentGameWidget()
        YearlyGoalWidget()
        BacklogPickWidget()
    }
}
