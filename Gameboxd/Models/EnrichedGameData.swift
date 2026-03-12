//
//  EnrichedGameData.swift
//  Gameboxd
//
//  Enriched data fetched from HowLongToBeat
//

import Foundation

struct EnrichedGameData: Codable {
    var hltbMainStory: Double?
    var hltbCompletionist: Double?
    var lastFetched: Date

    // MARK: - Cache

    private static let ttl: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    static func cacheKey(for gameId: UUID) -> String {
        "enriched_\(gameId.uuidString)"
    }

    static func cached(for gameId: UUID) -> EnrichedGameData? {
        let key = cacheKey(for: gameId)
        guard let data = UserDefaults.standard.data(forKey: key),
              let enriched = try? JSONDecoder().decode(EnrichedGameData.self, from: data),
              Date().timeIntervalSince(enriched.lastFetched) < ttl else {
            return nil
        }
        return enriched
    }

    func save(for gameId: UUID) {
        let key = EnrichedGameData.cacheKey(for: gameId)
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Mock (for development/preview)

    static let mock = EnrichedGameData(
        hltbMainStory: 51.5,
        hltbCompletionist: 187.0,
        lastFetched: Date()
    )
}
