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

    func testEmptyingTheCollectionEmptiesTheOnlineCopyOnceReconciled() {
        let online: Set<UUID> = [UUID(), UUID()]
        // A phone that knows the online copy: what it no longer has is deleted, all of it too.
        XCTAssertEqual(LibrarySync.removals(current: [], online: online, reconciled: true), online)
        let kept = online.first!
        XCTAssertEqual(LibrarySync.removals(current: [kept], online: online, reconciled: true), online.subtracting([kept]))
    }

    func testANewPhoneNeverDeletesWhatItHasNotReceivedYet() {
        let online: Set<UUID> = [UUID(), UUID()]
        XCTAssertTrue(LibrarySync.removals(current: [], online: online, reconciled: false).isEmpty)
        XCTAssertTrue(LibrarySync.removals(current: [UUID()], online: online, reconciled: false).isEmpty)
    }

    func testReconciledIsRememberedPerAccount() {
        let account = UUID()
        XCTAssertFalse(LibrarySync.isReconciled(account))
        LibrarySync.setReconciled(account, true)
        XCTAssertTrue(LibrarySync.isReconciled(account))
        LibrarySync.setReconciled(account, false)
        XCTAssertFalse(LibrarySync.isReconciled(account))
    }
}
