//
//  Achievement.swift
//  Gameboxd
//
//  Achievement/Badge system for gamification
//

import SwiftUI

// MARK: - Achievement Model
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let requirement: Int
    var currentProgress: Int = 0
    var isUnlocked: Bool = false
    var unlockedDate: Date?
    
    var progressPercentage: Double {
        min(Double(currentProgress) / Double(requirement), 1.0)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, icon, category, requirement, currentProgress, isUnlocked, unlockedDate
    }
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id && lhs.isUnlocked == rhs.isUnlocked && lhs.currentProgress == rhs.currentProgress
    }
}

enum AchievementCategory: String, Codable, CaseIterable {
    case collection = "Collection"
    case completion = "Complétion"
    case time = "Temps de jeu"
    case social = "Social"
    case exploration = "Exploration"
    case dedication = "Dévouement"
    
    var icon: String {
        switch self {
        case .collection: return "square.stack.3d.up.fill"
        case .completion: return "checkmark.seal.fill"
        case .time: return "clock.fill"
        case .social: return "person.2.fill"
        case .exploration: return "binoculars.fill"
        case .dedication: return "flame.fill"
        }
    }
}

// MARK: - Achievement Definitions
struct AchievementDefinitions {
    static let all: [(id: String, title: String, description: String, icon: String, category: AchievementCategory, requirement: Int)] = [
        // Collection Achievements
        ("first_game", "Premier pas", "Ajoute ton premier jeu", "gamecontroller.fill", .collection, 1),
        ("collector_10", "Collectionneur", "Ajoute 10 jeux à ta collection", "square.stack.3d.up.fill", .collection, 10),
        ("collector_50", "Grand collectionneur", "Ajoute 50 jeux à ta collection", "crown.fill", .collection, 50),
        ("collector_100", "Maître collectionneur", "Ajoute 100 jeux à ta collection", "trophy.fill", .collection, 100),
        
        // Completion Achievements
        ("first_complete", "Fin de partie", "Termine ton premier jeu", "flag.checkered", .completion, 1),
        ("complete_10", "Finisseur", "Termine 10 jeux", "checkmark.circle.fill", .completion, 10),
        ("complete_25", "Vétéran", "Termine 25 jeux", "medal.fill", .completion, 25),
        ("platinum_5", "Platine addict", "Obtiens 5 platines", "star.circle.fill", .completion, 5),
        
        // Time Achievements
        ("time_100", "Joueur régulier", "Cumule 100 heures de jeu", "clock.fill", .time, 100),
        ("time_500", "Joueur assidu", "Cumule 500 heures de jeu", "hourglass", .time, 500),
        ("time_1000", "Légende vivante", "Cumule 1000 heures de jeu", "sparkles", .time, 1000),
        
        // Exploration Achievements
        ("genres_5", "Curieux", "Joue à 5 genres différents", "globe", .exploration, 5),
        ("platforms_3", "Multi-plateforme", "Joue sur 3 plateformes différentes", "display.2", .exploration, 3),
        ("decades_3", "Voyageur temporel", "Joue à des jeux de 3 décennies différentes", "clock.arrow.circlepath", .exploration, 3),
        
        // Social Achievements
        ("first_review", "Critique en herbe", "Écris ta première critique", "text.quote", .social, 1),
        ("reviews_10", "Critique reconnu", "Écris 10 critiques", "star.bubble.fill", .social, 10),
        ("lists_5", "Organisateur", "Crée 5 listes personnalisées", "list.bullet.rectangle.fill", .social, 5),
        
        // Dedication Achievements
        ("streak_7", "Semaine parfaite", "Joue 7 jours d'affilée", "flame.fill", .dedication, 7),
        ("streak_30", "Mois parfait", "Joue 30 jours d'affilée", "bolt.fill", .dedication, 30),
        ("indie_lover", "Indie Lover", "Joue à 20 jeux indépendants", "heart.fill", .dedication, 20),
        ("retro_gamer", "Retro Gamer", "Joue à 10 jeux d'avant 2000", "arcade.stick", .dedication, 10),
        ("favorite_genre", "Expert en genre", "Joue 10 jeux d'un même genre", "star.fill", .dedication, 10)
    ]
}

// MARK: - Theme Model
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
        case .default: return Color(hex: "8CC24A")
        case .ocean: return Color(hex: "2196F3")
        case .sunset: return Color(hex: "FF6B6B")
        case .purple: return Color(hex: "9C27B0")
        case .gold: return Color(hex: "FFD700")
        case .mint: return Color(hex: "00BFA5")
        case .rose: return Color(hex: "FF4081")
        case .cyber: return Color(hex: "00FFFF")
        }
    }
    
    var darkColor: Color {
        switch self {
        case .default: return Color(hex: "1A1A1E")
        case .ocean: return Color(hex: "0D1B2A")
        case .sunset: return Color(hex: "2D1B2D")
        case .purple: return Color(hex: "1A1625")
        case .gold: return Color(hex: "1A1A0D")
        case .mint: return Color(hex: "0D1A1A")
        case .rose: return Color(hex: "1A0D15")
        case .cyber: return Color(hex: "0A0A1A")
        }
    }
    
    var cardColor: Color {
        switch self {
        case .default: return Color(hex: "26262E")
        case .ocean: return Color(hex: "1B3A4B")
        case .sunset: return Color(hex: "3D2B3D")
        case .purple: return Color(hex: "2A2635")
        case .gold: return Color(hex: "2A2A1D")
        case .mint: return Color(hex: "1B2A2A")
        case .rose: return Color(hex: "2A1B25")
        case .cyber: return Color(hex: "1A1A2A")
        }
    }
}

// MARK: - Custom Tag Model
struct CustomTag: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
    var icon: String
    
    var color: Color { Color(hex: colorHex) }
    
    static let suggestions: [CustomTag] = [
        CustomTag(name: "Multijoueur", colorHex: "2196F3", icon: "person.2.fill"),
        CustomTag(name: "Solo", colorHex: "4CAF50", icon: "person.fill"),
        CustomTag(name: "Histoire", colorHex: "9C27B0", icon: "book.fill"),
        CustomTag(name: "Compétitif", colorHex: "F44336", icon: "flame.fill"),
        CustomTag(name: "Détente", colorHex: "00BCD4", icon: "leaf.fill"),
        CustomTag(name: "Rétro", colorHex: "FF9800", icon: "arcade.stick"),
        CustomTag(name: "Indie", colorHex: "E91E63", icon: "heart.fill"),
        CustomTag(name: "AAA", colorHex: "FFD700", icon: "star.fill")
    ]
}

// MARK: - Friend Model (for social features)
struct Friend: Identifiable, Codable {
    var id = UUID()
    var username: String
    var avatarEmoji: String
    var gamesCount: Int
    var isFollowing: Bool = true
    var lastActive: Date = Date()
}

// MARK: - Activity Feed Item
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

// MARK: - Notification Model
struct GameNotification: Identifiable, Codable {
    var id = UUID()
    var gameId: UUID
    var gameTitle: String
    var releaseDate: Date
    var isEnabled: Bool = true
    var notifyDaysBefore: Int = 1
}
