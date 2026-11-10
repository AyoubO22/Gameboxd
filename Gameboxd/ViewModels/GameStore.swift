//
//  GameStore.swift
//  Gameboxd
//
//  Central store for all app data with persistence
//

import SwiftUI

import UserNotifications

@MainActor
@Observable
final class GameStore {
    // MARK: - State
    var myGames: [Game] = []
    var playSessions: [PlaySession] = []
    var gameLists: [GameList] = []
    var userProfile: UserProfile = UserProfile()
    var isLoggedIn: Bool = false
    
    // API Data
    var trendingGames: [Game] = []
    var newReleases: [Game] = []
    var topRated: [Game] = []
    var upcomingGames: [Game] = []
    var searchResults: [Game] = []
    
    // Loading States
    var isLoadingTrending = false
    var isLoadingNewReleases = false
    var isLoadingTopRated = false
    var isLoadingUpcoming = false
    var isSearching = false
    /// The last search failed (RAWG unreachable), so "no results" would be a lie.
    var searchFailed = false
    /// Discover couldn't load anything and has nothing cached to show.
    var discoverUnavailable = false
    
    var achievements: [Achievement] = []
    var customTags: [CustomTag] = []
    var notifications: [GameNotification] = []
    var recentlyUnlockedAchievements: [Achievement] = []
    
    // Monthly Goals
    var monthlyGoals: [MonthlyGoal] = []
    var completedGoals: [MonthlyGoal] = []
    
    // Notification Settings
    var achievementAlerts: Bool = UserDefaults.standard.object(forKey: StorageKeys.achievementAlerts) as? Bool ?? true {
        didSet { UserDefaults.standard.set(achievementAlerts, forKey: StorageKeys.achievementAlerts) }
    }
    
    // Linked Gaming Accounts
    var linkedAccounts: [LinkedAccount] = []
    /// Unlocked stickers, all games (see StickerRules for what unlocks them).
    var stickers: [Sticker] = []
    /// Play Steam saw since last time, offered as diary sessions (see SteamSync).
    var steamSuggestions: [SteamSessionSuggestion] = []
    var importedGames: [ImportedGame] = []
    
    // Services
    let rawgService = RAWGService.shared
    let securityManager = SecurityManager.shared
    let steamService = SteamService.shared
    let psnService = PlayStationService.shared
    
    // Storage Keys
    enum StorageKeys {
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
        static let discoverCache = "gameboxd_discover_cache_v2" // v2: lists without editions and DLC
        static let stickers = "gameboxd_stickers"
        static let steamSuggestions = "gameboxd_steam_suggestions"
    }
    
    // Collections are stored as JSON files (see FileStore); small flags stay in UserDefaults.
    var fileStore: FileStore
    /// The no-account space; accounts' spaces live inside it.
    let guestStore: FileStore
    /// The app remembers the account between launches; tests (own space) don't.
    let remembersAccount: Bool
    /// The account whose data is loaded (nil: no account). Remembered so the app reopens
    /// on it right away, offline too.
    private(set) var currentAccountId: UUID?
    static let currentAccountKey = "gameboxd_current_account"

    // Kept here because extensions can't hold stored properties.
    var isFillingDiscoverArt = false
    var discoverCacheDate: Date?
    var latestSearchQuery = ""
    /// The query `searchResults` answers. Until it equals what's typed, a search is pending.
    var searchedQuery = ""
    var iCloudObserver: NSObjectProtocol?
    var isFetchingBoxArt = false
    var isFillingAgeRatings = false

    // MARK: - Initialization
    init(fileStore: FileStore? = nil) {
        // Tests pass their own space and start without an account.
        let saved = fileStore == nil ? UserDefaults.standard.string(forKey: Self.currentAccountKey).flatMap(UUID.init(uuidString:)) : nil
        guestStore = fileStore ?? .shared
        remembersAccount = fileStore == nil
        currentAccountId = saved
        if fileStore == nil { PSNTokenStore.owner = saved }
        self.fileStore = .forAccount(saved, in: guestStore)
        isLoggedIn = UserDefaults.standard.bool(forKey: StorageKeys.isLoggedIn)
        loadAllData()
        initializeAchievements()
        updateGoalProgress()
        syncStickers() // backfill: play logged before stickers existed still counts
        syncWidgetData()
        setICloudObservation(UserDefaults.standard.bool(forKey: "icloud_enabled"))
        Task {
            await fetchMissingBoxArt()
            await fillMissingAgeRatings()
        }
        // Discover data is loaded lazily in DiscoverView.onAppear
    }
    
    // MARK: - Auth Methods
    func setLoggedIn(_ value: Bool) {
        isLoggedIn = value
        #if DEBUG
        if DemoShelf.isOn { return } // the demo shelf never touches the real account or settings
        #endif
        UserDefaults.standard.set(value, forKey: StorageKeys.isLoggedIn)
        if value {
            saveUserProfile()
        }
    }
    
    func logout() {
        #if DEBUG
        // The demo shelf never touches the real account: signing out would revoke the session
        // saved in the Keychain, and the sign-in screen behind it could upload the demo games.
        if DemoShelf.isOn { return }
        #endif
        Task { await AccountService.shared.signOut() }
        switchAccount(to: nil)
        
        // Reset auth state
        userProfile.authProvider = "email"
        userProfile.authProviderUserId = ""
        userProfile.avatarURL = nil
        saveUserProfile()
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: StorageKeys.isLoggedIn)
    }
    
    // MARK: - Persistence
    
    // MARK: - Accounts on this phone

    /// Loads the data of `account` (nil: no account). A brand new account takes the
    /// collection made without an account (`claimGuestData`), moved so no other account
    /// can get it too.
    func switchAccount(to account: UUID?, claimGuestData: Bool = false) {
        let legacy = remembersAccount && account != nil && UserDefaults.standard.string(forKey: Self.currentAccountKey) == nil
            && UserDefaults.standard.bool(forKey: StorageKeys.isLoggedIn)
        guard account != currentAccountId || legacy else { return }
        let target = FileStore.forAccount(account, in: guestStore)
        // Before accounts had their own space, the signed-in player used the shared one:
        // their collection moves to their account on the first launch of this version.
        if account != nil, !target.hasData, claimGuestData || legacy {
            guestStore.moveContents(to: target)
        }
        fileStore.flush()
        fileStore = target
        currentAccountId = account
        if remembersAccount {
            PSNTokenStore.owner = account
            if let account {
                UserDefaults.standard.set(account.uuidString, forKey: Self.currentAccountKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.currentAccountKey)
            }
        }
        LibrarySync.shared.reset()
        // The backlog reminder names a game of the previous account: drop it (Settings
        // schedules a new one for this account).
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["backlog_reminder"])
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        resetLoadedData()
        loadAllData()
        initializeAchievements()
        updateGoalProgress()
        syncStickers()
        syncWidgetData()
    }

    /// Fills an empty collection from the account's online copy (a new phone, a reinstall).
    func restoreFromCloud(_ games: [Game]) {
        guard myGames.isEmpty, !games.isEmpty else { return }
        myGames = games
        saveGames()
    }

    func deleteLocalData(forAccount id: UUID) {
        FileStore.forAccount(id, in: guestStore).removeAll()
        LibrarySync.setReconciled(id, false)
    }

    func flush() { fileStore.flush() }

    func resetLoadedData() {
        myGames = []
        playSessions = []
        gameLists = []
        userProfile = UserProfile()
        achievements = []
        customTags = []
        monthlyGoals = []
        completedGoals = []
        linkedAccounts = []
        importedGames = []
        stickers = []
        steamSuggestions = []
        notifications = []
        recentlyUnlockedAchievements = []
    }

    func loadAllData() {
        loadGames()
        loadPlaySessions()
        loadGameLists()
        loadUserProfile()
        loadAchievements()
        loadCustomTags()
        loadMonthlyGoals()
        loadLinkedAccounts()
        loadImportedGames()
        loadDiscoverCache()
        stickers = load([Sticker].self, key: StorageKeys.stickers) ?? []
        steamSuggestions = load([SteamSessionSuggestion].self, key: StorageKeys.steamSuggestions) ?? []
        // Recut art made by an older StickerMaker, once (v2: main character first;
        // v3: same art in another crop no longer repeats; v4: Steam art as a source).
        // Unlocks are kept.
        if UserDefaults.standard.integer(forKey: "gameboxd_sticker_art_version") < 4 {
            StickerService.shared.remove(stickers)
            for i in stickers.indices { stickers[i].imageFile = nil }
            fileStore.save(stickers, key: StorageKeys.stickers)
            UserDefaults.standard.set(4, forKey: "gameboxd_sticker_art_version")
        }
    }
    
    func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        fileStore.load(type, key: key)
    }

    func loadGames() {
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
    
    func saveGames(syncWidget: Bool = true) {
        fileStore.save(myGames, key: StorageKeys.myGames)
        LibrarySync.shared.schedule(myGames)
        syncStickers()
        checkAchievements()
        updateGoalProgress()
        if syncWidget {
            syncWidgetData()
        }
    }
    
    func loadPlaySessions() {
        if let decoded = load([PlaySession].self, key: StorageKeys.playSessions) {
            playSessions = decoded
        }
    }
    
    func savePlaySessions() {
        fileStore.save(playSessions, key: StorageKeys.playSessions)
    }
    
    func loadGameLists() {
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
    
    func saveGameLists() {
        fileStore.save(gameLists, key: StorageKeys.gameLists)
    }
    
    func loadUserProfile() {
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
        // A platinum is a finished game, all the way.
        if updated.status == .platinum { updated.completionPercentage = 100 }
        if (updated.status == .completed || updated.status == .platinum) && updated.completedDate == nil {
            updated.completedDate = Date()
        }

        let previous = index.map { myGames[$0] }
        if let index {
            updated.id = myGames[index].id
            if updated.boxArtURL == nil { updated.boxArtURL = myGames[index].boxArtURL }
            myGames[index] = updated
        } else {
            myGames.append(updated)
            Task { await fetchMissingBoxArt() }
        }
        shareChanges(from: previous, to: updated)

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
    func removeGames(ids: Set<UUID>) {
        myGames.removeAll { ids.contains($0.id) }
        playSessions.removeAll { ids.contains($0.gameId) }
        for i in gameLists.indices {
            gameLists[i].gameIds.removeAll { ids.contains($0) }
        }
        userProfile.favoriteGameIds.removeAll { ids.contains($0) }
        StickerService.shared.remove(stickers.filter { ids.contains($0.gameId) })
        stickers.removeAll { ids.contains($0.gameId) }
        fileStore.save(stickers, key: StorageKeys.stickers)
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

    func syncFavoriteIds(for game: Game, syncWidget: Bool = true) {
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
    
}
