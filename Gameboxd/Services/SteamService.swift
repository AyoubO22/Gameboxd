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
//  2. Set it in SteamConfig.apiKey
//  3. User needs a public Steam profile
//

import Foundation

// MARK: - Steam Configuration
struct SteamConfig {
    /// Get your API key at: https://steamcommunity.com/dev/apikey
    static let apiKey = "YOUR_STEAM_API_KEY"
    static let baseURL = "https://api.steampowered.com"
    static let storeBaseURL = "https://store.steampowered.com"
    
    /// Check if the API key is configured
    static var isConfigured: Bool {
        apiKey != "YOUR_STEAM_API_KEY" && !apiKey.isEmpty
    }
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

struct SteamPlayerAchievementsResponse: Codable {
    let playerstats: SteamPlayerStats?
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

struct SteamRecentlyPlayedResponse: Codable {
    let response: SteamRecentlyPlayed
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
            return "Clé API Steam non configurée. Ajoutez votre clé dans SteamConfig."
        case .invalidSteamId:
            return "Steam ID invalide. Vérifie ton identifiant Steam."
        case .profilePrivate:
            return "Profil Steam privé. Rends ton profil public dans les paramètres Steam."
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
/// 2. Replace `YOUR_STEAM_API_KEY` in `SteamConfig.apiKey`
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
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Resolve Steam ID from custom URL
    
    /// Resolves a Steam vanity URL (custom profile URL) to a 64-bit Steam ID
    /// Input: "myprofilename" from https://steamcommunity.com/id/myprofilename
    func resolveSteamId(vanityName: String) async throws -> String {
        guard SteamConfig.isConfigured else { throw SteamServiceError.notConfigured }
        
        guard let url = URL(string: "\(SteamConfig.baseURL)/ISteamUser/ResolveVanityURL/v1/?key=\(SteamConfig.apiKey)&vanityurl=\(vanityName)") else {
            throw SteamServiceError.invalidSteamId
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode(SteamVanityURLResponse.self, from: data)
        
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
        guard SteamConfig.isConfigured else { throw SteamServiceError.notConfigured }
        
        guard let url = URL(string: "\(SteamConfig.baseURL)/ISteamUser/GetPlayerSummaries/v2/?key=\(SteamConfig.apiKey)&steamids=\(steamId)") else {
            throw SteamServiceError.invalidSteamId
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode(SteamPlayerSummaryResponse.self, from: data)
        
        guard let player = result.response.players.first else {
            throw SteamServiceError.invalidSteamId
        }
        
        return player
    }
    
    // MARK: - Game Library
    
    /// Fetches user's owned games with playtime
    func getOwnedGames(steamId: String, includeAppInfo: Bool = true) async throws -> [SteamGame] {
        guard SteamConfig.isConfigured else { throw SteamServiceError.notConfigured }
        
        var urlString = "\(SteamConfig.baseURL)/IPlayerService/GetOwnedGames/v1/?key=\(SteamConfig.apiKey)&steamid=\(steamId)&format=json"
        if includeAppInfo {
            urlString += "&include_appinfo=1"
        }
        urlString += "&include_played_free_games=1"
        
        guard let url = URL(string: urlString) else {
            throw SteamServiceError.invalidSteamId
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode(SteamOwnedGamesResponse.self, from: data)
        
        guard let games = result.response.games, !games.isEmpty else {
            throw SteamServiceError.noGamesFound
        }
        
        return games
    }
    
    /// Fetches recently played games (last 2 weeks)
    func getRecentlyPlayed(steamId: String) async throws -> [SteamGame] {
        guard SteamConfig.isConfigured else { throw SteamServiceError.notConfigured }
        
        guard let url = URL(string: "\(SteamConfig.baseURL)/IPlayerService/GetRecentlyPlayedGames/v1/?key=\(SteamConfig.apiKey)&steamid=\(steamId)&format=json") else {
            throw SteamServiceError.invalidSteamId
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode(SteamRecentlyPlayedResponse.self, from: data)
        return result.response.games ?? []
    }
    
    // MARK: - Achievements
    
    /// Fetches player achievements for a specific game
    func getPlayerAchievements(steamId: String, appId: Int) async throws -> [SteamAchievement] {
        guard SteamConfig.isConfigured else { throw SteamServiceError.notConfigured }
        
        guard let url = URL(string: "\(SteamConfig.baseURL)/ISteamUserStats/GetPlayerAchievements/v1/?key=\(SteamConfig.apiKey)&steamid=\(steamId)&appid=\(appId)&l=french") else {
            throw SteamServiceError.invalidSteamId
        }
        
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        let result = try JSONDecoder().decode(SteamPlayerAchievementsResponse.self, from: data)
        return result.playerstats?.achievements ?? []
    }
    
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
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        switch httpResponse.statusCode {
        case 200: return
        case 401: throw SteamServiceError.notConfigured
        case 403: throw SteamServiceError.profilePrivate
        case 429: throw SteamServiceError.rateLimited
        default:
            throw SteamServiceError.networkError("Code HTTP \(httpResponse.statusCode)")
        }
    }
}
