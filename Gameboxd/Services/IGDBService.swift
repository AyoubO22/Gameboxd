//
//  IGDBService.swift
//  Gameboxd
//
//  Official portrait box art from IGDB (Twitch). RAWG only has landscape
//  screenshots, which is why box fronts looked cropped.
//

import Foundation

enum IGDBConfig {
    // Set IGDB_CLIENT_ID and IGDB_CLIENT_SECRET in Secrets.xcconfig
    // (a free Twitch developer application). Without them the app keeps RAWG images.
    static var clientID: String { value(for: "IGDB_CLIENT_ID") }
    static var clientSecret: String { value(for: "IGDB_CLIENT_SECRET") }

    private static func value(for key: String) -> String {
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty { return v }
        return ProcessInfo.processInfo.environment[key] ?? ""
    }
}

final class IGDBService {
    static let shared = IGDBService()

    // ponytail: the client secret ships inside the app, so anyone can extract it and spend
    // our IGDB quota. Fine for a personal build; before the App Store, move the token
    // exchange behind a tiny proxy (e.g. a free Cloudflare Worker) and drop the secret here.
    var isConfigured: Bool { !IGDBConfig.clientID.isEmpty && !IGDBConfig.clientSecret.isEmpty }

    private var token: (value: String, expires: Date)?
    private var cache: [String: URL?] = [:]

    struct SearchResult: Decodable {
        struct Cover: Decodable { let image_id: String }
        let name: String
        let first_release_date: TimeInterval?
        let cover: Cover?
    }

    /// Portrait cover for a title. Nil when IGDB has no match; throws on network or auth
    /// errors, so callers can retry later instead of recording "not found".
    func boxArtURL(title: String, year: String?) async throws -> URL? {
        let key = "\(Self.normalize(title))|\(year ?? "")"
        if let cached = cache[key] { return cached }
        guard isConfigured else { return nil }

        let escaped = title.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "")
        let query = "search \"\(escaped)\"; fields name, first_release_date, cover.image_id; where cover != null; limit 10;"
        let results: [SearchResult] = try await post("games", body: query)
        let url = Self.bestMatch(in: results, title: title, year: year)
            .flatMap { $0.cover?.image_id }
            .flatMap { URL(string: "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\($0).jpg") }
        cache[key] = url
        return url
    }

    /// Exact title beats a partial one ("Portal" must not become "Portal 2"),
    /// then the closest release year (the original rather than a remake).
    static func bestMatch(in results: [SearchResult], title: String, year: String?) -> SearchResult? {
        let wanted = normalize(title)
        let wantedYear = year.flatMap(Int.init)
        func nameScore(_ r: SearchResult) -> Int {
            let name = normalize(r.name)
            if name == wanted { return 100 }
            return name.hasPrefix(wanted) || wanted.hasPrefix(name) ? 30 : 0
        }
        func score(_ r: SearchResult) -> Int {
            var s = nameScore(r)
            if let wantedYear, let date = r.first_release_date {
                let released = Calendar(identifier: .gregorian).component(.year, from: Date(timeIntervalSince1970: date))
                let gap = abs(released - wantedYear)
                s += gap == 0 ? 40 : gap == 1 ? 20 : 0
            }
            return s
        }
        // A title that doesn't match at all is never accepted, whatever its year.
        return results
            .filter { $0.cover != nil && nameScore($0) > 0 }
            .max { a, b in
                let (sa, sb) = (score(a), score(b))
                // Tie: the shorter name, i.e. the base game rather than an edition.
                return sa != sb ? sa < sb : a.name.count > b.name.count
            }
    }

    static func normalize(_ title: String) -> String {
        title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
            .map(String.init).joined()
            .split(separator: " ").joined(separator: " ")
    }

    // MARK: - HTTP

    private func post<T: Decodable>(_ endpoint: String, body: String) async throws -> T {
        var request = URLRequest(url: URL(string: "https://api.igdb.com/v4/\(endpoint)")!)
        request.httpMethod = "POST"
        request.setValue(IGDBConfig.clientID, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(body.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { token = nil }
        guard (200...299).contains(status) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func accessToken() async throws -> String {
        if let token, token.expires > Date() { return token.value }
        var components = URLComponents(string: "https://id.twitch.tv/oauth2/token")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: IGDBConfig.clientID),
            URLQueryItem(name: "client_secret", value: IGDBConfig.clientSecret),
            URLQueryItem(name: "grant_type", value: "client_credentials"),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
        struct Token: Decodable { let access_token: String; let expires_in: TimeInterval }
        let decoded = try JSONDecoder().decode(Token.self, from: data)
        token = (decoded.access_token, Date().addingTimeInterval(decoded.expires_in - 60))
        return decoded.access_token
    }
}
