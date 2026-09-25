import XCTest
@testable import Gameboxd

/// A store backed by a throwaway directory, so tests never touch the app's real data.
@MainActor
func makeIsolatedStore() -> GameStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let defaults = UserDefaults(suiteName: "tests-\(UUID().uuidString)")!
    return GameStore(fileStore: FileStore(directory: dir, legacyDefaults: defaults))
}

@MainActor
final class GameStoreTests: XCTestCase {
    func testUpdateGameKeepsReviewTextIntact() {
        let store = makeIsolatedStore()
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
        XCTAssertEqual(saved?.review, "<script>alert(1)</script>")
        XCTAssertEqual(saved?.notes, "hello & bye")
    }

    func testAddThenDeletePlaySessionRestoresPlayTime() {
        let store = makeIsolatedStore()
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
        let store = makeIsolatedStore()
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

    // MARK: - Bug-fix regressions

    private func makeGame(_ title: String = "Test", rawgId: Int? = nil, status: GameStatus = .playing) -> Game {
        Game(title: title, developer: "Dev", platform: "iOS", releaseYear: "2024",
             coverColor: .green, status: status, rawgId: rawgId)
    }

    private func emptyStore() -> GameStore {
        let store = makeIsolatedStore()
        store.myGames = []
        store.playSessions = []
        store.gameLists = [GameList(name: "L")]
        store.userProfile.favoriteGameIds = []
        return store
    }

    func testSavingFreshRAWGCopyUpdatesOwnedGameInsteadOfDuplicating() {
        let store = emptyStore()
        let owned = makeGame(rawgId: 42)
        store.updateGame(owned)

        var fresh = makeGame(rawgId: 42)   // new random id, as Discover produces
        fresh.rating = 5
        store.updateGame(fresh)

        XCTAssertEqual(store.myGames.count, 1)
        XCTAssertEqual(store.myGames.first?.id, owned.id)
        XCTAssertEqual(store.myGames.first?.rating, 5)
    }

    func testCompletingAGameSetsCompletedDate() {
        let store = emptyStore()
        var game = makeGame()
        store.updateGame(game)
        XCTAssertNil(store.myGames.first?.completedDate)

        game.status = .completed
        store.updateGame(game)
        XCTAssertNotNil(store.myGames.first?.completedDate)
    }

    func testAddingNewGameSetsStartedDate() {
        let store = emptyStore()
        store.updateGame(makeGame(status: .none))
        XCTAssertEqual(store.myGames.first?.status, .wantToPlay)
        XCTAssertNotNil(store.myGames.first?.startedDate)
    }

    func testDeleteGameRemovesSessionsListEntriesAndFavorites() {
        let store = emptyStore()
        var game = makeGame()
        game.isFavorite = true
        store.updateGame(game)
        store.addGameToList(game, list: store.gameLists[0])
        store.addPlaySession(PlaySession(gameId: game.id, gameTitle: game.title, duration: 5))

        store.deleteGame(game)

        XCTAssertTrue(store.playSessions.isEmpty)
        XCTAssertTrue(store.gameLists[0].gameIds.isEmpty)
        XCTAssertFalse(store.userProfile.favoriteGameIds.contains(game.id))
    }

    func testBackdatedSessionIsInsertedInDateOrder() {
        let store = emptyStore()
        let game = makeGame()
        store.updateGame(game)
        let today = PlaySession(gameId: game.id, gameTitle: "T", date: Date(), duration: 1)
        let lastWeek = PlaySession(gameId: game.id, gameTitle: "T", date: Date().addingTimeInterval(-7 * 86_400), duration: 1)
        store.addPlaySession(today)
        store.addPlaySession(lastWeek)
        XCTAssertEqual(store.playSessions.map(\.id), [today.id, lastWeek.id])
    }

    func testAddingNonLibraryGameToListAddsItToLibrary() {
        let store = emptyStore()
        let game = makeGame(rawgId: 7, status: .none)
        store.addGameToList(game, list: store.gameLists[0])
        XCTAssertEqual(store.myGames.count, 1)
        XCTAssertEqual(store.gameLists[0].gameIds, [store.myGames[0].id])
    }

    func testGameDecodingToleratesMissingFieldsAndUnknownStatus() throws {
        let json = """
        {"id":"\(UUID().uuidString)","title":"Old save","status":"SomeRenamedStatus","moodTags":["Fun","Gone"]}
        """
        let game = try JSONDecoder().decode(Game.self, from: Data(json.utf8))
        XCTAssertEqual(game.title, "Old save")
        XCTAssertEqual(game.status, .wantToPlay)
        XCTAssertEqual(game.moodTags, [.fun])
        XCTAssertEqual(game.playthroughCount, 1)
    }
}
