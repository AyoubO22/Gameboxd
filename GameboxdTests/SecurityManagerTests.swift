import XCTest
@testable import Gameboxd

@MainActor
final class SecurityManagerTests: XCTestCase {
    func testEmailValidation() {
        let manager = SecurityManager.shared
        XCTAssertTrue(manager.isValidEmail("user@example.com"))
        XCTAssertFalse(manager.isValidEmail("invalid-email"))
    }

    func testPasswordStrength() {
        let manager = SecurityManager.shared
        XCTAssertEqual(manager.validatePasswordStrength("12345"), .weak)
        XCTAssertNotEqual(manager.validatePasswordStrength("Str0ngPass!"), .weak)
    }

    func testSanitizeInputKeepsTextButDropsControlCharacters() {
        let manager = SecurityManager.shared
        XCTAssertEqual(manager.sanitizeInput("L'écriture est <b>incroyable</b> & drôle"),
                       "L'écriture est <b>incroyable</b> & drôle")
        XCTAssertEqual(manager.sanitizeInput("a\u{0}b\u{7}c\nd\te"), "abc\nd\te")
        XCTAssertEqual(manager.sanitizeInput(String(repeating: "x", count: 12_000)).count, 10_000)
        // Saving twice must not change the text (autosave runs on every edit).
        let once = manager.sanitizeInput("C'est \"génial\" & beau")
        XCTAssertEqual(manager.sanitizeInput(once), once)
    }

    func testLegacyEntitiesAreRepaired() {
        XCTAssertEqual(SecurityManager.unescapeLegacyEntities("l&#x27;écriture"), "l'écriture")
        // Escaped again on each save by older versions:
        XCTAssertEqual(SecurityManager.unescapeLegacyEntities("l&amp;amp;#x27;écriture &amp;amp;amp; co"), "l'écriture & co")
        XCTAssertEqual(SecurityManager.unescapeLegacyEntities("rien à réparer"), "rien à réparer")
    }
}
