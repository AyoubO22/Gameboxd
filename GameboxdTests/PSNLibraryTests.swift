import XCTest
@testable import Gameboxd

@MainActor
final class PSNLibraryTests: XCTestCase {
    private func played(_ name: String, category: String = "ps5_native_game", concept: Int? = nil,
                        duration: String? = nil, lastPlayed: String? = nil) -> PSNPlayedTitle {
        PSNPlayedTitle(titleId: "PPSA0\(name.count)_00", name: name, localizedName: nil, imageUrl: "https://image.api.playstation.com/\(name).png",
                       localizedImageUrl: nil, category: category, concept: concept.map { .init(id: $0) },
                       lastPlayedDateTime: lastPlayed, playDuration: duration)
    }

    private func trophies(_ name: String, id: String, platform: String = "PS5", earned: Int, defined: Int) -> PSNGameTitle {
        PSNGameTitle(npCommunicationId: id, trophyTitleName: name, trophyTitleIconUrl: nil, trophyTitlePlatform: platform,
                     definedTrophies: PSNTrophyCounts(bronze: defined, silver: 0, gold: 0, platinum: 0),
                     earnedTrophies: PSNTrophyCounts(bronze: earned, silver: 0, gold: 0, platinum: 0),
                     progress: nil, lastUpdatedDateTime: nil)
    }

    func testDurations() {
        XCTAssertEqual(PSNLibrary.minutes(fromDuration: "PT228H56M33S"), 228 * 60 + 56)
        XCTAssertEqual(PSNLibrary.minutes(fromDuration: "P1DT2H"), 26 * 60)
        XCTAssertEqual(PSNLibrary.minutes(fromDuration: "PT45S"), 0)
        XCTAssertEqual(PSNLibrary.minutes(fromDuration: nil), 0)
        XCTAssertEqual(PSNLibrary.minutes(fromDuration: "garbage"), 0)
    }

    func testPS4AndPS5VersionsBecomeOneGameWithTrophies() {
        let games = PSNLibrary.games(
            played: [played("Ghost of Tsushima", concept: 7, duration: "PT10H", lastPlayed: "2026-10-01T20:00:00.000Z"),
                     played("Ghost of Tsushima", category: "ps4_game", concept: 7, duration: "PT5H30M")],
            trophies: [trophies("Ghost of Tsushima™", id: "NPWR1", earned: 30, defined: 60)]
        )
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].playtimeMinutes, 15 * 60 + 30)
        XCTAssertEqual(games[0].platformGameId, "concept-7")
        XCTAssertEqual(games[0].console, "PlayStation 5")
        XCTAssertEqual(games[0].achievementsEarned, 30)
        XCTAssertEqual(games[0].achievementsTotal, 60)
        XCTAssertNotNil(games[0].lastPlayed)
    }

    func testTrophyOnlyGamesAreKept() {
        let games = PSNLibrary.games(
            played: [played("Astro Bot", concept: 1, duration: "PT8H")],
            trophies: [trophies("Demon's Souls", id: "NPWR2", platform: "PS3", earned: 3, defined: 40),
                       trophies("Astro Bot", id: "NPWR3", earned: 10, defined: 50)]
        )
        XCTAssertEqual(games.map(\.title), ["Astro Bot", "Demon's Souls"])
        XCTAssertEqual(games[1].platformGameId, "NPWR2")
        XCTAssertEqual(games[1].console, "PlayStation 3")
    }

    func testNPSSOFromJSONOrBareValue() {
        XCTAssertEqual(PlayStationService.npssoValue(from: #"{"npsso":"abc123"}"#), "abc123")
        XCTAssertEqual(PlayStationService.npssoValue(from: "  \"abc123\"\n"), "abc123")
    }

    func testSignInURLAsksSonyForACode() {
        let items = URLComponents(url: PlayStationConfig.signInURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "response_type" }?.value, "code")
        XCTAssertEqual(items.first { $0.name == "redirect_uri" }?.value, "com.scee.psxandroid.scecompcall://redirect")
    }
    func testTrophySummaryLevelAsNumberOrString() throws {
        let number = #"{"accountId":"123","trophyLevel":433,"progress":12,"tier":5,"earnedTrophies":{"bronze":10,"silver":3,"gold":1,"platinum":1}}"#
        let summary = try JSONDecoder().decode(PSNTrophySummaryResponse.self, from: Data(number.utf8))
        XCTAssertEqual(summary.trophyLevel, 433)
        XCTAssertEqual(summary.earnedTrophies?.total, 15)

        let string = #"{"accountId":"123","trophyLevel":"433","earnedTrophies":{"bronze":10}}"#
        let older = try JSONDecoder().decode(PSNTrophySummaryResponse.self, from: Data(string.utf8))
        XCTAssertEqual(older.trophyLevel, 433)
        XCTAssertEqual(older.earnedTrophies?.total, 10)
    }
}
