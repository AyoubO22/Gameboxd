//
//  ContentView.swift
//  Gameboxd
//
//  Root view that switches between Auth and Main app
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @Environment(TimerManager.self) private var timerManager
    @State private var showingAchievementToast = false
    @State private var toastAchievement: Achievement?
    @State private var achievementQueue: [Achievement] = []
    @State private var showingUsernameSetup = false
    #if DEBUG
    @State private var debugGame: Game?
    #endif

    var body: some View {
        ZStack {
            Group {
                if store.isLoggedIn {
                    MainTabView()
                } else {
                    AuthView()
                }
            }
            .animation(.easeInOut, value: store.isLoggedIn)

            if store.isLoggedIn {
                PlayTimerOverlay(timerManager: timerManager, onStop: logTimedSession)
                    // ponytail: fixed offset to clear the tab bar; measure it if the tab bar changes
                    .padding(.bottom, 56)
            }

            // Achievement Toast Overlay
            VStack {
                if showingAchievementToast, let achievement = toastAchievement {
                    AchievementToast(achievement: achievement)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .zIndex(100)
                }
                Spacer()
            }
        }
        .onChange(of: store.recentlyUnlockedAchievements) { _, newAchievements in
            if !newAchievements.isEmpty {
                achievementQueue.append(contentsOf: newAchievements)
                store.recentlyUnlockedAchievements.removeAll()
                if !showingAchievementToast {
                    showNextAchievement()
                }
            }
        }
        .onChange(of: store.isLoggedIn) { _, _ in
            checkUsernameSetup()
        }
        // Also on launch: if the app was killed mid-setup, isLoggedIn is already
        // true and onChange never fires.
        .onAppear(perform: checkUsernameSetup)
        .sheet(isPresented: $showingUsernameSetup) {
            UsernameSetupView()
                .environmentObject(store)
        }
        #if DEBUG
        // Launch argument `-debugOpenGame "<title>"`: open that game's page, for simulator screenshots.
        .onAppear {
            if let title = UserDefaults.standard.string(forKey: "debugOpenGame") {
                debugGame = store.myGames.first { $0.title == title }
            }
        }
        .fullScreenCover(item: $debugGame) { game in
            NavigationStack { GameDetailView(game: game) }
        }
        #endif
    }

    /// Stops the live timer and records it as a diary session.
    func logTimedSession() {
        guard let game = timerManager.activeGame else { return }
        let minutes = timerManager.stop()
        store.addPlaySession(PlaySession(
            gameId: game.id,
            gameTitle: game.title,
            gameCoverURL: game.artURL?.absoluteString,
            gameCoverColor: game.coverColor,
            duration: minutes
        ))
        HapticManager.notification(.success)
    }

    func checkUsernameSetup() {
        if store.isLoggedIn && store.userProfile.needsUsernameSetup {
            showingUsernameSetup = true
        }
    }

    func showNextAchievement() {
        guard !achievementQueue.isEmpty else { return }
        let achievement = achievementQueue.removeFirst()
        toastAchievement = achievement
        HapticManager.notification(.success)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingAchievementToast = true
        }

        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.spring()) {
                showingAchievementToast = false
            }
            try? await Task.sleep(for: .milliseconds(500))
            showNextAchievement()
        }
    }
}

// MARK: - Achievement Toast

struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon container — accent tint, no gradient, no colored shadow
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(Color.accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: achievement.category.icon)
                    .font(DS.Typography.title)
                    .foregroundStyle(Color.accent)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "trophy.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accent)

                    Text("Succès débloqué")
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(Color.accent)
                }

                Text(achievement.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(achievement.description)
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(Color.surfacePrimary)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(Color.separator, lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStore())
}
