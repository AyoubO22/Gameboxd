//
//  RAWGService.swift
//  Gameboxd
//
//  Network service for RAWG.io API
//

import Foundation
import Combine
import SwiftUI

// MARK: - API Configuration
enum RAWGConfig {
    // 🔑 RAWG API Key (https://rawg.io/apidocs)
    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String,
           !key.isEmpty {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["RAWG_API_KEY"], !key.isEmpty {
            return key
        }
        return "07fc16efc7a54bb49f8bcdd75e54147a"
    }
    static let baseURL = "https://api.rawg.io/api"
}

// MARK: - RAWG API Response Models
struct RAWGGameResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [RAWGGame]
}

struct RAWGGame: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let released: String?
    let backgroundImage: String?
    let rating: Double
    let ratingTop: Int
    let ratingsCount: Int
    let metacritic: Int?
    let playtime: Int
    let genres: [RAWGGenre]?
    let platforms: [RAWGPlatformWrapper]?
    let stores: [RAWGStoreWrapper]?
    let shortScreenshots: [RAWGScreenshot]?
    let developers: [RAWGDeveloper]?
    let publishers: [RAWGPublisher]?
    let description: String?
    let descriptionRaw: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, released, rating, metacritic, playtime, genres, platforms, stores, developers, publishers, description
        case backgroundImage = "background_image"
        case ratingTop = "rating_top"
        case ratingsCount = "ratings_count"
        case shortScreenshots = "short_screenshots"
        case descriptionRaw = "description_raw"
    }
}

struct RAWGGenre: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
}

struct RAWGPlatformWrapper: Codable {
    let platform: RAWGPlatform
}

struct RAWGPlatform: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
}

struct RAWGStoreWrapper: Codable {
    let store: RAWGStore
}

struct RAWGStore: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
}

struct RAWGScreenshot: Codable, Identifiable {
    let id: Int
    let image: String
}

struct RAWGDeveloper: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
}

struct RAWGPublisher: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
}

struct RAWGGameDetail: Codable {
    let id: Int
    let name: String
    let slug: String
    let released: String?
    let backgroundImage: String?
    let backgroundImageAdditional: String?
    let rating: Double
    let metacritic: Int?
    let playtime: Int
    let genres: [RAWGGenre]?
    let platforms: [RAWGPlatformWrapper]?
    let developers: [RAWGDeveloper]?
    let publishers: [RAWGPublisher]?
    let descriptionRaw: String?
    let website: String?
    let redditUrl: String?
    let metacriticUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug, released, rating, metacritic, playtime, genres, platforms, developers, publishers, website
        case backgroundImage = "background_image"
        case backgroundImageAdditional = "background_image_additional"
        case descriptionRaw = "description_raw"
        case redditUrl = "reddit_url"
        case metacriticUrl = "metacritic_url"
    }
}

struct RAWGScreenshotsResponse: Codable {
    let count: Int
    let results: [RAWGScreenshot]
}

// MARK: - RAWG Service
class RAWGService: ObservableObject {
    static let shared = RAWGService()
    
    @Published var isLoading = false
    @Published var error: String?
    
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
    
    var hasValidAPIKey: Bool {
        !RAWGConfig.apiKey.isEmpty
    }
    
    // MARK: - Search Games
    func searchGames(query: String, page: Int = 1, pageSize: Int = 20) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(RAWGConfig.baseURL)/games?key=\(RAWGConfig.apiKey)&search=\(encodedQuery)&page=\(page)&page_size=\(pageSize)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get Game Details
    func getGameDetails(id: Int) async throws -> RAWGGameDetail {
        guard hasValidAPIKey else { throw URLError(.userAuthenticationRequired) }
        
        let urlString = "\(RAWGConfig.baseURL)/games/\(id)?key=\(RAWGConfig.apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(RAWGGameDetail.self, from: data)
    }
    
    // MARK: - Get Screenshots
    func getScreenshots(gameId: Int) async throws -> [RAWGScreenshot] {
        guard hasValidAPIKey else { return [] }
        
        let urlString = "\(RAWGConfig.baseURL)/games/\(gameId)/screenshots?key=\(RAWGConfig.apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGScreenshotsResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get Trending Games
    func getTrendingGames(page: Int = 1) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let endDate = dateFormatter.string(from: Date())
        guard let start = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        let startDate = dateFormatter.string(from: start)
        
        let urlString = "\(RAWGConfig.baseURL)/games?key=\(RAWGConfig.apiKey)&dates=\(startDate),\(endDate)&ordering=-added&page=\(page)&page_size=10"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get New Releases
    func getNewReleases(page: Int = 1) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        guard let past = Calendar.current.date(byAdding: .month, value: -2, to: Date()) else { return [] }
        let pastDate = dateFormatter.string(from: past)
        
        let urlString = "\(RAWGConfig.baseURL)/games?key=\(RAWGConfig.apiKey)&dates=\(pastDate),\(today)&ordering=-released&page=\(page)&page_size=10"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get Top Rated
    func getTopRated(page: Int = 1) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let urlString = "\(RAWGConfig.baseURL)/games?key=\(RAWGConfig.apiKey)&ordering=-rating&page=\(page)&page_size=10&metacritic=80,100"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get Upcoming Games
    func getUpcomingGames(page: Int = 1) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        guard let future = Calendar.current.date(byAdding: .year, value: 1, to: Date()) else { return [] }
        let futureDate = dateFormatter.string(from: future)
        
        let urlString = "\(RAWGConfig.baseURL)/games?key=\(RAWGConfig.apiKey)&dates=\(today),\(futureDate)&ordering=released&page=\(page)&page_size=10"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get Similar Games
    func getSimilarGames(gameId: Int) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let urlString = "\(RAWGConfig.baseURL)/games/\(gameId)/suggested?key=\(RAWGConfig.apiKey)&page_size=6"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
    
    // MARK: - Get Games by Genre
    func getGamesByGenre(genreSlug: String, page: Int = 1) async throws -> [RAWGGame] {
        guard hasValidAPIKey else { return [] }
        
        let urlString = "\(RAWGConfig.baseURL)/games?key=\(RAWGConfig.apiKey)&genres=\(genreSlug)&ordering=-rating&page=\(page)&page_size=20"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(RAWGGameResponse.self, from: data)
        return response.results
    }
}

// MARK: - Convert RAWG Game to App Game Model
extension RAWGGame {
    func toGame() -> Game {
        let platformName = platforms?.first?.platform.name ?? "Unknown"
        let developerName = developers?.first?.name ?? "Unknown"
        let year = released?.prefix(4).description ?? "TBA"
        let genreList = genres?.map { $0.name } ?? []
        
        return Game(
            title: name,
            developer: developerName,
            platform: platformName,
            releaseYear: year,
            coverImageURL: backgroundImage,
            coverColor: .purple,
            rating: 0,
            status: .none,
            review: "",
            playTime: "",
            rawgId: id,
            genres: genreList,
            metacriticScore: metacritic,
            estimatedPlaytime: playtime,
            description: descriptionRaw ?? description
        )
    }
}
