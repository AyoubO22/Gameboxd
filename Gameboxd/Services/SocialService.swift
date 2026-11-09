//
//  SocialService.swift
//  Gameboxd
//
//  Following players and seeing what they play (server collections `follows` and
//  `activities`, see server/pb_migrations). Needs an account; without one it stays idle.
//

import Foundation

/// One shared moment: a session, a finished game, a rating, a review.
nonisolated struct RemoteActivity: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case played, completed, platinum, rated, reviewed, added

        var verb: String {
            switch self {
            case .played: "a joué à"
            case .completed: "a terminé"
            case .platinum: "a platiné"
            case .rated: "a noté"
            case .reviewed: "a critiqué"
            case .added: "a ajouté"
            }
        }
    }

    /// The author, embedded by the query (`expand=user_id`).
    struct Author: Codable, Equatable {
        let username: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case username
            case displayName = "display_name"
        }
    }

    let id: UUID
    let userId: UUID
    let kind: Kind
    let gameTitle: String
    let gameCoverURL: String?
    let rating: Int?
    let review: String?
    let minutes: Int?
    let createdAt: Date
    private let expand: Expand?
    var author: Author? { expand?.user }

    struct Expand: Codable, Equatable {
        let user: Author?
        enum CodingKeys: String, CodingKey { case user = "user_id" }
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, rating, review, minutes
        case userId = "user_id"
        case gameTitle = "game_title"
        case gameCoverURL = "game_cover_url"
        case expand
        case createdAt = "created_at"
    }
}

/// What the app sends when something worth sharing happens.
nonisolated private struct NewActivity: Encodable {
    let user_id: String
    let kind: String
    let game_title: String
    let game_cover_url: String?
    let rating: Int?
    let review: String?
    let minutes: Int?
}

nonisolated private struct SteamLinkResponse: Decodable {
    let url: URL
}

nonisolated private struct Follow: Codable {
    var id: String?
    let follower_id: UUID
    let followee_id: UUID
}

nonisolated private struct NewFollow: Encodable {
    let follower_id: String
    let followee_id: String
}

@MainActor
@Observable
final class SocialService {
    static let shared = SocialService()

    /// Ids of the players you follow.
    private(set) var following: Set<UUID> = []

    /// Public profile (Réglages): your collection and activity are visible to other players.
    /// On by default. Stored in `profiles.is_public`, so the server enforces it: while it's
    /// off, nobody else can read your collection or activity.
    var isSharing: Bool {
        get {
            if hasLegacyPrivateChoice { return false }
            return account.profile?.isPublic ?? true
        }
        set {
            guard newValue != isSharing, account.isSignedIn else { return }
            Task { await setSharing(newValue) }
        }
    }

    /// Before this setting lived on the account, "private" was one switch for the whole
    /// phone, without knowing which account turned it off. Every account on this phone
    /// stays private until it has carried that choice over (or turned sharing back on).
    private static let legacySharingKey = "gameboxd_share_activity"
    private static let legacyCarriedOverKey = "gameboxd_share_activity_carried_over"

    private var hasLegacyPrivateChoice: Bool {
        guard UserDefaults.standard.object(forKey: Self.legacySharingKey) as? Bool == false,
              let myId else { return false }
        let done = UserDefaults.standard.stringArray(forKey: Self.legacyCarriedOverKey) ?? []
        return !done.contains(myId.uuidString)
    }

    private func setSharing(_ value: Bool) async {
        guard let id = myId else { return }
        do {
            try await account.setPublic(value)
        } catch {
            return // setPublic already put the switch back
        }
        var done = UserDefaults.standard.stringArray(forKey: Self.legacyCarriedOverKey) ?? []
        if !done.contains(id.uuidString) {
            done.append(id.uuidString)
            UserDefaults.standard.set(done, forKey: Self.legacyCarriedOverKey)
        }
        if value { await LibrarySync.shared.pushCurrent() } else { await LibrarySync.shared.removeAll() }
    }

    /// Carries the old phone-wide "private" choice over to the signed-in account. Run at
    /// launch and after sign-in, before the collection is pushed.
    func migrateLegacySharing() async {
        guard hasLegacyPrivateChoice else { return }
        await setSharing(false)
    }

    private let account = AccountService.shared
    private let backend = Backend.shared

    /// The signed-in player's id; nil (so everything stays idle) when signed out.
    private var myId: UUID? { account.isSignedIn ? account.profile?.id : nil }

    // MARK: - Players

    /// Players whose pseudo contains `query`, yourself excluded.
    func searchPlayers(_ query: String) async throws -> [RemoteProfile] {
        // Pseudos are [a-z0-9_]: anything else can't match, and stays out of the filter.
        let text = query.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
        guard myId != nil, text.count >= 2 else { return [] }
        let players: [RemoteProfile] = try await backend.list("users", filter: "username ~ \(Backend.quoted(text))",
                                                              sort: "username", limit: 20)
        return players.filter { $0.id != myId }
    }

    func profiles(ids: Set<UUID>) async throws -> [RemoteProfile] {
        guard myId != nil, !ids.isEmpty else { return [] }
        return try await backend.list("users", filter: Backend.any("id", in: ids.map(\.serverId)), sort: "username")
    }

    func counts(for id: UUID) async throws -> (followers: Int, following: Int) {
        guard myId != nil else { return (0, 0) }
        async let followers = backend.count("follows", filter: "followee_id = \(Backend.quoted(id.serverId))")
        async let following = backend.count("follows", filter: "follower_id = \(Backend.quoted(id.serverId))")
        return try await (followers, following)
    }

    // MARK: - Steam

    /// Steam's sign-in page. Signing in there proves you own the Steam account, and only
    /// then does your profile show its id so your Steam friends can find you: the app
    /// itself can't write it (server/pb_hooks: the steam-link route and the users rules).
    func steamLinkURL() async throws -> URL {
        guard myId != nil else { throw AccountError.notConfigured }
        let response: SteamLinkResponse = try await backend.send("POST", "/api/gameboxd/steam-link")
        return response.url
    }

    /// Your Steam friends who have a Gameboxd account (needs a public Steam friend list).
    func steamFriendsOnGameboxd(steamId: String) async -> [RemoteProfile] {
        guard myId != nil else { return [] }
        let ids = await SteamService.shared.friendIds(steamId: steamId).filter { $0.allSatisfy(\.isNumber) }
        guard !ids.isEmpty else { return [] }
        let players: [RemoteProfile] = (try? await backend.list("users", filter: Backend.any("steam_id", in: ids))) ?? []
        return players.filter { $0.id != myId }
    }

    /// What the players you follow are playing on Steam right now, by player id.
    func nowPlaying() async -> [UUID: String] {
        guard let players = try? await profiles(ids: following) else { return [:] }
        let bySteamId = Dictionary(players.compactMap { p in p.steamId.map { ($0, p.id) } }, uniquingKeysWith: { a, _ in a })
        let summaries = await SteamService.shared.summaries(steamIds: Array(bySteamId.keys))
        var result: [UUID: String] = [:]
        for summary in summaries {
            if let game = summary.gameextrainfo, let id = bySteamId[summary.steamid] { result[id] = game }
        }
        return result
    }

    // MARK: - Following

    func loadFollowing() async {
        guard let myId else { following = []; return }
        let rows: [Follow]? = try? await backend.list("follows", filter: "follower_id = \(Backend.quoted(myId.serverId))", limit: 10_000)
        following = Set((rows ?? []).map(\.followee_id))
    }

    func follow(_ id: UUID) async throws {
        guard let myId else { return }
        following.insert(id) // optimistic: the button flips right away
        do {
            try await backend.send("POST", "/api/collections/follows/records",
                                   body: NewFollow(follower_id: myId.serverId, followee_id: id.serverId))
        } catch {
            following.remove(id)
            throw AccountService.translate(error)
        }
    }

    func unfollow(_ id: UUID) async throws {
        guard let myId else { return }
        following.remove(id)
        do {
            let rows: [Follow] = try await backend.list("follows", filter: "follower_id = \(Backend.quoted(myId.serverId)) && followee_id = \(Backend.quoted(id.serverId))")
            for row in rows { if let rowId = row.id { try await backend.send("DELETE", "/api/collections/follows/records/\(rowId)") } }
        } catch {
            following.insert(id)
            throw AccountService.translate(error)
        }
    }

    // MARK: - Activity

    /// What you and the players you follow did lately, newest first.
    func feed() async throws -> [RemoteActivity] {
        guard let myId else { return [] }
        let authors = (following.union([myId])).map(\.serverId)
        return try await backend.list("activities", filter: Backend.any("user_id", in: authors),
                                      sort: "-created_at", expand: "user_id", limit: 60)
    }

    func activities(of id: UUID) async throws -> [RemoteActivity] {
        guard myId != nil else { return [] }
        return try await backend.list("activities", filter: "user_id = \(Backend.quoted(id.serverId))",
                                      sort: "-created_at", expand: "user_id", limit: 30)
    }

    /// Shares something you did. Silent no-op when signed out, sharing is off, or offline:
    /// your own collection never depends on it.
    func publish(_ kind: RemoteActivity.Kind, game: Game, rating: Int? = nil, review: String? = nil, minutes: Int? = nil) {
        guard isSharing, let myId else { return }
        let activity = NewActivity(user_id: myId.serverId, kind: kind.rawValue, game_title: game.title,
                                   game_cover_url: RemoteImage.shareable(game.artURL?.absoluteString), rating: rating,
                                   review: review.map { String($0.prefix(2000)) }, minutes: minutes)
        Task {
            do {
                try await backend.send("POST", "/api/collections/activities/records", body: activity)
            } catch {
                #if DEBUG
                print("SocialService: sharing \(kind.rawValue) failed: \(error)")
                #endif
            }
        }
    }

    func deleteActivity(_ id: UUID) async throws {
        guard myId != nil else { return }
        try await backend.send("DELETE", "/api/collections/activities/records/\(id.serverId)")
    }
}
