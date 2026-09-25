import XCTest
@testable import Gameboxd

final class FileStoreTests: XCTestCase {
    private var dir: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        suiteName = "filestore-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeStore() -> FileStore {
        FileStore(directory: dir, legacyDefaults: defaults)
    }

    func testSaveThenLoadRoundTrips() {
        let store = makeStore()
        store.save(["a", "b"], key: "list")
        XCTAssertEqual(store.load([String].self, key: "list"), ["a", "b"])
        // A fresh instance reads the same file from disk.
        XCTAssertEqual(makeStore().load([String].self, key: "list"), ["a", "b"])
    }

    func testMigratesLegacyUserDefaultsValueToFile() throws {
        defaults.set(try JSONEncoder().encode([1, 2, 3]), forKey: "numbers")
        let store = makeStore()

        XCTAssertEqual(store.load([Int].self, key: "numbers"), [1, 2, 3])
        XCTAssertNil(defaults.data(forKey: "numbers"), "legacy key is removed once the file exists")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: "numbers").path))
    }

    func testUnreadableFileIsBackedUpNotLost() throws {
        let store = makeStore()
        try Data("not json".utf8).write(to: store.url(for: "broken"))

        XCTAssertNil(store.load([Int].self, key: "broken"))
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("broken.unreadable-") }
        XCTAssertEqual(backups.count, 1)
    }

    func testRemoveDeletesFileAndLegacyKey() {
        let store = makeStore()
        store.save([1], key: "gone")
        defaults.set(Data(), forKey: "gone")
        store.remove(key: "gone")
        store.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(for: "gone").path))
        XCTAssertNil(defaults.data(forKey: "gone"))
    }

    @MainActor
    func testGameStorePersistsLibraryAcrossInstances() {
        let fileStore = makeStore()
        let store = GameStore(fileStore: fileStore)
        let game = Game(title: "Persisted", developer: "D", platform: "PC", releaseYear: "2024", coverColor: .green)
        store.updateGame(game)

        let reopened = GameStore(fileStore: fileStore)
        XCTAssertEqual(reopened.myGames.map(\.id), [game.id])
    }
}
