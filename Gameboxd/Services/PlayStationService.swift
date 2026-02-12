//
//  PlayStationService.swift
//  Gameboxd
//
//  PlayStation Network integration for importing game library and trophies
//
//  PSN has no official public API. This service is structured to work with:
//  - PSN API wrapper (psn-api / PlayStation Partners API when available)
//  - Third-party endpoints that provide PSN data
//
//  When Sony releases an official API or you obtain partner access,
//  replace the placeholder URLs and auth flow.
//
//  Current approach: NPSSO token-based auth (from PlayStation web login)
//

import Foundation

// MARK: - PlayStation Configuration
struct PlayStationConfig {
    /// Base URL for PSN API (using community-maintained API structure)
    /// Replace with official API when available
    static let authURL = "https://ca.account.sony.com/api/authz/v3/oauth"
    static let baseURL = "https://m.np.playstation.com/api"
    
    /// Your registered client ID (from PlayStation Partners or proxy)
    /// For testing, users provide their NPSSO token directly
    static let clientId = "YOUR_PSN_CLIENT_ID"
    static let clientSecret = "YOUR_PSN_CLIENT_SECRET"
    static let redirectURI = "com.gameboxd://psn-callback"
    
    static var isConfigured: Bool {
        clientId != "YOUR_PSN_CLIENT_ID" && !clientId.isEmpty
    }
}

// MARK: - PSN API Response Models

struct PSNAuthTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String?
}

struct PSNProfileResponse: Codable {
    let onlineId: String
    let aboutMe: String?
    let avatarUrl: String?
    let plus: Int?               // 1 = PS Plus subscriber
    let trophySummary: PSNTrophySummary?
}

struct PSNTrophySummary: Codable {
    let level: Int
    let progress: Int
    let earnedTrophies: PSNTrophyCounts
}

struct PSNTrophyCounts: Codable {
    let bronze: Int
    let silver: Int
    let gold: Int
    let platinum: Int
    
    var total: Int { bronze + silver + gold + platinum }
}

struct PSNGameListResponse: Codable {
    let totalItemCount: Int?
    let trophyTitles: [PSNGameTitle]?
}

struct PSNGameTitle: Codable {
    let npCommunicationId: String         // Trophy set ID
    let trophyTitleName: String
    let trophyTitleIconUrl: String?
    let trophyTitlePlatform: String?       // "PS5", "PS4", "PS3", "PSVITA"
    let hasTrophyGroups: Bool?
    let definedTrophies: PSNTrophyCounts?
    let earnedTrophies: PSNTrophyCounts?
    let progress: Int?                     // 0-100
    let lastUpdatedDateTime: String?
    let npTitleId: String?                 // Game title ID
}

struct PSNGameTrophiesResponse: Codable {
    let totalItemCount: Int?
    let trophies: [PSNTrophy]?
}

struct PSNTrophy: Codable {
    let trophyId: Int
    let trophyHidden: Bool?
    let earned: Bool?
    let earnedDateTime: String?
    let trophyType: String?                // "bronze", "silver", "gold", "platinum"
    let trophyName: String?
    let trophyDetail: String?
    let trophyIconUrl: String?
    let trophyGroupId: String?
}

// MARK: - PlayStation Service Errors
enum PlayStationServiceError: LocalizedError {
    case notConfigured
    case invalidNPSSO
    case authenticationFailed(String)
    case profilePrivate
    case networkError(String)
    case decodingError(String)
    case noGamesFound
    case rateLimited
    case tokenExpired
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Le service PlayStation n'est pas encore configuré."
        case .invalidNPSSO:
            return "Jeton NPSSO invalide. Reconnecte-toi à PlayStation."
        case .authenticationFailed(let msg):
            return "Authentification PSN échouée : \(msg)"
        case .profilePrivate:
            return "Profil PSN privé. Change tes paramètres de confidentialité."
        case .networkError(let msg):
            return "Erreur réseau PSN : \(msg)"
        case .decodingError(let msg):
            return "Erreur de données PSN : \(msg)"
        case .noGamesFound:
            return "Aucun jeu trouvé sur ce compte PlayStation."
        case .rateLimited:
            return "Trop de requêtes PSN. Réessaie dans quelques minutes."
        case .tokenExpired:
            return "Session PSN expirée. Reconnecte-toi."
        }
    }
}

// MARK: - PlayStation Service
/// Integrates with PlayStation Network APIs to fetch game library and trophies
///
/// ## Authentication Flow:
/// PSN uses OAuth 2.0 with NPSSO tokens. The flow is:
/// 1. User logs in at ca.account.sony.com and gets an NPSSO cookie
/// 2. Exchange NPSSO for an authorization code
/// 3. Exchange code for access_token + refresh_token
/// 4. Use access_token for API calls
///
/// ## Setup for Production:
/// 1. Apply for PlayStation Partners Program or use a PSN API proxy
/// 2. Set `PlayStationConfig.clientId` and `clientSecret`
/// 3. Implement the OAuth web login flow in-app (ASWebAuthenticationSession)
/// 4. Replace placeholder API calls with real endpoints
///
/// ## API Endpoints (PSN Trophy API v2):
/// - `GET /trophy/v1/users/{accountId}/trophyTitles` — Game list with trophies
/// - `GET /trophy/v1/users/{accountId}/npCommunicationIds/{id}/trophies` — Game trophies
/// - `GET /userProfile/v1/internal/users/{accountId}/profiles` — User profile
///
class PlayStationService {
    static let shared = PlayStationService()
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication
    
    /// Links a PlayStation account using PSN ID (Online ID)
    /// In production, this would trigger the OAuth web flow
    ///
    /// For testing/development: accepts PSN Online ID and simulates the auth
    /// For production: use ASWebAuthenticationSession with Sony's OAuth endpoint
    func authenticate(psnId: String) async throws -> PSNProfileResponse {
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // PRODUCTION IMPLEMENTATION:
        //
        // Step 1: Open ASWebAuthenticationSession to Sony login page
        // let authURL = URL(string: "\(PlayStationConfig.authURL)/authorize?..." )!
        //
        // Step 2: User logs in, you receive authorization code via redirect
        //
        // Step 3: Exchange code for tokens
        // let tokenResponse = try await exchangeCodeForTokens(code: authCode)
        // self.accessToken = tokenResponse.access_token
        // self.refreshToken = tokenResponse.refresh_token
        // self.tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        //
        // Step 4: Fetch user profile
        // return try await getProfile()
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        // Simulated profile for development
        return PSNProfileResponse(
            onlineId: psnId,
            aboutMe: nil,
            avatarUrl: nil,
            plus: 1,
            trophySummary: PSNTrophySummary(
                level: 12,
                progress: 45,
                earnedTrophies: PSNTrophyCounts(
                    bronze: 120,
                    silver: 45,
                    gold: 12,
                    platinum: 3
                )
            )
        )
    }
    
    /// Authenticate with NPSSO token (advanced users / development)
    func authenticateWithNPSSO(npsso: String) async throws {
        // Step 1: Exchange NPSSO for authorization code
        // var request = URLRequest(url: URL(string: "\(PlayStationConfig.authURL)/authorize")!)
        // request.setValue("npsso=\(npsso)", forHTTPHeaderField: "Cookie")
        // ... follow redirects to get ?code=xxx
        
        // Step 2: Exchange code for access token
        // let tokenResponse = try await exchangeCodeForTokens(code: authCode)
        
        // Placeholder:
        self.accessToken = "psn_simulated_\(UUID().uuidString)"
        self.tokenExpiration = Date().addingTimeInterval(3600)
    }
    
    // MARK: - Game Library
    
    /// Fetches user's game list with trophy progress
    func getGameList(accountId: String, offset: Int = 0, limit: Int = 100) async throws -> [PSNGameTitle] {
        // Real endpoint:
        // GET \(baseURL)/trophy/v1/users/\(accountId)/trophyTitles?offset=\(offset)&limit=\(limit)
        // Header: Authorization: Bearer \(accessToken)
        
        guard accessToken != nil || !PlayStationConfig.isConfigured else {
            throw PlayStationServiceError.notConfigured
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // PRODUCTION IMPLEMENTATION:
        //
        // var request = URLRequest(url: URL(string: "\(PlayStationConfig.baseURL)/trophy/v1/users/\(accountId)/trophyTitles?offset=\(offset)&limit=\(limit)")!)
        // request.setValue("Bearer \(accessToken!)", forHTTPHeaderField: "Authorization")
        // let (data, response) = try await session.data(for: request)
        // try validateResponse(response)
        // let result = try JSONDecoder().decode(PSNGameListResponse.self, from: data)
        // return result.trophyTitles ?? []
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        // Simulated return for development
        return []
    }
    
    /// Fetches detailed trophies for a specific game
    func getGameTrophies(accountId: String, communicationId: String) async throws -> [PSNTrophy] {
        // Real endpoint:
        // GET \(baseURL)/trophy/v1/users/\(accountId)/npCommunicationIds/\(communicationId)/trophyGroups/all/trophies
        
        // Placeholder
        return []
    }
    
    // MARK: - Full Library Sync
    
    /// Performs a full sync: fetches all games and converts to ImportedGame models
    func syncLibrary(psnId: String) async throws -> (games: [ImportedGame], profile: PSNProfileResponse) {
        let profile = try await authenticate(psnId: psnId)
        
        // In production, fetch real game list
        let psnGames = try await getGameList(accountId: psnId)
        
        let importedGames = psnGames.map { game in
            ImportedGame(
                platform: .playstation,
                platformGameId: game.npCommunicationId,
                title: game.trophyTitleName,
                coverImageURL: game.trophyTitleIconUrl,
                playtimeMinutes: 0, // PSN doesn't expose playtime easily
                lastPlayed: parseISO8601(game.lastUpdatedDateTime),
                achievementsEarned: game.earnedTrophies?.total ?? 0,
                achievementsTotal: game.definedTrophies?.total ?? 0
            )
        }
        
        return (importedGames, profile)
    }
    
    // MARK: - Helpers
    
    private func parseISO8601(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw PlayStationServiceError.tokenExpired
        case 403: throw PlayStationServiceError.profilePrivate
        case 429: throw PlayStationServiceError.rateLimited
        default:
            throw PlayStationServiceError.networkError("Code HTTP \(httpResponse.statusCode)")
        }
    }
}
