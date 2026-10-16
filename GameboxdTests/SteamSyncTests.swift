import XCTest
@testable import Gameboxd

@MainActor
final class SteamSyncTests: XCTestCase {
    private func game(appId: Int?, minutes: Int = 0, status: GameStatus = .wantToPlay) -> Game {
        var g = Game(title: "Hades", developer: "", platform: "PC", releaseYear: "2020", coverColor: .gray,
                     status: status, playTimeMinutes: minutes)
        g.steamAppId = appId
        return g
    }

    func testFirstSyncOnlyRecordsABaseline() {
        let plan = SteamSyncRules.plan(library: [game(appId: 1, minutes: 60)], steamMinutes: [1: 600], baseline: nil)
        XCTAssertTrue(plan.suggestions.isEmpty)          // no "540 min since last time" on day one
        XCTAssertEqual(plan.playtime.values.first, 600)  // but Steam's total is taken
        XCTAssertEqual(plan.baseline, [1: 600])
    }

    func testPlaySinceLastSyncBecomesASuggestion() {
        let g = game(appId: 1, minutes: 600)
        let plan = SteamSyncRules.plan(library: [g], steamMinutes: [1: 735], baseline: [1: 600])
        XCTAssertEqual(plan.suggestions.map(\.minutes), [135])
        XCTAssertEqual(plan.suggestions.first?.gameId, g.id)
    }

    func testShortGapsAndUnknownGamesAreIgnored() {
        let plan = SteamSyncRules.plan(library: [game(appId: 1, minutes: 600), game(appId: nil)],
                                       steamMinutes: [1: 610], baseline: [1: 600])
        XCTAssertTrue(plan.suggestions.isEmpty)   // 10 min is noise
        XCTAssertTrue(plan.playtime.count == 1)   // the game without an app id is left alone
    }

    func testLocalPlaytimeIsNeverLowered() {
        let plan = SteamSyncRules.plan(library: [game(appId: 1, minutes: 900)], steamMinutes: [1: 600], baseline: nil)
        XCTAssertTrue(plan.playtime.isEmpty)
    }

    func testCompletionRoundsDown() {
        XCTAssertEqual(SteamSyncRules.completion(unlocked: 50, total: 51), 98)
        XCTAssertEqual(SteamSyncRules.completion(unlocked: 51, total: 51), 100)
        XCTAssertEqual(SteamSyncRules.completion(unlocked: 0, total: 0), 0)
    }

    func testApplyingSteamStartsGamesAndPlatinumsAtHundredPercent() {
        let store = makeIsolatedStore()
        store.myGames = []
        store.updateGame(game(appId: 1))
        let id = store.myGames[0].id
        store.applySteamSync(playtime: [id: 300], completion: [id: 100], suggestions: [])
        XCTAssertEqual(store.myGames[0].playTimeMinutes, 300)
        XCTAssertEqual(store.myGames[0].status, .platinum)
    }

    func testAcceptedSuggestionDoesNotCountTimeTwice() {
        let store = makeIsolatedStore()
        store.myGames = []
        store.updateGame(game(appId: 1, minutes: 600, status: .playing))
        let g = store.myGames[0]
        let suggestion = SteamSessionSuggestion(gameId: g.id, gameTitle: g.title, minutes: 120, date: Date())
        store.applySteamSync(playtime: [:], completion: [:], suggestions: [suggestion])
        store.acceptSteamSuggestion(store.steamSuggestions[0])
        XCTAssertEqual(store.myGames[0].playTimeMinutes, 600)   // already in Steam's total
        XCTAssertTrue(store.steamSuggestions.isEmpty)
        XCTAssertEqual(store.sessionsForGame(g).first?.duration, 120)
    }
}
