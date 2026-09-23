import XCTest
@testable import Gameboxd

final class IGDBServiceTests: XCTestCase {
    private func results(_ json: String) throws -> [IGDBService.SearchResult] {
        try JSONDecoder().decode([IGDBService.SearchResult].self, from: Data(json.utf8))
    }

    // Unix timestamps: 2007-10-10, 2011-04-19, 2018-10-26, 2023-06-01
    func testExactTitleBeatsSequel() throws {
        let r = try results("""
        [{"name":"Portal 2","first_release_date":1303171200,"cover":{"image_id":"p2"}},
         {"name":"Portal","first_release_date":1191974400,"cover":{"image_id":"p1"}}]
        """)
        XCTAssertEqual(IGDBService.bestMatch(in: r, title: "Portal", year: "2007")?.cover?.image_id, "p1")
    }

    func testReleaseYearPicksOriginalOverRemake() throws {
        let r = try results("""
        [{"name":"Red Dead Redemption 2","first_release_date":1685577600,"cover":{"image_id":"remaster"}},
         {"name":"Red Dead Redemption 2","first_release_date":1540512000,"cover":{"image_id":"original"}}]
        """)
        XCTAssertEqual(IGDBService.bestMatch(in: r, title: "Red Dead Redemption 2", year: "2018")?.cover?.image_id, "original")
    }

    func testPunctuationAndCaseAreIgnored() throws {
        let r = try results("""
        [{"name":"The Witcher 3: Wild Hunt","first_release_date":1431993600,"cover":{"image_id":"w3"}}]
        """)
        XCTAssertEqual(IGDBService.bestMatch(in: r, title: "the witcher 3 wild hunt", year: nil)?.cover?.image_id, "w3")
    }

    func testUnrelatedTitleIsRejectedEvenWithSameYear() throws {
        let r = try results("""
        [{"name":"Something Else","first_release_date":1540512000,"cover":{"image_id":"x"}}]
        """)
        XCTAssertNil(IGDBService.bestMatch(in: r, title: "Red Dead Redemption 2", year: "2018"))
    }

    func testGameArtPrefersBoxArtAndFallsBackToRAWG() {
        var game = Game(title: "T", developer: "", platform: "PC", releaseYear: "2020",
                        coverImageURL: "https://rawg.example/landscape.jpg", coverColor: .gray)
        XCTAssertEqual(game.artURL?.absoluteString, "https://rawg.example/landscape.jpg")
        game.boxArtURL = ""   // looked up, nothing found
        XCTAssertEqual(game.artURL?.absoluteString, "https://rawg.example/landscape.jpg")
        game.boxArtURL = "https://images.igdb.com/cover.jpg"
        XCTAssertEqual(game.artURL?.absoluteString, "https://images.igdb.com/cover.jpg")
    }
}
