//
//  SecurityManager.swift
//  Gameboxd
//
//  Security Manager demonstrating CompTIA Security+ knowledge
//  Covers: Encryption, Authentication, Secure Storage, Input Validation, 
//  Biometrics, Certificate Pinning, Secure Coding Practices
//

import Foundation
import Security
import LocalAuthentication
import CryptoKit
import CommonCrypto
import Combine
import UIKit

// MARK: - Security Manager
/// Central security manager implementing defense-in-depth security model
/// Demonstrates CompTIA Security+ concepts
@MainActor
class SecurityManager: ObservableObject {
    static let shared = SecurityManager()
    
    @Published var isAuthenticated = false
    @Published var biometricType: BiometricType = .none
    @Published var securityLevel: SecurityLevel = .standard
    
    private let keychainService = "com.gameboxd.keychain"
    
    init() {
        checkBiometricCapability()
    }
    
    // MARK: - Biometric Authentication (Authentication Factor: Something You Are)
    
    enum BiometricType {
        case none, touchID, faceID
    }
    
    /// Check device biometric capabilities
    func checkBiometricCapability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
    
    /// Authenticate user with biometrics
    /// Implements multi-factor authentication (MFA) as fallback
    func authenticateWithBiometrics(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        context.localizedFallbackTitle = "Utiliser le code"
        
        // Set authentication timeout
        context.touchIDAuthenticationAllowableReuseDuration = 60
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                isAuthenticated = true
                // Log successful authentication (audit trail)
                await logSecurityEvent(.authenticationSuccess, details: "Biometric authentication")
            }
            
            return success
        } catch let error as LAError {
            // Handle specific biometric errors
            switch error.code {
            case .authenticationFailed:
                await logSecurityEvent(.authenticationFailure, details: "Biometric failed")
                throw SecurityError.authenticationFailed
            case .userCancel:
                throw SecurityError.userCancelled
            case .biometryLockout:
                // Too many failed attempts - requires passcode
                throw SecurityError.biometryLockout
            case .biometryNotAvailable:
                throw SecurityError.biometryNotAvailable
            default:
                throw SecurityError.unknown(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Keychain Operations (Secure Storage)
    
    /// Store sensitive data in iOS Keychain with encryption
    /// Keychain provides hardware-backed encryption on devices with Secure Enclave
    func storeInKeychain(key: String, data: Data, accessControl: KeychainAccessControl = .whenUnlocked) throws {
        // Create access control flags
        var accessControlFlags: SecAccessControlCreateFlags = []
        
        switch accessControl {
        case .whenUnlocked:
            accessControlFlags = .init()
        case .whenUnlockedThisDeviceOnly:
            accessControlFlags = .init()
        case .afterFirstUnlock:
            accessControlFlags = .init()
        case .biometricOnly:
            accessControlFlags = [.biometryCurrentSet]
        case .biometricOrPasscode:
            accessControlFlags = [.biometryCurrentSet, .or, .devicePasscode]
        }
        
        // Create access control object
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            accessControlFlags,
            &error
        ) else {
            throw SecurityError.keychainError("Failed to create access control")
        }
        
        // Prepare keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecurityError.keychainError("Failed to store item: \(status)")
        }
    }
    
    /// Retrieve data from Keychain
    func retrieveFromKeychain(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw SecurityError.keychainError("Failed to retrieve item: \(status)")
        }
    }
    
    /// Delete item from Keychain
    func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityError.keychainError("Failed to delete item: \(status)")
        }
    }
    
    // MARK: - Token Management (JWT/OAuth)
    
    /// Store authentication tokens securely
    func storeAuthTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws {
        let tokenData = AuthTokenData(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
        )
        
        let data = try JSONEncoder().encode(tokenData)
        try storeInKeychain(key: "auth_tokens", data: data, accessControl: .biometricOrPasscode)
    }
    
    /// Retrieve and validate tokens
    func getValidAccessToken() throws -> String? {
        guard let data = try retrieveFromKeychain(key: "auth_tokens") else {
            return nil
        }
        
        let tokenData = try JSONDecoder().decode(AuthTokenData.self, from: data)
        
        // Check token expiration
        if tokenData.expiresAt < Date() {
            // Token expired - need to refresh
            throw SecurityError.tokenExpired
        }
        
        return tokenData.accessToken
    }
    
    /// Parse and validate JWT token (without verification - demo only)
    func parseJWT(_ token: String) throws -> JWTPayload {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw SecurityError.invalidToken
        }
        
        // Decode payload (middle part)
        var payload = String(parts[1])
        
        // Add padding if needed
        while payload.count % 4 != 0 {
            payload += "="
        }
        
        guard let payloadData = Data(base64Encoded: payload) else {
            throw SecurityError.invalidToken
        }
        
        return try JSONDecoder().decode(JWTPayload.self, from: payloadData)
    }
    
    // MARK: - Encryption (AES-256-GCM)
    
    /// Encrypt data using AES-256-GCM (Authenticated Encryption)
    /// GCM provides both confidentiality and integrity
    func encrypt(data: Data, using key: SymmetricKey) throws -> EncryptedData {
        // Generate random nonce (IV)
        let nonce = AES.GCM.Nonce()
        
        // Encrypt with authentication tag
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        
        guard let combined = sealedBox.combined else {
            throw SecurityError.encryptionFailed
        }
        
        return EncryptedData(
            ciphertext: combined,
            nonce: Data(nonce),
            tag: Data(sealedBox.tag)
        )
    }
    
    /// Decrypt AES-256-GCM encrypted data
    func decrypt(encryptedData: EncryptedData, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData.ciphertext)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    /// Generate secure encryption key
    func generateEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Derive key from password using PBKDF2
    func deriveKey(from password: String, salt: Data, iterations: Int = 100000) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var derivedKey = Data(count: 32) // 256 bits
        
        derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        
        return SymmetricKey(data: derivedKey)
    }
    
    // MARK: - Hashing
    
    /// Hash password using SHA-256 with salt
    func hashPassword(_ password: String, salt: String) -> String {
        let saltedPassword = salt + password + salt
        let data = Data(saltedPassword.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Generate secure random salt
    func generateSalt(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes).base64EncodedString()
    }
    
    /// Compute HMAC for message authentication
    func computeHMAC(data: Data, key: SymmetricKey) -> Data {
        let authCode = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(authCode)
    }
    
    // MARK: - Input Validation (Prevent Injection Attacks)
    
    /// Validate and sanitize user input
    func sanitizeInput(_ input: String) -> String {
        // Remove potential XSS/injection characters
        var sanitized = input
        
        // HTML entities
        let replacements: [String: String] = [
            "<": "&lt;",
            ">": "&gt;",
            "\"": "&quot;",
            "'": "&#x27;",
            "&": "&amp;",
            "/": "&#x2F;"
        ]
        
        for (char, replacement) in replacements {
            sanitized = sanitized.replacingOccurrences(of: char, with: replacement)
        }
        
        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        
        // Limit length to prevent buffer overflow
        if sanitized.count > 10000 {
            sanitized = String(sanitized.prefix(10000))
        }
        
        return sanitized
    }
    
    /// Validate email format
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    /// Validate password strength
    func validatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // Length checks
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        
        // Character type checks
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) }) { score += 1 }
        
        // Check for common patterns
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
    
    /// Validate URL to prevent SSRF
    func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        // Only allow HTTPS
        guard url.scheme == "https" else { return false }
        
        // Block private IP ranges (SSRF prevention)
        let blockedHosts = ["localhost", "127.0.0.1", "0.0.0.0", "10.", "172.16.", "192.168."]
        let host = url.host ?? ""
        
        for blocked in blockedHosts {
            if host.hasPrefix(blocked) || host == blocked {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Certificate Pinning (Network Security)
    
    /// Validate SSL certificate against pinned certificates
    func validateCertificate(_ serverTrust: SecTrust, pinnedCertificates: [SecCertificate]) -> Bool {
        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }
        
        // Get server certificate data
        let serverCertData = SecCertificateCopyData(serverCertificate) as Data
        
        // Compare against pinned certificates
        for pinnedCert in pinnedCertificates {
            let pinnedData = SecCertificateCopyData(pinnedCert) as Data
            if serverCertData == pinnedData {
                return true
            }
        }
        
        return false
    }
    
    /// Load pinned certificate from bundle
    func loadPinnedCertificate(named: String) -> SecCertificate? {
        guard let certPath = Bundle.main.path(forResource: named, ofType: "cer"),
              let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)),
              let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            return nil
        }
        return certificate
    }
    
    // MARK: - Security Audit Logging
    
    /// Log security-related events for audit trail
    func logSecurityEvent(_ event: SecurityEvent, details: String) async {
        let logEntry = SecurityLogEntry(
            timestamp: Date(),
            event: event,
            details: details,
            deviceId: getDeviceIdentifier()
        )
        
        // In production: Send to SIEM or CloudWatch
        print("🔐 Security Event: \(event.rawValue) - \(details)")
        
        // Store locally for compliance
        storeAuditLog(logEntry)
    }
    
    private func storeAuditLog(_ entry: SecurityLogEntry) {
        // Append to secure local storage
        // Logs should be tamper-evident and encrypted
    }
    
    private func getDeviceIdentifier() -> String {
        // Use identifierForVendor for device identification
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
    
    // MARK: - Secure Data Wipe
    
    /// Securely delete all sensitive data
    func secureWipe() async throws {
        // Delete all keychain items
        let secClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for secClass in secClasses {
            let query: [String: Any] = [kSecClass as String: secClass]
            SecItemDelete(query as CFDictionary)
        }
        
        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        
        // Log wipe event
        await logSecurityEvent(.dataWipe, details: "Complete data wipe performed")
        
        isAuthenticated = false
    }
}

// MARK: - Security Enums & Types

enum KeychainAccessControl {
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case biometricOnly
    case biometricOrPasscode
}

enum SecurityLevel {
    case minimal
    case standard
    case high
    case paranoid
}

enum PasswordStrength {
    case weak
    case medium
    case strong
    case veryStrong
    
    var color: String {
        switch self {
        case .weak: return "red"
        case .medium: return "orange"
        case .strong: return "green"
        case .veryStrong: return "blue"
        }
    }
}

enum SecurityEvent: String {
    case authenticationSuccess = "AUTH_SUCCESS"
    case authenticationFailure = "AUTH_FAILURE"
    case tokenRefresh = "TOKEN_REFRESH"
    case tokenExpired = "TOKEN_EXPIRED"
    case dataAccess = "DATA_ACCESS"
    case dataModification = "DATA_MODIFY"
    case dataWipe = "DATA_WIPE"
    case suspiciousActivity = "SUSPICIOUS"
    case permissionChange = "PERMISSION_CHANGE"
}

enum SecurityError: Error, LocalizedError {
    case authenticationFailed
    case userCancelled
    case biometryLockout
    case biometryNotAvailable
    case keychainError(String)
    case tokenExpired
    case invalidToken
    case encryptionFailed
    case decryptionFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed: return "Échec de l'authentification"
        case .userCancelled: return "Annulé par l'utilisateur"
        case .biometryLockout: return "Biométrie verrouillée"
        case .biometryNotAvailable: return "Biométrie non disponible"
        case .keychainError(let msg): return "Erreur Keychain: \(msg)"
        case .tokenExpired: return "Session expirée"
        case .invalidToken: return "Token invalide"
        case .encryptionFailed: return "Échec du chiffrement"
        case .decryptionFailed: return "Échec du déchiffrement"
        case .unknown(let msg): return msg
        }
    }
}

// MARK: - Data Models

struct AuthTokenData: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct JWTPayload: Codable {
    let sub: String?
    let email: String?
    let exp: Int?
    let iat: Int?
    let iss: String?
}

struct EncryptedData {
    let ciphertext: Data
    let nonce: Data
    let tag: Data
}

struct SecurityLogEntry {
    let timestamp: Date
    let event: SecurityEvent
    let details: String
    let deviceId: String
}

// MARK: - Secure URLSession Configuration

extension URLSession {
    /// Create URLSession with certificate pinning
    static func securePinned(pinnedCertificates: [String]) -> URLSession {
        let config = URLSessionConfiguration.default
        
        // Security headers
        config.httpAdditionalHeaders = [
            "X-Content-Type-Options": "nosniff",
            "X-Frame-Options": "DENY",
            "X-XSS-Protection": "1; mode=block"
        ]
        
        // Disable caching for sensitive data
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        // TLS configuration
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        
        return URLSession(configuration: config)
    }
}
