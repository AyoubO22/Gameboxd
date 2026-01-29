//
//  Goal.swift
//  Gameboxd
//
//  Monthly goals model
//

import Foundation

struct MonthlyGoal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var icon: String
    var type: GoalType
    var target: Int
    var current: Int
    var month: Date = Date()
    var completedDate: Date?
    
    var isCompleted: Bool {
        current >= target
    }
}

enum GoalType: String, Codable, CaseIterable {
    case gamesCompleted = "games_completed"
    case hoursPlayed = "hours_played"
    case reviewsWritten = "reviews_written"
    case newGames = "new_games"
    case platinums = "platinums"
    case backlogCleared = "backlog_cleared"
    
    var title: String {
        switch self {
        case .gamesCompleted: return "Jeux terminés"
        case .hoursPlayed: return "Heures jouées"
        case .reviewsWritten: return "Critiques écrites"
        case .newGames: return "Nouveaux jeux"
        case .platinums: return "Platines obtenus"
        case .backlogCleared: return "Backlog réduit"
        }
    }
    
    var icon: String {
        switch self {
        case .gamesCompleted: return "checkmark.circle.fill"
        case .hoursPlayed: return "clock.fill"
        case .reviewsWritten: return "text.quote"
        case .newGames: return "plus.circle.fill"
        case .platinums: return "star.circle.fill"
        case .backlogCleared: return "tray.full.fill"
        }
    }
    
    var description: String {
        switch self {
        case .gamesCompleted: return "Termine des jeux ce mois"
        case .hoursPlayed: return "Cumule des heures de jeu"
        case .reviewsWritten: return "Écris des critiques"
        case .newGames: return "Ajoute des jeux à ta bibliothèque"
        case .platinums: return "Obtiens des trophées platine"
        case .backlogCleared: return "Termine des jeux du backlog"
        }
    }
}

struct GoalSuggestion {
    let title: String
    let description: String
    let icon: String
    let type: GoalType
    let defaultTarget: Int
}

struct GoalSuggestions {
    static let all: [GoalSuggestion] = [
        GoalSuggestion(title: "Finir 3 jeux", description: "Termine 3 jeux ce mois", icon: "checkmark.circle.fill", type: .gamesCompleted, defaultTarget: 3),
        GoalSuggestion(title: "50 heures de jeu", description: "Joue au moins 50 heures", icon: "clock.fill", type: .hoursPlayed, defaultTarget: 50),
        GoalSuggestion(title: "5 critiques", description: "Partage ton avis sur 5 jeux", icon: "text.quote", type: .reviewsWritten, defaultTarget: 5),
        GoalSuggestion(title: "Réduire le backlog", description: "Joue à 5 jeux de ton backlog", icon: "tray.full.fill", type: .backlogCleared, defaultTarget: 5)
    ]
}
