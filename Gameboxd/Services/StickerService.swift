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
    /// Feature prints of the sources already cut, per game: IGDB often lists one key art
    /// several times (cropped, with or without the logo).
    private var usedSources: [UUID: [StickerMaker.Print]] = [:]
    private var inProgress: Set<UUID> = []

    func url(for file: String) -> URL { directory.appendingPathComponent(file) }

    /// Cuts art for the game's stickers that have none yet. Returns the file written per
    /// sticker id, or "" once every source has been read and nothing is left for it.
    ///
    /// ponytail: sticker N gets cut-out N of the pool, so a pool that changes between
    /// launches (IGDB adding art) can repeat an image. Store the cut-out hash on the
    /// sticker if that ever shows.
    func cutMissing(_ stickers: [Sticker], for game: Game) async -> [UUID: String] {
        let missing = stickers.filter { $0.imageFile == nil }
        guard !missing.isEmpty, !inProgress.contains(game.id) else { return [:] }
        inProgress.insert(game.id)
        defer { inProgress.remove(game.id) }

        let alreadyCut = stickers.filter(\.hasArt).count
        let (pool, exhausted) = await pool(for: game, needed: stickers.count)
        var files: [UUID: String] = [:]
        for (offset, sticker) in missing.enumerated() {
            guard alreadyCut + offset < pool.count else {
                if exhausted { files[sticker.id] = "" }
                continue
            }
            let file = "\(sticker.id.uuidString).png"
            guard (try? pool[alreadyCut + offset].png.write(to: url(for: file), options: .atomic)) != nil else { continue }
            files[sticker.id] = file
        }
        return files
    }

    func remove(_ stickers: [Sticker]) {
        // Only real files: an empty name would resolve to the stickers folder itself.
        for file in stickers.compactMap(\.imageFile) where !file.isEmpty {
            try? FileManager.default.removeItem(at: url(for: file))
        }
    }

    /// Reads art sources until there are `needed` distinct cut-outs or no sources left.
    /// Character portraits and artworks (IGDB) first, then the game's screenshots.
    private func pool(for game: Game, needed: Int) async -> (cutouts: [StickerMaker.Cutout], exhausted: Bool) {
        var entry = pools[game.id] ?? ([], 0, nil)
        if entry.sources == nil {
            // A network or auth failure leaves `sources` nil, so the next visit retries
            // instead of declaring the game out of art.
            guard let art = try? await IGDBService.shared.stickerArtURLs(title: game.title, year: game.releaseYear) else {
                return (entry.cutouts, false)
            }
            entry.sources = art + game.screenshotURLs.compactMap(URL.init(string:))
        }
        let sources = entry.sources ?? []
        while entry.cutouts.count < needed, entry.sourcesRead < sources.count {
            // Offline: stop here and retry this source next time, rather than skip it.
            guard let (data, response) = try? await URLSession.shared.data(from: sources[entry.sourcesRead]) else { break }
            entry.sourcesRead += 1
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            let print = await Task.detached(priority: .utility) { StickerMaker.print(of: data) }.value
            if let print {
                // Skipped sources are remembered too: variants chain (A ≈ B ≈ C) even when
                // C is a little further from A than the threshold.
                let isRepeat = usedSources[game.id, default: []].contains { $0.distance(to: print) < StickerMaker.sameSourceDistance }
                usedSources[game.id, default: []].append(print)
                if isRepeat { continue }
            }
            let cutouts = await Task.detached(priority: .utility) { StickerMaker.cutouts(from: data) }.value
            for cutout in cutouts where !entry.cutouts.contains(where: cutout.isDuplicate) {
                entry.cutouts.append(cutout)
            }
        }
        pools[game.id] = entry
        return (entry.cutouts, entry.sourcesRead >= sources.count)
    }
}
