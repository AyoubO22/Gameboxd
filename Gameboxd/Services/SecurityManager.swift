//
//  SecurityManager.swift
//  Gameboxd
//
//  Local profile credentials (PBKDF2 hash in the Keychain) and input validation.
//

import Foundation
import Security
import CommonCrypto

@MainActor
final class SecurityManager {
    static let shared = SecurityManager()

    private let keychainService = "com.gameboxd.keychain"

    // MARK: - Local Profile Credentials
    //
    // There is no account server: an email/password "account" is a profile that
    // lives on this device only. The password is stored as a PBKDF2 hash in the
    // Keychain so login actually checks it.

    private static let localCredentialsKey = "local_profile_credentials"

    private struct LocalCredentials: Codable {
        let email: String
        let salt: Data
        let hash: Data
    }

    func saveLocalCredentials(email: String, password: String) throws {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let credentials = LocalCredentials(email: email.lowercased(), salt: salt, hash: passwordHash(password, salt: salt))
        try storeInKeychain(key: Self.localCredentialsKey, data: JSONEncoder().encode(credentials))
    }

    var hasLocalCredentials: Bool {
        retrieveFromKeychain(key: Self.localCredentialsKey) != nil
    }

    func verifyLocalCredentials(email: String, password: String) -> Bool {
        guard let data = retrieveFromKeychain(key: Self.localCredentialsKey),
              let credentials = try? JSONDecoder().decode(LocalCredentials.self, from: data) else { return false }
        return credentials.email == email.lowercased()
            && passwordHash(password, salt: credentials.salt) == credentials.hash
    }

    /// PBKDF2-HMAC-SHA256, 100 000 rounds, 32 bytes. Changing any of these breaks existing logins.
    private func passwordHash(_ password: String, salt: Data) -> Data {
        let passwordData = Data(password.utf8)
        var derived = Data(count: 32)
        _ = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self), passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 100_000,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self), 32
                    )
                }
            }
        }
        return derived
    }

    // MARK: - Keychain

    private func itemQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: key]
    }

    private func storeInKeychain(key: String, data: Data) throws {
        SecItemDelete(itemQuery(key) as CFDictionary)
        var item = itemQuery(key)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Erreur Keychain (\(status))"])
        }
    }

    private func retrieveFromKeychain(key: String) -> Data? {
        var query = itemQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

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

    func validatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }

        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }) { score += 1 }

        let commonPatterns = ["password", "123456", "qwerty", "admin", "letmein"]
        if commonPatterns.contains(where: { password.lowercased().contains($0) }) {
            score = max(0, score - 3)
        }

        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .veryStrong
        }
    }
}

enum PasswordStrength {
    case weak, medium, strong, veryStrong
}
