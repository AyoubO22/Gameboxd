//
//  GameStore.swift
//  Gameboxd
//
//  Central store for all app data with persistence
//

import SwiftUI
import Combine
import UserNotifications

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
    
    // NEW: Achievements, Themes, Social
    @Published var achievements: [Achievement] = []
    @Published var currentTheme: AppTheme = .default
    @Published var customTags: [CustomTag] = []
    @Published var friends: [Friend] = []
    @Published var activityFeed: [ActivityItem] = []
    @Published var notifications: [GameNotification] = []
    @Published var recentlyUnlockedAchievements: [Achievement] = []
    
    // Monthly Goals
    @Published var monthlyGoals: [MonthlyGoal] = []
    @Published var completedGoals: [MonthlyGoal] = []
    
    // Notification Settings
    @Published var releaseReminders: Bool = true
    @Published var weeklyDigest: Bool = false
    @Published var achievementAlerts: Bool = true
    
    // Services
    private let rawgService = RAWGService.shared
    private let securityManager = SecurityManager.shared
    
    // Storage Keys
    private enum StorageKeys {
        static let myGames = "gameboxd_my_games"
        static let playSessions = "gameboxd_play_sessions"
        static let gameLists = "gameboxd_game_lists"
        static let userProfile = "gameboxd_user_profile"
        static let isLoggedIn = "gameboxd_is_logged_in"
        static let achievements = "gameboxd_achievements"
        static let currentTheme = "gameboxd_theme"
        static let customTags = "gameboxd_custom_tags"
        static let friends = "gameboxd_friends"
        static let releaseReminders = "gameboxd_release_reminders"
        static let weeklyDigest = "gameboxd_weekly_digest"
        static let achievementAlerts = "gameboxd_achievement_alerts"
        static let monthlyGoals = "gameboxd_monthly_goals"
        static let completedGoals = "gameboxd_completed_goals"
    }
    
    // MARK: - Initialization
    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: StorageKeys.isLoggedIn)
        loadAllData()
        loadSettings()
        initializeAchievements()
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
    
    // MARK: - Settings
    
    private func loadSettings() {
        releaseReminders = UserDefaults.standard.object(forKey: StorageKeys.releaseReminders) as? Bool ?? true
        weeklyDigest = UserDefaults.standard.bool(forKey: StorageKeys.weeklyDigest)
        achievementAlerts = UserDefaults.standard.object(forKey: StorageKeys.achievementAlerts) as? Bool ?? true
        
        if let themeRaw = UserDefaults.standard.string(forKey: StorageKeys.currentTheme),
           let theme = AppTheme(rawValue: themeRaw) {
            currentTheme = theme
            ThemeManager.shared.currentTheme = theme
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(releaseReminders, forKey: StorageKeys.releaseReminders)
        UserDefaults.standard.set(weeklyDigest, forKey: StorageKeys.weeklyDigest)
        UserDefaults.standard.set(achievementAlerts, forKey: StorageKeys.achievementAlerts)
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        ThemeManager.shared.currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: StorageKeys.currentTheme)
        objectWillChange.send()
    }
    
    // MARK: - Persistence
    
    private func loadAllData() {
        loadGames()
        loadPlaySessions()
        loadGameLists()
        loadUserProfile()
        loadAchievements()
        loadCustomTags()
        loadFriends()
        loadMonthlyGoals()
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
        checkAchievements()
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
        var sanitizedGame = game
        sanitizedGame.review = securityManager.sanitizeInput(game.review)
        sanitizedGame.notes = securityManager.sanitizeInput(game.notes)
        if let index = myGames.firstIndex(where: { $0.id == game.id }) {
            myGames[index] = sanitizedGame
        } else {
            var newGame = sanitizedGame
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
        
        // Sync favorite state with userProfile
        syncFavoriteIds(for: sanitizedGame)
        
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
            
            // Sync with userProfile.favoriteGameIds
            if myGames[index].isFavorite {
                if !userProfile.favoriteGameIds.contains(game.id) && userProfile.favoriteGameIds.count < 4 {
                    userProfile.favoriteGameIds.append(game.id)
                }
            } else {
                userProfile.favoriteGameIds.removeAll { $0 == game.id }
            }
            
            saveGames()
            saveUserProfile()
        }
    }
    
    private func syncFavoriteIds(for game: Game) {
        if game.isFavorite {
            if !userProfile.favoriteGameIds.contains(game.id) && userProfile.favoriteGameIds.count < 4 {
                userProfile.favoriteGameIds.append(game.id)
                saveUserProfile()
            }
        } else {
            if userProfile.favoriteGameIds.contains(game.id) {
                userProfile.favoriteGameIds.removeAll { $0 == game.id }
                saveUserProfile()
            }
        }
    }
    
    // MARK: - Library Helpers
    
    func isInLibrary(_ game: Game) -> Bool {
        if let rawgId = game.rawgId {
            return myGames.contains { $0.rawgId == rawgId }
        }
        return myGames.contains {
            $0.id == game.id ||
            ($0.title == game.title && $0.developer == game.developer && $0.platform == game.platform)
        }
    }
    
    func libraryGame(for game: Game) -> Game? {
        if let rawgId = game.rawgId {
            return myGames.first { $0.rawgId == rawgId }
        }
        return myGames.first {
            $0.id == game.id ||
            ($0.title == game.title && $0.developer == game.developer && $0.platform == game.platform)
        }
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
            myGames[index].playTimeMinutes = max(0, myGames[index].playTimeMinutes - session.duration)
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
        // First try userProfile favorites (pinned order)
        let pinned = userProfile.favoriteGameIds.compactMap { id in
            myGames.first { $0.id == id }
        }
        if !pinned.isEmpty { return pinned }
        
        // Fallback: games with isFavorite flag
        return Array(myGames.filter { $0.isFavorite }.prefix(4))
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
    
    // MARK: - Achievements System
    
    private func initializeAchievements() {
        // If no achievements exist, create them from definitions
        if achievements.isEmpty {
            achievements = AchievementDefinitions.all.map { def in
                Achievement(
                    id: def.id,
                    title: def.title,
                    description: def.description,
                    icon: def.icon,
                    category: def.category,
                    requirement: def.requirement,
                    currentProgress: 0,
                    isUnlocked: false
                )
            }
        }
    }
    
    private func loadAchievements() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.achievements),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = decoded
        }
    }
    
    private func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.achievements)
        }
    }
    
    func checkAchievements() {
        var newlyUnlocked: [Achievement] = []
        
        for i in achievements.indices {
            let oldUnlocked = achievements[i].isUnlocked
            
            switch achievements[i].id {
            case "first_game":
                achievements[i].currentProgress = min(myGames.count, 1)
            case "collector_10":
                achievements[i].currentProgress = min(myGames.count, 10)
            case "collector_50":
                achievements[i].currentProgress = min(myGames.count, 50)
            case "collector_100":
                achievements[i].currentProgress = min(myGames.count, 100)
            case "complete_10":
                let completed = myGames.filter { $0.status == .completed || $0.status == .platinum }.count
                achievements[i].currentProgress = min(completed, 10)
            case "complete_25":
                let completed = myGames.filter { $0.status == .completed || $0.status == .platinum }.count
                achievements[i].currentProgress = min(completed, 25)
            case "platinum_5":
                let platinums = myGames.filter { $0.status == .platinum }.count
                achievements[i].currentProgress = min(platinums, 5)
            case "time_100":
                let hours = totalPlayTimeMinutes / 60
                achievements[i].currentProgress = min(hours, 100)
            case "time_500":
                let hours = totalPlayTimeMinutes / 60
                achievements[i].currentProgress = min(hours, 500)
            case "time_1000":
                let hours = totalPlayTimeMinutes / 60
                achievements[i].currentProgress = min(hours, 1000)
            case "genres_5":
                let uniqueGenres = Set(myGames.flatMap { $0.genres })
                achievements[i].currentProgress = min(uniqueGenres.count, 5)
            case "platforms_3":
                let uniquePlatforms = Set(myGames.map { $0.platform })
                achievements[i].currentProgress = min(uniquePlatforms.count, 3)
            case "reviews_10":
                let reviews = myGames.filter { !$0.review.isEmpty }.count
                achievements[i].currentProgress = min(reviews, 10)
            case "streak_7":
                achievements[i].currentProgress = min(calculatePlayStreak(), 7)
            case "streak_30":
                achievements[i].currentProgress = min(calculatePlayStreak(), 30)
            case "favorite_genre":
                if let topGenre = topGenres.first, topGenre.1 >= 10 {
                    achievements[i].currentProgress = 10
                }
            case "lists_5":
                achievements[i].currentProgress = min(gameLists.count, 5)
            case "indie_lover":
                let indieGames = myGames.filter { $0.genres.contains("Indie") }.count
                achievements[i].currentProgress = min(indieGames, 20)
            case "retro_gamer":
                let retroGames = myGames.filter {
                    guard let year = Int($0.releaseYear) else { return false }
                    return year < 2000
                }.count
                achievements[i].currentProgress = min(retroGames, 10)
            default:
                break
            }
            
            // Check if newly unlocked
            if achievements[i].currentProgress >= achievements[i].requirement && !oldUnlocked {
                achievements[i].isUnlocked = true
                achievements[i].unlockedDate = Date()
                newlyUnlocked.append(achievements[i])
            }
        }
        
        if !newlyUnlocked.isEmpty {
            recentlyUnlockedAchievements = newlyUnlocked
            saveAchievements()
            
            if achievementAlerts {
                for achievement in newlyUnlocked {
                    sendAchievementNotification(achievement)
                }
            }
        }
    }
    
    private func calculatePlayStreak() -> Int {
        // Calculate consecutive days with play sessions
        guard !playSessions.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        var streak = 1
        var currentDate = calendar.startOfDay(for: Date())
        
        // Check if played today
        let playedToday = playSessions.contains { calendar.isDate($0.date, inSameDayAs: currentDate) }
        if !playedToday {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        while true {
            let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            let playedPreviousDay = playSessions.contains { calendar.isDate($0.date, inSameDayAs: previousDay) }
            
            if playedPreviousDay {
                streak += 1
                currentDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }
    }
    
    var lockedAchievements: [Achievement] {
        achievements.filter { !$0.isUnlocked }
    }
    
    func achievementProgress() -> Double {
        guard !achievements.isEmpty else { return 0 }
        return Double(unlockedAchievements.count) / Double(achievements.count)
    }
    
    // MARK: - Custom Tags
    
    private func loadCustomTags() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.customTags),
           let decoded = try? JSONDecoder().decode([CustomTag].self, from: data) {
            customTags = decoded
        }
    }
    
    func saveCustomTags() {
        if let encoded = try? JSONEncoder().encode(customTags) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.customTags)
        }
    }
    
    func addCustomTag(_ tag: CustomTag) {
        customTags.append(tag)
        saveCustomTags()
    }
    
    func removeCustomTag(_ tag: CustomTag) {
        customTags.removeAll { $0.id == tag.id }
        saveCustomTags()
    }
    
    // MARK: - Friends & Social
    
    private func loadFriends() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.friends),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            friends = decoded
        }
    }
    
    private func saveFriends() {
        if let encoded = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.friends)
        }
    }
    
    // MARK: - Monthly Goals
    
    private func loadMonthlyGoals() {
        if let data = UserDefaults.standard.data(forKey: StorageKeys.monthlyGoals),
           let decoded = try? JSONDecoder().decode([MonthlyGoal].self, from: data) {
            monthlyGoals = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StorageKeys.completedGoals),
           let decoded = try? JSONDecoder().decode([MonthlyGoal].self, from: data) {
            completedGoals = decoded
        }
    }
    
    private func saveMonthlyGoals() {
        if let encoded = try? JSONEncoder().encode(monthlyGoals) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.monthlyGoals)
        }
        if let encoded = try? JSONEncoder().encode(completedGoals) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.completedGoals)
        }
    }
    
    func addMonthlyGoal(_ goal: MonthlyGoal) {
        monthlyGoals.append(goal)
        saveMonthlyGoals()
    }
    
    func updateGoalProgress() {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())
        
        for i in monthlyGoals.indices {
            // Check if goal is for current month
            guard calendar.component(.month, from: monthlyGoals[i].month) == currentMonth,
                  calendar.component(.year, from: monthlyGoals[i].month) == currentYear else {
                continue
            }
            
                        guard let monthStart = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)),
                                    let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
                                continue
                        }
            
            switch monthlyGoals[i].type {
            case .gamesCompleted:
                let completed = myGames.filter { game in
                    guard let completedDate = game.completedDate else { return false }
                    return completedDate >= monthStart && completedDate <= monthEnd &&
                           (game.status == .completed || game.status == .platinum)
                }.count
                monthlyGoals[i].current = completed
                
            case .hoursPlayed:
                let sessions = playSessions.filter { $0.date >= monthStart && $0.date <= monthEnd }
                let totalMinutes = sessions.reduce(0) { $0 + $1.duration }
                monthlyGoals[i].current = totalMinutes / 60
                
            case .reviewsWritten:
                let reviews = myGames.filter { game in
                    guard let reviewed = game.startedDate, !game.review.isEmpty else { return false }
                    return reviewed >= monthStart && reviewed <= monthEnd
                }.count
                monthlyGoals[i].current = reviews
                
            case .newGames:
                let newGames = myGames.filter { game in
                    guard let started = game.startedDate else { return false }
                    return started >= monthStart && started <= monthEnd
                }.count
                monthlyGoals[i].current = newGames
                
            case .platinums:
                let platinums = myGames.filter { game in
                    guard let completedDate = game.completedDate else { return false }
                    return completedDate >= monthStart && completedDate <= monthEnd &&
                           game.status == .platinum
                }.count
                monthlyGoals[i].current = platinums
                
            case .backlogCleared:
                // For backlog cleared, we count games completed this month
                // (since they were likely in backlog before being completed)
                let cleared = myGames.filter { game in
                    guard let completedDate = game.completedDate else { return false }
                    return completedDate >= monthStart && completedDate <= monthEnd &&
                           (game.status == .completed || game.status == .platinum)
                }.count
                monthlyGoals[i].current = cleared
            }
            
            // Check if goal is completed
            if monthlyGoals[i].current >= monthlyGoals[i].target && monthlyGoals[i].completedDate == nil {
                monthlyGoals[i].completedDate = Date()
                completedGoals.append(monthlyGoals[i])
            }
        }
        
        saveMonthlyGoals()
    }
    
    func removeMonthlyGoal(_ goal: MonthlyGoal) {
        monthlyGoals.removeAll { $0.id == goal.id }
        saveMonthlyGoals()
    }
    
    func addFriend(_ friend: Friend) {
        var newFriend = friend
        newFriend.isFollowing = true
        friends.append(newFriend)
        saveFriends()
        generateMockActivity(for: newFriend)
    }
    
    func removeFriend(_ friend: Friend) {
        friends.removeAll { $0.id == friend.id }
        activityFeed.removeAll { $0.username == friend.username }
        saveFriends()
    }
    
    func toggleFollowFriend(_ friend: Friend) {
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index].isFollowing.toggle()
            if !friends[index].isFollowing {
                activityFeed.removeAll { $0.username == friend.username }
            } else {
                generateMockActivity(for: friends[index])
            }
            saveFriends()
        }
    }
    
    private func generateMockActivity(for friend: Friend) {
        // Generate some mock activity for demo purposes
        let mockGames = ["The Witcher 3", "Red Dead Redemption 2", "God of War", "Hades", "Celeste"]
        let mockCovers = [
            "https://media.rawg.io/media/games/618/618c2031a07bbff6b4f611f10b6f6f92.jpg",
            "https://media.rawg.io/media/games/511/5118aff5091cb3efec399c808f8c598f.jpg"
        ]
        
        for i in 0..<2 {
            let activity = ActivityItem(
                id: UUID(),
                username: friend.username,
                avatarEmoji: friend.avatarEmoji,
                actionType: [.played, .completed, .rated].randomElement() ?? .played,
                gameTitle: mockGames.randomElement() ?? "Unknown Game",
                gameCoverURL: mockCovers.randomElement(),
                rating: Int.random(in: 3...5),
                review: i == 0 ? "Incroyable jeu!" : nil,
                timestamp: Date().addingTimeInterval(Double(-i * 3600))
            )
            activityFeed.append(activity)
        }
        activityFeed.sort { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Notifications
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    func scheduleReleaseReminder(for game: Game, on date: Date) {
        guard releaseReminders else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🎮 Sortie aujourd'hui!"
        content.body = "\(game.title) sort aujourd'hui!"
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "release_\(game.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendAchievementNotification(_ achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 Succès débloqué!"
        content.body = "\(achievement.icon) \(achievement.title)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_\(achievement.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Import/Export
    
    struct ExportData: Codable {
        let games: [Game]
        let playSessions: [PlaySession]
        let gameLists: [GameList]
        let userProfile: UserProfile
        let customTags: [CustomTag]
        let exportDate: Date
        let appVersion: String
    }
    
    func exportData() -> URL? {
        let exportData = ExportData(
            games: myGames,
            playSessions: playSessions,
            gameLists: gameLists,
            userProfile: userProfile,
            customTags: customTags,
            exportDate: Date(),
            appVersion: "1.0"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(exportData) else { return nil }
        
        let fileName = "gameboxd_backup_\(Date().formatted(.dateTime.year().month().day())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
    
    func importData(from url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importedData = try decoder.decode(ExportData.self, from: data)
            
            // Merge or replace data
            myGames = importedData.games
            playSessions = importedData.playSessions
            gameLists = importedData.gameLists
            userProfile = importedData.userProfile
            customTags = importedData.customTags
            
            // Save all data
            saveGames()
            savePlaySessions()
            saveGameLists()
            saveUserProfile()
            saveCustomTags()
            checkAchievements()
            
            return true
        } catch {
            print("Import error: \(error)")
            return false
        }
    }
    
    // MARK: - Delete All Data
    
    func deleteAllData() {
        // Clear all data
        myGames = []
        playSessions = []
        gameLists = []
        customTags = []
        friends = []
        activityFeed = []
        achievements = []
        
        // Reset profile but keep username
        let username = userProfile.username
        userProfile = UserProfile()
        userProfile.username = username
        
        // Clear UserDefaults
        let keys = [
            StorageKeys.myGames,
            StorageKeys.playSessions,
            StorageKeys.gameLists,
            StorageKeys.customTags,
            StorageKeys.friends,
            StorageKeys.achievements
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Reinitialize achievements
        initializeAchievements()
        saveAchievements()
        saveUserProfile()
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
