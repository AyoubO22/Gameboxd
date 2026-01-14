//
//  GameStore.swift
//  Gameboxd
//
//  Central store for all app data with persistence
//

import SwiftUI
import Combine

@MainActor
class GameStore: ObservableObject {
    // MARK: - Published Properties
    @Published var myGames: [Game] = []
    @Published var playSessions: [PlaySession] = []
    @Published var gameLists: [GameList] = []
    @Published var userProfile: UserProfile = UserProfile()
    @Published var isLoggedIn: Bool = false
    
    // API Data
    @Published var trendingGames: [Game] = []
    @Published var newReleases: [Game] = []
    @Published var topRated: [Game] = []
    @Published var upcomingGames: [Game] = []
    @Published var searchResults: [Game] = []
    
    // Loading States
    @Published var isLoadingTrending = false
    @Published var isLoadingNewReleases = false
    @Published var isLoadingTopRated = false
    @Published var isLoadingUpcoming = false
    @Published var isSearching = false
    
    // Services
    private let rawgService = RAWGService.shared
    
    // Storage Keys
    private enum StorageKeys {
        static let myGames = "gameboxd_my_games"
        static let playSessions = "gameboxd_play_sessions"
        static let gameLists = "gameboxd_game_lists"
        static let userProfile = "gameboxd_user_profile"
        static let isLoggedIn = "gameboxd_is_logged_in"
    }
    
    // MARK: - Initialization
    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: StorageKeys.isLoggedIn)
        loadAllData()
        Task {
            await loadDiscoverData()
        }
    }
    
    // MARK: - Auth Methods
    func setLoggedIn(_ value: Bool) {
        isLoggedIn = value
        UserDefaults.standard.set(value, forKey: StorageKeys.isLoggedIn)
        if value {
            saveUserProfile()
        }
    }
    
    func logout() {
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: StorageKeys.isLoggedIn)
    }
    
    // MARK: - Persistence
    
    private func loadAllData() {
        loadGames()
        loadPlaySessions()
        loadGameLists()
        loadUserProfile()
    }
    
    private func loadGames() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.myGames),
           let decoded = try? JSONDecoder().decode([Game].self, from: data) {
            myGames = decoded
        } else {
            loadMockData()
        }
    }
    
    private func saveGames() {
        if let encoded = try? JSONEncoder().encode(myGames) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.myGames)
        }
    }
    
    private func loadPlaySessions() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.playSessions),
           let decoded = try? JSONDecoder().decode([PlaySession].self, from: data) {
            playSessions = decoded
        }
    }
    
    private func savePlaySessions() {
        if let encoded = try? JSONEncoder().encode(playSessions) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.playSessions)
        }
    }
    
    private func loadGameLists() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.gameLists),
           let decoded = try? JSONDecoder().decode([GameList].self, from: data) {
            gameLists = decoded
        } else {
            // Create default lists
            gameLists = [
                GameList(name: "Mon Top 10", description: "Mes jeux préférés de tous les temps", iconName: "star.fill", color: .yellow, isDefault: true),
                GameList(name: "À découvrir", description: "Jeux recommandés par des amis", iconName: "lightbulb.fill", color: .orange, isDefault: true)
            ]
            saveGameLists()
        }
    }
    
    private func saveGameLists() {
        if let encoded = try? JSONEncoder().encode(gameLists) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.gameLists)
        }
    }
    
    private func loadUserProfile() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.userProfile),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = decoded
        }
    }
    
    private func saveUserProfile() {
        if let encoded = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.userProfile)
        }
    }
    
    // MARK: - API Methods
    
    func loadDiscoverData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTrendingGames() }
            group.addTask { await self.fetchNewReleases() }
            group.addTask { await self.fetchTopRated() }
            group.addTask { await self.fetchUpcomingGames() }
        }
    }
    
    func fetchTrendingGames() async {
        isLoadingTrending = true
        do {
            let games = try await rawgService.getTrendingGames()
            trendingGames = games.map { $0.toGame() }
        } catch {
            print("Error fetching trending: \(error)")
        }
        isLoadingTrending = false
    }
    
    func fetchNewReleases() async {
        isLoadingNewReleases = true
        do {
            let games = try await rawgService.getNewReleases()
            newReleases = games.map { $0.toGame() }
        } catch {
            print("Error fetching new releases: \(error)")
        }
        isLoadingNewReleases = false
    }
    
    func fetchTopRated() async {
        isLoadingTopRated = true
        do {
            let games = try await rawgService.getTopRated()
            topRated = games.map { $0.toGame() }
        } catch {
            print("Error fetching top rated: \(error)")
        }
        isLoadingTopRated = false
    }
    
    func fetchUpcomingGames() async {
        isLoadingUpcoming = true
        do {
            let games = try await rawgService.getUpcomingGames()
            upcomingGames = games.map { $0.toGame() }
        } catch {
            print("Error fetching upcoming: \(error)")
        }
        isLoadingUpcoming = false
    }
    
    func searchGamesOnline(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            let games = try await rawgService.searchGames(query: query)
            searchResults = games.map { $0.toGame() }
        } catch {
            print("Error searching: \(error)")
        }
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
            return updatedGame
        } catch {
            print("Error fetching details: \(error)")
            return nil
        }
    }
    
    // MARK: - Game CRUD
    
    func updateGame(_ game: Game) {
        if let index = myGames.firstIndex(where: { $0.id == game.id }) {
            myGames[index] = game
        } else {
            var newGame = game
            if newGame.status == .none {
                newGame = Game(
                    id: newGame.id,
                    title: newGame.title,
                    developer: newGame.developer,
                    platform: newGame.platform,
                    releaseYear: newGame.releaseYear,
                    coverImageURL: newGame.coverImageURL,
                    coverColor: newGame.coverColor,
                    rating: newGame.rating,
                    subRatings: newGame.subRatings,
                    status: .wantToPlay,
                    review: newGame.review,
                    isSpoiler: newGame.isSpoiler,
                    playTime: newGame.playTime,
                    playTimeMinutes: newGame.playTimeMinutes,
                    completionPercentage: newGame.completionPercentage,
                    difficulty: newGame.difficulty,
                    moodTags: newGame.moodTags,
                    priority: newGame.priority,
                    isFavorite: newGame.isFavorite,
                    startedDate: Date(),
                    completedDate: newGame.completedDate,
                    rawgId: newGame.rawgId,
                    genres: newGame.genres,
                    metacriticScore: newGame.metacriticScore,
                    estimatedPlaytime: newGame.estimatedPlaytime,
                    description: newGame.description,
                    screenshotURLs: newGame.screenshotURLs,
                    playthroughCount: newGame.playthroughCount,
                    notes: newGame.notes
                )
            }
            myGames.append(newGame)
        }
        saveGames()
    }
    
    func deleteGame(at offsets: IndexSet) {
        myGames.remove(atOffsets: offsets)
        saveGames()
    }
    
    func deleteGame(_ game: Game) {
        myGames.removeAll { $0.id == game.id }
        saveGames()
    }
    
    func toggleFavorite(_ game: Game) {
        if let index = myGames.firstIndex(where: { $0.id == game.id }) {
            myGames[index].isFavorite.toggle()
            saveGames()
        }
    }
    
    // MARK: - Library Helpers
    
    func isInLibrary(_ game: Game) -> Bool {
        myGames.contains { $0.title == game.title && $0.developer == game.developer }
    }
    
    func libraryGame(for game: Game) -> Game? {
        myGames.first { $0.title == game.title && $0.developer == game.developer }
    }
    
    func gamesCount(for status: GameStatus) -> Int {
        myGames.filter { $0.status == status }.count
    }
    
    // MARK: - Play Session Methods
    
    func addPlaySession(_ session: PlaySession) {
        playSessions.insert(session, at: 0)
        
        // Update game's total play time
        if let index = myGames.firstIndex(where: { $0.id == session.gameId }) {
            myGames[index].playTimeMinutes += session.duration
        }
        
        savePlaySessions()
        saveGames()
    }
    
    func deletePlaySession(_ session: PlaySession) {
        if let index = myGames.firstIndex(where: { $0.id == session.gameId }) {
            myGames[index].playTimeMinutes -= session.duration
        }
        playSessions.removeAll { $0.id == session.id }
        savePlaySessions()
        saveGames()
    }
    
    func sessionsForGame(_ game: Game) -> [PlaySession] {
        playSessions.filter { $0.gameId == game.id }
    }
    
    func sessionsForDate(_ date: Date) -> [PlaySession] {
        playSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    func recentSessions(limit: Int = 10) -> [PlaySession] {
        Array(playSessions.prefix(limit))
    }
    
    // MARK: - Game Lists Methods
    
    func createList(_ list: GameList) {
        gameLists.append(list)
        saveGameLists()
    }
    
    func updateList(_ list: GameList) {
        if let index = gameLists.firstIndex(where: { $0.id == list.id }) {
            gameLists[index] = list
            saveGameLists()
        }
    }
    
    func deleteList(_ list: GameList) {
        gameLists.removeAll { $0.id == list.id }
        saveGameLists()
    }
    
    func addGameToList(_ game: Game, list: GameList) {
        if let index = gameLists.firstIndex(where: { $0.id == list.id }) {
            if !gameLists[index].gameIds.contains(game.id) {
                gameLists[index].gameIds.append(game.id)
                gameLists[index].updatedDate = Date()
                saveGameLists()
            }
        }
    }
    
    func removeGameFromList(_ game: Game, list: GameList) {
        if let index = gameLists.firstIndex(where: { $0.id == list.id }) {
            gameLists[index].gameIds.removeAll { $0 == game.id }
            gameLists[index].updatedDate = Date()
            saveGameLists()
        }
    }
    
    func gamesInList(_ list: GameList) -> [Game] {
        list.gameIds.compactMap { id in
            myGames.first { $0.id == id }
        }
    }
    
    // MARK: - Profile Methods
    
    func updateProfile(_ profile: UserProfile) {
        userProfile = profile
        saveUserProfile()
    }
    
    func addFavoriteGame(_ game: Game) {
        guard userProfile.favoriteGameIds.count < 4 else { return }
        if !userProfile.favoriteGameIds.contains(game.id) {
            userProfile.favoriteGameIds.append(game.id)
            saveUserProfile()
        }
    }
    
    func removeFavoriteGame(_ game: Game) {
        userProfile.favoriteGameIds.removeAll { $0 == game.id }
        saveUserProfile()
    }
    
    func favoriteGames() -> [Game] {
        userProfile.favoriteGameIds.compactMap { id in
            myGames.first { $0.id == id }
        }
    }
    
    // MARK: - Statistics
    
    var totalGames: Int { myGames.count }
    
    var totalPlayTimeMinutes: Int {
        myGames.reduce(0) { $0 + $1.playTimeMinutes }
    }
    
    var totalPlayTimeFormatted: String {
        let hours = totalPlayTimeMinutes / 60
        return "\(hours)h"
    }
    
    var averageRating: Double {
        let ratedGames = myGames.filter { $0.rating > 0 }
        guard !ratedGames.isEmpty else { return 0 }
        return Double(ratedGames.reduce(0) { $0 + $1.rating }) / Double(ratedGames.count)
    }
    
    var completedThisYear: Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return myGames.filter { game in
            guard let completedDate = game.completedDate else { return false }
            return calendar.component(.year, from: completedDate) == currentYear && 
                   (game.status == .completed || game.status == .platinum)
        }.count
    }
    
    var yearlyProgress: Double {
        guard userProfile.yearlyGoal > 0 else { return 0 }
        return min(Double(completedThisYear) / Double(userProfile.yearlyGoal), 1.0)
    }
    
    var topGenres: [(String, Int)] {
        var genreCounts: [String: Int] = [:]
        for game in myGames {
            for genre in game.genres {
                genreCounts[genre, default: 0] += 1
            }
        }
        return genreCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    var topPlatforms: [(String, Int)] {
        var platformCounts: [String: Int] = [:]
        for game in myGames {
            platformCounts[game.platform, default: 0] += 1
        }
        return platformCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }
    
    func getYearStats(for year: Int) -> YearStats {
        let calendar = Calendar.current
        let gamesThisYear = myGames.filter { game in
            if let started = game.startedDate {
                return calendar.component(.year, from: started) == year
            }
            return false
        }
        
        let completedThisYear = myGames.filter { game in
            guard let completed = game.completedDate else { return false }
            return calendar.component(.year, from: completed) == year
        }
        
        let totalTime = gamesThisYear.reduce(0) { $0 + $1.playTimeMinutes }
        
        let ratedGames = gamesThisYear.filter { $0.rating > 0 }
        let avgRating = ratedGames.isEmpty ? 0 : Double(ratedGames.reduce(0) { $0 + $1.rating }) / Double(ratedGames.count)
        
        let favoriteGame = gamesThisYear.max { $0.rating < $1.rating }
        let mostPlayed = gamesThisYear.max { $0.playTimeMinutes < $1.playTimeMinutes }
        
        return YearStats(
            year: year,
            gamesPlayed: gamesThisYear.count,
            gamesCompleted: completedThisYear.count,
            totalPlayTime: totalTime,
            averageRating: avgRating,
            topGenres: topGenres,
            topPlatforms: topPlatforms,
            favoriteGame: favoriteGame,
            mostPlayedGame: mostPlayed
        )
    }
    
    // MARK: - Backlog
    
    var backlog: [Game] {
        myGames
            .filter { $0.status == .wantToPlay }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }
    
    func randomBacklogPick() -> Game? {
        backlog.randomElement()
    }
    
    // MARK: - Mock Data
    
    private func loadMockData() {
        myGames = [
            Game(title: "The Legend of Zelda: TOTK", developer: "Nintendo", platform: "Switch", releaseYear: "2023", coverColor: .green, rating: 5, status: .playing, review: "Une liberté totale, c'est fou.", playTime: "45h", playTimeMinutes: 2700, startedDate: Date(), genres: ["Action", "Adventure"]),
            Game(title: "Elden Ring", developer: "FromSoftware", platform: "PS5", releaseYear: "2022", coverColor: .yellow, rating: 5, status: .completed, review: "Difficile mais le monde est magnifique.", playTime: "120h", playTimeMinutes: 7200, completionPercentage: 100, moodTags: [.challenging, .beautiful], completedDate: Date(), genres: ["Action RPG", "Souls-like"]),
            Game(title: "Hollow Knight", developer: "Team Cherry", platform: "PC", releaseYear: "2017", coverColor: .blue.opacity(0.7), rating: 4, status: .completed, review: "Ambiance mélancolique incroyable.", playTime: "30h", playTimeMinutes: 1800, genres: ["Metroidvania", "Indie"])
        ]
    }
}
