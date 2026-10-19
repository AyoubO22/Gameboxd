//
//  PlayStationService.swift
//  Gameboxd
//
//  PlayStation Network: sign in with Sony, then import the games played on the account
//  (with play time) and their trophies.
//
//  Sony has no public API. This uses the sign-in and endpoints of Sony's own mobile app,
//  as the community `psn-api` library does (https://github.com/achievements-app/psn-api):
//   1. Sony's sign-in page (in a browser sheet) redirects to the app's scheme with a code,
//      or a pasted NPSSO cookie is exchanged for that code.
//   2. The code becomes an access token (1 h) and a refresh token (about 2 months), kept
//      in the Keychain on this phone only: they never reach Gameboxd's server.
//   3. The library is read as "me", so a private PSN profile still works.
//

import Foundation
import Security

// MARK: - PlayStation Configuration
enum PlayStationConfig {
    static let authURL = "https://ca.account.sony.com/api/authz/v3/oauth"
    static let apiURL = "https://m.np.playstation.com/api"
    /// Where an NPSSO cookie can be read once signed in on playstation.com.
    static let npssoURL = URL(string: "https://ca.account.sony.com/api/v1/ssocookie")!

    // Sony's PlayStation App client, the one psn-api uses (public, not a Gameboxd secret).
    static let clientId = "09515159-7237-4370-9b40-3806e67c0891"
    static let clientBasicAuth = "MDk1MTUxNTktNzIzNy00MzcwLTliNDAtMzgwNmU2N2MwODkxOnVjUGprYTV0bnRCMktxc1A="
    static let callbackScheme = "com.scee.psxandroid.scecompcall"
    static let redirectURI = "\(callbackScheme)://redirect"
    static let scope = "psn:mobile.v2.core psn:clientapp"

    /// Sony's sign-in page; after sign-in it sends the browser to `redirectURI?code=…`.
    static var signInURL: URL {
        var components = URLComponents(string: "\(authURL)/authorize")!
        components.queryItems = [
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope)
        ]
        return components.url!
    }
}

// MARK: - PSN API Response Models

struct PSNProfileResponse: Codable {
    let onlineId: String
    let avatarUrl: String?
    let trophyLevel: Int?
    let earnedTrophies: PSNTrophyCounts?
}

struct PSNTrophyCounts: Codable, Equatable {
    let bronze: Int
    let silver: Int
    let gold: Int
    let platinum: Int

    init(bronze: Int, silver: Int, gold: Int, platinum: Int) {
        self.bronze = bronze
        self.silver = silver
        self.gold = gold
        self.platinum = platinum
    }

    /// A missing count is zero (Sony leaves some out, e.g. platinum on sets without one).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bronze = (try? c.decode(Int.self, forKey: .bronze)) ?? 0
        silver = (try? c.decode(Int.self, forKey: .silver)) ?? 0
        gold = (try? c.decode(Int.self, forKey: .gold)) ?? 0
        platinum = (try? c.decode(Int.self, forKey: .platinum)) ?? 0
    }

    var total: Int { bronze + silver + gold + platinum }
}

/// `GET /trophy/v1/users/me/trophySummary`
struct PSNTrophySummaryResponse: Decodable {
    let accountId: String
    let trophyLevel: Int?
    let earnedTrophies: PSNTrophyCounts?

    private enum CodingKeys: String, CodingKey { case accountId, trophyLevel, earnedTrophies }

    init(accountId: String, trophyLevel: Int?, earnedTrophies: PSNTrophyCounts?) {
        self.accountId = accountId
        self.trophyLevel = trophyLevel
        self.earnedTrophies = earnedTrophies
    }

    // Sony has sent the level both as a number and as a string ("451"): take either,
    // and don't fail the whole link over the level or the counts.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try c.decode(String.self, forKey: .accountId)
        trophyLevel = (try? c.decode(Int.self, forKey: .trophyLevel))
            ?? (try? c.decode(String.self, forKey: .trophyLevel)).flatMap { Int($0) }
        earnedTrophies = try? c.decode(PSNTrophyCounts.self, forKey: .earnedTrophies)
    }
}

/// `GET /userProfile/v1/internal/users/{accountId}/profiles`
struct PSNUserProfileResponse: Codable {
    struct Avatar: Codable { let size: String?; let url: String? }
    let onlineId: String
    let avatars: [Avatar]?
}

/// `GET /trophy/v1/users/me/trophyTitles`
struct PSNGameListResponse: Codable {
    let totalItemCount: Int?
    let nextOffset: Int?
    let trophyTitles: [PSNGameTitle]?
}

struct PSNGameTitle: Codable, Equatable {
    let npCommunicationId: String          // Trophy set ID
    let trophyTitleName: String
    let trophyTitleIconUrl: String?
    let trophyTitlePlatform: String?       // "PS5", "PS4", "PS3", "PSVITA", or "PS5,PS4"
    let definedTrophies: PSNTrophyCounts?
    let earnedTrophies: PSNTrophyCounts?
    let progress: Int?                     // 0-100
    let lastUpdatedDateTime: String?
}

/// `GET /gamelist/v2/users/me/titles`: games played on PS4 and PS5, with play time.
struct PSNPlayedTitlesResponse: Codable {
    let titles: [PSNPlayedTitle]?
    let nextOffset: Int?
    let totalItemCount: Int?
}

struct PSNPlayedTitle: Codable, Equatable {
    struct Concept: Codable, Equatable { let id: Int? }
    let titleId: String
    let name: String
    let localizedName: String?
    let imageUrl: String?
    let localizedImageUrl: String?
    let category: String?                  // "ps5_native_game", "ps4_game"
    let concept: Concept?
    let lastPlayedDateTime: String?
    let playDuration: String?              // ISO 8601 duration, "PT228H56M33S"
}

/// `GET /trophy/v1/npCommunicationIds/{id}/trophyGroups/all/trophies` (what each trophy is)
/// and `/trophy/v1/users/me/npCommunicationIds/{id}/…` (which ones are earned).
struct PSNTrophyListResponse: Decodable {
    struct Trophy: Decodable {
        let trophyId: Int
        let trophyName: String?
        let trophyDetail: String?
        let earned: Bool?
    }
    let trophies: [Trophy]?
}

struct PSNTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var accessExpiry: Date
    var refreshExpiry: Date
}

// MARK: - PlayStation Service Errors
enum PlayStationServiceError: LocalizedError {
    case invalidNPSSO
    case signInFailed
    case notSignedIn
    case tokenExpired
    case networkError(String)
    case decodingError(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidNPSSO:
            return "Code NPSSO refusé par Sony. Reconnecte-toi sur playstation.com et copie un nouveau code."
        case .signInFailed:
            return "Sony n'a pas confirmé la connexion. Réessaie."
        case .notSignedIn, .tokenExpired:
            return "Session PlayStation expirée. Délie puis relie ton compte PlayStation."
        case .networkError(let msg):
            return "Erreur réseau PSN : \(msg)"
        case .decodingError(let msg):
            return "Erreur de données PSN : \(msg)"
        case .rateLimited:
            return "Trop de requêtes PSN. Réessaie dans quelques minutes."
        }
    }
}

// MARK: - Library merge (pure, tested)

/// Turns Sony's two lists (games played, trophy sets) into one import list.
enum PSNLibrary {
    /// "PT228H56M33S" → 13 736. Sony also sends days ("P1DT2H").
    static func minutes(fromDuration duration: String?) -> Int {
        guard let duration, duration.hasPrefix("P") else { return 0 }
        var seconds = 0.0
        var number = ""
        for char in duration.dropFirst() {
            if char.isNumber || char == "." {
                number.append(char)
                continue
            }
            let value = Double(number) ?? 0
            number = ""
            switch char {
            case "D": seconds += value * 86_400
            case "H": seconds += value * 3_600
            case "M": seconds += value * 60
            case "S": seconds += value
            default: break // "T" separates days from hours
            }
        }
        return Int(seconds / 60)
    }

    /// Names as Sony writes them differ between lists ("Marvel's Spider-Man 2" vs
    /// "Marvel’s Spider-Man 2™"): compare letters and digits only.
    static func key(_ title: String) -> String {
        String(title.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            .map(Character.init))
    }

    static func console(category: String?) -> String? {
        switch category {
        case "ps5_native_game": return "PlayStation 5"
        case "ps4_game": return "PlayStation 4"
        default: return nil
        }
    }

    static func console(trophyPlatform: String?) -> String? {
        switch trophyPlatform?.split(separator: ",").first.map(String.init) {
        case "PS5": return "PlayStation 5"
        case "PS4": return "PlayStation 4"
        case "PS3": return "PlayStation 3"
        case "PSVITA": return "PlayStation Vita"
        default: return nil
        }
    }

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return precise.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    /// One game per title: the PS4 and PS5 versions of a game add up their play time,
    /// trophies come from the matching trophy set, and trophy sets with no play record
    /// (PS3, Vita, games played before Sony kept play time) are kept too.
    /// Sets worth asking about the story trophy: started, but not every trophy earned.
    static func needsStoryCheck(_ set: PSNGameTitle) -> Bool {
        (set.earnedTrophies?.total ?? 0) > 0 && (set.progress ?? 0) < 100
    }

    /// A trophy for finishing the story or the campaign, read from its (English) name and
    /// description. Sony doesn't mark these, so a set without such wording says nothing.
    static func isStoryTrophy(name: String?, detail: String?) -> Bool {
        let text = "\(name ?? "") \(detail ?? "")".lowercased().replacingOccurrences(of: "’", with: "'")
        let verbs = ["complete", "completed", "finish", "finished", "beat", "clear", "cleared", "end", "conclude", "concluded"]
        let objects = ["the game", "the story", "the main story", "the campaign", "the main campaign", "story mode",
                       "campaign mode", "the main quest", "the main game", "the journey", "the adventure",
                       "the final chapter", "the last chapter", "the final mission", "the last mission", "the final act"]
        if verbs.contains(where: { verb in objects.contains { text.contains("\(verb) \($0)") } }) { return true }
        let phrases = ["see the credits", "watch the credits", "roll the credits", "credits roll", "reach the credits",
                       "see the ending", "reach the ending", "reach an ending", "see an ending", "see the end of",
                       "main story complete", "story completed",
                       // In case Sony answers in French despite the en-US request.
                       "terminer l'histoire", "terminez l'histoire", "terminer le jeu", "terminez le jeu", "finir le jeu",
                       "finissez le jeu", "terminer la campagne", "terminez la campagne", "le générique"]
        return phrases.contains { text.contains($0) }
    }

    static func games(played: [PSNPlayedTitle], trophies: [PSNGameTitle], finishedSets: Set<String> = []) -> [ImportedGame] {
        // A game counts as finished if any of its sets (PS4 or PS5) has its story trophy.
        let finishedKeys = Set(trophies.filter { finishedSets.contains($0.npCommunicationId) }.map { Self.key($0.trophyTitleName) })

        var trophiesByKey: [String: PSNGameTitle] = [:]
        for set in trophies {
            let key = Self.key(set.trophyTitleName)
            // A game with several trophy sets (PS4 and PS5): the most played one speaks for it.
            if let existing = trophiesByKey[key], (existing.earnedTrophies?.total ?? 0) >= (set.earnedTrophies?.total ?? 0) { continue }
            trophiesByKey[key] = set
        }

        var order: [String] = []
        var grouped: [String: [PSNPlayedTitle]] = [:]
        for title in played {
            let key = Self.key(title.localizedName ?? title.name)
            guard !key.isEmpty else { continue }
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(title)
        }

        var games: [ImportedGame] = order.compactMap { key in
            guard let versions = grouped[key], let newest = versions.first else { return nil }
            let trophySet = trophiesByKey[key]
            let consoles = versions.compactMap { console(category: $0.category) }
            return ImportedGame(
                platform: .playstation,
                platformGameId: newest.concept?.id.map { "concept-\($0)" } ?? newest.titleId,
                title: newest.localizedName ?? newest.name,
                coverImageURL: newest.localizedImageUrl ?? newest.imageUrl ?? trophySet?.trophyTitleIconUrl,
                playtimeMinutes: versions.reduce(0) { $0 + minutes(fromDuration: $1.playDuration) },
                lastPlayed: versions.compactMap { date($0.lastPlayedDateTime) }.max(),
                achievementsEarned: trophySet?.earnedTrophies?.total ?? 0,
                achievementsTotal: trophySet?.definedTrophies?.total ?? 0,
                console: consoles.contains("PlayStation 5") ? "PlayStation 5" : consoles.first,
                storyCompleted: finishedKeys.contains(key) ? true : nil
            )
        }

        let playedKeys = Set(order)
        var seenTrophyKeys = Set<String>()
        for set in trophies {
            let key = Self.key(set.trophyTitleName)
            guard !playedKeys.contains(key), seenTrophyKeys.insert(key).inserted, let best = trophiesByKey[key] else { continue }
            games.append(ImportedGame(
                platform: .playstation,
                platformGameId: best.npCommunicationId,
                title: best.trophyTitleName,
                coverImageURL: best.trophyTitleIconUrl,
                lastPlayed: date(best.lastUpdatedDateTime),
                achievementsEarned: best.earnedTrophies?.total ?? 0,
                achievementsTotal: best.definedTrophies?.total ?? 0,
                console: console(trophyPlatform: best.trophyTitlePlatform),
                storyCompleted: finishedKeys.contains(key) ? true : nil
            ))
        }
        return games
    }
}

// MARK: - Token storage (Keychain, this device only)
enum PSNTokenStore {
    private static let service = "com.gameboxd.psn"
    private static let account = "tokens"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> PSNTokens? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(PSNTokens.self, from: data)
    }

    static func save(_ tokens: PSNTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - PlayStation Service
final class PlayStationService {
    static let shared = PlayStationService()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = ["Accept": "application/json", "Accept-Language": "fr-FR"]
        self.session = URLSession(configuration: config)
    }

    // MARK: Sign-in

    /// The code from Sony's sign-in page (the `code` of the redirect).
    func signIn(callback: URL) async throws {
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw PlayStationServiceError.signInFailed
        }
        try await exchange(code: code)
    }

    /// An NPSSO cookie pasted by the player (from `PlayStationConfig.npssoURL`). Accepts the
    /// whole JSON (`{"npsso":"…"}`) as well as the bare value.
    func signIn(npsso input: String) async throws {
        let npsso = Self.npssoValue(from: input)
        guard npsso.count >= 32 else { throw PlayStationServiceError.invalidNPSSO }

        var request = URLRequest(url: PlayStationConfig.signInURL)
        request.httpShouldHandleCookies = false
        request.setValue("npsso=\(npsso)", forHTTPHeaderField: "Cookie")
        let (_, response) = try await session.data(for: request, delegate: NoRedirects())
        guard let location = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location"),
              let callback = URL(string: location), callback.scheme == PlayStationConfig.callbackScheme else {
            throw PlayStationServiceError.invalidNPSSO
        }
        do {
            try await signIn(callback: callback)
        } catch PlayStationServiceError.signInFailed {
            throw PlayStationServiceError.invalidNPSSO
        }
    }

    static func npssoValue(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = object["npsso"] as? String {
            return value
        }
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    func signOut() {
        PSNTokenStore.clear()
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
        let refresh_token_expires_in: Int?
    }

    private func exchange(code: String) async throws {
        try await requestTokens([
            "code": code,
            "redirect_uri": PlayStationConfig.redirectURI,
            "grant_type": "authorization_code",
            "token_format": "jwt"
        ], keepingRefresh: nil)
    }

    private func requestTokens(_ form: [String: String], keepingRefresh previous: PSNTokens?) async throws {
        var request = URLRequest(url: URL(string: "\(PlayStationConfig.authURL)/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic \(PlayStationConfig.clientBasicAuth)", forHTTPHeaderField: "Authorization")
        var body = URLComponents()
        body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        // "+" means a space in a form body: encode it, or a scope or token with "+" breaks.
        request.httpBody = body.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let tokens = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw previous == nil ? PlayStationServiceError.signInFailed : PlayStationServiceError.tokenExpired
        }
        let now = Date()
        PSNTokenStore.save(PSNTokens(
            accessToken: tokens.access_token,
            refreshToken: tokens.refresh_token ?? previous?.refreshToken ?? "",
            accessExpiry: now.addingTimeInterval(TimeInterval(tokens.expires_in - 60)),
            refreshExpiry: tokens.refresh_token_expires_in.map { now.addingTimeInterval(TimeInterval($0)) }
                ?? previous?.refreshExpiry ?? now.addingTimeInterval(55 * 86_400)
        ))
    }

    private func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard let tokens = PSNTokenStore.load() else { throw PlayStationServiceError.notSignedIn }
        if !forceRefresh, tokens.accessExpiry > Date() { return tokens.accessToken }
        guard !tokens.refreshToken.isEmpty, tokens.refreshExpiry > Date() else { throw PlayStationServiceError.tokenExpired }
        try await requestTokens([
            "refresh_token": tokens.refreshToken,
            "grant_type": "refresh_token",
            "token_format": "jwt",
            "scope": PlayStationConfig.scope
        ], keepingRefresh: tokens)
        guard let fresh = PSNTokenStore.load() else { throw PlayStationServiceError.notSignedIn }
        return fresh.accessToken
    }

    // MARK: API

    private func get<T: Decodable>(_ path: String, _ query: [String: String] = [:], language: String? = nil,
                                   as type: T.Type) async throws -> T {
        var components = URLComponents(string: PlayStationConfig.apiURL + path)!
        if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = components.url else { throw PlayStationServiceError.networkError("URL") }

        var retried = false
        while true {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(try await accessToken(forceRefresh: retried))", forHTTPHeaderField: "Authorization")
            if let language { request.setValue(language, forHTTPHeaderField: "Accept-Language") }
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw PlayStationServiceError.networkError(error.localizedDescription)
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw PlayStationServiceError.decodingError("\(T.self) \(Self.describe(error))")
                }
            case 401 where !retried:
                retried = true // the token can be revoked before its expiry: refresh once
            case 401:
                throw PlayStationServiceError.tokenExpired
            case 429:
                throw PlayStationServiceError.rateLimited
            default:
                throw PlayStationServiceError.networkError("Code HTTP \(status)")
            }
        }
    }

    /// Which field didn't match, so a report from the app says what to fix.
    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return "" }
        let path: (DecodingError.Context) -> String = { $0.codingPath.map(\.stringValue).joined(separator: ".") }
        switch decodingError {
        case .keyNotFound(let key, let context): return "(\(path(context)).\(key.stringValue) manquant)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context): return "(\(path(context)) : type inattendu)"
        case .dataCorrupted(let context): return "(\(path(context)) illisible)"
        @unknown default: return ""
        }
    }

    func profile() async throws -> PSNProfileResponse {
        let summary = try await get("/trophy/v1/users/me/trophySummary", as: PSNTrophySummaryResponse.self)
        let user = try? await get("/userProfile/v1/internal/users/\(summary.accountId)/profiles", as: PSNUserProfileResponse.self)
        let avatar = user?.avatars?.first { $0.size == "xl" }?.url ?? user?.avatars?.last?.url
        return PSNProfileResponse(
            onlineId: user?.onlineId ?? "PlayStation",
            avatarUrl: avatar,
            trophyLevel: summary.trophyLevel,
            earnedTrophies: summary.earnedTrophies
        )
    }

    func playedTitles() async throws -> [PSNPlayedTitle] {
        var all: [PSNPlayedTitle] = []
        var offset = 0
        for _ in 0..<10 { // 2 000 games is plenty
            let page = try await get("/gamelist/v2/users/me/titles", [
                "categories": "ps4_game,ps5_native_game", "limit": "200", "offset": "\(offset)"
            ], as: PSNPlayedTitlesResponse.self)
            all += page.titles ?? []
            guard let next = page.nextOffset, next > offset, !(page.titles ?? []).isEmpty else { break }
            offset = next
        }
        return all
    }

    func trophyTitles() async throws -> [PSNGameTitle] {
        var all: [PSNGameTitle] = []
        for _ in 0..<5 {
            let page = try await get("/trophy/v1/users/me/trophyTitles", [
                "limit": "800", "offset": "\(all.count)"
            ], as: PSNGameListResponse.self)
            let titles = page.trophyTitles ?? []
            all += titles
            guard !titles.isEmpty, all.count < (page.totalItemCount ?? 0) else { break }
        }
        return all
    }

    /// Whether the story trophy of a set is earned: nil when the set has none.
    private func storyCompleted(_ set: PSNGameTitle) async throws -> Bool? {
        let path = "/npCommunicationIds/\(set.npCommunicationId)/trophyGroups/all/trophies"
        let service = ["npServiceName": (set.trophyTitlePlatform ?? "").contains("PS5") ? "trophy2" : "trophy"]
        async let defined = get("/trophy/v1" + path, service, language: "en-US", as: PSNTrophyListResponse.self)
        async let mine = get("/trophy/v1/users/me" + path, service, as: PSNTrophyListResponse.self)
        let story = Set((try await defined.trophies ?? [])
            .filter { PSNLibrary.isStoryTrophy(name: $0.trophyName, detail: $0.trophyDetail) }.map(\.trophyId))
        guard !story.isEmpty else { return nil }
        return try await mine.trophies?.contains { story.contains($0.trophyId) && $0.earned == true } ?? false
    }

    /// What the last story check did, shown after a sync (sets read, finished, failures).
    private(set) var lastStoryCheck = (checked: 0, failed: 0, firstError: String?.none)

    /// Answers kept per set and trophy count: a set only gets asked again once a trophy is won.
    private static let storyCacheKey = "gameboxd_psn_story_trophies_v2"
    private nonisolated static func storyCacheKey(_ set: PSNGameTitle) -> String {
        "\(set.npCommunicationId)-\(set.earnedTrophies?.total ?? 0)"
    }

    /// Sets whose story trophy is earned. Two requests per set the first time, a few at once;
    /// a set Sony won't answer for (rate limit, odd set) is simply not counted.
    func finishedSets(_ sets: [PSNGameTitle]) async -> Set<String> {
        var cache = UserDefaults.standard.dictionary(forKey: Self.storyCacheKey) as? [String: Bool] ?? [:]
        let toCheck = sets.filter { PSNLibrary.needsStoryCheck($0) && cache[Self.storyCacheKey($0)] == nil }
        var failed = 0
        var firstError: String?

        for chunk in stride(from: 0, to: toCheck.count, by: 6).map({ Array(toCheck[$0..<min($0 + 6, toCheck.count)]) }) {
            let answers = await withTaskGroup(of: (String, Result<Bool, Error>).self) { group in
                for set in chunk {
                    group.addTask { @MainActor in
                        do { return (Self.storyCacheKey(set), .success(try await self.storyCompleted(set) ?? false)) }
                        catch { return (Self.storyCacheKey(set), .failure(error)) }
                    }
                }
                var answers: [(String, Result<Bool, Error>)] = []
                for await answer in group { answers.append(answer) }
                return answers
            }
            for (key, answer) in answers {
                switch answer {
                case .success(let finished): cache[key] = finished
                case .failure(let error):
                    failed += 1
                    if firstError == nil { firstError = error.localizedDescription }
                }
            }
        }
        UserDefaults.standard.set(cache, forKey: Self.storyCacheKey)
        lastStoryCheck = (toCheck.count, failed, firstError)
        return Set(sets.filter { cache[Self.storyCacheKey($0)] == true }.map(\.npCommunicationId))
    }

    // MARK: - Full Library Sync

    /// Profile, played games and trophies of the signed-in account.
    func syncLibrary() async throws -> (games: [ImportedGame], profile: PSNProfileResponse) {
        let profile = try await profile()
        async let played = playedTitles()
        // Trophies are a bonus: a hiccup there shouldn't stop the import.
        async let trophies = (try? trophyTitles()) ?? []
        let trophySets = await trophies
        let finished = await finishedSets(trophySets)
        return (PSNLibrary.games(played: try await played, trophies: trophySets, finishedSets: finished), profile)
    }
}

/// Keeps Sony's redirect to the app scheme as a response instead of following it.
private nonisolated final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // The completion-handler form: the async one crashes the compiler (Xcode 26/27, SILGen).
        completionHandler(nil)
    }
}
