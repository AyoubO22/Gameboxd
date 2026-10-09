//
//  SocialService.swift
//  Gameboxd
//
//  Following players and seeing what they play (Supabase tables `follows` and
//  `activities`, see supabase/schema.sql). Needs an account; without one it stays idle.
//

import Foundation
import Supabase

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

    /// The author, embedded by the query (`profiles(...)`).
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
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case id, kind, rating, review, minutes
        case userId = "user_id"
        case gameTitle = "game_title"
        case gameCoverURL = "game_cover_url"
        case createdAt = "created_at"
        case author = "profiles"
    }
}

/// What the app sends when something worth sharing happens.
nonisolated private struct NewActivity: Encodable {
    let user_id: UUID
    let kind: String
    let game_title: String
    let game_cover_url: String?
    let rating: Int?
    let review: String?
    let minutes: Int?
}

nonisolated private struct Follow: Codable {
    let follower_id: UUID
    let followee_id: UUID
}

@MainActor
@Observable
final class SocialService {
    static let shared = SocialService()

    /// Ids of the players you follow.
    private(set) var following: Set<UUID> = []

    /// Public profile (Réglages): your collection and activity are visible to other players.
    /// On by default once signed in. Turning it off takes the collection offline.
    var isSharing: Bool = UserDefaults.standard.object(forKey: SocialService.sharingKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isSharing, forKey: Self.sharingKey)
            guard isSharing != oldValue else { return }
            Task {
                if isSharing { await LibrarySync.shared.pushCurrent() } else { await LibrarySync.shared.removeAll() }
            }
        }
    }
    private static let sharingKey = "gameboxd_share_activity"

    private let account = AccountService.shared
    private static let activityColumns = "*, profiles(username, display_name)"

    private var client: SupabaseClient? { account.isSignedIn ? account.client : nil }
    private var myId: UUID? { account.profile?.id }

    // MARK: - Players

    /// Players whose pseudo contains `query`, yourself excluded.
    func searchPlayers(_ query: String) async throws -> [RemoteProfile] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard let client, text.count >= 2 else { return [] }
        // Wildcards typed by the user are matched literally.
        let escaped = text.replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
        let players: [RemoteProfile] = try await client.from("profiles")
            .select()
            .ilike("username", pattern: "%\(escaped)%")
            .order("username")
            .limit(20)
            .execute().value
        return players.filter { $0.id != myId }
    }

    func profiles(ids: Set<UUID>) async throws -> [RemoteProfile] {
        guard let client, !ids.isEmpty else { return [] }
        return try await client.from("profiles")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .order("username")
            .execute().value
    }

    func counts(for id: UUID) async throws -> (followers: Int, following: Int) {
        guard let client else { return (0, 0) }
        async let followers = client.from("follows").select("*", head: true, count: .exact).eq("followee_id", value: id).execute().count
        async let following = client.from("follows").select("*", head: true, count: .exact).eq("follower_id", value: id).execute().count
        return try await (followers ?? 0, following ?? 0)
    }

    // MARK: - Following

    func loadFollowing() async {
        guard let client, let myId else { following = []; return }
        let rows: [Follow]? = try? await client.from("follows").select().eq("follower_id", value: myId).execute().value
        following = Set((rows ?? []).map(\.followee_id))
    }

    func follow(_ id: UUID) async throws {
        guard let client, let myId else { return }
        following.insert(id) // optimistic: the button flips right away
        do {
            try await client.from("follows").insert(Follow(follower_id: myId, followee_id: id)).execute()
        } catch {
            following.remove(id)
            throw AccountService.translate(error)
        }
    }

    func unfollow(_ id: UUID) async throws {
        guard let client, let myId else { return }
        following.remove(id)
        do {
            try await client.from("follows").delete().eq("follower_id", value: myId).eq("followee_id", value: id).execute()
        } catch {
            following.insert(id)
            throw AccountService.translate(error)
        }
    }

    // MARK: - Activity

    /// What you and the players you follow did lately, newest first.
    func feed() async throws -> [RemoteActivity] {
        guard let client, let myId else { return [] }
        let authors = (following.union([myId])).map(\.uuidString)
        return try await client.from("activities")
            .select(Self.activityColumns)
            .in("user_id", values: authors)
            .order("created_at", ascending: false)
            .limit(60)
            .execute().value
    }

    func activities(of id: UUID) async throws -> [RemoteActivity] {
        guard let client else { return [] }
        return try await client.from("activities")
            .select(Self.activityColumns)
            .eq("user_id", value: id)
            .order("created_at", ascending: false)
            .limit(30)
            .execute().value
    }

    /// Shares something you did. Silent no-op when signed out, sharing is off, or offline:
    /// your own collection never depends on it.
    func publish(_ kind: RemoteActivity.Kind, game: Game, rating: Int? = nil, review: String? = nil, minutes: Int? = nil) {
        guard isSharing, let client, let myId else { return }
        let activity = NewActivity(user_id: myId, kind: kind.rawValue, game_title: game.title,
                                   game_cover_url: game.artURL?.absoluteString, rating: rating,
                                   review: review.map { String($0.prefix(2000)) }, minutes: minutes)
        Task {
            do {
                _ = try await client.from("activities").insert(activity).execute().status
            } catch {
                #if DEBUG
                print("SocialService: sharing \(kind.rawValue) failed: \(error)")
                #endif
            }
        }
    }

    func deleteActivity(_ id: UUID) async throws {
        guard let client else { return }
        try await client.from("activities").delete().eq("id", value: id).execute()
    }
}
