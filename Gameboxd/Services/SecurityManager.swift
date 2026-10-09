//
//  SecurityManager.swift
//  Gameboxd
//
//  Input validation for text the user types.
//

import Foundation

@MainActor
final class SecurityManager {
    static let shared = SecurityManager()

    // MARK: - Input Validation

    /// Cleans free text before storing it: drops NUL and invisible control characters
    /// (keeping line breaks and tabs) and caps the length.
    ///
    /// No HTML escaping: nothing in the app renders HTML, and escaping at storage time
    /// corrupted text ("l'écriture" was saved as "l&#x27;écriture", then escaped again on
    /// every save). Escape at the point of rendering if HTML output is ever added.
    func sanitizeInput(_ input: String) -> String {
        let kept = input.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar)
        }
        return String(String.UnicodeScalarView(kept).prefix(10_000))
    }

    /// Undoes the HTML entities older versions wrote into reviews and notes
    /// (possibly several layers deep, one per save).
    static func unescapeLegacyEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        let entities = [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#x27;", "'"), ("&#x2F;", "/"), ("&amp;", "&")]
        var current = text
        for _ in 0..<8 {
            var next = current
            for (entity, char) in entities { next = next.replacingOccurrences(of: entity, with: char) }
            if next == current { break }
            current = next
        }
        return current
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}
