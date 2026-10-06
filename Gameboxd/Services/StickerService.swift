//
//  StickerService.swift
//  Gameboxd
//
//  Cuts the art for unlocked stickers, lazily (when the game's page asks for it) and once:
//  the PNGs live in Application Support, the records in GameStore.
//

import Foundation

final class StickerService {
    static let shared = StickerService()

    let directory: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gameboxd/Stickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Cut-outs found so far per game, best first, plus how many art sources were already read.
    private var pools: [UUID: (cutouts: [StickerMaker.Cutout], sourcesRead: Int, sources: [URL]?)] = [:]
    private var inProgress: Set<UUID> = []

    func url(for file: String) -> URL { directory.appendingPathComponent(file) }

    /// Cuts art for the game's stickers that have none yet. Returns the file written per
    /// sticker id; stickers left out had no art to cut (no sources, or the simulator).
    ///
    /// ponytail: sticker N gets cut-out N of the pool, so a pool that changes between
    /// launches (IGDB adding art) can repeat an image. Store the cut-out hash on the
    /// sticker if that ever shows.
    func cutMissing(_ stickers: [Sticker], for game: Game) async -> [UUID: String] {
        let missing = stickers.filter { $0.imageFile == nil }
        guard !missing.isEmpty, !inProgress.contains(game.id) else { return [:] }
        inProgress.insert(game.id)
        defer { inProgress.remove(game.id) }

        let alreadyCut = stickers.count - missing.count
        let pool = await pool(for: game, needed: stickers.count)
        var files: [UUID: String] = [:]
        for (offset, sticker) in missing.enumerated() where alreadyCut + offset < pool.count {
            let file = "\(sticker.id.uuidString).png"
            guard (try? pool[alreadyCut + offset].png.write(to: url(for: file), options: .atomic)) != nil else { continue }
            files[sticker.id] = file
        }
        return files
    }

    func remove(_ stickers: [Sticker]) {
        for file in stickers.compactMap(\.imageFile) { try? FileManager.default.removeItem(at: url(for: file)) }
    }

    /// Reads art sources until there are `needed` distinct cut-outs or no sources left.
    /// Character portraits and artworks (IGDB) first, then the game's screenshots.
    private func pool(for game: Game, needed: Int) async -> [StickerMaker.Cutout] {
        var entry = pools[game.id] ?? ([], 0, nil)
        if entry.sources == nil {
            let art = (try? await IGDBService.shared.stickerArtURLs(title: game.title, year: game.releaseYear)) ?? []
            entry.sources = art + game.screenshotURLs.compactMap(URL.init(string:))
        }
        let sources = entry.sources ?? []
        while entry.cutouts.count < needed, entry.sourcesRead < sources.count {
            let source = sources[entry.sourcesRead]
            entry.sourcesRead += 1
            guard let (data, response) = try? await URLSession.shared.data(from: source),
                  (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            let cutouts = await Task.detached(priority: .utility) { StickerMaker.cutouts(from: data) }.value
            for cutout in cutouts where !entry.cutouts.contains(where: cutout.isDuplicate) {
                entry.cutouts.append(cutout)
            }
        }
        pools[game.id] = entry
        return entry.cutouts
    }
}
