import XCTest
@testable import Gameboxd

@MainActor
final class TimerManagerTests: XCTestCase {
    private func game() -> Game {
        Game(title: "Timed", developer: "Dev", platform: "iOS", releaseYear: "2024", coverColor: .green)
    }

    func testPauseKeepsSessionActiveAndStopReturnsAtLeastOneMinute() {
        let timer = TimerManager()
        timer.start(game: game())
        timer.pause()
        XCTAssertTrue(timer.isRunning, "a paused session is still active (overlay must stay visible)")
        XCTAssertTrue(timer.isPaused)
        XCTAssertEqual(timer.stop(), 1)
        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(timer.activeGame)
    }

    func testRunningSessionSurvivesRelaunch() {
        let timer = TimerManager()
        let g = game()
        timer.start(game: g)

        let relaunched = TimerManager()
        XCTAssertTrue(relaunched.isRunning)
        XCTAssertEqual(relaunched.activeGame?.id, g.id)
        relaunched.stop()
        XCTAssertFalse(TimerManager().isRunning)
    }
}
