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
    
    // NEW: Achievements, Social
    @Published var achievements: [Achievement] = []
    @Published var customTags: [CustomTag] = []
    @Published var friends: [Friend] = []
    @Published var activityFeed: [ActivityItem] = []
    @Published var notifications: [GameNotification] = []
    @Published var recentlyUnlockedAchievements: [Achievement] = []
    
    // Monthly Goals
    @Published var monthlyGoals: [MonthlyGoal] = []
    @Published var completedGoals: [MonthlyGoal] = []
    
    // Notification Settings
    @Published var achievementAlerts: Bool = UserDefaults.standard.object(forKey: StorageKeys.achievementAlerts) as? Bool ?? true {
        didSet { UserDefaults.standard.set(achievementAlerts, forKey: StorageKeys.achievementAlerts) }
    }
    
    // Linked Gaming Accounts
    @Published var linkedAccounts: [LinkedAccount] = []
    @Published var importedGames: [ImportedGame] = []
    
    // Services
    private let rawgService = RAWGService.shared
    private let securityManager = SecurityManager.shared
    private let steamService = SteamService.shared
    private let psnService = PlayStationService.shared
    
    // Storage Keys
    private enum StorageKeys {
        static let myGames = "gameboxd_my_games"
        static let playSessions = "gameboxd_play_sessions"
        static let gameLists = "gameboxd_game_lists"
        static let userProfile = "gameboxd_user_profile"
        static let isLoggedIn = "gameboxd_is_logged_in"
        static let achievements = "gameboxd_achievements"
        static let customTags = "gameboxd_custom_tags"
        static let friends = "gameboxd_friends"
        static let achievementAlerts = "gameboxd_achievement_alerts"
        static let monthlyGoals = "gameboxd_monthly_goals"
        static let completedGoals = "gameboxd_completed_goals"
        static let linkedAccounts = "gameboxd_linked_accounts"
        static let importedGames = "gameboxd_imported_games"
        static let discoverCache = "gameboxd_discover_cache"
    }
    
    // Collections are stored as JSON files (see FileStore); small flags stay in UserDefaults.
    private let fileStore: FileStore

    // MARK: - Initialization
    init(fileStore: FileStore = .shared) {
        self.fileStore = fileStore
        isLoggedIn = UserDefaults.standard.bool(forKey: StorageKeys.isLoggedIn)
        loadAllData()
        initializeAchievements()
        updateGoalProgress()
        syncWidgetData()
        setICloudObservation(UserDefaults.standard.bool(forKey: "icloud_enabled"))
        Task { await fetchMissingBoxArt() }
        // Discover data is loaded lazily in DiscoverView.onAppear
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
        // Sign out from social providers if needed
        if userProfile.authProvider == "google" {
            GoogleSignInService.shared.signOut()
        }
        
        // Reset auth state
        userProfile.authProvider = "email"
        userProfile.authProviderUserId = ""
        userProfile.avatarURL = nil
        saveUserProfile()
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: StorageKeys.isLoggedIn)
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
        loadLinkedAccounts()
        loadImportedGames()
        loadDiscoverCache()
    }
    
    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        fileStore.load(type, key: key)
    }

    private func loadGames() {
        if let decoded = load([Game].self, key: StorageKeys.myGames) {
            myGames = decoded.map { game in
                var repaired = game
                repaired.review = SecurityManager.unescapeLegacyEntities(game.review)
                repaired.notes = SecurityManager.unescapeLegacyEntities(game.notes)
                return repaired
            }
        }
        // A fresh install starts with an empty library — no seeded demo games.
    }
    
    private func saveGames(syncWidget: Bool = true) {
        fileStore.save(myGames, key: StorageKeys.myGames)
        checkAchievements()
        updateGoalProgress()
        if syncWidget {
            syncWidgetData()
        }
    }
    
    private func loadPlaySessions() {
        if let decoded = load([PlaySession].self, key: StorageKeys.playSessions) {
            playSessions = decoded
        }
    }
    
    private func savePlaySessions() {
        fileStore.save(playSessions, key: StorageKeys.playSessions)
    }
    
    private func loadGameLists() {
        if let decoded = load([GameList].self, key: StorageKeys.gameLists) {
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
        fileStore.save(gameLists, key: StorageKeys.gameLists)
    }
    
    private func loadUserProfile() {
        if let decoded = load(UserProfile.self, key: StorageKeys.userProfile) {
            userProfile = decoded
        }
    }
    
    func saveUserProfile(syncWidget: Bool = true) {
        fileStore.save(userProfile, key: StorageKeys.userProfile)
        if syncWidget {
            syncWidgetData()
        }
    }
    
    // MARK: - Linked Accounts
    
    private func loadLinkedAccounts() {
        if let decoded = load([LinkedAccount].self, key: StorageKeys.linkedAccounts) {
            linkedAccounts = decoded
        }
    }
    
    private func saveLinkedAccounts() {
        fileStore.save(linkedAccounts, key: StorageKeys.linkedAccounts)
    }
    
    private func loadImportedGames() {
        if let decoded = load([ImportedGame].self, key: StorageKeys.importedGames) {
            importedGames = decoded
        }
    }
    
    private func saveImportedGames() {
        fileStore.save(importedGames, key: StorageKeys.importedGames)
    }
    
    /// Link a new gaming platform account
    func linkPlatformAccount(platform: GamingPlatform, platformId: String) async throws {
        switch platform {
        case .steam:
            let steamId = try await steamService.parseSteamId(input: platformId)
            let (games, profile) = try await steamService.syncLibrary(steamId: steamId)
            
            let account = LinkedAccount(
                platform: .steam,
                platformUserId: steamId,
                platformUsername: profile.personaname,
                avatarURL: profile.avatarfull,
                lastSyncDate: Date(),
                importedGameCount: games.count
            )
            
            storeLinkedAccount(account, games: games)
            
        case .playstation:
            let (games, profile) = try await psnService.syncLibrary(psnId: platformId)
            
            let account = LinkedAccount(
                platform: .playstation,
                platformUserId: platformId,
                platformUsername: profile.onlineId,
                avatarURL: profile.avatarUrl,
                lastSyncDate: Date(),
                importedGameCount: games.count,
                trophyCount: profile.trophySummary?.earnedTrophies.total,
                level: profile.trophySummary?.level
            )
            
            storeLinkedAccount(account, games: games)
        }
    }

    /// Replaces any existing account for the same platform and only adds imported
    /// games that aren't already there, so unlink + relink doesn't duplicate.
    private func storeLinkedAccount(_ account: LinkedAccount, games: [ImportedGame]) {
        linkedAccounts.removeAll { $0.platform == account.platform }
        linkedAccounts.append(account)
        let existing = Set(importedGames.filter { $0.platform == account.platform }.map(\.platformGameId))
        importedGames.append(contentsOf: games.filter { !existing.contains($0.platformGameId) })
        saveLinkedAccounts()
        saveImportedGames()
    }
    
    /// Sync an existing linked account to fetch new games
    func syncLinkedAccount(_ account: LinkedAccount) async throws -> PlatformSyncResult {
        var newGames: [ImportedGame] = []
        let existingIds = Set(importedGames.filter { $0.platform == account.platform }.map { $0.platformGameId })
        
        switch account.platform {
        case .steam:
            let (games, _) = try await steamService.syncLibrary(steamId: account.platformUserId)
            newGames = games.filter { !existingIds.contains($0.platformGameId) }
            
        case .playstation:
            let (games, _) = try await psnService.syncLibrary(psnId: account.platformUserId)
            newGames = games.filter { !existingIds.contains($0.platformGameId) }
        }
        
        let result = PlatformSyncResult(
            platform: account.platform,
            gamesFound: existingIds.count + newGames.count,
            newGames: newGames.count,
            updatedGames: 0,
            errors: [],
            syncDate: Date()
        )
        
        // Add new games
        importedGames.append(contentsOf: newGames)
        
        // Update account sync date and count
        if let index = linkedAccounts.firstIndex(where: { $0.id == account.id }) {
            linkedAccounts[index].lastSyncDate = Date()
            linkedAccounts[index].importedGameCount = importedGames.filter { $0.platform == account.platform }.count
        }
        
        saveLinkedAccounts()
        saveImportedGames()
        
        return result
    }
    
    /// Unlink a platform account
    func unlinkAccount(_ account: LinkedAccount) {
        linkedAccounts.removeAll { $0.id == account.id }
        // Keep imported games — user might want to keep them
        saveLinkedAccounts()
    }
    
    /// Add an imported game to the main Gameboxd library
    func addImportedGameToLibrary(_ importedGame: ImportedGame) {
        // Create a Game from ImportedGame
        let platformName: String
        switch importedGame.platform {
        case .steam: platformName = "PC"
        case .playstation: platformName = "PlayStation"
        }
        
        let game = Game(
            title: importedGame.title,
            developer: "",
            platform: platformName,
            releaseYear: "",
            coverImageURL: importedGame.coverImageURL,
            coverColor: importedGame.platform == .steam ? .blue : .indigo,
            status: importedGame.playtimeMinutes > 0 ? .playing : .wantToPlay,
            playTimeMinutes: importedGame.playtimeMinutes,
            completionPercentage: importedGame.completionPercentage
        )
        
        myGames.append(game)
        saveGames()
        
        // Mark as imported
        if let index = importedGames.firstIndex(where: { $0.id == importedGame.id }) {
            importedGames[index].isImportedToLibrary = true
            importedGames[index].linkedGameId = game.id
            saveImportedGames()
        }
    }
    
    // MARK: - API Methods
    
    func loadDiscoverData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in await self.fetchTrendingGames() }
            group.addTask { @MainActor in await self.fetchNewReleases() }
            group.addTask { @MainActor in await self.fetchTopRated() }
            group.addTask { @MainActor in await self.fetchUpcomingGames() }
        }
        guard !trendingGames.isEmpty || !newReleases.isEmpty else { return }
        discoverCacheDate = Date()
        fileStore.save(DiscoverCache(date: Date(), trending: trendingGames, newReleases: newReleases,
                                     topRated: topRated, upcoming: upcomingGames), key: StorageKeys.discoverCache)
    }

    // MARK: - Discover cache
    // Discover opens instantly with the last lists; they refresh in the background when old.

    private struct DiscoverCache: Codable {
        let date: Date
        let trending, newReleases, topRated, upcoming: [Game]
    }

    private var discoverCacheDate: Date?

    private func loadDiscoverCache() {
        guard let cache = load(DiscoverCache.self, key: StorageKeys.discoverCache) else { return }
        trendingGames = cache.trending
        newReleases = cache.newReleases
        topRated = cache.topRated
        upcomingGames = cache.upcoming
        discoverCacheDate = cache.date
    }

    func refreshDiscoverIfStale() async {
        if let date = discoverCacheDate, Date().timeIntervalSince(date) < 6 * 3600 { return }
        await loadDiscoverData()
    }
    
    func fetchTrendingGames() async {
        isLoadingTrending = trendingGames.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getTrendingGames()
            trendingGames = games.map { $0.toGame() }
        } catch {
            print("Error fetching trending: \(error)")
        }
        isLoadingTrending = false
    }
    
    func fetchNewReleases() async {
        isLoadingNewReleases = newReleases.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getNewReleases()
            newReleases = games.map { $0.toGame() }
        } catch {
            print("Error fetching new releases: \(error)")
        }
        isLoadingNewReleases = false
    }
    
    func fetchTopRated() async {
        isLoadingTopRated = topRated.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getTopRated()
            topRated = games.map { $0.toGame() }
        } catch {
            print("Error fetching top rated: \(error)")
        }
        isLoadingTopRated = false
    }
    
    func fetchUpcomingGames() async {
        isLoadingUpcoming = upcomingGames.isEmpty // keep showing the cached list while refreshing
        do {
            let games = try await rawgService.getUpcomingGames()
            upcomingGames = games.map { $0.toGame() }
        } catch {
            print("Error fetching upcoming: \(error)")
        }
        isLoadingUpcoming = false
    }
    
    private var latestSearchQuery = ""
    /// The query `searchResults` answers. Until it equals what's typed, a search is pending.
    @Published private(set) var searchedQuery = ""

    func searchGamesOnline(query: String) async {
        latestSearchQuery = query
        guard !query.isEmpty else {
            searchResults = []
            searchedQuery = ""
            isSearching = false
            return
        }
        isSearching = true
        do {
            let games = try await rawgService.searchGames(query: query)
            // A slower, older request must not overwrite newer results.
            guard query == latestSearchQuery else { return }
            searchResults = games.map { $0.toGame() }
        } catch {
            print("Error searching: \(error)")
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
            return updatedGame
        } catch {
            print("Error fetching details: \(error)")
            return nil
        }
    }
    
    // MARK: - Game CRUD
    
    func updateGame(_ game: Game) {
        var updated = game
        updated.review = securityManager.sanitizeInput(game.review)
        updated.notes = securityManager.sanitizeInput(game.notes)

        // Match by id, or by RAWG id so a fresh copy from Discover/Search updates
        // the owned game instead of adding a duplicate.
        let index = myGames.firstIndex { $0.id == game.id || (game.rawgId != nil && $0.rawgId == game.rawgId) }

        if index == nil {
            if updated.status == .none { updated.status = .wantToPlay }
            if updated.startedDate == nil { updated.startedDate = Date() }
        }
        if (updated.status == .completed || updated.status == .platinum) && updated.completedDate == nil {
            updated.completedDate = Date()
        }

        if let index {
            updated.id = myGames[index].id
            if updated.boxArtURL == nil { updated.boxArtURL = myGames[index].boxArtURL }
            myGames[index] = updated
        } else {
            myGames.append(updated)
            Task { await fetchMissingBoxArt() }
        }

        // Sync favorite state with userProfile
        syncFavoriteIds(for: updated, syncWidget: false)

        saveGames()
    }
    
    func deleteGame(at offsets: IndexSet) {
        removeGames(ids: Set(offsets.map { myGames[$0].id }))
    }
    
    func deleteGame(_ game: Game) {
        removeGames(ids: [game.id])
    }

    /// Removes games and everything that points at them: their diary sessions,
    /// list memberships and pinned-favorite slots.
    private func removeGames(ids: Set<UUID>) {
        myGames.removeAll { ids.contains($0.id) }
        playSessions.removeAll { ids.contains($0.gameId) }
        for i in gameLists.indices {
            gameLists[i].gameIds.removeAll { ids.contains($0) }
        }
        userProfile.favoriteGameIds.removeAll { ids.contains($0) }
        savePlaySessions()
        saveGameLists()
        saveUserProfile(syncWidget: false)
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
            
            saveGames(syncWidget: false)
            saveUserProfile()
        }
    }

    private func syncFavoriteIds(for game: Game, syncWidget: Bool = true) {
        if game.isFavorite {
            if !userProfile.favoriteGameIds.contains(game.id) && userProfile.favoriteGameIds.count < 4 {
                userProfile.favoriteGameIds.append(game.id)
                saveUserProfile(syncWidget: syncWidget)
            }
        } else {
            if userProfile.favoriteGameIds.contains(game.id) {
                userProfile.favoriteGameIds.removeAll { $0 == game.id }
                saveUserProfile(syncWidget: syncWidget)
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
        // Keep newest-first by session date, so back-dated entries land in place.
        let index = playSessions.firstIndex { $0.date < session.date } ?? playSessions.endIndex
        playSessions.insert(session, at: index)
        
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
        // A list can only point at library games; add it first if needed.
        if libraryGame(for: game) == nil { updateGame(game) }
        guard let owned = libraryGame(for: game) else { return }
        if let index = gameLists.firstIndex(where: { $0.id == list.id }) {
            if !gameLists[index].gameIds.contains(owned.id) {
                gameLists[index].gameIds.append(owned.id)
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

        // Compute genre/platform stats for this year only
        var yearGenreCounts: [String: Int] = [:]
        for game in gamesThisYear {
            for genre in game.genres { yearGenreCounts[genre, default: 0] += 1 }
        }
        let yearTopGenres = yearGenreCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        var yearPlatformCounts: [String: Int] = [:]
        for game in gamesThisYear { yearPlatformCounts[game.platform, default: 0] += 1 }
        let yearTopPlatforms = yearPlatformCounts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }

        return YearStats(
            year: year,
            gamesPlayed: gamesThisYear.count,
            gamesCompleted: completedThisYear.count,
            totalPlayTime: totalTime,
            averageRating: avgRating,
            topGenres: yearTopGenres,
            topPlatforms: yearTopPlatforms,
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
        if let decoded = load([Achievement].self, key: StorageKeys.achievements) {
            achievements = decoded
        }
    }
    
    private func saveAchievements() {
        fileStore.save(achievements, key: StorageKeys.achievements)
    }
    
    func checkAchievements() {
        var newlyUnlocked: [Achievement] = []

        // Pre-compute aggregates once
        let gameCount = myGames.count
        let completedCount = myGames.filter { $0.status == .completed || $0.status == .platinum }.count
        let platinumCount = myGames.filter { $0.status == .platinum }.count
        let totalHours = totalPlayTimeMinutes / 60
        let uniqueGenres = Set(myGames.flatMap { $0.genres })
        let uniquePlatforms = Set(myGames.map { $0.platform })
        let reviewCount = myGames.filter { !$0.review.isEmpty }.count
        let streak = calculatePlayStreak()
        let indieCount = myGames.filter { $0.genres.contains("Indie") }.count
        let retroCount = myGames.filter {
            guard let year = Int($0.releaseYear) else { return false }
            return year < 2000
        }.count

        for i in achievements.indices {
            let oldUnlocked = achievements[i].isUnlocked

            switch achievements[i].id {
            case "first_game":
                achievements[i].currentProgress = min(gameCount, 1)
            case "collector_10":
                achievements[i].currentProgress = min(gameCount, 10)
            case "collector_50":
                achievements[i].currentProgress = min(gameCount, 50)
            case "collector_100":
                achievements[i].currentProgress = min(gameCount, 100)
            case "complete_10":
                achievements[i].currentProgress = min(completedCount, 10)
            case "complete_25":
                achievements[i].currentProgress = min(completedCount, 25)
            case "platinum_5":
                achievements[i].currentProgress = min(platinumCount, 5)
            case "time_100":
                achievements[i].currentProgress = min(totalHours, 100)
            case "time_500":
                achievements[i].currentProgress = min(totalHours, 500)
            case "time_1000":
                achievements[i].currentProgress = min(totalHours, 1000)
            case "genres_5":
                achievements[i].currentProgress = min(uniqueGenres.count, 5)
            case "platforms_3":
                achievements[i].currentProgress = min(uniquePlatforms.count, 3)
            case "reviews_10":
                achievements[i].currentProgress = min(reviewCount, 10)
            case "streak_7":
                achievements[i].currentProgress = min(streak, 7)
            case "streak_30":
                achievements[i].currentProgress = min(streak, 30)
            case "favorite_genre":
                if let topGenre = topGenres.first, topGenre.1 >= 10 {
                    achievements[i].currentProgress = 10
                }
            case "lists_5":
                achievements[i].currentProgress = min(gameLists.count, 5)
            case "indie_lover":
                achievements[i].currentProgress = min(indieCount, 20)
            case "retro_gamer":
                achievements[i].currentProgress = min(retroCount, 10)
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

        // Always persist progress so progress bars survive a relaunch,
        // not only when an achievement is newly unlocked.
        saveAchievements()

        if !newlyUnlocked.isEmpty {
            recentlyUnlockedAchievements = newlyUnlocked

            if achievementAlerts {
                for achievement in newlyUnlocked {
                    sendAchievementNotification(achievement)
                }
            }
        }
    }
    
    private func calculatePlayStreak() -> Int {
        guard !playSessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        // Build a Set of session days for O(1) lookups
        let sessionDays = Set(playSessions.map { calendar.startOfDay(for: $0.date) })

        var streak = 1
        var currentDate = calendar.startOfDay(for: Date())

        // Check if played today
        if !sessionDays.contains(currentDate) {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            if !sessionDays.contains(currentDate) {
                return 0
            }
        }

        while let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate),
              sessionDays.contains(previousDay) {
            streak += 1
            currentDate = previousDay
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
        if let decoded = load([CustomTag].self, key: StorageKeys.customTags) {
            customTags = decoded
        }
    }
    
    func saveCustomTags() {
        fileStore.save(customTags, key: StorageKeys.customTags)
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
        if let decoded = load([Friend].self, key: StorageKeys.friends) {
            friends = decoded
        }
    }
    
    private func saveFriends() {
        fileStore.save(friends, key: StorageKeys.friends)
    }
    
    // MARK: - Monthly Goals
    
    private func loadMonthlyGoals() {
        if let decoded = load([MonthlyGoal].self, key: StorageKeys.monthlyGoals) {
            monthlyGoals = decoded
        }
        if let decoded = load([MonthlyGoal].self, key: StorageKeys.completedGoals) {
            completedGoals = decoded
        }
    }
    
    private func saveMonthlyGoals() {
        fileStore.save(monthlyGoals, key: StorageKeys.monthlyGoals)
        fileStore.save(completedGoals, key: StorageKeys.completedGoals)
    }
    
    func addMonthlyGoal(_ goal: MonthlyGoal) {
        monthlyGoals.append(goal)
        saveMonthlyGoals()
        // Immediately reflect any progress already achieved this month.
        updateGoalProgress()
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
                                    let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart),
                                    let monthEnd = calendar.date(byAdding: .second, value: -1, to: nextMonthStart) else {
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
                // Note: uses startedDate as a proxy since there's no dedicated reviewedDate field
                let reviews = myGames.filter { game in
                    guard let started = game.startedDate, !game.review.isEmpty else { return false }
                    return started >= monthStart && started <= monthEnd
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
    
    private func sendAchievementNotification(_ achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "Succès débloqué!"
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
        monthlyGoals = []
        completedGoals = []
        linkedAccounts = []
        importedGames = []
        
        // Reset profile but keep username
        let username = userProfile.username
        userProfile = UserProfile()
        userProfile.username = username
        
        // Remove the stored files
        let keys = [
            StorageKeys.myGames,
            StorageKeys.playSessions,
            StorageKeys.gameLists,
            StorageKeys.customTags,
            StorageKeys.friends,
            StorageKeys.achievements,
            StorageKeys.monthlyGoals,
            StorageKeys.completedGoals,
            StorageKeys.linkedAccounts,
            StorageKeys.importedGames
        ]
        
        for key in keys {
            fileStore.remove(key: key)
        }
        
        // Recreate the default lists and achievements
        loadGameLists()
        initializeAchievements()
        saveAchievements()
        saveUserProfile()
    }
    
    // MARK: - iCloud (key-value store)

    private var iCloudObserver: NSObjectProtocol?

    /// One observer for the app's lifetime; removed when sync is turned off.
    func setICloudObservation(_ enabled: Bool) {
        if let iCloudObserver { NotificationCenter.default.removeObserver(iCloudObserver) }
        iCloudObserver = nil
        guard enabled else { return }
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.mergeFromICloud() }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func uploadToICloud() {
        let kv = NSUbiquitousKeyValueStore.default
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(myGames) { kv.set(data, forKey: "icloud_games") }
        if let data = try? encoder.encode(playSessions) { kv.set(data, forKey: "icloud_sessions") }
        if let data = try? encoder.encode(gameLists) { kv.set(data, forKey: "icloud_lists") }
        if let data = try? encoder.encode(monthlyGoals) { kv.set(data, forKey: "icloud_goals") }
        kv.synchronize()
    }

    /// Adds games, sessions, lists and goals from iCloud that this device doesn't
    /// have yet. Returns how many items were added.
    @discardableResult
    func mergeFromICloud() -> Int {
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        func remote<T: Decodable & Identifiable>(_ key: String, missingFrom local: [T]) -> [T] where T.ID == UUID {
            guard let data = kv.data(forKey: key),
                  let items = try? JSONDecoder().decode([T].self, from: data) else { return [] }
            let localIds = Set(local.map(\.id))
            return items.filter { !localIds.contains($0.id) }
        }
        let newGames = remote("icloud_games", missingFrom: myGames)
        let newSessions = remote("icloud_sessions", missingFrom: playSessions)
        let newLists = remote("icloud_lists", missingFrom: gameLists)
        let newGoals = remote("icloud_goals", missingFrom: monthlyGoals)

        let count = newGames.count + newSessions.count + newLists.count + newGoals.count
        guard count > 0 else { return 0 }
        myGames += newGames
        playSessions = (playSessions + newSessions).sorted { $0.date > $1.date }
        gameLists += newLists
        monthlyGoals += newGoals
        savePlaySessions()
        saveGameLists()
        saveMonthlyGoals()
        saveGames()
        return count
    }

    // MARK: - Box art (IGDB)

    private var isFetchingBoxArt = false

    /// Looks up portrait box art for library games that don't have it yet, one request
    /// at a time (IGDB allows 4 per second). Network errors leave the game for next launch.
    func fetchMissingBoxArt() async {
        guard IGDBService.shared.isConfigured, !isFetchingBoxArt else { return }
        isFetchingBoxArt = true
        defer { isFetchingBoxArt = false }

        var changed = false
        while let game = myGames.first(where: { $0.boxArtURL == nil }) {
            let url: URL?
            do {
                url = try await IGDBService.shared.boxArtURL(title: game.title, year: game.releaseYear)
            } catch {
                break // offline or auth failure: try again next launch
            }
            if let index = myGames.firstIndex(where: { $0.id == game.id }) {
                myGames[index].boxArtURL = url?.absoluteString ?? ""
                changed = true
            }
            try? await Task.sleep(for: .milliseconds(260))
        }
        if changed { saveGames() }
    }

    // MARK: - Widget Sync

    private func makeWidgetGame(from game: Game) -> SharedDataProvider.WidgetGame {
        SharedDataProvider.WidgetGame(
            title: game.title,
            coverURL: game.artURL?.absoluteString,
            platform: game.platform,
            playTimeMinutes: game.playTimeMinutes,
            status: game.status.rawValue
        )
    }

    /// Pushes the latest widget-relevant snapshot into the shared App Group store
    /// and asks WidgetKit to reload its timelines.
    ///
    /// Note: the GameboxdWidget extension is not a build target yet and there is no
    /// App Group entitlement, so today this writes to an app-local suite that no
    /// widget reads. It starts working once the target + App Group are added.
    private func syncWidgetData() {
        let currentWidgetGame = myGames.first { $0.status == .playing }.map(makeWidgetGame)
        let backlogWidgetGames = backlog.prefix(20).map(makeWidgetGame)

        SharedDataProvider.updateWidgetData(
            currentGame: currentWidgetGame,
            yearlyCompleted: completedThisYear,
            yearlyTarget: max(userProfile.yearlyGoal, 1),
            backlogGames: Array(backlogWidgetGames),
            totalPlayTimeMinutes: totalPlayTimeMinutes
        )
    }

}
