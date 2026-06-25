import XCTest
@testable import Gameboxd

@MainActor
final class GameStoreTests: XCTestCase {
    func testUpdateGameSanitizesReviewAndNotes() {
        let store = GameStore()
        store.myGames = []
        let game = Game(
            title: "Test",
            developer: "Dev",
            platform: "iOS",
            releaseYear: "2024",
            coverColor: .green,
            rating: 4,
            status: .playing,
            review: "<script>alert(1)</script>",
            notes: "hello & bye"
        )
        store.updateGame(game)
        let saved = store.myGames.first(where: { $0.id == game.id })
        XCTAssertEqual(saved?.review, "&lt;script&gt;alert(1)&lt;&#x2F;script&gt;")
        XCTAssertEqual(saved?.notes, "hello &amp; bye")
    }

    func testAddThenDeletePlaySessionRestoresPlayTime() {
        let store = GameStore()
        store.myGames = []
        store.playSessions = []
        var game = Game(
            title: "Test",
            developer: "Dev",
            platform: "iOS",
            releaseYear: "2024",
            coverColor: .green,
            status: .playing
        )
        game.playTimeMinutes = 10
        store.updateGame(game)

        let session = PlaySession(gameId: game.id, gameTitle: game.title, duration: 15)
        store.addPlaySession(session)      // 10 + 15 = 25
        store.deletePlaySession(session)   // 25 - 15 = 10

        let updated = store.myGames.first(where: { $0.id == game.id })
        XCTAssertEqual(updated?.playTimeMinutes, 10)
    }

    func testDeletePlaySessionDoesNotGoNegative() {
        let store = GameStore()
        store.myGames = []
        store.playSessions = []
        var game = Game(
            title: "Test",
            developer: "Dev",
            platform: "iOS",
            releaseYear: "2024",
            coverColor: .green,
            status: .playing
        )
        game.playTimeMinutes = 10
        store.updateGame(game)

        // Data-integrity edge case: delete a session longer than the recorded
        // play time. The total must clamp to 0, never go negative.
        let session = PlaySession(gameId: game.id, gameTitle: game.title, duration: 15)
        store.deletePlaySession(session)

        let updated = store.myGames.first(where: { $0.id == game.id })
        XCTAssertEqual(updated?.playTimeMinutes, 0)
    }
}
