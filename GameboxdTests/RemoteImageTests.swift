import XCTest
@testable import Gameboxd

final class RemoteImageTests: XCTestCase {
    func testGameDatabasesAreAllowed() {
        XCTAssertTrue(RemoteImage.isAllowed("https://media.rawg.io/media/games/a.jpg"))
        XCTAssertTrue(RemoteImage.isAllowed("https://images.igdb.com/igdb/image/upload/t_cover_big_2x/x.jpg"))
        XCTAssertTrue(RemoteImage.isAllowed("https://cdn.cloudflare.steamstatic.com/steam/apps/1/header.jpg"))
        XCTAssertTrue(RemoteImage.isAllowed("https://image.api.playstation.com/cdn/x.png"))
    }

    func testOtherHostsAreRefused() {
        XCTAssertFalse(RemoteImage.isAllowed("https://evil.example/track.png"))
        XCTAssertFalse(RemoteImage.isAllowed("https://rawg.io.evil.example/x.jpg"))
        XCTAssertFalse(RemoteImage.isAllowed("https://evilrawg.io/x.jpg"))
        XCTAssertFalse(RemoteImage.isAllowed("https://evil.example/rawg.io/x.jpg"))
        XCTAssertFalse(RemoteImage.isAllowed("https://media.rawg.io@evil.example/x.jpg"))
        XCTAssertFalse(RemoteImage.isAllowed("http://media.rawg.io/media/games/a.jpg"))
        XCTAssertFalse(RemoteImage.isAllowed("file:///var/mobile/cover.jpg"))
        XCTAssertNil(RemoteImage.url(nil))
        XCTAssertNil(RemoteImage.shareable("https://evil.example/x.jpg"))
        XCTAssertFalse(RemoteImage.isAllowed("https://media.rawg.io/" + String(repeating: "a", count: 3000)))
    }

    func testGenresAreBoundedLikeTheDatabase() {
        XCTAssertEqual(RemoteLibraryGame.boundedGenres(Array(repeating: "RPG", count: 50)).count, 30)
        let long = RemoteLibraryGame.boundedGenres(Array(repeating: String(repeating: "x", count: 400), count: 5))
        XCTAssertEqual(long.count, 2)
        XCTAssertLessThanOrEqual(long.joined(separator: ",").count, 1000)
    }
}
