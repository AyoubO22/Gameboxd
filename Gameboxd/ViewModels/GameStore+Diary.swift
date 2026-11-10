//
//  GameStore+Diary.swift
//  Gameboxd
//
//  Play sessions, lists and profile favourites.
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - Play Session Methods
    
    /// Tells followers about what changed: a new game, a finish, a first rating, a review.
    /// Small edits (moving the rating, retyping the review) aren't re-shared.
    func shareChanges(from old: Game?, to new: Game) {
        let social = SocialService.shared
        guard let old else {
            social.publish(new.status == .platinum ? .platinum : new.status == .completed ? .completed : .added, game: new)
            return
        }
        if new.status != old.status, new.status == .completed || new.status == .platinum {
            social.publish(new.status == .platinum ? .platinum : .completed, game: new, rating: new.rating > 0 ? new.rating : nil)
        }
        if old.rating == 0, new.rating > 0 {
            social.publish(.rated, game: new, rating: new.rating)
        }
        let review = new.review.trimmingCharacters(in: .whitespacesAndNewlines)
        if old.review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !review.isEmpty, !new.isSpoiler {
            social.publish(.reviewed, game: new, rating: new.rating > 0 ? new.rating : nil, review: review)
        }
    }

    func addPlaySession(_ session: PlaySession, countsTowardPlaytime: Bool = true) {
        // Keep newest-first by session date, so back-dated entries land in place.
        let index = playSessions.firstIndex { $0.date < session.date } ?? playSessions.endIndex
        playSessions.insert(session, at: index)
        
        // Update game's total play time
        if let index = myGames.firstIndex(where: { $0.id == session.gameId }) {
            if countsTowardPlaytime { myGames[index].playTimeMinutes += session.duration }
            SocialService.shared.publish(.played, game: myGames[index], minutes: session.duration)
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
}
