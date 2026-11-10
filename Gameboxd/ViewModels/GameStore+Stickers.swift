//
//  GameStore+Stickers.swift
//  Gameboxd
//
//  Stickers: unlocked per game, and their art cut from the cover.
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - Stickers

    func stickers(for game: Game) -> [Sticker] {
        stickers.filter { $0.gameId == game.id }.sorted { $0.reason < $1.reason }
    }

    /// What to show for a game: the stickers whose art is cut. Until the first one is (or
    /// when the game has no art at all, e.g. on the simulator) a single sticker stands in
    /// with the cover, so an unlocked game never looks empty and never shows a row of
    /// identical covers. The rest appear as their art gets cut.
    func displayedStickers(for game: Game) -> [Sticker] {
        let all = stickers(for: game)
        let withArt = all.filter(\.hasArt)
        return withArt.isEmpty ? Array(all.prefix(1)) : withArt
    }

    /// Adds a sticker for every reason a game has newly earned. Earned stickers are kept
    /// even if the reason goes away (a rating cleared): they're collectibles.
    func syncStickers() {
        var owned = Dictionary(grouping: stickers, by: \.gameId).mapValues { Set($0.map(\.reason)) }
        var added = false
        for game in myGames {
            for reason in StickerRules.earned(by: game).subtracting(owned[game.id, default: []]).sorted() {
                stickers.append(Sticker(gameId: game.id, reason: reason))
                owned[game.id, default: []].insert(reason)
                added = true
            }
        }
        if added { fileStore.save(stickers, key: StorageKeys.stickers) }
    }

    /// Cuts the art of this game's stickers that don't have any yet (called by its page).
    func cutStickers(for game: Game) async {
        let files = await StickerService.shared.cutMissing(stickers(for: game), for: game)
        guard !files.isEmpty else { return }
        for i in stickers.indices {
            if let file = files[stickers[i].id] { stickers[i].imageFile = file }
        }
        fileStore.save(stickers, key: StorageKeys.stickers)
    }
}
