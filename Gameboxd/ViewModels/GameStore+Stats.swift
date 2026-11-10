//
//  GameStore+Stats.swift
//  Gameboxd
//
//  Statistics and backlog, computed from the collection.
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - Statistics
    
    var totalGames: Int { myGames.count }
    
    var totalPlayTimeMinutes: Int {
        myGames.reduce(0) { $0 + $1.playTimeMinutes }
    }
    
    var totalPlayTimeFormatted: String {
        let hours = totalPlayTimeMinutes / 60
        return "\(hours) h"
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
}
