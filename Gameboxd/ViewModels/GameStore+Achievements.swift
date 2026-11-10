//
//  GameStore+Achievements.swift
//  Gameboxd
//
//  Achievements, custom tags, monthly goals and their notifications.
//

import SwiftUI
import UserNotifications

extension GameStore {
    // MARK: - Achievements System
    
    func initializeAchievements() {
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
    
    func loadAchievements() {
        if let decoded = load([Achievement].self, key: StorageKeys.achievements) {
            achievements = decoded
        }
    }
    
    func saveAchievements() {
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

        // Work on a copy: one store update (and one write) instead of one per achievement.
        var updated = achievements
        for i in updated.indices {
            let oldUnlocked = updated[i].isUnlocked

            switch updated[i].id {
            case "first_game":
                updated[i].currentProgress = min(gameCount, 1)
            case "collector_10":
                updated[i].currentProgress = min(gameCount, 10)
            case "collector_50":
                updated[i].currentProgress = min(gameCount, 50)
            case "collector_100":
                updated[i].currentProgress = min(gameCount, 100)
            case "complete_10":
                updated[i].currentProgress = min(completedCount, 10)
            case "complete_25":
                updated[i].currentProgress = min(completedCount, 25)
            case "platinum_5":
                updated[i].currentProgress = min(platinumCount, 5)
            case "time_100":
                updated[i].currentProgress = min(totalHours, 100)
            case "time_500":
                updated[i].currentProgress = min(totalHours, 500)
            case "time_1000":
                updated[i].currentProgress = min(totalHours, 1000)
            case "genres_5":
                updated[i].currentProgress = min(uniqueGenres.count, 5)
            case "platforms_3":
                updated[i].currentProgress = min(uniquePlatforms.count, 3)
            case "reviews_10":
                updated[i].currentProgress = min(reviewCount, 10)
            case "streak_7":
                updated[i].currentProgress = min(streak, 7)
            case "streak_30":
                updated[i].currentProgress = min(streak, 30)
            case "favorite_genre":
                if let topGenre = topGenres.first, topGenre.1 >= 10 {
                    updated[i].currentProgress = 10
                }
            case "lists_5":
                updated[i].currentProgress = min(gameLists.count, 5)
            case "indie_lover":
                updated[i].currentProgress = min(indieCount, 20)
            case "retro_gamer":
                updated[i].currentProgress = min(retroCount, 10)
            default:
                break
            }

            // Check if newly unlocked
            if updated[i].currentProgress >= updated[i].requirement && !oldUnlocked {
                updated[i].isUnlocked = true
                updated[i].unlockedDate = Date()
                newlyUnlocked.append(updated[i])
            }
        }

        // Persist progress (not only unlocks) so progress bars survive a relaunch;
        // skip the write when nothing moved.
        if updated != achievements {
            achievements = updated
            saveAchievements()
        }

        if !newlyUnlocked.isEmpty {
            recentlyUnlockedAchievements = newlyUnlocked

            if achievementAlerts {
                for achievement in newlyUnlocked {
                    sendAchievementNotification(achievement)
                }
            }
        }
    }
    
    func calculatePlayStreak() -> Int {
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
    
    
    // MARK: - Custom Tags
    
    func loadCustomTags() {
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
    
    
    // MARK: - Monthly Goals
    
    func loadMonthlyGoals() {
        if let decoded = load([MonthlyGoal].self, key: StorageKeys.monthlyGoals) {
            monthlyGoals = decoded
        }
        if let decoded = load([MonthlyGoal].self, key: StorageKeys.completedGoals) {
            completedGoals = decoded
        }
    }
    
    func saveMonthlyGoals() {
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
        var goals = monthlyGoals
        var doneGoals = completedGoals

        for i in goals.indices {
            // Check if goal is for current month
            guard calendar.component(.month, from: goals[i].month) == currentMonth,
                  calendar.component(.year, from: goals[i].month) == currentYear else {
                continue
            }
            
                        guard let monthStart = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: 1)),
                                    let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart),
                                    let monthEnd = calendar.date(byAdding: .second, value: -1, to: nextMonthStart) else {
                                continue
                        }
            
            switch goals[i].type {
            case .gamesCompleted:
                let completed = myGames.filter { game in
                    guard let completedDate = game.completedDate else { return false }
                    return completedDate >= monthStart && completedDate <= monthEnd &&
                           (game.status == .completed || game.status == .platinum)
                }.count
                goals[i].current = completed
                
            case .hoursPlayed:
                let sessions = playSessions.filter { $0.date >= monthStart && $0.date <= monthEnd }
                let totalMinutes = sessions.reduce(0) { $0 + $1.duration }
                goals[i].current = totalMinutes / 60
                
            case .reviewsWritten:
                // Note: uses startedDate as a proxy since there's no dedicated reviewedDate field
                let reviews = myGames.filter { game in
                    guard let started = game.startedDate, !game.review.isEmpty else { return false }
                    return started >= monthStart && started <= monthEnd
                }.count
                goals[i].current = reviews
                
            case .newGames:
                let newGames = myGames.filter { game in
                    guard let started = game.startedDate else { return false }
                    return started >= monthStart && started <= monthEnd
                }.count
                goals[i].current = newGames
                
            case .platinums:
                let platinums = myGames.filter { game in
                    guard let completedDate = game.completedDate else { return false }
                    return completedDate >= monthStart && completedDate <= monthEnd &&
                           game.status == .platinum
                }.count
                goals[i].current = platinums
                
            case .backlogCleared:
                // For backlog cleared, we count games completed this month
                // (since they were likely in backlog before being completed)
                let cleared = myGames.filter { game in
                    guard let completedDate = game.completedDate else { return false }
                    return completedDate >= monthStart && completedDate <= monthEnd &&
                           (game.status == .completed || game.status == .platinum)
                }.count
                goals[i].current = cleared
            }
            
            // Check if goal is completed
            if goals[i].current >= goals[i].target && goals[i].completedDate == nil {
                goals[i].completedDate = Date()
                doneGoals.append(goals[i])
            }
        }
        
        guard goals != monthlyGoals || doneGoals != completedGoals else { return }
        monthlyGoals = goals
        completedGoals = doneGoals
        saveMonthlyGoals()
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
    
    func sendAchievementNotification(_ achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "Succès débloqué!"
        content.body = "\(achievement.icon) \(achievement.title)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_\(achievement.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
