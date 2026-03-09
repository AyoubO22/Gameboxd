//
//  MigrationService.swift
//  Gameboxd
//
//  One-shot migration from UserDefaults (Codable structs) to SwiftData.
//  Call `MigrationService.migrateIfNeeded(into:)` once during app startup,
//  before your GameStore or any other observer reads from SwiftData.
//
//  The migration is idempotent: a UserDefaults flag prevents it from running
//  more than once per device install.
//

import Foundation
import SwiftData

// MARK: - MigrationService

/// Reads every persisted UserDefaults key that GameStore uses, decodes the
/// data via the existing Codable structs, then inserts the corresponding SD
/// model objects into the provided ModelContext.
///
/// Usage:
/// ```swift
/// let container = try ModelContainer(for: SDGame.self, ...)
/// MigrationService.migrateIfNeeded(into: container.mainContext)
/// ```
public enum MigrationService {

    // MARK: - Migration flag

    /// UserDefaults key written after a successful migration.
    public static let migrationFlagKey = "gameboxd_migrated_to_swiftdata"

    // MARK: - Storage keys (mirrors GameStore.StorageKeys)

    private enum StorageKeys {
        static let myGames          = "gameboxd_my_games"
        static let playSessions     = "gameboxd_play_sessions"
        static let gameLists        = "gameboxd_game_lists"
        static let userProfile      = "gameboxd_user_profile"
        static let achievements     = "gameboxd_achievements"
        static let customTags       = "gameboxd_custom_tags"
        static let friends          = "gameboxd_friends"
        static let monthlyGoals     = "gameboxd_monthly_goals"
        static let completedGoals   = "gameboxd_completed_goals"
        static let linkedAccounts   = "gameboxd_linked_accounts"
        static let importedGames    = "gameboxd_imported_games"
        static let activityFeed     = "gameboxd_activity_feed"
    }

    // MARK: - Entry point

    /// Performs the migration if it has never been run on this device.
    ///
    /// - Parameter context: The SwiftData `ModelContext` to insert objects into.
    ///   This must be the main-actor context if called on the main thread, or a
    ///   background context for off-thread use. The caller is responsible for
    ///   choosing the correct concurrency context.
    public static func migrateIfNeeded(into context: ModelContext) {
        let defaults = UserDefaults.standard

        // Guard: only run once per install
        guard !defaults.bool(forKey: migrationFlagKey) else {
            return
        }

        migrateGames(into: context, using: defaults)
        migratePlaySessions(into: context, using: defaults)
        migrateGameLists(into: context, using: defaults)
        migrateUserProfile(into: context, using: defaults)
        migrateAchievements(into: context, using: defaults)
        migrateCustomTags(into: context, using: defaults)
        migrateFriends(into: context, using: defaults)
        migrateMonthlyGoals(into: context, using: defaults, key: StorageKeys.monthlyGoals)
        migrateMonthlyGoals(into: context, using: defaults, key: StorageKeys.completedGoals)
        migrateLinkedAccounts(into: context, using: defaults)
        migrateImportedGames(into: context, using: defaults)
        migrateActivityFeed(into: context, using: defaults)

        do {
            try context.save()
            defaults.set(true, forKey: migrationFlagKey)
        } catch {
            // Log and leave the flag unset so the migration will be retried
            // on the next launch. No data is lost because UserDefaults is still intact.
            print("[MigrationService] SwiftData save failed: \(error). Migration will retry on next launch.")
        }
    }

    // MARK: - Per-type migrators

    private static func migrateGames(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.myGames),
            let games = try? JSONDecoder().decode([Game].self, from: data)
        else { return }

        for game in games {
            let sdGame = SDGame(from: game)
            context.insert(sdGame)
        }
        print("[MigrationService] Migrated \(games.count) game(s).")
    }

    private static func migratePlaySessions(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.playSessions),
            let sessions = try? JSONDecoder().decode([PlaySession].self, from: data)
        else { return }

        for session in sessions {
            let sdSession = SDPlaySession(from: session)
            context.insert(sdSession)
        }
        print("[MigrationService] Migrated \(sessions.count) play session(s).")
    }

    private static func migrateGameLists(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.gameLists),
            let lists = try? JSONDecoder().decode([GameList].self, from: data)
        else { return }

        for list in lists {
            let sdList = SDGameList(from: list)
            context.insert(sdList)
        }
        print("[MigrationService] Migrated \(lists.count) game list(s).")
    }

    private static func migrateUserProfile(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.userProfile),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return }

        let sdProfile = SDUserProfile(from: profile)
        context.insert(sdProfile)
        print("[MigrationService] Migrated user profile (\(profile.username)).")
    }

    private static func migrateAchievements(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.achievements),
            let achievements = try? JSONDecoder().decode([Achievement].self, from: data)
        else { return }

        for achievement in achievements {
            let sdAchievement = SDAchievement(from: achievement)
            context.insert(sdAchievement)
        }
        print("[MigrationService] Migrated \(achievements.count) achievement(s).")
    }

    private static func migrateCustomTags(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.customTags),
            let tags = try? JSONDecoder().decode([CustomTag].self, from: data)
        else { return }

        for tag in tags {
            let sdTag = SDCustomTag(from: tag)
            context.insert(sdTag)
        }
        print("[MigrationService] Migrated \(tags.count) custom tag(s).")
    }

    private static func migrateFriends(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.friends),
            let friends = try? JSONDecoder().decode([Friend].self, from: data)
        else { return }

        for friend in friends {
            let sdFriend = SDFriend(from: friend)
            context.insert(sdFriend)
        }
        print("[MigrationService] Migrated \(friends.count) friend(s).")
    }

    /// Migrates both `monthlyGoals` and `completedGoals` keys — both are `[MonthlyGoal]`.
    private static func migrateMonthlyGoals(
        into context: ModelContext,
        using defaults: UserDefaults,
        key: String
    ) {
        guard
            let data = defaults.data(forKey: key),
            let goals = try? JSONDecoder().decode([MonthlyGoal].self, from: data)
        else { return }

        for goal in goals {
            let sdGoal = SDMonthlyGoal(from: goal)
            context.insert(sdGoal)
        }
        print("[MigrationService] Migrated \(goals.count) goal(s) from key '\(key)'.")
    }

    private static func migrateLinkedAccounts(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.linkedAccounts),
            let accounts = try? JSONDecoder().decode([LinkedAccount].self, from: data)
        else { return }

        for account in accounts {
            let sdAccount = SDLinkedAccount(from: account)
            context.insert(sdAccount)
        }
        print("[MigrationService] Migrated \(accounts.count) linked account(s).")
    }

    private static func migrateImportedGames(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.importedGames),
            let games = try? JSONDecoder().decode([ImportedGame].self, from: data)
        else { return }

        for game in games {
            let sdGame = SDImportedGame(from: game)
            context.insert(sdGame)
        }
        print("[MigrationService] Migrated \(games.count) imported game(s).")
    }

    private static func migrateActivityFeed(into context: ModelContext, using defaults: UserDefaults) {
        guard
            let data = defaults.data(forKey: StorageKeys.activityFeed),
            let items = try? JSONDecoder().decode([ActivityItem].self, from: data)
        else { return }

        for item in items {
            let sdItem = SDActivityItem(from: item)
            context.insert(sdItem)
        }
        print("[MigrationService] Migrated \(items.count) activity item(s).")
    }
}
