//
//  LibrarySync.swift
//  Gameboxd
//
//  Mirrors your collection to Supabase (`library_games`) so friends can browse it, and
//  reads theirs. The phone stays the source of truth: the mirror is rebuilt from it.
//

import Foundation
import Supabase

/// A game in someone's public collection.
nonisolated struct RemoteLibraryGame: Codable, Identifiable, Equatable {
    let userId: UUID
    let gameId: UUID
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
        rawgId = game.rawgId
        title = String(game.title.prefix(200))
        platform = game.platform.isEmpty ? nil : String(game.platform.prefix(60))
        releaseYear = game.releaseYear.isEmpty ? nil : String(game.releaseYear.prefix(10))
        coverURL = game.artURL?.absoluteString
        genres = game.genres
        status = Self.key(for: game.status)
        rating = min(max(game.rating, 0), 5)
        let text = game.review.trimmingCharacters(in: .whitespacesAndNewlines)
        review = text.isEmpty ? nil : String(text.prefix(10_000))
        isSpoiler = game.isSpoiler
        playMinutes = max(game.playTimeMinutes, 0)
        completion = min(max(game.completionPercentage, 0), 100)
        isFavorite = game.isFavorite
        completedAt = game.completedDate
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
        guard SocialService.shared.isSharing, let client = account.client, let me = account.profile?.id else { return }
        let current = Dictionary(games.map { ($0.id, RemoteLibraryGame(owner: me, game: $0)) }, uniquingKeysWith: { a, _ in a })
        do {
            if !hasFullState {
                // First push of the session: learn what's online, so deletions made while
                // offline (or on an older version) are caught too.
                let online: [RemoteLibraryGame] = try await client.from("library_games").select().eq("user_id", value: me).execute().value
                lastSent = Dictionary(online.map { ($0.gameId, $0) }, uniquingKeysWith: { a, _ in a })
                hasFullState = true
            }
            let changed = current.values.filter { lastSent[$0.gameId] != $0 }
            let removed = lastSent.keys.filter { current[$0] == nil }
            for batch in stride(from: 0, to: changed.count, by: 200).map({ Array(changed[$0..<min($0 + 200, changed.count)]) }) {
                try await client.from("library_games").upsert(batch, onConflict: "user_id,game_id").execute()
            }
            if !removed.isEmpty {
                try await client.from("library_games").delete()
                    .eq("user_id", value: me)
                    .in("game_id", values: removed.map(\.uuidString))
                    .execute()
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
        guard let client = account.client, let me = account.profile?.id else { return }
        _ = try? await client.from("library_games").delete().eq("user_id", value: me).execute().status
        lastSent = [:]
        hasFullState = true
    }

    /// Forget what was sent (sign-out): the next account starts from what's online.
    func reset() {
        pending?.cancel()
        lastSent = [:]
        hasFullState = false
    }

    /// Someone's public collection, most recently finished first.
    func library(of user: UUID) async throws -> [RemoteLibraryGame] {
        guard let client = account.client else { return [] }
        return try await client.from("library_games")
            .select()
            .eq("user_id", value: user)
            .order("updated_at", ascending: false)
            .execute().value
    }
}
