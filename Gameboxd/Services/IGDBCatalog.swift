//
//  IGDBCatalog.swift
//  Gameboxd
//
//  Stand-in for RAWG when it's down (or has no key): search and the Discover shelves
//  come from IGDB instead, through the Gameboxd server. Results keep RAWG's shape so the
//  screens don't change; their ids are negative so they're never taken for RAWG ids.
//

import Foundation

enum IGDBCatalog {
    enum Shelf { case trending, newReleases, topRated, upcoming }

    private static let fields = "fields name,first_release_date,cover.image_id,genres.name,platforms.name,involved_companies.company.name,involved_companies.developer,summary,aggregated_rating;"
    /// Main games only: no editions, ports listed apart, or DLC.
    private static let mainGames = "cover != null & version_parent = null & parent_game = null"

    static func search(_ query: String, page: Int = 1, pageSize: Int = 20) async throws -> [RAWGGame] {
        let text = query.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "")
        return try await games("search \"\(text)\"; \(fields) where \(mainGames); limit \(pageSize); offset \((page - 1) * pageSize);")
    }

    static func shelf(_ shelf: Shelf, page: Int = 1) async throws -> [RAWGGame] {
        let now = Int(Date().timeIntervalSince1970)
        let day = 86_400
        let filter = switch shelf {
        case .trending: "where \(mainGames) & first_release_date > \(now - 30 * day) & first_release_date < \(now); sort hypes desc;"
        case .newReleases: "where \(mainGames) & first_release_date > \(now - 60 * day) & first_release_date < \(now) & hypes >= 3; sort first_release_date desc;"
        case .topRated: "where \(mainGames) & aggregated_rating >= 85 & aggregated_rating_count >= 5; sort aggregated_rating desc;"
        case .upcoming: "where \(mainGames) & first_release_date > \(now) & hypes >= 20; sort first_release_date asc;"
        }
        return try await games("\(fields) \(filter) limit 20; offset \((page - 1) * 20);")
    }

    private nonisolated struct Entry: Decodable {
        struct Named: Decodable { let id: Int; let name: String }
        struct Cover: Decodable { let image_id: String }
        struct Company: Decodable { let company: Named?; let developer: Bool? }
        let id: Int
        let name: String
        let first_release_date: TimeInterval?
        let cover: Cover?
        let genres: [Named]?
        let platforms: [Named]?
        let involved_companies: [Company]?
        let summary: String?
        let aggregated_rating: Double?
    }

    private static func games(_ query: String) async throws -> [RAWGGame] {
        let entries: [Entry] = try await IGDBService.shared.post("games", body: query)
        return entries.map(game)
    }

    private static func game(_ e: Entry) -> RAWGGame {
        let released = e.first_release_date.map { Date(timeIntervalSince1970: $0).formatted(.iso8601.year().month().day()) }
        let slug = e.name.lowercased()
        let developers = (e.involved_companies ?? []).filter { $0.developer == true }.compactMap(\.company)
        return RAWGGame(
            id: -e.id, name: e.name, slug: slug, released: released,
            backgroundImage: e.cover.map { "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\($0.image_id).jpg" },
            rating: 0, ratingTop: 5, ratingsCount: 0, metacritic: e.aggregated_rating.map { Int($0.rounded()) }, playtime: 0,
            genres: e.genres?.map { RAWGGenre(id: $0.id, name: $0.name, slug: $0.name.lowercased()) },
            platforms: e.platforms?.map { RAWGPlatformWrapper(platform: RAWGPlatform(id: $0.id, name: $0.name, slug: $0.name.lowercased())) },
            stores: nil, shortScreenshots: nil,
            developers: developers.map { RAWGDeveloper(id: $0.id, name: $0.name, slug: $0.name.lowercased()) },
            publishers: nil, description: nil, descriptionRaw: e.summary, esrbRating: nil
        )
    }
}
