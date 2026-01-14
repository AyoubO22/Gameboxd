//
//  Game.swift
//  Gameboxd
//
//  Enhanced Game model with full tracking support
//

import SwiftUI

// MARK: - Game Status
enum GameStatus: String, CaseIterable, Codable {
    case none = "Non suivi"
    case wantToPlay = "À jouer"
    case playing = "En cours"
    case completed = "Terminé"
    case shelved = "Abandonné"
    case platinum = "Platiné"
    
    var color: Color {
        switch self {
        case .wantToPlay: return .blue
        case .playing: return .gbGreen
        case .completed: return .orange
        case .shelved: return .red
        case .platinum: return .purple
        case .none: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .wantToPlay: return "bookmark.fill"
        case .playing: return "gamecontroller.fill"
        case .completed: return "checkmark.circle.fill"
        case .shelved: return "archivebox.fill"
        case .platinum: return "trophy.fill"
        case .none: return "circle"
        }
    }
}

// MARK: - Backlog Priority
enum BacklogPriority: String, CaseIterable, Codable {
    case low = "Faible"
    case medium = "Moyenne"
    case high = "Haute"
    case urgent = "Urgent"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - Difficulty
enum GameDifficulty: String, CaseIterable, Codable {
    case easy = "Facile"
    case normal = "Normal"
    case hard = "Difficile"
    case veryHard = "Très difficile"
    case custom = "Personnalisé"
}

// MARK: - Mood Tags
enum MoodTag: String, CaseIterable, Codable {
    case relaxing = "Relaxant"
    case challenging = "Challengeant"
    case emotional = "Émouvant"
    case fun = "Fun"
    case scary = "Effrayant"
    case addictive = "Addictif"
    case beautiful = "Magnifique"
    case mindless = "Détente"
    case stressful = "Stressant"
    case nostalgic = "Nostalgique"
    
    var icon: String {
        switch self {
        case .relaxing: return "leaf.fill"
        case .challenging: return "flame.fill"
        case .emotional: return "heart.fill"
        case .fun: return "face.smiling.fill"
        case .scary: return "eye.fill"
        case .addictive: return "bolt.fill"
        case .beautiful: return "sparkles"
        case .mindless: return "brain.head.profile"
        case .stressful: return "exclamationmark.triangle.fill"
        case .nostalgic: return "clock.arrow.circlepath"
        }
    }
    
    var color: Color {
        switch self {
        case .relaxing: return .green
        case .challenging: return .orange
        case .emotional: return .pink
        case .fun: return .yellow
        case .scary: return .purple
        case .addictive: return .red
        case .beautiful: return .cyan
        case .mindless: return .mint
        case .stressful: return .red
        case .nostalgic: return .brown
        }
    }
}

// MARK: - Sub Ratings
struct SubRatings: Codable, Hashable {
    var story: Int = 0      // 0-5
    var gameplay: Int = 0   // 0-5
    var graphics: Int = 0   // 0-5
    var sound: Int = 0      // 0-5
    
    var average: Double {
        let ratings = [story, gameplay, graphics, sound].filter { $0 > 0 }
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
}

// MARK: - Game Model
struct Game: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let developer: String
    let platform: String
    let releaseYear: String
    var coverImageURL: String?
    let coverColorHex: String
    var rating: Int // 0 à 5
    var subRatings: SubRatings
    var status: GameStatus
    var review: String
    var isSpoiler: Bool
    var playTime: String
    var playTimeMinutes: Int
    var completionPercentage: Int // 0-100
    var difficulty: GameDifficulty?
    var moodTags: [MoodTag]
    var priority: BacklogPriority
    var isFavorite: Bool
    var startedDate: Date?
    var completedDate: Date?
    var rawgId: Int?
    var genres: [String]
    var metacriticScore: Int?
    var estimatedPlaytime: Int? // in hours from RAWG
    var description: String?
    var screenshotURLs: [String]
    var playthroughCount: Int
    var notes: String
    
    // Computed property pour la couleur
    var coverColor: Color {
        Color(hex: coverColorHex)
    }
    
    // Initialiseur complet
    init(
        id: UUID = UUID(),
        title: String,
        developer: String,
        platform: String,
        releaseYear: String,
        coverImageURL: String? = nil,
        coverColor: Color,
        rating: Int = 0,
        subRatings: SubRatings = SubRatings(),
        status: GameStatus = .none,
        review: String = "",
        isSpoiler: Bool = false,
        playTime: String = "",
        playTimeMinutes: Int = 0,
        completionPercentage: Int = 0,
        difficulty: GameDifficulty? = nil,
        moodTags: [MoodTag] = [],
        priority: BacklogPriority = .medium,
        isFavorite: Bool = false,
        startedDate: Date? = nil,
        completedDate: Date? = nil,
        rawgId: Int? = nil,
        genres: [String] = [],
        metacriticScore: Int? = nil,
        estimatedPlaytime: Int? = nil,
        description: String? = nil,
        screenshotURLs: [String] = [],
        playthroughCount: Int = 1,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.developer = developer
        self.platform = platform
        self.releaseYear = releaseYear
        self.coverImageURL = coverImageURL
        self.coverColorHex = coverColor.toHex()
        self.rating = rating
        self.subRatings = subRatings
        self.status = status
        self.review = review
        self.isSpoiler = isSpoiler
        self.playTime = playTime
        self.playTimeMinutes = playTimeMinutes
        self.completionPercentage = completionPercentage
        self.difficulty = difficulty
        self.moodTags = moodTags
        self.priority = priority
        self.isFavorite = isFavorite
        self.startedDate = startedDate
        self.completedDate = completedDate
        self.rawgId = rawgId
        self.genres = genres
        self.metacriticScore = metacriticScore
        self.estimatedPlaytime = estimatedPlaytime
        self.description = description
        self.screenshotURLs = screenshotURLs
        self.playthroughCount = playthroughCount
        self.notes = notes
    }
    
    // Formatted play time
    var formattedPlayTime: String {
        if playTimeMinutes > 0 {
            let hours = playTimeMinutes / 60
            let mins = playTimeMinutes % 60
            if hours > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(mins)m"
            }
        }
        return playTime.isEmpty ? "—" : playTime
    }
    
    // Days since started
    var daysSinceStarted: Int? {
        guard let start = startedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: Date()).day
    }
}

// MARK: - Play Session (Diary Entry)
struct PlaySession: Identifiable, Codable, Hashable {
    let id: UUID
    let gameId: UUID
    let gameTitle: String
    let gameCoverURL: String?
    let gameCoverColorHex: String
    let date: Date
    var duration: Int // minutes
    var rating: Int? // optional rating for this session
    var notes: String
    var isSpoiler: Bool
    var mood: MoodTag?
    
    init(
        id: UUID = UUID(),
        gameId: UUID,
        gameTitle: String,
        gameCoverURL: String? = nil,
        gameCoverColor: Color = .gray,
        date: Date = Date(),
        duration: Int = 0,
        rating: Int? = nil,
        notes: String = "",
        isSpoiler: Bool = false,
        mood: MoodTag? = nil
    ) {
        self.id = id
        self.gameId = gameId
        self.gameTitle = gameTitle
        self.gameCoverURL = gameCoverURL
        self.gameCoverColorHex = gameCoverColor.toHex()
        self.date = date
        self.duration = duration
        self.rating = rating
        self.notes = notes
        self.isSpoiler = isSpoiler
        self.mood = mood
    }
    
    var gameCoverColor: Color {
        Color(hex: gameCoverColorHex)
    }
    
    var formattedDuration: String {
        let hours = duration / 60
        let mins = duration % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Game List (Collection)
struct GameList: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var iconName: String
    var colorHex: String
    var gameIds: [UUID]
    var isDefault: Bool
    var createdDate: Date
    var updatedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        iconName: String = "list.bullet",
        color: Color = .blue,
        gameIds: [UUID] = [],
        isDefault: Bool = false,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.colorHex = color.toHex()
        self.gameIds = gameIds
        self.isDefault = isDefault
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - User Profile
struct UserProfile: Codable {
    var username: String
    var bio: String
    var avatarEmoji: String
    var favoriteGameIds: [UUID] // Max 4
    var yearlyGoal: Int // Number of games to complete
    var joinedDate: Date
    var preferredPlatforms: [String]
    
    init(
        username: String = "Gamer",
        bio: String = "",
        avatarEmoji: String = "🎮",
        favoriteGameIds: [UUID] = [],
        yearlyGoal: Int = 12,
        joinedDate: Date = Date(),
        preferredPlatforms: [String] = []
    ) {
        self.username = username
        self.bio = bio
        self.avatarEmoji = avatarEmoji
        self.favoriteGameIds = favoriteGameIds
        self.yearlyGoal = yearlyGoal
        self.joinedDate = joinedDate
        self.preferredPlatforms = preferredPlatforms
    }
}

// MARK: - Year Stats
struct YearStats {
    let year: Int
    let gamesPlayed: Int
    let gamesCompleted: Int
    let totalPlayTime: Int // minutes
    let averageRating: Double
    let topGenres: [(String, Int)]
    let topPlatforms: [(String, Int)]
    let favoriteGame: Game?
    let mostPlayedGame: Game?
}
