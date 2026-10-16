import XCTest
@testable import Gameboxd

@MainActor
final class AccountSpacesTests: XCTestCase {
    private func game(_ title: String) -> Game {
        Game(title: title, developer: "", platform: "PC", releaseYear: "2020", coverColor: .gray, status: .playing)
    }

    func testTwoAccountsOnOnePhoneKeepTheirOwnCollection() {
        let store = makeIsolatedStore()
        store.myGames = []
        let a = UUID(), b = UUID()

        store.switchAccount(to: a)
        store.updateGame(game("Hades"))
        store.linkedAccounts = [LinkedAccount(platform: .steam, platformUserId: "76561198000000001")]

        store.switchAccount(to: b)
        XCTAssertTrue(store.myGames.isEmpty)          // B doesn't see A's games…
        XCTAssertTrue(store.linkedAccounts.isEmpty)   // …nor A's Steam account
        store.updateGame(game("Celeste"))

        store.switchAccount(to: a)
        XCTAssertEqual(store.myGames.map(\.title), ["Hades"])
    }

    func testANewAccountTakesTheNoAccountCollectionOnce() {
        let store = makeIsolatedStore()
        store.myGames = []
        store.updateGame(game("Portal"))               // played without an account

        store.switchAccount(to: UUID(), claimGuestData: true)
        XCTAssertEqual(store.myGames.map(\.title), ["Portal"])

        store.switchAccount(to: nil)
        XCTAssertTrue(store.myGames.isEmpty)           // moved, not copied
        store.switchAccount(to: UUID(), claimGuestData: true)
        XCTAssertTrue(store.myGames.isEmpty)           // a second account can't receive it too
    }

    func testRestoringFromTheCloudOnlyFillsAnEmptyCollection() {
        let store = makeIsolatedStore()
        store.myGames = []
        store.switchAccount(to: UUID())
        store.restoreFromCloud([game("Skyrim")])
        XCTAssertEqual(store.myGames.map(\.title), ["Skyrim"])
        store.restoreFromCloud([game("Other")])
        XCTAssertEqual(store.myGames.map(\.title), ["Skyrim"])   // never overwrites
    }
}
