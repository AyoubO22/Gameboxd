//
//  Achievement.swift
//  Gameboxd
//
//  Achievement and CustomTag model definitions.
//

import SwiftUI

// MARK: - Achievement

struct Achievement: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String
    var icon: String
    var category: AchievementCategory
    var requirement: Int
    var currentProgress: Int
    var isUnlocked: Bool
    var unlockedDate: Date?

    var progressPercentage: Double {
        guard requirement > 0 else { return 0 }
        return min(Double(currentProgress) / Double(requirement), 1.0)
    }
}

// MARK: - AchievementCategory

enum AchievementCategory: String, Codable, CaseIterable, Hashable {
    case collection = "Collection"
    case completion = "Complétion"
    case time = "Temps de jeu"
    case exploration = "Exploration"
    case social = "Social"
    case dedication = "Dévotion"

    var icon: String {
        switch self {
        case .collection: return "books.vertical"
        case .completion: return "checkmark.seal"
        case .time: return "clock"
        case .exploration: return "safari"
        case .social: return "person.2"
        case .dedication: return "flame"
        }
    }
}

// MARK: - AchievementDefinition

struct AchievementDefinition {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let requirement: Int
}

enum AchievementDefinitions {
    static let all: [AchievementDefinition] = [
        // Collection
        AchievementDefinition(id: "first_game", title: "Premier pas", description: "Ajoute ton premier jeu", icon: "🎮", category: .collection, requirement: 1),
        AchievementDefinition(id: "collector_10", title: "Collectionneur", description: "Ajoute 10 jeux à ta bibliothèque", icon: "📚", category: .collection, requirement: 10),
        AchievementDefinition(id: "collector_50", title: "Grand collectionneur", description: "Ajoute 50 jeux à ta bibliothèque", icon: "🏛️", category: .collection, requirement: 50),
        AchievementDefinition(id: "collector_100", title: "Bibliothécaire", description: "Ajoute 100 jeux à ta bibliothèque", icon: "📖", category: .collection, requirement: 100),

        // Completion
        AchievementDefinition(id: "complete_10", title: "Finisseur", description: "Termine 10 jeux", icon: "✅", category: .completion, requirement: 10),
        AchievementDefinition(id: "complete_25", title: "Marathonien", description: "Termine 25 jeux", icon: "🏅", category: .completion, requirement: 25),
        AchievementDefinition(id: "platinum_5", title: "Platine", description: "Obtiens 5 platines", icon: "💎", category: .completion, requirement: 5),

        // Time
        AchievementDefinition(id: "time_100", title: "Joueur assidu", description: "Joue pendant 100 heures", icon: "⏰", category: .time, requirement: 100),
        AchievementDefinition(id: "time_500", title: "Vétéran", description: "Joue pendant 500 heures", icon: "🕐", category: .time, requirement: 500),
        AchievementDefinition(id: "time_1000", title: "Légende", description: "Joue pendant 1000 heures", icon: "👑", category: .time, requirement: 1000),

        // Exploration
        AchievementDefinition(id: "genres_5", title: "Explorateur", description: "Joue à 5 genres différents", icon: "🧭", category: .exploration, requirement: 5),
        AchievementDefinition(id: "platforms_3", title: "Multi-plateforme", description: "Joue sur 3 plateformes différentes", icon: "🖥️", category: .exploration, requirement: 3),
        AchievementDefinition(id: "indie_lover", title: "Indie lover", description: "Joue à 20 jeux indépendants", icon: "🎨", category: .exploration, requirement: 20),
        AchievementDefinition(id: "retro_gamer", title: "Rétro gamer", description: "Joue à 10 jeux d'avant 2000", icon: "👾", category: .exploration, requirement: 10),
        AchievementDefinition(id: "favorite_genre", title: "Spécialiste", description: "Joue à 10 jeux du même genre", icon: "🎯", category: .exploration, requirement: 10),

        // Social
        AchievementDefinition(id: "reviews_10", title: "Critique", description: "Écris 10 critiques", icon: "✍️", category: .social, requirement: 10),
        AchievementDefinition(id: "lists_5", title: "Curateur", description: "Crée 5 listes", icon: "📋", category: .social, requirement: 5),

        // Dedication
        AchievementDefinition(id: "streak_7", title: "Régulier", description: "Joue 7 jours de suite", icon: "🔥", category: .dedication, requirement: 7),
        AchievementDefinition(id: "streak_30", title: "Inarrêtable", description: "Joue 30 jours de suite", icon: "💪", category: .dedication, requirement: 30),
    ]
}

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case `default` = "default"
    case ocean = "ocean"
    case sunset = "sunset"
    case purple = "purple"
    case gold = "gold"
    case mint = "mint"
    case rose = "rose"
    case cyber = "cyber"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .default: return "Gameboy"
        case .ocean: return "Océan"
        case .sunset: return "Coucher de soleil"
        case .purple: return "Violet"
        case .gold: return "Or"
        case .mint: return "Menthe"
        case .rose: return "Rose"
        case .cyber: return "Cyber"
        }
    }

    var accentColor: Color {
        switch self {
        case .default: return Color(hex: "00E676")
        case .ocean: return Color(hex: "29B6F6")
        case .sunset: return Color(hex: "FF7043")
        case .purple: return Color(hex: "AB47BC")
        case .gold: return Color(hex: "FFD54F")
        case .mint: return Color(hex: "26A69A")
        case .rose: return Color(hex: "EC407A")
        case .cyber: return Color(hex: "00E5FF")
        }
    }

    var darkColor: Color {
        switch self {
        case .default: return Color(hex: "121212")
        case .ocean: return Color(hex: "0D1B2A")
        case .sunset: return Color(hex: "1A1210")
        case .purple: return Color(hex: "1A0E2E")
        case .gold: return Color(hex: "1A1708")
        case .mint: return Color(hex: "0D1F1C")
        case .rose: return Color(hex: "1A0D14")
        case .cyber: return Color(hex: "0A0E17")
        }
    }

    var cardColor: Color {
        switch self {
        case .default: return Color(hex: "1E1E1E")
        case .ocean: return Color(hex: "1B2838")
        case .sunset: return Color(hex: "2A1E1A")
        case .purple: return Color(hex: "2A1840")
        case .gold: return Color(hex: "2A2510")
        case .mint: return Color(hex: "1A302C")
        case .rose: return Color(hex: "2A1520")
        case .cyber: return Color(hex: "141A26")
        }
    }
}

// MARK: - Friend

struct Friend: Identifiable, Codable {
    var id = UUID()
    var username: String
    var avatarEmoji: String
    var gamesCount: Int
    var isFollowing: Bool = true
    var lastActive: Date = Date()
}

// MARK: - ActivityItem

struct ActivityItem: Identifiable, Codable {
    var id: UUID
    var username: String
    var avatarEmoji: String
    var actionType: ActivityType
    var gameTitle: String
    var gameCoverURL: String?
    var rating: Int?
    var review: String?
    var timestamp: Date

    enum ActivityType: String, Codable {
        case played = "joue à"
        case completed = "a terminé"
        case rated = "a noté"
        case reviewed = "a critiqué"
        case added = "a ajouté"
    }
}

// MARK: - GameNotification

struct GameNotification: Identifiable, Codable {
    var id = UUID()
    var gameId: UUID
    var gameTitle: String
    var releaseDate: Date
    var isEnabled: Bool = true
    var notifyDaysBefore: Int = 1
}

// MARK: - CustomTag

struct CustomTag: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var icon: String

    init(id: UUID = UUID(), name: String, colorHex: String, icon: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
    }

    var color: Color {
        Color(hex: colorHex)
    }

    static let suggestions: [CustomTag] = [
        CustomTag(name: "Chef-d'œuvre", colorHex: "FFD700", icon: "crown"),
        CustomTag(name: "Multijoueur", colorHex: "4A90D9", icon: "person.2.fill"),
        CustomTag(name: "Solo", colorHex: "9B59B6", icon: "person.fill"),
        CustomTag(name: "Coop", colorHex: "2ECC71", icon: "person.3.fill"),
        CustomTag(name: "Compétitif", colorHex: "E74C3C", icon: "flame.fill"),
        CustomTag(name: "Détente", colorHex: "1ABC9C", icon: "leaf.fill"),
        CustomTag(name: "Histoire", colorHex: "E67E22", icon: "book.fill"),
        CustomTag(name: "Nostalgie", colorHex: "F39C12", icon: "clock.arrow.circlepath"),
    ]
}
