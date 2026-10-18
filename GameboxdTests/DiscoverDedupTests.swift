import XCTest
@testable import Gameboxd

final class DiscoverDedupTests: XCTestCase {
    private func games(_ titles: [String]) -> [Game] {
        titles.map { Game(title: $0, developer: "", platform: "", releaseYear: "2015", coverColor: .purple) }
    }

    func testEditionsCollapseToTheFirstEntry() {
        let shelf = RAWGService.distinct(games([
            "The Witcher 3: Wild Hunt",
            "The Witcher 3: Wild Hunt – Game of the Year Edition",
            "The Witcher 3: Wild Hunt - Complete Edition",
            "Portal 2",
        ]))
        XCTAssertEqual(shelf.map(\.title), ["The Witcher 3: Wild Hunt", "Portal 2"])
    }

    func testEditionListedBeforeTheBaseGameStillCountsOnce() {
        let shelf = RAWGService.distinct(games(["Red Dead Redemption 2 (GOTY)", "Red Dead Redemption 2"]))
        XCTAssertEqual(shelf.count, 1)
    }

    func testSequelsAndSubtitledGamesAreKept() {
        let titles = ["Portal", "Portal 2", "Mass Effect", "Mass Effect 2", "God of War (2018)", "God of War: Ragnarök", "Halo", "Halo: Reach"]
        XCTAssertEqual(RAWGService.distinct(games(titles)).map(\.title), titles)
    }

    func testKeepsTheShelfAtTheLimit() {
        XCTAssertEqual(RAWGService.distinct(games((1...20).map { "Game \($0)" })).count, 10)
    }

    func testBaseTitleDropsEditionSuffixes() {
        XCTAssertEqual(RAWGService.baseTitle("The Witcher 3: Wild Hunt – Complete Edition"), "the witcher 3 wild hunt")
        XCTAssertEqual(RAWGService.baseTitle("Death Stranding Director's Cut"), "death stranding directors cut")
        XCTAssertEqual(RAWGService.baseTitle("Death Stranding: Director's Cut"), "death stranding")
    }
}
