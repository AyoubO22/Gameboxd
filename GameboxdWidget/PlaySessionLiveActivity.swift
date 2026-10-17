//
//  PlaySessionLiveActivity.swift
//  GameboxdWidget
//
//  The play-session timer on the Lock Screen and in the Dynamic Island.
//  The app starts, updates and ends the activity (see TimerManager); the
//  timer text counts on its own from `startDate`, so no updates are needed
//  while the session runs.
//

#if os(iOS)
import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct PlaySessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaySessionAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let tint = Color(sessionHex: context.attributes.coverColorHex)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                        .foregroundStyle(tint)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PauseButton(isPaused: context.state.isPaused, tint: tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.gameTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.platform)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionTimeText(state: context.state)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .foregroundStyle(context.state.isPaused ? .secondary : .primary)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "gamecontroller.fill")
                    .foregroundStyle(tint)
            } compactTrailing: {
                SessionTimeText(state: context.state)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .frame(maxWidth: 56)
                    .foregroundStyle(context.state.isPaused ? .secondary : tint)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "gamecontroller.fill")
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<PlaySessionAttributes>

    var body: some View {
        let tint = Color(sessionHex: context.attributes.coverColorHex)
        HStack(spacing: 14) {
            Image(systemName: "gamecontroller.fill")
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.gameTitle)
                    .font(.headline)
                    .lineLimit(1)
                SessionTimeText(state: context.state)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(context.state.isPaused ? .secondary : .primary)
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            PauseButton(isPaused: context.state.isPaused, tint: tint)
        }
        .padding(16)
    }
}

// MARK: - Pieces

/// Counts up by itself while running; frozen at the paused value otherwise.
private struct SessionTimeText: View {
    let state: PlaySessionAttributes.ContentState

    var body: some View {
        Group {
            if let paused = state.pausedElapsed {
                Text(Self.format(paused))
            } else {
                Text(timerInterval: state.startDate...Date.distantFuture, countsDown: false)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.center)
    }

    private static func format(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

private struct PauseButton: View {
    let isPaused: Bool
    let tint: Color

    var body: some View {
        Button(intent: TogglePlaySessionIntent()) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(tint.opacity(0.35), in: Circle())
        .accessibilityLabel(isPaused ? "Reprendre le chrono" : "Mettre le chrono en pause")
    }
}

private extension Color {
    /// Parses the `RRGGBB` hex the app stores for cover colors (falls back to gray).
    init(sessionHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt64(cleaned.prefix(6), radix: 16) ?? 0x808080
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
#endif
