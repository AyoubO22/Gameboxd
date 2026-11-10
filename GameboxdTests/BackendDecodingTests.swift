import XCTest
@testable import Gameboxd

/// Records exactly as the Gameboxd server (PocketBase) sends them.
@MainActor
final class BackendDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try Backend.decoder.decode(T.self, from: Backend.withoutEmptyValues(Data(json.utf8)))
    }

    func testProfileEmptyTextsBecomeNil() throws {
        let profile = try decode(RemoteProfile.self, #"{"avatar_url":"","bio":"","display_name":"","id":"9bba121d-ae84-40e1-a91c-51cf703717e9","is_public":true,"steam_id":"","username":"tester_one","created":"2026-11-09 20:53:31.599Z"}"#)
        XCTAssertEqual(profile.id.serverId, "9bba121d-ae84-40e1-a91c-51cf703717e9")
        XCTAssertNil(profile.displayName)
        XCTAssertNil(profile.steamId)
        XCTAssertEqual(profile.isPublic, true)
    }

    func testActivityWithExpandedAuthorAndServerDate() throws {
        let activity = try decode(RemoteActivity.self, #"{"created_at":"2026-11-09 21:02:10.170Z","expand":{"user_id":{"display_name":"","id":"9bba121d-ae84-40e1-a91c-51cf703717e9","username":"tester_one"}},"game_cover_url":"","game_title":"Hades","id":"6700d203-0b41-4224-bc23-002762842ed4","kind":"played","minutes":45,"rating":0,"review":"","user_id":"9bba121d-ae84-40e1-a91c-51cf703717e9"}"#)
        XCTAssertEqual(activity.author?.username, "tester_one")
        XCTAssertNil(activity.gameCoverURL)
        XCTAssertEqual(activity.minutes, 45)
        XCTAssertEqual(activity.createdAt.timeIntervalSince1970, 1794258130.170, accuracy: 0.001)
    }

    func testLibraryGameRoundTripsUnchanged() throws {
        let online = try decode(RemoteLibraryGame.self, #"{"completed_at":"","completion":0,"cover_url":"","game_id":"0f8fad5b-d9cb-469f-a165-70867728950e","genres":["Action"],"is_favorite":false,"is_spoiler":false,"platform":"","play_minutes":0,"rating":0,"rawg_id":0,"release_year":"","review":"","status":"playing","title":"Hades","updated_at":"2026-11-09 21:02:10.368Z","user_id":"9bba121d-ae84-40e1-a91c-51cf703717e9"}"#)
        XCTAssertNil(online.asGame.rawgId)
        XCTAssertNil(online.completedAt)
        // The same game from the phone compares equal, so it isn't uploaded again.
        var game = online.asGame
        game.coverImageURL = nil
        game.boxArtURL = nil
        XCTAssertEqual(RemoteLibraryGame(owner: online.userId, game: game), online)
    }

    func testFilterValuesAreQuoted() {
        XCTAssertEqual(Backend.quoted(#"a"b"#), #""a\"b""#)
        XCTAssertEqual(Backend.any("id", in: ["x", "y"]), #"(id = "x" || id = "y")"#)
    }
}
