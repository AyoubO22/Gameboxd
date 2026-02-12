//
//  LinkedAccount.swift
//  Gameboxd
//
//  Models for linked gaming platform accounts (PlayStation, Steam, etc.)
//

import SwiftUI

// MARK: - Gaming Platform
enum GamingPlatform: String, CaseIterable, Codable, Identifiable {
    case playstation = "PlayStation"
    case steam = "Steam"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .playstation: return "playstation.logo"
        case .steam: return "steamlogo"  // Custom asset or fallback
        }
    }
    
    /// SF Symbol fallback for platforms without a direct symbol
    var sfSymbol: String {
        switch self {
        case .playstation: return "playstation.logo"
        case .steam: return "gamecontroller.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .playstation: return .blue
        case .steam: return Color(red: 0.11, green: 0.14, blue: 0.18)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .playstation: return Color(red: 0.0, green: 0.32, blue: 0.65)
        case .steam: return Color(red: 0.39, green: 0.55, blue: 0.74)
        }
    }
    
    var description: String {
        switch self {
        case .playstation: return "Importe ta bibliothèque PlayStation et tes trophées"
        case .steam: return "Importe ta bibliothèque Steam et tes succès"
        }
    }
    
    var setupInstructions: String {
        switch self {
        case .playstation:
            return """
            Pour lier ton compte PlayStation :
            1. Va dans les paramètres PSN (account.sonyentertainmentnetwork.com)
            2. Active les paramètres de confidentialité "N'importe qui" pour Jeux
            3. Copie ton PSN ID ci-dessous
            """
        case .steam:
            return """
            Pour lier ton compte Steam :
            1. Va dans les paramètres Steam → Profil
            2. Assure-toi que ton profil est public
            3. Copie ton Steam ID ou URL de profil personnalisée
            """
        }
    }
}

// MARK: - Linked Account
struct LinkedAccount: Identifiable, Codable, Hashable {
    let id: UUID
    let platform: GamingPlatform
    var platformUserId: String    // PSN ID or Steam ID
    var platformUsername: String   // Display name on the platform
    var avatarURL: String?
    var linkedDate: Date
    var lastSyncDate: Date?
    var isActive: Bool
    var importedGameCount: Int
    var trophyCount: Int?         // PlayStation trophies
    var achievementCount: Int?    // Steam achievements
    var level: Int?               // Platform level (PSN level, Steam level)
    
    init(
        id: UUID = UUID(),
        platform: GamingPlatform,
        platformUserId: String,
        platformUsername: String = "",
        avatarURL: String? = nil,
        linkedDate: Date = Date(),
        lastSyncDate: Date? = nil,
        isActive: Bool = true,
        importedGameCount: Int = 0,
        trophyCount: Int? = nil,
        achievementCount: Int? = nil,
        level: Int? = nil
    ) {
        self.id = id
        self.platform = platform
        self.platformUserId = platformUserId
        self.platformUsername = platformUsername
        self.avatarURL = avatarURL
        self.linkedDate = linkedDate
        self.lastSyncDate = lastSyncDate
        self.isActive = isActive
        self.importedGameCount = importedGameCount
        self.trophyCount = trophyCount
        self.achievementCount = achievementCount
        self.level = level
    }
}

// MARK: - Imported Game (from external platform)
struct ImportedGame: Identifiable, Codable, Hashable {
    let id: UUID
    let platform: GamingPlatform
    let platformGameId: String      // Steam App ID or PSN Title ID
    let title: String
    let coverImageURL: String?
    let playtimeMinutes: Int        // Total playtime on platform
    let lastPlayed: Date?
    let achievementsEarned: Int
    let achievementsTotal: Int
    var isImportedToLibrary: Bool   // Whether user has added it to Gameboxd library
    var linkedGameId: UUID?          // Reference to Gameboxd Game if imported
    
    init(
        id: UUID = UUID(),
        platform: GamingPlatform,
        platformGameId: String,
        title: String,
        coverImageURL: String? = nil,
        playtimeMinutes: Int = 0,
        lastPlayed: Date? = nil,
        achievementsEarned: Int = 0,
        achievementsTotal: Int = 0,
        isImportedToLibrary: Bool = false,
        linkedGameId: UUID? = nil
    ) {
        self.id = id
        self.platform = platform
        self.platformGameId = platformGameId
        self.title = title
        self.coverImageURL = coverImageURL
        self.playtimeMinutes = playtimeMinutes
        self.lastPlayed = lastPlayed
        self.achievementsEarned = achievementsEarned
        self.achievementsTotal = achievementsTotal
        self.isImportedToLibrary = isImportedToLibrary
        self.linkedGameId = linkedGameId
    }
    
    var formattedPlaytime: String {
        let hours = playtimeMinutes / 60
        let mins = playtimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    var completionPercentage: Int {
        guard achievementsTotal > 0 else { return 0 }
        return Int((Double(achievementsEarned) / Double(achievementsTotal)) * 100)
    }
}

// MARK: - Sync Result
struct PlatformSyncResult {
    let platform: GamingPlatform
    let gamesFound: Int
    let newGames: Int
    let updatedGames: Int
    let errors: [String]
    let syncDate: Date
    
    var isSuccess: Bool { errors.isEmpty }
    
    var summary: String {
        if isSuccess {
            return "\(gamesFound) jeux trouvés, \(newGames) nouveaux, \(updatedGames) mis à jour"
        } else {
            return "Erreurs : \(errors.joined(separator: ", "))"
        }
    }
}
