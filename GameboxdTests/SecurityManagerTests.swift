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

    func testSanitizeInput() {
        let manager = SecurityManager.shared
        let input = "<b>Hello</b> & bye"
        let sanitized = manager.sanitizeInput(input)
        XCTAssertEqual(sanitized, "&lt;b&gt;Hello&lt;&#x2F;b&gt; &amp; bye")
    }
}
