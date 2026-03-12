//
//  ContentView.swift
//  Gameboxd
//
//  Root view that switches between Auth and Main app
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingAchievementToast = false
    @State private var toastAchievement: Achievement?
    @State private var achievementQueue: [Achievement] = []
    @State private var showingUsernameSetup = false

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
        .onChange(of: store.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn && store.userProfile.needsUsernameSetup {
                showingUsernameSetup = true
            }
        }
        .sheet(isPresented: $showingUsernameSetup) {
            UsernameSetupView()
                .environmentObject(store)
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

                Image(systemName: achievement.icon)
                    .font(.body.weight(.semibold))
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
