//
//  SteamViews.swift
//  Gameboxd
//
//  What a linked Steam account adds to the screens: sessions to log in the diary and a
//  game's achievements on its page.
//

import SwiftUI

// MARK: - Diary: sessions Steam saw

struct SteamSuggestionsBanner: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if !store.steamSuggestions.isEmpty {
            VStack(spacing: DS.Spacing.xs) {
                ForEach(store.steamSuggestions) { suggestion in
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(Color.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Tu as joué \(Self.duration(suggestion.minutes)) à \(suggestion.gameTitle)")
                                .font(DS.Typography.bodyMedium)
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)
                            Text("Vu sur Steam · \(suggestion.date.formatted(.relative(presentation: .named)))")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        Spacer(minLength: 0)
                        Button("Ignorer") { withAnimation { store.dismissSteamSuggestion(suggestion) } }
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(Color.textSecondary)
                        Button("Ajouter") { withAnimation { store.acceptSteamSuggestion(suggestion) } }
                            .font(DS.Typography.captionMedium)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.accent, in: Capsule())
                            .foregroundStyle(Color.gbDark)
                    }
                    .buttonStyle(.plain)
                    .padding(DS.Spacing.sm)
                    .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, DS.Spacing.xs)
        }
    }

    static func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m)"
    }
}

// MARK: - Game page: Steam achievements

struct SteamAchievementsSection: View {
    let game: Game
    @Environment(GameStore.self) private var store
    @State private var progress: (unlocked: Int, total: Int)?
    @State private var rarest: [SteamAchievementInfo] = []

    var body: some View {
        Group {
            if let progress {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DetailSectionTitle(title: "Succès Steam", trailing: "\(progress.unlocked) / \(progress.total)")
                    ProgressView(value: Double(progress.unlocked), total: Double(max(progress.total, 1)))
                        .tint(.accent)
                    if !rarest.isEmpty {
                        Text("Tes plus rares")
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(Color.textSecondary)
                        ForEach(rarest) { achievement in
                            HStack(spacing: DS.Spacing.sm) {
                                CachedAsyncImage(url: achievement.iconURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Color.surfaceSecondary }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(achievement.name)
                                        .font(DS.Typography.bodyMedium)
                                        .foregroundStyle(Color.textPrimary)
                                    if let percent = achievement.globalPercent {
                                        Text("\(percent.formatted(.number.precision(.fractionLength(0...1)))) % des joueurs l'ont")
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(percent < 10 ? DS.Colors.warning : Color.textTertiary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .task(id: game.id) { await load() }
    }

    private func load() async {
        guard let appId = game.steamAppId, let steamId = SteamSync.shared.steamId(in: store),
              let result = await SteamService.shared.playerAchievements(steamId: steamId, appId: appId) else { return }
        progress = (result.unlocked.count, result.total)
        guard !result.unlocked.isEmpty else { return }
        let info = await SteamService.shared.achievementInfo(appId: appId)
        rarest = result.unlocked
            .map { key, date in
                SteamAchievementInfo(id: key, name: info[key]?.name ?? key, iconURL: info[key]?.icon,
                                     globalPercent: info[key]?.percent, unlockedAt: date)
            }
            .sorted { ($0.globalPercent ?? 100) < ($1.globalPercent ?? 100) }
            .prefix(3)
            .map { $0 }
    }
}
