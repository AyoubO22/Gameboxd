//
//  PlayTimerView.swift
//  Gameboxd
//
//  The active play-session timer: docked in the tab bar accessory on iOS 26.1+,
//  as a floating card on iOS 26.0.
//

import SwiftUI

/// A floating bottom-anchored card that displays the active play-session timer.
/// Used on iOS 26.0 only; `MainTabView` docks `SessionAccessory` in the tab bar on 26.1+.
///
/// The overlay is fully transparent when no session is running, so it can be
/// permanently attached without any conditional wrapping at the call site.
struct PlayTimerOverlay: View {

    // MARK: - Dependencies

    @Environment(TimerManager.self) private var timerManager

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
        if let url = game.artURL {
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
                .font(DS.Typography.display(24, weight: .heavy, relativeTo: .title3).monospacedDigit())
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
        .accessibilityLabel(timerManager.isPaused ? "Reprendre le chrono" : "Mettre le chrono en pause")
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
        .accessibilityLabel("Arrêter et enregistrer la session")
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

// MARK: - Tab Bar Accessory

/// The timer as a tab bar accessory (iOS 26.1+). The system draws the glass capsule,
/// so this view has no background of its own. Expanded above the bar it shows the
/// cover, title and time; folded into a minimized bar it keeps the time and controls.
@available(iOS 26.1, *)
struct SessionAccessory: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let onStop: () -> Void

    var body: some View {
        if let game = timerManager.activeGame {
            // One view tree for both placements: inserting and removing the cover and title
            // while the bar morphs on scroll made the accessory jump and reload its cover.
            // Folded, the title just fades and gives up its width.
            HStack(spacing: DS.Spacing.sm) {
                cover(for: game)

                Text(game.title)
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .opacity(placement == .inline ? 0 : 1)
                    .accessibilityHidden(placement == .inline)

                Text(timerManager.formattedTime)
                    .font(DS.Typography.headline.monospacedDigit())
                    .fixedSize()
                    .layoutPriority(1)
                    .foregroundStyle(Color.accent)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: timerManager.formattedTime)

                Button {
                    if timerManager.isPaused {
                        timerManager.resume()
                    } else {
                        timerManager.pause()
                    }
                } label: {
                    Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(timerManager.isPaused ? "Reprendre le chrono" : "Mettre le chrono en pause")

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundStyle(DS.Colors.error)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Arrêter et enregistrer la session")
            }
            .font(.body.weight(.semibold))
            .padding(.horizontal, DS.Spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Session en cours : \(game.title)")
        }
    }

    @ViewBuilder
    private func cover(for game: Game) -> some View {
        Group {
            if let url = game.artURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(game.coverColor.gradient)
                }
            } else {
                Rectangle().fill(game.coverColor.gradient)
            }
        }
        .frame(width: 24, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
