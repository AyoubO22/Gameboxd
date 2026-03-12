//
//  GameEnrichmentService.swift
//  Gameboxd
//
//  Fetches and caches enriched game data from HowLongToBeat
//

import Foundation

final class GameEnrichmentService {
    static let shared = GameEnrichmentService()

    private let session = URLSession.shared

    /// Set to true to use mock data instead of live API (for development/previews)
    var useMockData = false

    private init() {}

    // MARK: - Public API

    func enrich(gameId: UUID, title: String) async -> EnrichedGameData? {
        // Check cache first
        if let cached = EnrichedGameData.cached(for: gameId) {
            return cached
        }

        // Mock mode for development
        if useMockData {
            try? await Task.sleep(nanoseconds: 800_000_000) // simulate network delay
            let mock = EnrichedGameData.mock
            mock.save(for: gameId)
            return mock
        }

        guard let result = await fetchHLTB(title: title) else { return nil }

        let enriched = EnrichedGameData(
            hltbMainStory: result.mainStory,
            hltbCompletionist: result.completionist,
            lastFetched: Date()
        )
        enriched.save(for: gameId)
        return enriched
    }

    // MARK: - HowLongToBeat

    private struct HLTBResult {
        let mainStory: Double?
        let completionist: Double?
    }

    private func fetchHLTB(title: String) async -> HLTBResult? {
        guard let url = URL(string: "https://howlongtobeat.com/api/search") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://howlongtobeat.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "searchType": "games",
            "searchTerms": title.components(separatedBy: " "),
            "searchPage": 1,
            "size": 1,
            "searchOptions": [
                "games": [
                    "userId": 0,
                    "platform": "",
                    "sortCategory": "popular",
                    "rangeCategory": "main",
                    "rangeTime": ["min": 0, "max": 0],
                    "gameplay": ["perspective": "", "flow": "", "genre": ""],
                    "modifier": ""
                ],
                "users": ["sortCategory": "postcount"],
                "filter": "",
                "sort": 0,
                "randomizer": 0
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["data"] as? [[String: Any]],
                  let first = results.first else { return nil }

            // HLTB returns times in seconds
            let mainSeconds = first["comp_main"] as? Double ?? 0
            let completionistSeconds = first["comp_plus"] as? Double ?? first["comp_100"] as? Double ?? 0

            let mainHours = mainSeconds > 0 ? mainSeconds / 3600.0 : nil
            let completionistHours = completionistSeconds > 0 ? completionistSeconds / 3600.0 : nil

            guard mainHours != nil || completionistHours != nil else { return nil }
            return HLTBResult(mainStory: mainHours, completionist: completionistHours)
        } catch {
            return nil
        }
    }
}
