//
//  SteamSync.swift
//  Gameboxd
//
//  Keeps the collection in step with a linked Steam account, on its own: playtime,
//  suggested diary sessions, completion from achievements, and the Steam id on the
//  public profile (so friends can find each other).
//

import Foundation

/// "You played 2 h of Hades since last time": offered in the diary, added on a tap.
struct SteamSessionSuggestion: Codable, Identifiable, Equatable {
    var id = UUID()
    let gameId: UUID
    let gameTitle: String
    let minutes: Int
    let date: Date
}

enum SteamSyncRules {
    /// Smaller gaps are noise (a launcher opened, a menu checked).
    static let minimumSessionMinutes = 15

    struct Plan: Equatable {
        /// New total playtime per game, only where Steam knows more than the app.
        var playtime: [UUID: Int] = [:]
        var suggestions: [SteamSessionSuggestion] = []
        /// Steam totals per app id, to compare with next time.
        var baseline: [Int: Int] = [:]
    }

    /// Steam's totals are the truth for PC games. The first sync only records a baseline:
    /// suggesting "500 h since last time" for a whole back catalogue would be noise.
    static func plan(library: [Game], steamMinutes: [Int: Int], baseline: [Int: Int]?, now: Date = Date()) -> Plan {
        var plan = Plan(baseline: steamMinutes)
        for game in library {
            guard let appId = game.steamAppId, let total = steamMinutes[appId] else { continue }
            if total > game.playTimeMinutes { plan.playtime[game.id] = total }
            if let before = baseline?[appId], total - before >= minimumSessionMinutes {
                plan.suggestions.append(SteamSessionSuggestion(gameId: game.id, gameTitle: game.title,
                                                               minutes: total - before, date: now))
            }
        }
        return plan
    }

    static func completion(unlocked: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        // Rounded down: 99.6 % isn't a platinum.
        return min(100, unlocked * 100 / total)
    }
}

@MainActor
final class SteamSync {
    static let shared = SteamSync()

    private var lastRun: Date?
    private let baselineKey = "gameboxd_steam_playtime_baseline"
    private let achievementsCheckedKey = "gameboxd_steam_achievements_checked"
    /// Achievement checks per run: one request each, Steam rate-limits.
    private let achievementChecksPerRun = 8

    /// The linked, active Steam account, if any.
    func steamId(in store: GameStore) -> String? {
        store.linkedAccounts.first { $0.platform == .steam && $0.isActive }?.platformUserId
    }

    /// Runs at launch and when the app comes back, at most every 10 minutes.
    func run(store: GameStore, force: Bool = false) async {
        guard SteamConfig.isConfigured, let steamId = steamId(in: store) else { return }
        if !force, let lastRun, Date().timeIntervalSince(lastRun) < 600 { return }
        lastRun = Date()

        guard let owned = try? await SteamService.shared.getOwnedGames(steamId: steamId, includeAppInfo: false) else { return }
        let minutes = Dictionary(owned.map { ($0.appid, $0.playtime_forever) }, uniquingKeysWith: max)
        let plan = SteamSyncRules.plan(library: store.myGames, steamMinutes: minutes, baseline: loadBaseline(steamId))
        saveBaseline(plan.baseline, steamId)

        // Achievements: games that just moved first, then the ones never checked.
        let checked = UserDefaults.standard.dictionary(forKey: achievementsCheckedKey) as? [String: Double] ?? [:]
        let candidates = store.myGames
            .filter { $0.steamAppId != nil }
            .sorted { a, b in
                let movedA = plan.playtime[a.id] != nil, movedB = plan.playtime[b.id] != nil
                if movedA != movedB { return movedA }
                return (checked[String(a.steamAppId!)] ?? 0) < (checked[String(b.steamAppId!)] ?? 0)
            }
            .prefix(achievementChecksPerRun)
        var completion: [UUID: Int] = [:]
        var stamps = checked
        for game in candidates {
            guard let appId = game.steamAppId else { continue }
            stamps[String(appId)] = Date().timeIntervalSince1970
            if let result = await SteamService.shared.playerAchievements(steamId: steamId, appId: appId) {
                completion[game.id] = SteamSyncRules.completion(unlocked: result.unlocked.count, total: result.total)
            }
        }
        UserDefaults.standard.set(stamps, forKey: achievementsCheckedKey)

        store.applySteamSync(playtime: plan.playtime, completion: completion, suggestions: plan.suggestions)
        await SocialService.shared.saveSteamId(steamId)
    }

    /// After linking an account: start from now, so the whole history isn't "a session".
    func resetBaseline(steamId: String) {
        UserDefaults.standard.removeObject(forKey: "\(baselineKey)_\(steamId)")
        lastRun = nil
    }

    /// Per Steam account: two Gameboxd accounts on one phone can link different ones.
    private func loadBaseline(_ steamId: String) -> [Int: Int]? {
        guard let raw = UserDefaults.standard.dictionary(forKey: "\(baselineKey)_\(steamId)") as? [String: Int] else { return nil }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in Int(key).map { ($0, value) } })
    }

    private func saveBaseline(_ baseline: [Int: Int], _ steamId: String) {
        UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: baseline.map { (String($0.key), $0.value) }), forKey: "\(baselineKey)_\(steamId)")
    }
}
