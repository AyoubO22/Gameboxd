import XCTest
@testable import Gameboxd

@MainActor
final class LibrarySyncTests: XCTestCase {
    func testEveryStatusRoundTripsThroughItsKey() {
        for status in GameStatus.allCases {
            let game = Game(title: "T", developer: "", platform: "PC", releaseYear: "2020", coverColor: .gray, status: status)
            XCTAssertEqual(RemoteLibraryGame(owner: UUID(), game: game).gameStatus, status)
        }
    }

    func testValuesAreKeptWithinTheDatabaseLimits() {
        var game = Game(title: String(repeating: "x", count: 300), developer: "", platform: "", releaseYear: "",
                        coverColor: .gray, rating: 9, review: "   ", playTimeMinutes: -5, completionPercentage: 140)
        game.isSpoiler = true
        let remote = RemoteLibraryGame(owner: UUID(), game: game)
        XCTAssertEqual(remote.title.count, 200)
        XCTAssertEqual(remote.rating, 5)
        XCTAssertNil(remote.review)        // blank review isn't sent
        XCTAssertNil(remote.platform)      // empty strings become null
        XCTAssertEqual(remote.playMinutes, 0)
        XCTAssertEqual(remote.completion, 100)
        XCTAssertTrue(remote.isSpoiler)
    }
}
