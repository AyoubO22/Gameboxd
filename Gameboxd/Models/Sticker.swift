//
//  Sticker.swift
//  Gameboxd
//
//  Die-cut stickers you unlock by playing: cut from the game's own art (see StickerMaker).
//

import Foundation

struct Sticker: Identifiable, Codable, Equatable {
    var id = UUID()
    let gameId: UUID
    let reason: Reason
    var unlockedAt = Date()
    /// File name in the stickers folder once the art has been cut; nil until then.
    /// "" means the game ran out of art for it: the sticker stays unlocked but isn't shown,
    /// so a game with 6 cut-outs never shows the same character twice.
    var imageFile: String?

    var hasArt: Bool { imageFile.map { !$0.isEmpty } ?? false }
    var isOutOfArt: Bool { imageFile == "" }
    /// Fixed tilt so a sticker always sits the same way.
    var tilt = Double.random(in: -7...7)

    var isHolo: Bool { reason == .platinum }

    enum Reason: Codable, Hashable, Comparable {
        /// `hours == 0` is the first session.
        case playtime(hours: Int)
        case rated
        case reviewed
        case completed
        case platinum

        var isPlaytime: Bool {
            if case .playtime = self { return true }
            return false
        }

        var label: String {
            switch self {
            case .playtime(0): return "1re session"
            case .playtime(let h): return "\(h) h de jeu"
            case .rated: return "Noter le jeu"
            case .reviewed: return "Écrire une critique"
            case .completed: return "Terminer le jeu"
            case .platinum: return "Platiner le jeu"
            }
        }
    }
}

enum StickerRules {
    /// A new playtime sticker every this many hours.
    static let hoursStep = 5
    /// Playtime stickers stop here (100 h); games rarely have more art than that anyway.
    static let maxPlaytimeStickers = 20

    /// A game finished at 100 % or platinumed unlocks everything at once: people joining
    /// with a back catalogue have played it already, they won't log the sessions.
    static func unlocksAll(_ game: Game) -> Bool {
        game.completionPercentage >= 100 || game.status == .platinum
    }

    /// Every reason this game has earned so far.
    static func earned(by game: Game) -> Set<Sticker.Reason> {
        if unlocksAll(game) {
            var all: Set<Sticker.Reason> = [.rated, .reviewed, .completed]
            for step in 0..<maxPlaytimeStickers { all.insert(.playtime(hours: step * hoursStep)) }
            if game.status == .platinum { all.insert(.platinum) }
            return all
        }
        var reasons: Set<Sticker.Reason> = []
        let hours = game.playTimeMinutes / 60
        if game.playTimeMinutes > 0 {
            reasons.insert(.playtime(hours: 0))
            let milestones = min(hours / hoursStep, maxPlaytimeStickers - 1)
            if milestones > 0 {
                for step in 1...milestones { reasons.insert(.playtime(hours: step * hoursStep)) }
            }
        }
        if game.rating > 0 { reasons.insert(.rated) }
        if !game.review.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { reasons.insert(.reviewed) }
        if game.status == .completed || game.status == .platinum { reasons.insert(.completed) }
        if game.status == .platinum { reasons.insert(.platinum) }
        return reasons
    }

    /// What's still locked, nearest first: the next playtime milestone, then the one-offs.
    static func nextGoals(for game: Game) -> [Sticker.Reason] {
        let earned = earned(by: game)
        let next: Sticker.Reason = game.playTimeMinutes == 0
            ? .playtime(hours: 0)
            : .playtime(hours: (game.playTimeMinutes / 60 / hoursStep + 1) * hoursStep)
        let candidates: [Sticker.Reason] = [next, .rated, .reviewed, .completed, .platinum]
        return candidates.filter { !earned.contains($0) && !isPastCap($0) }
    }

    private static func isPastCap(_ reason: Sticker.Reason) -> Bool {
        if case .playtime(let h) = reason { return h / hoursStep >= maxPlaytimeStickers }
        return false
    }
}
