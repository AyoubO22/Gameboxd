//
//  LibrarySync.swift
//  Gameboxd
//
//  Mirrors your collection to the server (`library_games`) so friends can browse it, and
//  reads theirs. The phone stays the source of truth: the mirror is rebuilt from it.
//

import Foundation
import SwiftUI

/// A game in someone's public collection.
nonisolated struct RemoteLibraryGame: Codable, Identifiable, Equatable {
    let userId: UUID
    let gameId: UUID
    /// 0 when the game has no RAWG id (the server stores no "missing" number).
    var rawgId: Int?
    var title: String
    var platform: String?
    var releaseYear: String?
    var coverURL: String?
    var genres: [String]
    var status: String
    var rating: Int
    var review: String?
    var isSpoiler: Bool
    var playMinutes: Int
    var completion: Int
    var isFavorite: Bool
    var completedAt: Date?

    var id: UUID { gameId }

    /// Back to a game of the collection (restoring a phone from the online copy).
    @MainActor var asGame: Game {
        var game = Game(id: gameId, title: title, developer: "", platform: platform ?? "", releaseYear: releaseYear ?? "",
                        coverImageURL: coverURL, coverColor: .gray, rating: rating, status: gameStatus,
                        review: review ?? "", isSpoiler: isSpoiler, playTimeMinutes: playMinutes,
                        completionPercentage: completion, isFavorite: isFavorite, completedDate: completedAt,
                        rawgId: rawgId == 0 ? nil : rawgId, genres: genres)
        game.boxArtURL = coverURL
        return game
    }

    /// Same bounds as the database check: at most 30 labels, 1000 characters in all.
    static func boundedGenres(_ genres: [String]) -> [String] {
        var kept: [String] = []
        var length = 0
        for genre in genres.prefix(30) {
            let added = genre.count + (kept.isEmpty ? 0 : 1)
            guard length + added <= 1000 else { break }
            kept.append(genre)
            length += added
        }
        return kept
    }

    /// Stable keys online; the app's own raw values are French labels.
    static func key(for status: GameStatus) -> String {
        switch status {
        case .none: "none"
        case .wantToPlay: "wantToPlay"
        case .playing: "playing"
        case .completed: "completed"
        case .shelved: "shelved"
        case .platinum: "platinum"
        }
    }

    var gameStatus: GameStatus {
        GameStatus.allCases.first { Self.key(for: $0) == status } ?? .none
    }

    @MainActor init(owner: UUID, game: Game) {
        userId = owner
        gameId = game.id
        rawgId = game.rawgId ?? 0
        title = String(game.title.prefix(200))
        platform = game.platform.isEmpty ? nil : String(game.platform.prefix(60))
        releaseYear = game.releaseYear.isEmpty ? nil : String(game.releaseYear.prefix(10))
        coverURL = RemoteImage.shareable(game.artURL?.absoluteString)
        genres = Self.boundedGenres(game.genres)
        status = Self.key(for: game.status)
        rating = min(max(game.rating, 0), 5)
        let text = game.review.trimmingCharacters(in: .whitespacesAndNewlines)
        review = text.isEmpty ? nil : String(text.prefix(10_000))
        isSpoiler = game.isSpoiler
        playMinutes = max(game.playTimeMinutes, 0)
        completion = min(max(game.completionPercentage, 0), 100)
        isFavorite = game.isFavorite
        // Whole seconds, as the server keeps them, so an unchanged game compares equal.
        completedAt = game.completedDate.map { Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded(.down)) }
    }

    enum CodingKeys: String, CodingKey {
        case title, platform, genres, status, rating, review, completion
        case userId = "user_id"
        case gameId = "game_id"
        case rawgId = "rawg_id"
        case releaseYear = "release_year"
        case coverURL = "cover_url"
        case isSpoiler = "is_spoiler"
        case playMinutes = "play_minutes"
        case isFavorite = "is_favorite"
        case completedAt = "completed_at"
    }
}

@MainActor
final class LibrarySync {
    static let shared = LibrarySync()

    private let account = AccountService.shared
    private let backend = Backend.shared

    /// What POST /api/gameboxd/library accepts (server/pb_hooks).
    private nonisolated struct LibraryChange: Encodable {
        var upsert: [RemoteLibraryGame] = []
        var remove: [String] = []
        var removeAll = false
    }
    /// The collection to mirror, set by GameStore at launch.
    weak var store: GameStore?

    func pushCurrent() async {
        if let store { await push(store.myGames) }
    }
    private var pending: Task<Void, Never>?
    /// What was last sent, to upload only what changed.
    private var lastSent: [UUID: RemoteLibraryGame] = [:]
    private var hasFullState = false

    /// Called after every save of the collection. Waits for a pause (2 s) so a burst of
    /// edits makes one upload.
    func schedule(_ games: [Game]) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await push(games)
        }
    }

    /// Sends the collection: upserts new or changed games, deletes the ones removed.
    /// Silent when signed out, private, or offline: it retries on the next change.
    func push(_ games: [Game]) async {
        guard SocialService.shared.isSharing, account.isSignedIn, let me = account.profile?.id else { return }
        let current = Dictionary(games.map { ($0.id, RemoteLibraryGame(owner: me, game: $0)) }, uniquingKeysWith: { a, _ in a })
        do {
            if !hasFullState {
                // First push of the session: learn what's online, so deletions made while
                // offline (or on an older version) are caught too.
                let online = try await library(of: me)
                lastSent = Dictionary(online.map { ($0.gameId, $0) }, uniquingKeysWith: { a, _ in a })
                hasFullState = true
            }
            let changed = current.values.filter { lastSent[$0.gameId] != $0 }
            // An empty phone never wipes the online copy: that's a new phone or a fresh
            // account space, and the copy is what restores it (see `restore`).
            let removed = current.isEmpty ? [] : lastSent.keys.filter { current[$0] == nil }
            for batch in stride(from: 0, to: changed.count, by: 200).map({ Array(changed[$0..<min($0 + 200, changed.count)]) }) {
                try await backend.send("POST", "/api/gameboxd/library", body: LibraryChange(upsert: batch))
            }
            if !removed.isEmpty {
                try await backend.send("POST", "/api/gameboxd/library", body: LibraryChange(remove: removed.map(\.serverId)))
            }
            lastSent = current
        } catch {
            #if DEBUG
            print("LibrarySync: push failed: \(error)")
            #endif
        }
    }

    /// Takes your collection offline (profile made private, or account deleted).
    func removeAll() async {
        guard account.isSignedIn else { return }
        try? await backend.send("POST", "/api/gameboxd/library", body: LibraryChange(removeAll: true))
        lastSent = [:]
        hasFullState = true
    }

    /// Forget what was sent (sign-out): the next account starts from what's online.
    func reset() {
        pending?.cancel()
        lastSent = [:]
        hasFullState = false
    }

    /// Brings the account's online collection back to an empty phone.
    func restore(into store: GameStore) async {
        guard store.myGames.isEmpty, let me = account.profile?.id,
              let online = try? await library(of: me), !online.isEmpty else { return }
        store.restoreFromCloud(online.map(\.asGame))
    }

    /// Someone's public collection, most recently finished first.
    func library(of user: UUID) async throws -> [RemoteLibraryGame] {
        guard account.isSignedIn else { return [] }
        return try await backend.list("library_games", filter: "user_id = \(Backend.quoted(user.serverId))",
                                      sort: "-updated_at", limit: 10_000) // the server's per-player quota
    }
}
