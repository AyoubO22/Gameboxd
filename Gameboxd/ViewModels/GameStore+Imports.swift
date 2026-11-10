//
//  GameStore+Imports.swift
//  Gameboxd
//
//  Linked Steam and PlayStation accounts: linking, syncing, importing their games.
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - Linked Accounts
    
    func loadLinkedAccounts() {
        if let decoded = load([LinkedAccount].self, key: StorageKeys.linkedAccounts) {
            linkedAccounts = decoded
        }
    }
    
    func saveLinkedAccounts() {
        fileStore.save(linkedAccounts, key: StorageKeys.linkedAccounts)
    }
    
    func loadImportedGames() {
        if let decoded = load([ImportedGame].self, key: StorageKeys.importedGames) {
            importedGames = decoded
        }
        // Steam imports made before games kept their app id: give it back to them.
        for imported in importedGames where imported.platform == .steam {
            guard let gameId = imported.linkedGameId, let appId = Int(imported.platformGameId),
                  let index = myGames.firstIndex(where: { $0.id == gameId }), myGames[index].steamAppId == nil else { continue }
            myGames[index].steamAppId = appId
        }
        if !UserDefaults.standard.bool(forKey: "gameboxd_psn_backlog_fixed") {
            fixPlayStationBacklog()
            UserDefaults.standard.set(true, forKey: "gameboxd_psn_backlog_fixed")
        }
    }
    
    func saveImportedGames() {
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
            // A fresh link starts counting from now: the whole history isn't "a session".
            SteamSync.shared.resetBaseline(steamId: steamId)
            
        case .playstation:
            // PlayStation links by signing in with Sony: see linkPlayStation.
            throw PlayStationServiceError.notSignedIn
        }
    }

    /// Links PlayStation once Sony's sign-in succeeded (a sign-in callback or a pasted NPSSO).
    func linkPlayStation(callback: URL? = nil, npsso: String? = nil) async throws {
        if let callback {
            try await psnService.signIn(callback: callback)
        } else if let npsso {
            try await psnService.signIn(npsso: npsso)
        }
        // Sony takes a while to answer: if another account takes the phone meanwhile, the
        // result must not land in its collection.
        let accountAtStart = currentAccountId
        let (games, profile) = try await psnService.syncLibrary()
        guard currentAccountId == accountAtStart else { throw CancellationError() }
        let account = LinkedAccount(
            platform: .playstation,
            platformUserId: profile.onlineId,
            platformUsername: profile.onlineId,
            avatarURL: profile.avatarUrl,
            lastSyncDate: Date(),
            importedGameCount: games.count,
            trophyCount: profile.earnedTrophies?.total,
            level: profile.trophyLevel
        )
        storeLinkedAccount(account, games: games)
    }

    /// Replaces any existing account for the same platform and only adds imported
    /// games that aren't already there, so unlink + relink doesn't duplicate.
    func storeLinkedAccount(_ account: LinkedAccount, games: [ImportedGame]) {
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
        var updated = 0
        var note: String?
        let existingIds = Set(importedGames.filter { $0.platform == account.platform }.map { $0.platformGameId })
        let accountAtStart = currentAccountId
        
        switch account.platform {
        case .steam:
            let (games, _) = try await steamService.syncLibrary(steamId: account.platformUserId)
            guard currentAccountId == accountAtStart else { throw CancellationError() }
            newGames = games.filter { !existingIds.contains($0.platformGameId) }
            
        case .playstation:
            let (games, profile) = try await psnService.syncLibrary()
            guard currentAccountId == accountAtStart else { throw CancellationError() }
            newGames = games.filter { !existingIds.contains($0.platformGameId) }
            updated = refreshPlayStationGames(games)
            let check = psnService.lastStoryCheck
            let finished = games.filter { $0.storyCompleted == true }.count
            note = "Trophées de fin : \(check.checked) jeux lus, \(finished) jeux finis repérés"
                + (check.failed > 0 ? ", \(check.failed) échecs (\(check.firstError ?? "?"))" : "")
            if let index = linkedAccounts.firstIndex(where: { $0.id == account.id }) {
                linkedAccounts[index].trophyCount = profile.earnedTrophies?.total
                linkedAccounts[index].level = profile.trophyLevel
            }
        }
        
        let result = PlatformSyncResult(
            platform: account.platform,
            gamesFound: existingIds.count + newGames.count,
            newGames: newGames.count,
            updatedGames: updated,
            errors: [],
            syncDate: Date(),
            note: note
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
    
    /// PlayStation knows more than the app about games already imported: newer play time
    /// and trophies, for the import list and the games added to the collection.
    /// Returns how many games of the collection it changed.
    @discardableResult
    func refreshPlayStationGames(_ games: [ImportedGame]) -> Int {
        let fresh = Dictionary(games.map { ($0.platformGameId, $0) }, uniquingKeysWith: { first, _ in first })
        var changedGames = Set<UUID>()
        for index in importedGames.indices where importedGames[index].platform == .playstation {
            let old = importedGames[index]
            guard let new = fresh[old.platformGameId] else { continue }
            importedGames[index] = ImportedGame(
                id: old.id, platform: .playstation, platformGameId: new.platformGameId, title: new.title,
                coverImageURL: new.coverImageURL, playtimeMinutes: new.playtimeMinutes, lastPlayed: new.lastPlayed,
                achievementsEarned: new.achievementsEarned, achievementsTotal: new.achievementsTotal,
                isImportedToLibrary: old.isImportedToLibrary, linkedGameId: old.linkedGameId, console: new.console,
                storyCompleted: new.storyCompleted, platinumEarned: new.platinumEarned
            )
            guard let gameIndex = libraryIndex(forImportedAt: index) else { continue }
            let gameId = myGames[gameIndex].id
            // The platinum is the last word; the story trophy moves it out of "À jouer" or "Abandonné".
            if new.platinumEarned == true, myGames[gameIndex].status != .platinum {
                setImportedStatus(.platinum, of: gameIndex, from: new)
                changedGames.insert(gameId)
            } else if new.storyCompleted == true, [.wantToPlay, .shelved].contains(myGames[gameIndex].status) {
                setImportedStatus(importedStatus(new), of: gameIndex, from: new)
                changedGames.insert(gameId)
            }
            if new.playtimeMinutes > myGames[gameIndex].playTimeMinutes {
                myGames[gameIndex].playTimeMinutes = new.playtimeMinutes
                changedGames.insert(gameId)
            }
            if new.completionPercentage > myGames[gameIndex].completionPercentage {
                myGames[gameIndex].completionPercentage = new.completionPercentage
                changedGames.insert(gameId)
            }
        }
        if !changedGames.isEmpty { saveGames() }
        return changedGames.count
    }

    /// Unlink a platform account
    func unlinkAccount(_ account: LinkedAccount) {
        if account.platform == .playstation { psnService.signOut() }
        linkedAccounts.removeAll { $0.id == account.id }
        // Keep imported games — user might want to keep them
        saveLinkedAccounts()
    }
    
    /// Add an imported game to the main Gameboxd library
    func addImportedGameToLibrary(_ importedGame: ImportedGame) {
        addImportedGamesToLibrary([importedGame])
    }

    /// Games of the import list not in the collection yet ("Tout ajouter").
    func importableGames(platform: GamingPlatform? = nil) -> [ImportedGame] {
        importedGames.filter { !$0.isImportedToLibrary && (platform == nil || $0.platform == platform) }
    }

    /// Adds imported games to the collection in one save. A game already in the collection
    /// under the same title is linked to it instead of added twice.
    func addImportedGamesToLibrary(_ games: [ImportedGame]) {
        guard !games.isEmpty else { return }
        var existingByTitle: [String: UUID] = [:]
        for game in myGames { existingByTitle[PSNLibrary.key(game.title)] = existingByTitle[PSNLibrary.key(game.title)] ?? game.id }

        for importedGame in games {
            guard let index = importedGames.firstIndex(where: { $0.id == importedGame.id }),
                  !importedGames[index].isImportedToLibrary else { continue }
            let key = PSNLibrary.key(importedGame.title)
            let gameId: UUID
            if let existing = existingByTitle[key] {
                gameId = existing
            } else {
                let game = libraryGame(from: importedGame)
                myGames.append(game)
                existingByTitle[key] = game.id
                gameId = game.id
            }
            importedGames[index].isImportedToLibrary = true
            importedGames[index].linkedGameId = gameId
        }
        saveGames()
        saveImportedGames()
    }

    /// Every trophy earned is a platinum on PlayStation, and the story trophy makes it finished.
    /// Otherwise only a game played in the last month is in progress; one left longer, or with
    /// no date at all, is shelved.
    /// Everything Sony lists was launched at least once (old PS4 games often report no play
    /// time and no trophy), so a PSN game is never "À jouer". Steam lists owned games too.
    func importedStatus(_ importedGame: ImportedGame) -> GameStatus {
        let played = importedGame.platform == .playstation
            || importedGame.playtimeMinutes > 0 || importedGame.achievementsEarned > 0
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        if importedGame.platinumEarned == true {
            return .platinum
        } else if importedGame.completionPercentage >= 100 {
            return importedGame.platform == .playstation ? .platinum : .completed
        } else if importedGame.storyCompleted == true {
            return .completed
        } else if !played {
            return .wantToPlay
        } else if let lastPlayed = importedGame.lastPlayed, lastPlayed >= monthAgo {
            return .playing
        } else {
            return .shelved
        }
    }

    /// The collection game an imported game stands for. A lost link (seen on imports made by
    /// older builds) is found again by title, and repaired so the game isn't offered again.
    func libraryIndex(forImportedAt importedIndex: Int) -> Int? {
        let imported = importedGames[importedIndex]
        if let gameId = imported.linkedGameId, let index = myGames.firstIndex(where: { $0.id == gameId }) { return index }
        let key = PSNLibrary.key(imported.title)
        guard !key.isEmpty, let index = myGames.firstIndex(where: { PSNLibrary.key($0.title) == key }) else { return nil }
        importedGames[importedIndex].linkedGameId = myGames[index].id
        importedGames[importedIndex].isImportedToLibrary = true
        return index
    }

    /// A status the platform decided, with what updateGame adds by hand: a platinum is 100 %,
    /// and a finished game gets a date (the last time it was played, not today).
    func setImportedStatus(_ status: GameStatus, of index: Int, from importedGame: ImportedGame) {
        myGames[index].status = status
        if status == .platinum { myGames[index].completionPercentage = 100 }
        if status == .completed || status == .platinum, myGames[index].completedDate == nil {
            myGames[index].completedDate = importedGame.lastPlayed
        }
    }

    /// PSN games added before importedStatus knew they were all played came in as "À jouer":
    /// sort those again. Games moved to another status by hand are left alone.
    func fixPlayStationBacklog() {
        var changed = false
        for importedIndex in importedGames.indices where importedGames[importedIndex].platform == .playstation {
            guard let index = libraryIndex(forImportedAt: importedIndex), myGames[index].status == .wantToPlay else { continue }
            setImportedStatus(importedStatus(importedGames[importedIndex]), of: index, from: importedGames[importedIndex])
            changed = true
        }
        if changed { saveGames() }
        saveImportedGames()
    }

    func libraryGame(from importedGame: ImportedGame) -> Game {
        let platformName: String
        switch importedGame.platform {
        case .steam: platformName = "PC"
        case .playstation: platformName = importedGame.console ?? "PlayStation 5"
        }

        let status = importedStatus(importedGame)
        var game = Game(
            title: importedGame.title,
            developer: "",
            platform: platformName,
            releaseYear: "",
            coverImageURL: importedGame.coverImageURL,
            coverColor: importedGame.platform == .steam ? .blue : .indigo,
            status: status,
            playTimeMinutes: importedGame.playtimeMinutes,
            completionPercentage: importedGame.completionPercentage
        )
        if importedGame.platform == .steam { game.steamAppId = Int(importedGame.platformGameId) }
        if status == .platinum { game.completionPercentage = 100 }
        if status == .completed || status == .platinum { game.completedDate = importedGame.lastPlayed }
        return game
    }
    
    // MARK: - Steam

    /// Applies what SteamSync found: playtime (Steam knows more), completion from
    /// achievements (100 % is a platinum) and new session suggestions. One save.
    func applySteamSync(playtime: [UUID: Int], completion: [UUID: Int], suggestions: [SteamSessionSuggestion]) {
        var changed = false
        for index in myGames.indices {
            let old = myGames[index]
            var game = old
            if let total = playtime[game.id], total > game.playTimeMinutes {
                game.playTimeMinutes = total
                if game.status == .wantToPlay || game.status == .none {
                    game.status = .playing
                    if game.startedDate == nil { game.startedDate = Date() }
                }
            }
            if let percent = completion[game.id], percent != game.completionPercentage, game.status != .platinum || percent == 100 {
                game.completionPercentage = percent
                if percent == 100 {
                    game.status = .platinum
                    if game.completedDate == nil { game.completedDate = Date() }
                }
            }
            if game != old {
                myGames[index] = game
                shareChanges(from: old, to: game)
                changed = true
            }
        }
        if !suggestions.isEmpty {
            // One pending suggestion per game: a newer one adds up with the older.
            for suggestion in suggestions {
                if let i = steamSuggestions.firstIndex(where: { $0.gameId == suggestion.gameId }) {
                    let previous = steamSuggestions[i]
                    steamSuggestions[i] = SteamSessionSuggestion(gameId: previous.gameId, gameTitle: previous.gameTitle,
                                                                 minutes: previous.minutes + suggestion.minutes, date: suggestion.date)
                } else {
                    steamSuggestions.append(suggestion)
                }
            }
            fileStore.save(steamSuggestions, key: StorageKeys.steamSuggestions)
        }
        if changed { saveGames() }
    }

    /// Logs the suggested session. Its time is already in the game's total (Steam counted it).
    func acceptSteamSuggestion(_ suggestion: SteamSessionSuggestion) {
        if let game = myGames.first(where: { $0.id == suggestion.gameId }) {
            addPlaySession(PlaySession(gameId: game.id, gameTitle: game.title, gameCoverURL: game.artURL?.absoluteString,
                                       gameCoverColor: game.coverColor, date: suggestion.date, duration: suggestion.minutes),
                           countsTowardPlaytime: false)
        }
        dismissSteamSuggestion(suggestion)
    }

    func dismissSteamSuggestion(_ suggestion: SteamSessionSuggestion) {
        steamSuggestions.removeAll { $0.id == suggestion.id }
        fileStore.save(steamSuggestions, key: StorageKeys.steamSuggestions)
    }
}
