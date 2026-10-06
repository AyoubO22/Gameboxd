//
//  StickerAlbumView.swift
//  Gameboxd
//
//  Every unlocked sticker, game by game, plus the profile's preview of the latest ones.
//

import SwiftUI

/// Games that have stickers, most recently unlocked first, with what to show for each.
private func albumEntries(_ store: GameStore) -> [(game: Game, stickers: [Sticker])] {
    store.myGames
        .map { (game: $0, stickers: store.displayedStickers(for: $0)) }
        .filter { !$0.stickers.isEmpty }
        .sorted { ($0.stickers.map(\.unlockedAt).max() ?? .distantPast) > ($1.stickers.map(\.unlockedAt).max() ?? .distantPast) }
}

// MARK: - Profile preview

struct StickerAlbumSection: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let entries = albumEntries(store)
        let latest = entries
            .flatMap { entry in entry.stickers.map { (game: entry.game, sticker: $0) } }
            .sorted { $0.sticker.unlockedAt > $1.sticker.unlockedAt }
            .prefix(8)
        let total = entries.reduce(0) { $0 + $1.stickers.count }

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            NavigationLink(destination: StickerAlbumView()) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Autocollants")
                        .font(DS.Typography.title)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if total > 0 {
                        Text("Voir les \(total)")
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(Color.accent)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(total == 0)

            if latest.isEmpty {
                Text("Joue, note ou termine un jeu pour débloquer tes premiers autocollants.")
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(Array(latest), id: \.sticker.id) { item in
                            StickerView(sticker: item.sticker, game: item.game, height: 96)
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)
                    .padding(.horizontal)
                }
                .padding(.horizontal, -DS.Spacing.md)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Album

struct StickerAlbumView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let entries = albumEntries(store)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text("Touche un autocollant pour le copier, puis colle-le dans Messages.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)

                ForEach(entries, id: \.game.id) { entry in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        NavigationLink(destination: GameDetailView(game: entry.game)) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.game.title)
                                    .font(DS.Typography.title3)
                                    .foregroundStyle(Color.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.stickers.count)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: DS.Spacing.md)], spacing: DS.Spacing.lg) {
                            ForEach(entry.stickers) { sticker in
                                StickerView(sticker: sticker, game: entry.game, height: 100)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Autocollants")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Games never opened since their unlock have no art yet: cut it, one game at a time.
            for entry in entries where store.stickers(for: entry.game).contains(where: { $0.imageFile == nil }) {
                await store.cutStickers(for: entry.game)
            }
        }
    }
}
