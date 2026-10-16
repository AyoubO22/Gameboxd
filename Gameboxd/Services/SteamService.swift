//
//  SteamService.swift
//  Gameboxd
//
//  Steam Web API integration for importing game library and achievements
//
//  API Documentation: https://developer.valvesoftware.com/wiki/Steam_Web_API
//  
//  Setup:
//  1. Get a Steam Web API Key from https://steamcommunity.com/dev/apikey
//  2. Store it as the STEAM_API_KEY secret of the `steam` Edge Function
//     (supabase/functions/steam), never in the app
//  3. User needs a public Steam profile
//

import Foundation
import Supabase

// MARK: - Steam Configuration
/// Steam's public art for a game (no key needed): the key art and store screenshots.
enum SteamStore {
    /// Wide key art, usually characters without the logo.
    static func heroURL(appId: Int) -> URL? {
        URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appId)/library_hero.jpg")
    }

    /// Full-size screenshots from the store page.
    static func screenshots(appId: Int, limit: Int = 4) async -> [URL] {
        struct Details: Decodable {
            struct Data: Decodable { struct Shot: Decodable { let path_full: String }; let screenshots: [Shot]? }
            let success: Bool
            let data: Data?
        }
        guard let url = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appId)&filters=screenshots"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let details = try? JSONDecoder().decode([String: Details].self, from: data)["\(appId)"],
              details.success else { return [] }
        return (details.data?.screenshots ?? []).prefix(limit).compactMap { URL(string: $0.path_full) }
    }
}

struct SteamConfig {
    /// The Steam Web API key lives in the `steam` Edge Function; the app only needs Supabase.
    static var isConfigured: Bool { SupabaseConfig.isConfigured }
}

// MARK: - Steam API Response Models
struct SteamOwnedGamesResponse: Codable {
    let response: SteamOwnedGames
}

struct SteamOwnedGames: Codable {
    let game_count: Int?
    let games: [SteamGame]?
}

struct SteamGame: Codable {
    let appid: Int
    let name: String?
    let playtime_forever: Int          // minutes
    let playtime_2weeks: Int?          // minutes in last 2 weeks
    let img_icon_url: String?
    let has_community_visible_stats: Bool?
    let rtime_last_played: Int?        // Unix timestamp
    
    var coverURL: String? {
        guard let icon = img_icon_url, !icon.isEmpty else {
            return "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appid)/header.jpg"
        }
        return "https://media.steampowered.com/steamcommunity/public/images/apps/\(appid)/\(icon).jpg"
    }
    
    var headerURL: String {
        "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appid)/header.jpg"
    }
    
    var lastPlayedDate: Date? {
        guard let timestamp = rtime_last_played, timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}


struct SteamPlayerStats: Codable {
    let steamID: String?
    let gameName: String?
    let achievements: [SteamAchievement]?
    let success: Bool?
}

struct SteamAchievement: Codable {
    let apiname: String
    let achieved: Int // 1 = unlocked, 0 = locked
    let unlocktime: Int?
    let name: String?
    let description: String?
}

struct SteamPlayerSummaryResponse: Codable {
    let response: SteamPlayerSummaryList
}

struct SteamPlayerSummaryList: Codable {
    let players: [SteamPlayerSummary]
}

struct SteamPlayerSummary: Codable {
    let steamid: String
    let personaname: String
    let avatarfull: String?
    let profileurl: String?
    let gameextrainfo: String?       // Currently playing game
    let gameid: String?              // Currently playing game ID
    let timecreated: Int?
    let loccountrycode: String?
}


struct SteamRecentlyPlayed: Codable {
    let total_count: Int?
    let games: [SteamGame]?
}

// MARK: - Resolve Vanity URL
struct SteamVanityURLResponse: Codable {
    let response: SteamVanityResult
}

struct SteamVanityResult: Codable {
    let steamid: String?
    let success: Int
    let message: String?
}

// MARK: - Steam Service Errors
enum SteamServiceError: LocalizedError {
    case notConfigured
    case invalidSteamId
    case profilePrivate
    case networkError(String)
    case decodingError(String)
    case noGamesFound
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "L'import Steam n'est pas disponible dans cette version."
        case .invalidSteamId:
            return "Steam ID invalide. Vérifie ton identifiant Steam."
        case .profilePrivate:
            return "Ta liste de jeux Steam est privée. Dans Steam : Profil → Modifier le profil → Confidentialité → « Détails des jeux » sur Public, puis réessaie."
        case .networkError(let msg):
            return "Erreur réseau Steam : \(msg)"
        case .decodingError(let msg):
            return "Erreur de données Steam : \(msg)"
        case .noGamesFound:
            return "Aucun jeu trouvé sur ce compte Steam."
        case .rateLimited:
            return "Trop de requêtes. Réessaie dans quelques minutes."
        }
    }
}

// MARK: - Steam Service
/// Integrates with Steam Web API to fetch user library, achievements, and profile
///
/// ## Setup Instructions:
/// 1. Register for a Steam Web API Key: https://steamcommunity.com/dev/apikey
/// 2. Set STEAM_API_KEY as a secret of the `steam` Edge Function
/// 3. Users need to:
///    - Have a public Steam profile (Settings → Privacy → Game Details: Public)
///    - Provide their Steam ID (64-bit) or custom URL name
///
/// ## API Endpoints Used:
/// - `IPlayerService/GetOwnedGames` - Get user's game library
/// - `ISteamUserStats/GetPlayerAchievements` - Get achievements per game
/// - `ISteamUser/GetPlayerSummaries` - Get user profile info
/// - `ISteamUser/ResolveVanityURL` - Convert custom URL to Steam ID
/// - `IPlayerService/GetRecentlyPlayedGames` - Recent games
///
class SteamService {
    static let shared = SteamService()

    // MARK: - Resolve Steam ID from custom URL

    /// Resolves a Steam vanity URL (custom profile URL) to a 64-bit Steam ID
    /// Input: "myprofilename" from https://steamcommunity.com/id/myprofilename
    func resolveSteamId(vanityName: String) async throws -> String {
        let result: SteamVanityURLResponse = try await call(SteamRequest(method: "resolveVanity", value: vanityName))

        guard result.response.success == 1, let steamId = result.response.steamid else {
            throw SteamServiceError.invalidSteamId
        }

        return steamId
    }
    
    /// Parses a Steam ID from various input formats:
    /// - Direct 64-bit ID: "76561198000000000"
    /// - Profile URL: "https://steamcommunity.com/profiles/76561198000000000"
    /// - Custom URL: "https://steamcommunity.com/id/username"
    /// - Custom name: "username"
    func parseSteamId(input: String) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct 64-bit Steam ID (17 digits)
        if trimmed.count == 17, trimmed.allSatisfy({ $0.isNumber }) {
            return trimmed
        }
        
        // Profile URL with direct ID
        if let match = trimmed.range(of: #"steamcommunity\.com/profiles/(\d{17})"#, options: .regularExpression) {
            let idPart = trimmed[match]
            if let idRange = idPart.range(of: #"\d{17}"#, options: .regularExpression) {
                return String(idPart[idRange])
            }
        }
        
        // Custom URL
        if let match = trimmed.range(of: #"steamcommunity\.com/id/([^/]+)"#, options: .regularExpression) {
            let captured = String(trimmed[match])
            let vanityName = captured.replacingOccurrences(of: "steamcommunity.com/id/", with: "")
            return try await resolveSteamId(vanityName: vanityName)
        }
        
        // Assume it's a vanity name
        return try await resolveSteamId(vanityName: trimmed)
    }
    
    // MARK: - Player Profile
    
    /// Fetches Steam player profile summary
    func getPlayerSummary(steamId: String) async throws -> SteamPlayerSummary {
        let result: SteamPlayerSummaryResponse = try await call(SteamRequest(method: "playerSummary", value: steamId))

        guard let player = result.response.players.first else {
            throw SteamServiceError.invalidSteamId
        }

        return player
    }

    // MARK: - Game Library

    /// Fetches user's owned games with playtime (free games included)
    func getOwnedGames(steamId: String, includeAppInfo: Bool = true) async throws -> [SteamGame] {
        let result: SteamOwnedGamesResponse = try await call(SteamRequest(method: "ownedGames", value: steamId, appInfo: includeAppInfo))

        // A private game list comes back as an empty response, without even a count.
        guard result.response.game_count != nil else { throw SteamServiceError.profilePrivate }
        guard let games = result.response.games, !games.isEmpty else {
            throw SteamServiceError.noGamesFound
        }

        return games
    }
    
    
    // MARK: - Achievements
    
    
    // MARK: - Full Library Sync
    
    /// Performs a full sync: fetches all games and converts to ImportedGame models
    func syncLibrary(steamId: String) async throws -> (games: [ImportedGame], profile: SteamPlayerSummary) {
        // Fetch profile and games in parallel
        async let profileTask = getPlayerSummary(steamId: steamId)
        async let gamesTask = getOwnedGames(steamId: steamId)
        
        let (profile, steamGames) = try await (profileTask, gamesTask)
        
        // Convert to ImportedGame models
        let importedGames = steamGames.map { game in
            ImportedGame(
                platform: .steam,
                platformGameId: String(game.appid),
                title: game.name ?? "Unknown Game (ID: \(game.appid))",
                coverImageURL: game.headerURL,
                playtimeMinutes: game.playtime_forever,
                lastPlayed: game.lastPlayedDate,
                achievementsEarned: 0,
                achievementsTotal: 0
            )
        }
        
        return (importedGames, profile)
    }
    
    // MARK: - Helpers

    /// Calls the Steam Web API through the `steam` Edge Function, which holds the key and
    /// checks the input (17-digit ids, plain vanity names).
    fileprivate func call<T: Decodable>(_ request: SteamRequest) async throws -> T {
        guard let client = AccountService.shared.client else { throw SteamServiceError.notConfigured }
        do {
            return try await client.functions.invoke(
                "steam",
                options: FunctionInvokeOptions(body: request),
                decoder: JSONDecoder()
            )
        } catch FunctionsError.httpError(let code, _) {
            switch code {
            case 400: throw SteamServiceError.invalidSteamId
            case 403: throw SteamServiceError.profilePrivate
            case 429: throw SteamServiceError.rateLimited
            case 404, 503: throw SteamServiceError.notConfigured
            default: throw SteamServiceError.networkError("Code HTTP \(code)")
            }
        } catch let error as DecodingError {
            throw SteamServiceError.decodingError(error.localizedDescription)
        }
    }
}

/// What the `steam` Edge Function accepts (see supabase/functions/steam).
nonisolated private struct SteamRequest: Encodable {
    let method: String
    var value: String?
    var appId: Int?
    var appInfo: Bool?
}

// MARK: - Achievements, friends, presence

/// One achievement as Steam reports it for a player.
struct SteamPlayerAchievement: Codable {
    let apiname: String
    let achieved: Int
    let unlocktime: Int
}

/// An achievement's name and icon (from the game's schema) with how rare it is worldwide.
struct SteamAchievementInfo: Identifiable {
    let id: String
    let name: String
    let iconURL: URL?
    let globalPercent: Double?
    let unlockedAt: Date?
}

extension SteamService {
    /// The player's achievements for a game: (unlocked api names with their date, total).
    /// Nil when the game has no achievements or the player's stats are private.
    func playerAchievements(steamId: String, appId: Int) async -> (unlocked: [String: Date], total: Int)? {
        struct Response: Decodable {
            struct Stats: Decodable { let achievements: [SteamPlayerAchievement]?; let success: Bool }
            let playerstats: Stats
        }
        guard SteamConfig.isConfigured,
              let response: Response = try? await call(SteamRequest(method: "achievements", value: steamId, appId: appId)),
              case let stats = response.playerstats,
              stats.success, let list = stats.achievements, !list.isEmpty else { return nil }
        var unlocked: [String: Date] = [:]
        for achievement in list where achievement.achieved == 1 {
            unlocked[achievement.apiname] = Date(timeIntervalSince1970: TimeInterval(achievement.unlocktime))
        }
        return (unlocked, list.count)
    }

    /// Names and icons of a game's achievements (needs the key), with worldwide unlock rates (public).
    func achievementInfo(appId: Int) async -> [String: (name: String, icon: URL?, percent: Double?)] {
        struct Schema: Decodable {
            struct Game: Decodable {
                struct Stats: Decodable {
                    struct Achievement: Decodable { let name: String; let displayName: String; let icon: String? }
                    let achievements: [Achievement]?
                }
                let availableGameStats: Stats?
            }
            let game: Game
        }
        struct Global: Decodable {
            struct List: Decodable {
                // Steam sends the percentage as a number or as a string depending on the endpoint version.
                struct Entry: Decodable {
                    let name: String
                    let percent: Double
                    init(from decoder: Decoder) throws {
                        let c = try decoder.container(keyedBy: CodingKeys.self)
                        name = try c.decode(String.self, forKey: .name)
                        if let d = try? c.decode(Double.self, forKey: .percent) { percent = d }
                        else { percent = Double(try c.decode(String.self, forKey: .percent)) ?? 0 }
                    }
                    enum CodingKeys: String, CodingKey { case name, percent }
                }
                let achievements: [Entry]
            }
            let achievementpercentages: List
        }
        var result: [String: (name: String, icon: URL?, percent: Double?)] = [:]
        if SteamConfig.isConfigured,
           let schema: Schema = try? await call(SteamRequest(method: "schema", appId: appId)) {
            for a in schema.game.availableGameStats?.achievements ?? [] {
                result[a.name] = (a.displayName, a.icon.flatMap(URL.init(string:)), nil)
            }
        }
        // Public endpoint, no key: called directly.
        if let url = URL(string: "https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=\(appId)"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let global = try? JSONDecoder().decode(Global.self, from: data) {
            for entry in global.achievementpercentages.achievements {
                let known = result[entry.name]
                result[entry.name] = (known?.name ?? entry.name, known?.icon, entry.percent)
            }
        }
        return result
    }

    /// Steam ids of the player's friends. Empty when the friend list is private.
    func friendIds(steamId: String) async -> [String] {
        struct Response: Decodable {
            struct List: Decodable { struct Friend: Decodable { let steamid: String }; let friends: [Friend] }
            let friendslist: List?
        }
        guard SteamConfig.isConfigured,
              let response: Response = try? await call(SteamRequest(method: "friends", value: steamId)),
              let list = response.friendslist else { return [] }
        return list.friends.map(\.steamid)
    }

    /// Public summaries (name, game being played right now) for up to 100 players at once.
    func summaries(steamIds: [String]) async -> [SteamPlayerSummary] {
        guard SteamConfig.isConfigured, !steamIds.isEmpty else { return [] }
        var all: [SteamPlayerSummary] = []
        for start in stride(from: 0, to: steamIds.count, by: 100) {
            let ids = steamIds[start..<min(start + 100, steamIds.count)].joined(separator: ",")
            guard let response: SteamPlayerSummaryResponse = try? await call(SteamRequest(method: "playerSummary", value: ids)) else { continue }
            all += response.response.players
        }
        return all
    }
}
