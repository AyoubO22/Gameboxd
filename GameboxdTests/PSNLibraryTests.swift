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
    func testAddAllImportsEveryGameOnceAndLinksExistingTitles() {
        let store = makeIsolatedStore()
        store.myGames = [Game(title: "Astro Bot", developer: "", platform: "PlayStation 5", releaseYear: "2024", coverColor: .blue)]
        store.importedGames = [
            ImportedGame(platform: .playstation, platformGameId: "concept-1", title: "Astro Bot™", playtimeMinutes: 300, console: "PlayStation 5"),
            ImportedGame(platform: .playstation, platformGameId: "concept-2", title: "Bloodborne", playtimeMinutes: 600,
                         achievementsEarned: 40, achievementsTotal: 40, console: "PlayStation 4"),
            ImportedGame(platform: .playstation, platformGameId: "NPWR3", title: "Demon's Souls")
        ]

        store.addImportedGamesToLibrary(store.importableGames(platform: .playstation))
        XCTAssertEqual(store.myGames.count, 3)                       // Astro Bot linked, not doubled
        XCTAssertTrue(store.importableGames().isEmpty)
        XCTAssertEqual(store.myGames.first { $0.title == "Bloodborne" }?.status, .platinum)
        XCTAssertEqual(store.myGames.first { $0.title == "Bloodborne" }?.platform, "PlayStation 4")
        XCTAssertEqual(store.myGames.first { $0.title == "Demon's Souls" }?.status, .shelved)

        store.addImportedGamesToLibrary(store.importedGames)         // a second tap adds nothing
        XCTAssertEqual(store.myGames.count, 3)
    }
    func testGamesLeftForOverAMonthArriveShelved() {
        let store = makeIsolatedStore()
        store.myGames = []
        let day: TimeInterval = 86_400
        store.importedGames = [
            ImportedGame(platform: .playstation, platformGameId: "a", title: "Recent", playtimeMinutes: 60, lastPlayed: Date().addingTimeInterval(-3 * day)),
            ImportedGame(platform: .playstation, platformGameId: "b", title: "Old", playtimeMinutes: 60, lastPlayed: Date().addingTimeInterval(-60 * day))
        ]
        store.addImportedGamesToLibrary(store.importableGames())
        XCTAssertEqual(store.myGames.first { $0.title == "Recent" }?.status, .playing)
        XCTAssertEqual(store.myGames.first { $0.title == "Old" }?.status, .shelved)
    }

    func testOldPlayStationGamesWithoutPlayTimeArriveShelved() {
        let store = makeIsolatedStore()
        store.myGames = []
        let day: TimeInterval = 86_400
        store.importedGames = [
            ImportedGame(platform: .playstation, platformGameId: "a", title: "Years ago", lastPlayed: Date().addingTimeInterval(-1_000 * day)),
            ImportedGame(platform: .playstation, platformGameId: "b", title: "No date", playtimeMinutes: 300),
            ImportedGame(platform: .playstation, platformGameId: "c", title: "Last week", lastPlayed: Date().addingTimeInterval(-7 * day)),
            ImportedGame(platform: .steam, platformGameId: "10", title: "Never launched")
        ]
        store.addImportedGamesToLibrary(store.importableGames())
        XCTAssertEqual(store.myGames.first { $0.title == "Years ago" }?.status, .shelved)
        XCTAssertEqual(store.myGames.first { $0.title == "No date" }?.status, .shelved)
        XCTAssertEqual(store.myGames.first { $0.title == "Last week" }?.status, .playing)
        XCTAssertEqual(store.myGames.first { $0.title == "Never launched" }?.status, .wantToPlay)
    }

    func testBacklogFixSortsOnlyPlayStationGamesStillToPlay() {
        let store = makeIsolatedStore()
        let old = Date().addingTimeInterval(-400 * 86_400)
        let stuck = Game(title: "Stuck", developer: "", platform: "PlayStation 4", releaseYear: "", coverColor: .indigo, status: .wantToPlay)
        let chosen = Game(title: "Chosen", developer: "", platform: "PlayStation 4", releaseYear: "", coverColor: .indigo, status: .completed)
        let unlinked = Game(title: "Mine", developer: "", platform: "PlayStation 4", releaseYear: "", coverColor: .indigo, status: .wantToPlay)
        store.myGames = [stuck, chosen, unlinked]
        store.importedGames = [
            ImportedGame(platform: .playstation, platformGameId: "a", title: "Stuck", lastPlayed: old,
                         isImportedToLibrary: true, linkedGameId: stuck.id),
            ImportedGame(platform: .playstation, platformGameId: "b", title: "Chosen", lastPlayed: old,
                         isImportedToLibrary: true, linkedGameId: chosen.id)
        ]
        store.fixPlayStationBacklog()
        XCTAssertEqual(store.myGames.first { $0.title == "Stuck" }?.status, .shelved)
        XCTAssertEqual(store.myGames.first { $0.title == "Chosen" }?.status, .completed)
        XCTAssertEqual(store.myGames.first { $0.title == "Mine" }?.status, .wantToPlay)
    }

    func testStoryTrophiesAreRecognised() {
        XCTAssertTrue(PSNLibrary.isStoryTrophy(name: "The End", detail: "Complete the story"))
        XCTAssertTrue(PSNLibrary.isStoryTrophy(name: "Ascension", detail: "Finished the game on any difficulty."))
        XCTAssertTrue(PSNLibrary.isStoryTrophy(name: "Fin", detail: "See the credits roll"))
        XCTAssertTrue(PSNLibrary.isStoryTrophy(name: "Veteran", detail: "Beat the main campaign on Hard"))
        XCTAssertFalse(PSNLibrary.isStoryTrophy(name: "Chapter 3", detail: "Complete chapter 3"))
        XCTAssertFalse(PSNLibrary.isStoryTrophy(name: "Collector", detail: "Collect every relic in the game"))
    }

    func testStoryTrophyMakesAGameFinished() {
        func set(_ id: String, _ name: String, platform: String) -> PSNGameTitle {
            PSNGameTitle(npCommunicationId: id, trophyTitleName: name, trophyTitleIconUrl: nil, trophyTitlePlatform: platform,
                         definedTrophies: PSNTrophyCounts(bronze: 40, silver: 5, gold: 2, platinum: 1),
                         earnedTrophies: PSNTrophyCounts(bronze: 10, silver: 1, gold: 1, platinum: 0),
                         progress: 30, lastUpdatedDateTime: "2020-03-01T10:00:00Z")
        }
        let games = PSNLibrary.games(played: [], trophies: [set("NPWR1", "Old Story", platform: "PS4"), set("NPWR2", "Unfinished", platform: "PS4")],
                                     finishedSets: ["NPWR1"])
        XCTAssertEqual(games.first { $0.title == "Old Story" }?.storyCompleted, true)
        XCTAssertNil(games.first { $0.title == "Unfinished" }?.storyCompleted)

        let store = makeIsolatedStore()
        store.myGames = []
        store.importedGames = games
        store.addImportedGamesToLibrary(store.importableGames())
        XCTAssertEqual(store.myGames.first { $0.title == "Old Story" }?.status, .completed)
        XCTAssertEqual(store.myGames.first { $0.title == "Unfinished" }?.status, .shelved)
    }

    func testLostLinksAreFoundAgainByTitle() {
        let store = makeIsolatedStore()
        let shelved = Game(title: "Stray", developer: "", platform: "PlayStation 5", releaseYear: "", coverColor: .indigo, status: .wantToPlay)
        store.myGames = [shelved]
        store.importedGames = [ImportedGame(platform: .playstation, platformGameId: "a", title: "Stray",
                                            lastPlayed: Date().addingTimeInterval(-400 * 86_400), storyCompleted: true)]
        store.fixPlayStationBacklog()
        XCTAssertEqual(store.myGames.first?.status, .completed)
        XCTAssertEqual(store.importedGames.first?.linkedGameId, shelved.id)
        XCTAssertTrue(store.importableGames().isEmpty)
    }

    func testPlatinumWithDLCLeftIsStillPlatinum() {
        let set = PSNGameTitle(npCommunicationId: "NPWR9", trophyTitleName: "Bloodborne", trophyTitleIconUrl: nil, trophyTitlePlatform: "PS4",
                               definedTrophies: PSNTrophyCounts(bronze: 50, silver: 10, gold: 5, platinum: 1),
                               earnedTrophies: PSNTrophyCounts(bronze: 30, silver: 8, gold: 4, platinum: 1),
                               progress: 80, lastUpdatedDateTime: "2019-03-01T10:00:00Z")
        let games = PSNLibrary.games(played: [], trophies: [set])
        XCTAssertEqual(games.first?.platinumEarned, true)

        let store = makeIsolatedStore()
        let shelved = Game(title: "Bloodborne", developer: "", platform: "PlayStation 4", releaseYear: "", coverColor: .indigo, status: .wantToPlay)
        store.myGames = [shelved]
        store.importedGames = games
        store.fixPlayStationBacklog()
        XCTAssertEqual(store.myGames.first?.status, .platinum)

        store.myGames = []
        store.importedGames = games
        store.addImportedGamesToLibrary(store.importableGames())
        XCTAssertEqual(store.myGames.first?.status, .platinum)
    }
}
