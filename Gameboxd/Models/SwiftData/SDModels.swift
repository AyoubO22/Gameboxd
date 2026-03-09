//
//  SDModels.swift
//  Gameboxd
//
//  SwiftData @Model classes mirroring the existing Codable structs.
//  Each class is prefixed with SD and provides round-trip conversion
//  via init(from:) and toStructType().
//

import SwiftData
import SwiftUI

// MARK: - Helpers

/// Encodes an array of strings as a single comma-separated string for storage.
/// Returns an empty string for an empty array so the field is never nil.
private func joinStrings(_ values: [String]) -> String {
    values.joined(separator: ",")
}

/// Decodes a comma-separated storage string back into a [String] array.
/// An empty storage string yields an empty array.
private func splitStrings(_ value: String) -> [String] {
    guard !value.isEmpty else { return [] }
    return value.components(separatedBy: ",")
}

/// Encodes a [UUID] array as a comma-separated string.
private func joinUUIDs(_ values: [UUID]) -> String {
    values.map(\.uuidString).joined(separator: ",")
}

/// Decodes a comma-separated UUID string back into [UUID].
private func splitUUIDs(_ value: String) -> [UUID] {
    guard !value.isEmpty else { return [] }
    return value.components(separatedBy: ",").compactMap { UUID(uuidString: $0) }
}

// MARK: - SDGame

/// SwiftData model mirroring the `Game` struct.
/// Flattened fields: SubRatings (story, gameplay, graphics, sound) are stored directly.
/// Arrays of enums are stored as comma-separated rawValue strings.
/// Arrays of String are stored as comma-separated strings.
@Model
final class SDGame {

    // MARK: Identity
    @Attribute(.unique) var id: UUID

    // MARK: Core metadata
    var title: String
    var developer: String
    var platform: String
    var releaseYear: String
    var coverImageURL: String?
    /// Hex string representation of the cover colour (e.g. "#1A2B3C").
    var coverColorHex: String

    // MARK: Ratings
    var rating: Int
    /// SubRatings.story (0-5)
    var subRatingStory: Int
    /// SubRatings.gameplay (0-5)
    var subRatingGameplay: Int
    /// SubRatings.graphics (0-5)
    var subRatingGraphics: Int
    /// SubRatings.sound (0-5)
    var subRatingSound: Int

    // MARK: Status & review
    /// `GameStatus.rawValue`
    var statusRaw: String
    var review: String
    var isSpoiler: Bool

    // MARK: Play time
    var playTime: String
    var playTimeMinutes: Int
    var completionPercentage: Int

    // MARK: Optional metadata
    /// `GameDifficulty.rawValue` — nil when not set
    var difficultyRaw: String?
    /// Comma-separated `MoodTag.rawValue` strings
    var moodTagsRaw: String
    /// `BacklogPriority.rawValue`
    var priorityRaw: String
    var isFavorite: Bool

    // MARK: Dates
    var startedDate: Date?
    var completedDate: Date?

    // MARK: RAWG / external data
    var rawgId: Int?
    /// Comma-separated genre strings
    var genresRaw: String
    var metacriticScore: Int?
    var estimatedPlaytime: Int?
    var gameDescription: String?
    /// Comma-separated screenshot URL strings
    var screenshotURLsRaw: String

    // MARK: Tracking
    var playthroughCount: Int
    var notes: String

    // MARK: - Initialiser from struct

    init(from game: Game) {
        self.id = game.id
        self.title = game.title
        self.developer = game.developer
        self.platform = game.platform
        self.releaseYear = game.releaseYear
        self.coverImageURL = game.coverImageURL
        self.coverColorHex = game.coverColorHex
        self.rating = game.rating
        self.subRatingStory = game.subRatings.story
        self.subRatingGameplay = game.subRatings.gameplay
        self.subRatingGraphics = game.subRatings.graphics
        self.subRatingSound = game.subRatings.sound
        self.statusRaw = game.status.rawValue
        self.review = game.review
        self.isSpoiler = game.isSpoiler
        self.playTime = game.playTime
        self.playTimeMinutes = game.playTimeMinutes
        self.completionPercentage = game.completionPercentage
        self.difficultyRaw = game.difficulty?.rawValue
        self.moodTagsRaw = joinStrings(game.moodTags.map(\.rawValue))
        self.priorityRaw = game.priority.rawValue
        self.isFavorite = game.isFavorite
        self.startedDate = game.startedDate
        self.completedDate = game.completedDate
        self.rawgId = game.rawgId
        self.genresRaw = joinStrings(game.genres)
        self.metacriticScore = game.metacriticScore
        self.estimatedPlaytime = game.estimatedPlaytime
        self.gameDescription = game.description
        self.screenshotURLsRaw = joinStrings(game.screenshotURLs)
        self.playthroughCount = game.playthroughCount
        self.notes = game.notes
    }

    // MARK: - Conversion back to struct

    func toStructType() -> Game {
        let subRatings = SubRatings(
            story: subRatingStory,
            gameplay: subRatingGameplay,
            graphics: subRatingGraphics,
            sound: subRatingSound
        )
        let moodTags: [MoodTag] = splitStrings(moodTagsRaw).compactMap { MoodTag(rawValue: $0) }
        let genres = splitStrings(genresRaw)
        let screenshotURLs = splitStrings(screenshotURLsRaw)

        return Game(
            id: id,
            title: title,
            developer: developer,
            platform: platform,
            releaseYear: releaseYear,
            coverImageURL: coverImageURL,
            coverColor: Color(hex: coverColorHex),
            rating: rating,
            subRatings: subRatings,
            status: GameStatus(rawValue: statusRaw) ?? .none,
            review: review,
            isSpoiler: isSpoiler,
            playTime: playTime,
            playTimeMinutes: playTimeMinutes,
            completionPercentage: completionPercentage,
            difficulty: difficultyRaw.flatMap { GameDifficulty(rawValue: $0) },
            moodTags: moodTags,
            priority: BacklogPriority(rawValue: priorityRaw) ?? .medium,
            isFavorite: isFavorite,
            startedDate: startedDate,
            completedDate: completedDate,
            rawgId: rawgId,
            genres: genres,
            metacriticScore: metacriticScore,
            estimatedPlaytime: estimatedPlaytime,
            description: gameDescription,
            screenshotURLs: screenshotURLs,
            playthroughCount: playthroughCount,
            notes: notes
        )
    }
}

// MARK: - SDPlaySession

/// SwiftData model mirroring the `PlaySession` struct.
@Model
final class SDPlaySession {

    @Attribute(.unique) var id: UUID
    var gameId: UUID
    var gameTitle: String
    var gameCoverURL: String?
    var gameCoverColorHex: String
    var date: Date
    var duration: Int
    var rating: Int?
    var notes: String
    var isSpoiler: Bool
    /// `MoodTag.rawValue` — nil when not set
    var moodRaw: String?

    // MARK: - Initialiser from struct

    init(from session: PlaySession) {
        self.id = session.id
        self.gameId = session.gameId
        self.gameTitle = session.gameTitle
        self.gameCoverURL = session.gameCoverURL
        self.gameCoverColorHex = session.gameCoverColorHex
        self.date = session.date
        self.duration = session.duration
        self.rating = session.rating
        self.notes = session.notes
        self.isSpoiler = session.isSpoiler
        self.moodRaw = session.mood?.rawValue
    }

    // MARK: - Conversion back to struct

    func toStructType() -> PlaySession {
        PlaySession(
            id: id,
            gameId: gameId,
            gameTitle: gameTitle,
            gameCoverURL: gameCoverURL,
            gameCoverColor: Color(hex: gameCoverColorHex),
            date: date,
            duration: duration,
            rating: rating,
            notes: notes,
            isSpoiler: isSpoiler,
            mood: moodRaw.flatMap { MoodTag(rawValue: $0) }
        )
    }
}

// MARK: - SDGameList

/// SwiftData model mirroring the `GameList` struct.
/// Game IDs are stored as a comma-separated UUID string.
@Model
final class SDGameList {

    @Attribute(.unique) var id: UUID
    var name: String
    var listDescription: String
    var iconName: String
    /// Hex string of the list colour
    var colorHex: String
    /// Comma-separated UUID strings
    var gameIdsRaw: String
    var isDefault: Bool
    var createdDate: Date
    var updatedDate: Date

    // MARK: - Initialiser from struct

    init(from list: GameList) {
        self.id = list.id
        self.name = list.name
        self.listDescription = list.description
        self.iconName = list.iconName
        self.colorHex = list.colorHex
        self.gameIdsRaw = joinUUIDs(list.gameIds)
        self.isDefault = list.isDefault
        self.createdDate = list.createdDate
        self.updatedDate = list.updatedDate
    }

    // MARK: - Conversion back to struct

    func toStructType() -> GameList {
        GameList(
            id: id,
            name: name,
            description: listDescription,
            iconName: iconName,
            color: Color(hex: colorHex),
            gameIds: splitUUIDs(gameIdsRaw),
            isDefault: isDefault,
            createdDate: createdDate,
            updatedDate: updatedDate
        )
    }
}

// MARK: - SDUserProfile

/// SwiftData model mirroring the `UserProfile` struct.
/// There is typically only one profile per user; uniqueness is enforced on the
/// authProviderUserId field which acts as a logical primary key.
/// We still use a generated UUID as the SwiftData identity.
@Model
final class SDUserProfile {

    @Attribute(.unique) var id: UUID
    var username: String
    var bio: String
    var avatarEmoji: String
    /// Comma-separated UUID strings for favourite games (max 4)
    var favoriteGameIdsRaw: String
    var yearlyGoal: Int
    var joinedDate: Date
    /// Comma-separated preferred platform strings
    var preferredPlatformsRaw: String
    var email: String
    var authProvider: String
    var authProviderUserId: String
    var avatarURL: String?
    var needsUsernameSetup: Bool

    // MARK: - Initialiser from struct

    init(id: UUID = UUID(), from profile: UserProfile) {
        self.id = id
        self.username = profile.username
        self.bio = profile.bio
        self.avatarEmoji = profile.avatarEmoji
        self.favoriteGameIdsRaw = joinUUIDs(profile.favoriteGameIds)
        self.yearlyGoal = profile.yearlyGoal
        self.joinedDate = profile.joinedDate
        self.preferredPlatformsRaw = joinStrings(profile.preferredPlatforms)
        self.email = profile.email
        self.authProvider = profile.authProvider
        self.authProviderUserId = profile.authProviderUserId
        self.avatarURL = profile.avatarURL
        self.needsUsernameSetup = profile.needsUsernameSetup
    }

    // MARK: - Conversion back to struct

    func toStructType() -> UserProfile {
        UserProfile(
            username: username,
            bio: bio,
            avatarEmoji: avatarEmoji,
            favoriteGameIds: splitUUIDs(favoriteGameIdsRaw),
            yearlyGoal: yearlyGoal,
            joinedDate: joinedDate,
            preferredPlatforms: splitStrings(preferredPlatformsRaw),
            email: email,
            authProvider: authProvider,
            authProviderUserId: authProviderUserId,
            avatarURL: avatarURL,
            needsUsernameSetup: needsUsernameSetup
        )
    }
}

// MARK: - SDAchievement

/// SwiftData model mirroring the `Achievement` struct.
/// `Achievement.id` is a String (not UUID), so it is stored as-is.
@Model
final class SDAchievement {

    /// String identifier matching `Achievement.id` (e.g. "first_game").
    @Attribute(.unique) var achievementId: String
    var title: String
    var achievementDescription: String
    var icon: String
    /// `AchievementCategory.rawValue`
    var categoryRaw: String
    var requirement: Int
    var currentProgress: Int
    var isUnlocked: Bool
    var unlockedDate: Date?

    // MARK: - Initialiser from struct

    init(from achievement: Achievement) {
        self.achievementId = achievement.id
        self.title = achievement.title
        self.achievementDescription = achievement.description
        self.icon = achievement.icon
        self.categoryRaw = achievement.category.rawValue
        self.requirement = achievement.requirement
        self.currentProgress = achievement.currentProgress
        self.isUnlocked = achievement.isUnlocked
        self.unlockedDate = achievement.unlockedDate
    }

    // MARK: - Conversion back to struct

    func toStructType() -> Achievement {
        Achievement(
            id: achievementId,
            title: title,
            description: achievementDescription,
            icon: icon,
            category: AchievementCategory(rawValue: categoryRaw) ?? .collection,
            requirement: requirement,
            currentProgress: currentProgress,
            isUnlocked: isUnlocked,
            unlockedDate: unlockedDate
        )
    }
}

// MARK: - SDCustomTag

/// SwiftData model mirroring the `CustomTag` struct.
@Model
final class SDCustomTag {

    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var icon: String

    // MARK: - Initialiser from struct

    init(from tag: CustomTag) {
        self.id = tag.id
        self.name = tag.name
        self.colorHex = tag.colorHex
        self.icon = tag.icon
    }

    // MARK: - Conversion back to struct

    func toStructType() -> CustomTag {
        CustomTag(
            id: id,
            name: name,
            colorHex: colorHex,
            icon: icon
        )
    }
}

// MARK: - SDFriend

/// SwiftData model mirroring the `Friend` struct.
@Model
final class SDFriend {

    @Attribute(.unique) var id: UUID
    var username: String
    var avatarEmoji: String
    var gamesCount: Int
    var isFollowing: Bool
    var lastActive: Date

    // MARK: - Initialiser from struct

    init(from friend: Friend) {
        self.id = friend.id
        self.username = friend.username
        self.avatarEmoji = friend.avatarEmoji
        self.gamesCount = friend.gamesCount
        self.isFollowing = friend.isFollowing
        self.lastActive = friend.lastActive
    }

    // MARK: - Conversion back to struct

    func toStructType() -> Friend {
        Friend(
            id: id,
            username: username,
            avatarEmoji: avatarEmoji,
            gamesCount: gamesCount,
            isFollowing: isFollowing,
            lastActive: lastActive
        )
    }
}

// MARK: - SDActivityItem

/// SwiftData model mirroring the `ActivityItem` struct.
@Model
final class SDActivityItem {

    @Attribute(.unique) var id: UUID
    var username: String
    var avatarEmoji: String
    /// `ActivityItem.ActivityType.rawValue`
    var actionTypeRaw: String
    var gameTitle: String
    var gameCoverURL: String?
    var rating: Int?
    var review: String?
    var timestamp: Date

    // MARK: - Initialiser from struct

    init(from item: ActivityItem) {
        self.id = item.id
        self.username = item.username
        self.avatarEmoji = item.avatarEmoji
        self.actionTypeRaw = item.actionType.rawValue
        self.gameTitle = item.gameTitle
        self.gameCoverURL = item.gameCoverURL
        self.rating = item.rating
        self.review = item.review
        self.timestamp = item.timestamp
    }

    // MARK: - Conversion back to struct

    func toStructType() -> ActivityItem {
        ActivityItem(
            id: id,
            username: username,
            avatarEmoji: avatarEmoji,
            actionType: ActivityItem.ActivityType(rawValue: actionTypeRaw) ?? .played,
            gameTitle: gameTitle,
            gameCoverURL: gameCoverURL,
            rating: rating,
            review: review,
            timestamp: timestamp
        )
    }
}

// MARK: - SDGameNotification

/// SwiftData model mirroring the `GameNotification` struct.
@Model
final class SDGameNotification {

    @Attribute(.unique) var id: UUID
    var gameId: UUID
    var gameTitle: String
    var releaseDate: Date
    var isEnabled: Bool
    var notifyDaysBefore: Int

    // MARK: - Initialiser from struct

    init(from notification: GameNotification) {
        self.id = notification.id
        self.gameId = notification.gameId
        self.gameTitle = notification.gameTitle
        self.releaseDate = notification.releaseDate
        self.isEnabled = notification.isEnabled
        self.notifyDaysBefore = notification.notifyDaysBefore
    }

    // MARK: - Conversion back to struct

    func toStructType() -> GameNotification {
        GameNotification(
            id: id,
            gameId: gameId,
            gameTitle: gameTitle,
            releaseDate: releaseDate,
            isEnabled: isEnabled,
            notifyDaysBefore: notifyDaysBefore
        )
    }
}

// MARK: - SDMonthlyGoal

/// SwiftData model mirroring the `MonthlyGoal` struct from Goal.swift.
@Model
final class SDMonthlyGoal {

    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var icon: String
    /// `GoalType.rawValue`
    var typeRaw: String
    var target: Int
    var current: Int
    var month: Date
    var completedDate: Date?

    // MARK: - Initialiser from struct

    init(from goal: MonthlyGoal) {
        self.id = goal.id
        self.title = goal.title
        self.goalDescription = goal.description
        self.icon = goal.icon
        self.typeRaw = goal.type.rawValue
        self.target = goal.target
        self.current = goal.current
        self.month = goal.month
        self.completedDate = goal.completedDate
    }

    // MARK: - Conversion back to struct

    func toStructType() -> MonthlyGoal {
        MonthlyGoal(
            id: id,
            title: title,
            description: goalDescription,
            icon: icon,
            type: GoalType(rawValue: typeRaw) ?? .gamesCompleted,
            target: target,
            current: current,
            month: month,
            completedDate: completedDate
        )
    }
}

// MARK: - SDLinkedAccount

/// SwiftData model mirroring the `LinkedAccount` struct from LinkedAccount.swift.
@Model
final class SDLinkedAccount {

    @Attribute(.unique) var id: UUID
    /// `GamingPlatform.rawValue`
    var platformRaw: String
    var platformUserId: String
    var platformUsername: String
    var avatarURL: String?
    var linkedDate: Date
    var lastSyncDate: Date?
    var isActive: Bool
    var importedGameCount: Int
    var trophyCount: Int?
    var achievementCount: Int?
    var level: Int?

    // MARK: - Initialiser from struct

    init(from account: LinkedAccount) {
        self.id = account.id
        self.platformRaw = account.platform.rawValue
        self.platformUserId = account.platformUserId
        self.platformUsername = account.platformUsername
        self.avatarURL = account.avatarURL
        self.linkedDate = account.linkedDate
        self.lastSyncDate = account.lastSyncDate
        self.isActive = account.isActive
        self.importedGameCount = account.importedGameCount
        self.trophyCount = account.trophyCount
        self.achievementCount = account.achievementCount
        self.level = account.level
    }

    // MARK: - Conversion back to struct

    func toStructType() -> LinkedAccount {
        LinkedAccount(
            id: id,
            platform: GamingPlatform(rawValue: platformRaw) ?? .steam,
            platformUserId: platformUserId,
            platformUsername: platformUsername,
            avatarURL: avatarURL,
            linkedDate: linkedDate,
            lastSyncDate: lastSyncDate,
            isActive: isActive,
            importedGameCount: importedGameCount,
            trophyCount: trophyCount,
            achievementCount: achievementCount,
            level: level
        )
    }
}

// MARK: - SDImportedGame

/// SwiftData model mirroring the `ImportedGame` struct from LinkedAccount.swift.
@Model
final class SDImportedGame {

    @Attribute(.unique) var id: UUID
    /// `GamingPlatform.rawValue`
    var platformRaw: String
    var platformGameId: String
    var title: String
    var coverImageURL: String?
    var playtimeMinutes: Int
    var lastPlayed: Date?
    var achievementsEarned: Int
    var achievementsTotal: Int
    var isImportedToLibrary: Bool
    var linkedGameId: UUID?

    // MARK: - Initialiser from struct

    init(from game: ImportedGame) {
        self.id = game.id
        self.platformRaw = game.platform.rawValue
        self.platformGameId = game.platformGameId
        self.title = game.title
        self.coverImageURL = game.coverImageURL
        self.playtimeMinutes = game.playtimeMinutes
        self.lastPlayed = game.lastPlayed
        self.achievementsEarned = game.achievementsEarned
        self.achievementsTotal = game.achievementsTotal
        self.isImportedToLibrary = game.isImportedToLibrary
        self.linkedGameId = game.linkedGameId
    }

    // MARK: - Conversion back to struct

    func toStructType() -> ImportedGame {
        ImportedGame(
            id: id,
            platform: GamingPlatform(rawValue: platformRaw) ?? .steam,
            platformGameId: platformGameId,
            title: title,
            coverImageURL: coverImageURL,
            playtimeMinutes: playtimeMinutes,
            lastPlayed: lastPlayed,
            achievementsEarned: achievementsEarned,
            achievementsTotal: achievementsTotal,
            isImportedToLibrary: isImportedToLibrary,
            linkedGameId: linkedGameId
        )
    }
}
