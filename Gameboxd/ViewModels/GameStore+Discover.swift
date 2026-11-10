//
//  GameStore+Discover.swift
//  Gameboxd
//
//  Discover lists, search and game details from the games databases (RAWG, IGDB fallback).
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - API Methods
    
    func loadDiscoverData() async {
        discoverUnavailable = false // the shelves show their loading state while retrying
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in await self.fetchTrendingGames() }
            group.addTask { @MainActor in await self.fetchNewReleases() }
            group.addTask { @MainActor in await self.fetchTopRated() }
            group.addTask { @MainActor in await self.fetchUpcomingGames() }
        }
        discoverUnavailable = trendingGames.isEmpty && newReleases.isEmpty && topRated.isEmpty && upcomingGames.isEmpty
        guard !trendingGames.isEmpty || !newReleases.isEmpty else { return }
        discoverCacheDate = Date()
        saveDiscoverCache()
        await fillDiscoverBoxArt()
    }

    func saveDiscoverCache() {
        fileStore.save(DiscoverCache(date: discoverCacheDate ?? Date(), trending: trendingGames, newReleases: newReleases,
                                     topRated: topRated, upcoming: upcomingGames), key: StorageKeys.discoverCache)
    }

    /// Portrait box art for the Discover shelves, looked up in the background and applied
    /// in batches (not per game, which would redraw Discover 40 times).
    func fillDiscoverBoxArt() async {
        guard IGDBService.shared.isConfigured, !isFillingDiscoverArt else { return }
        isFillingDiscoverArt = true
        defer { isFillingDiscoverArt = false }

        let lists: [ReferenceWritableKeyPath<GameStore, [Game]>] = [\.trendingGames, \.newReleases, \.topRated, \.upcomingGames]
        var pending: [Int: String] = [:]
        var anyFound = false
        func apply() {
            guard !pending.isEmpty else { return }
            for list in lists {
                self[keyPath: list] = self[keyPath: list].map { game in
                    guard let id = game.rawgId, let art = pending[id] else { return game }
                    var updated = game
                    updated.boxArtURL = art
                    return updated
                }
            }
            pending = [:]
            anyFound = true
        }

        var seen = Set<Int>()
        let missing = lists.flatMap { self[keyPath: $0] }.filter { $0.boxArtURL == nil }
        for game in missing {
            guard let id = game.rawgId, seen.insert(id).inserted else { continue }
            let url: URL?
            do {
                url = try await IGDBService.shared.boxArtURL(title: game.title, year: game.releaseYear)
            } catch {
                break // offline: try again on the next refresh
            }
            pending[id] = url?.absoluteString ?? ""
            if pending.count >= 5 { apply() }
            try? await Task.sleep(for: .milliseconds(260))
        }
        apply()
        if anyFound { saveDiscoverCache() }
    }

    // MARK: - Discover cache
    // Discover opens instantly with the last lists; they refresh in the background when old.

    struct DiscoverCache: Codable {
        let date: Date
        let trending, newReleases, topRated, upcoming: [Game]
    }

    func loadDiscoverCache() {
        guard let cache = load(DiscoverCache.self, key: StorageKeys.discoverCache) else { return }
        trendingGames = cache.trending
        newReleases = cache.newReleases
        topRated = cache.topRated
        upcomingGames = cache.upcoming
        discoverCacheDate = cache.date
    }

    func refreshDiscoverIfStale() async {
        if let date = discoverCacheDate, Date().timeIntervalSince(date) < 6 * 3600 {
            await fillDiscoverBoxArt() // a fresh cache may still miss some covers
            return
        }
        await loadDiscoverData()
    }
    
    func fetchTrendingGames() async {
        isLoadingTrending = trendingGames.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getTrendingGames()
            trendingGames = RAWGService.distinct(games.map { $0.toGame() })
        } catch {
            print("Error fetching trending: \(error)")
        }
        isLoadingTrending = false
    }
    
    func fetchNewReleases() async {
        isLoadingNewReleases = newReleases.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getNewReleases()
            newReleases = RAWGService.distinct(games.map { $0.toGame() })
        } catch {
            print("Error fetching new releases: \(error)")
        }
        isLoadingNewReleases = false
    }
    
    func fetchTopRated() async {
        isLoadingTopRated = topRated.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getTopRated()
            topRated = RAWGService.distinct(games.map { $0.toGame() })
        } catch {
            print("Error fetching top rated: \(error)")
        }
        isLoadingTopRated = false
    }
    
    func fetchUpcomingGames() async {
        isLoadingUpcoming = upcomingGames.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getUpcomingGames()
            upcomingGames = RAWGService.distinct(games.map { $0.toGame() })
        } catch {
            print("Error fetching upcoming: \(error)")
        }
        isLoadingUpcoming = false
    }
    

    func searchGamesOnline(query: String) async {
        latestSearchQuery = query
        guard !query.isEmpty else {
            searchResults = []
            searchedQuery = ""
            searchFailed = false
            isSearching = false
            return
        }
        isSearching = true
        do {
            let games = try await rawgService.searchGames(query: query)
            // A slower, older request must not overwrite newer results.
            guard query == latestSearchQuery else { return }
            searchResults = games.map { $0.toGame() }
            searchFailed = false
        } catch {
            print("Error searching: \(error)")
            guard query == latestSearchQuery else { return }
            // Typing a new letter cancels the request: that isn't RAWG being down.
            if (error as? URLError)?.code != .cancelled, !(error is CancellationError) {
                searchResults = []
                searchFailed = true
            }
        }
        guard query == latestSearchQuery else { return }
        searchedQuery = query
        isSearching = false
    }
    
    func fetchSimilarGames(for game: Game) async -> [Game] {
        guard let rawgId = game.rawgId else { return [] }
        do {
            let games = try await rawgService.getSimilarGames(gameId: rawgId)
            return games.map { $0.toGame() }
        } catch {
            print("Error fetching similar: \(error)")
            return []
        }
    }
    
    func fetchGameDetails(for game: Game) async -> Game? {
        guard let rawgId = game.rawgId else { return nil }
        do {
            let details = try await rawgService.getGameDetails(id: rawgId)
            let screenshots = try await rawgService.getScreenshots(gameId: rawgId)
            
            var updatedGame = game
            updatedGame.description = details.descriptionRaw
            updatedGame.screenshotURLs = screenshots.map { $0.image }
            updatedGame.ageRating = details.esrbRating?.slug ?? ""
            if game.developer.isEmpty || game.developer == "Unknown" || game.developer == "—",
               let developer = details.developers?.first?.name {
                updatedGame.developer = developer
            }
            return updatedGame
        } catch {
            print("Error fetching details: \(error)")
            return nil
        }
    }
}
