//
//  PlayTimerView.swift
//  Gameboxd
//
//  Floating overlay that surfaces the active play-session timer above all content.
//

import SwiftUI

/// A floating bottom-anchored overlay that displays the active play-session timer.
///
/// The overlay is fully transparent when no session is running, so it can be
/// permanently attached to the root view hierarchy without any conditional
/// wrapping at the call site:
///
/// ```swift
/// ZStack(alignment: .bottom) {
///     MainTabView()
///     PlayTimerOverlay(timerManager: timerManager) {
///         handleSessionStop()
///     }
/// }
/// ```
struct PlayTimerOverlay: View {

    // MARK: - Dependencies

    let timerManager: TimerManager

    /// Called when the user taps the stop button.
    /// The caller is responsible for persisting the returned elapsed minutes.
    let onStop: () -> Void

    // MARK: - Body

    var body: some View {
        if timerManager.isRunning, let game = timerManager.activeGame {
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: DS.Spacing.sm) {
                    gameCoverThumbnail(for: game)

                    sessionInfo(for: game)

                    Spacer()

                    pauseResumeButton

                    stopButton
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(overlayBackground)
                .overlay(overlayBorder)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: timerManager.isRunning)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func gameCoverThumbnail(for game: Game) -> some View {
        if let urlString = game.coverImageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(Color.surfaceSecondary)
            }
            .frame(width: 36, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        }
    }

    private func sessionInfo(for game: Game) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(game.title)
                .font(DS.Typography.captionMedium)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)

            Text(timerManager.formattedTime)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.accent)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.3), value: timerManager.formattedTime)
        }
    }

    private var pauseResumeButton: some View {
        Button {
            if timerManager.isPaused {
                timerManager.resume()
            } else {
                timerManager.pause()
            }
        } label: {
            Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accent)
                .frame(width: 36, height: 36)
                .background(Color.accent.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(DS.Colors.error)
                .frame(width: 36, height: 36)
                .background(DS.Colors.error.opacity(0.15))
                .clipShape(Circle())
        }
    }

    // MARK: - Background Helpers

    private var overlayBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            .fill(Color.surfacePrimary)
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: -4)
    }

    private var overlayBorder: some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            .stroke(Color.separator, lineWidth: 1)
    }
}
