import XCTest
@testable import Gameboxd

@MainActor
final class StickerRulesTests: XCTestCase {
    private func game(minutes: Int = 0, rating: Int = 0, review: String = "", status: GameStatus = .playing) -> Game {
        Game(title: "Test", developer: "", platform: "PC", releaseYear: "2020", coverColor: .gray,
             rating: rating, status: status, review: review, playTimeMinutes: minutes)
    }

    func testNothingPlayedNothingEarned() {
        XCTAssertTrue(StickerRules.earned(by: game()).isEmpty)
        XCTAssertEqual(StickerRules.nextGoals(for: game()).first, .playtime(hours: 0))
    }

    func testFirstSessionThenEveryFiveHours() {
        XCTAssertEqual(StickerRules.earned(by: game(minutes: 30)), [.playtime(hours: 0)])
        XCTAssertEqual(StickerRules.earned(by: game(minutes: 11 * 60)),
                       [.playtime(hours: 0), .playtime(hours: 5), .playtime(hours: 10)])
        XCTAssertEqual(StickerRules.nextGoals(for: game(minutes: 11 * 60)).first, .playtime(hours: 15))
    }

    func testPlaytimeStickersAreCapped() {
        let earned = StickerRules.earned(by: game(minutes: 1_000 * 60))
        XCTAssertEqual(earned.count, StickerRules.maxPlaytimeStickers)
        XCTAssertFalse(StickerRules.nextGoals(for: game(minutes: 1_000 * 60)).contains { if case .playtime = $0 { return true }; return false })
    }

    func testRatingReviewAndStatus() {
        let earned = StickerRules.earned(by: game(rating: 4, review: "Superbe", status: .platinum))
        XCTAssertTrue(earned.isSuperset(of: [.rated, .reviewed, .completed, .platinum]))
        XCTAssertFalse(StickerRules.earned(by: game(review: "   ")).contains(.reviewed))
        XCTAssertFalse(StickerRules.earned(by: game(status: .completed)).contains(.platinum))
    }

    func testStoreUnlocksOnceAndKeepsStickers() {
        let store = makeIsolatedStore()
        store.myGames = []
        var g = game(minutes: 0)
        store.updateGame(g)
        g = store.myGames[0]
        XCTAssertTrue(store.stickers(for: g).isEmpty)

        store.addPlaySession(PlaySession(gameId: g.id, gameTitle: g.title, duration: 60))
        XCTAssertEqual(store.stickers(for: g).map(\.reason), [.playtime(hours: 0)])

        g = store.myGames[0]
        g.rating = 5
        store.updateGame(g)
        g.rating = 0 // clearing the rating keeps the sticker
        store.updateGame(g)
        store.updateGame(g)
        XCTAssertEqual(store.stickers(for: g).map(\.reason), [.playtime(hours: 0), .rated])

        store.deleteGame(g)
        XCTAssertTrue(store.stickers.isEmpty)
    }

    // MARK: - Back catalogue

    func testHundredPercentOrPlatinumUnlocksEverything() {
        var finished = game(status: .completed)
        finished.completionPercentage = 100
        let earned = StickerRules.earned(by: finished)
        XCTAssertEqual(earned.filter(\.isPlaytime).count, StickerRules.maxPlaytimeStickers)
        XCTAssertTrue(earned.isSuperset(of: [.rated, .reviewed, .completed]))
        XCTAssertFalse(earned.contains(.platinum))
        XCTAssertEqual(StickerRules.nextGoals(for: finished), [.platinum])

        XCTAssertTrue(StickerRules.earned(by: game(status: .platinum)).contains(.platinum))
        XCTAssertTrue(StickerRules.nextGoals(for: game(status: .platinum)).isEmpty)
    }

    func testPlatinumSetsCompletionToFull() {
        let store = makeIsolatedStore()
        store.myGames = []
        store.updateGame(game(status: .platinum))
        XCTAssertEqual(store.myGames[0].completionPercentage, 100)
        XCTAssertEqual(store.stickers(for: store.myGames[0]).count, StickerRules.maxPlaytimeStickers + 4)
    }
}
