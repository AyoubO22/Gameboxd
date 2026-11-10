//
//  GameStore+Data.swift
//  Gameboxd
//
//  Export/import, deleting everything, iCloud, and filling missing box art and age ratings.
//

import SwiftUI
import UserNotifications

extension GameStore {
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
        achievements = []
        monthlyGoals = []
        completedGoals = []
        linkedAccounts = []
        importedGames = []
        StickerService.shared.remove(stickers)
        stickers = []
        
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
            StorageKeys.importedGames,
            StorageKeys.stickers
        ]
        
        for key in keys {
            fileStore.remove(key: key)
        }
        
        // The online copy empties too; otherwise it would bring the games back.
        LibrarySync.shared.schedule(myGames)

        // Recreate the default lists and achievements
        loadGameLists()
        initializeAchievements()
        saveAchievements()
        saveUserProfile()
    }
    
    // MARK: - iCloud (key-value store)

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

    /// Age ratings (for the PEGI badge on spines) for library games added before we kept them.
    func fillMissingAgeRatings() async {
        guard rawgService.hasValidAPIKey, !isFillingAgeRatings else { return }
        isFillingAgeRatings = true
        defer { isFillingAgeRatings = false }
        var changed = false
        while let game = myGames.first(where: { $0.ageRating == nil && $0.rawgId != nil }), let rawgId = game.rawgId {
            let slug: String
            do {
                slug = try await rawgService.getGameDetails(id: rawgId).esrbRating?.slug ?? ""
            } catch {
                break // offline: next launch
            }
            if let index = myGames.firstIndex(where: { $0.id == game.id }) {
                myGames[index].ageRating = slug
                changed = true
            }
        }
        if changed { saveGames(syncWidget: false) }
    }
}
