//
//  AppleSignInService.swift
//  Gameboxd
//
//  Handles Sign In with Apple authentication flow
//  Uses AuthenticationServices framework (native, no 3rd-party dependency)
//

import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Apple Sign In Result
struct AppleSignInResult {
    let userId: String       // Unique, stable Apple user identifier
    let email: String?       // Only provided on first sign-in
    let fullName: PersonNameComponents?
    let identityToken: String
    let authorizationCode: String
    
    var displayName: String? {
        guard let fullName = fullName else { return nil }
        return [fullName.givenName, fullName.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

// MARK: - Apple Sign In Errors
enum AppleSignInError: LocalizedError {
    case invalidCredential
    case authorizationFailed(Error)
    case missingIdentityToken
    case missingAuthorizationCode
    case cancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Les identifiants Apple sont invalides."
        case .authorizationFailed(let error):
            return "Échec de l'authentification Apple : \(error.localizedDescription)"
        case .missingIdentityToken:
            return "Le jeton d'identité Apple est manquant."
        case .missingAuthorizationCode:
            return "Le code d'autorisation Apple est manquant."
        case .cancelled:
            return "Connexion Apple annulée."
        case .unknown:
            return "Une erreur inconnue s'est produite."
        }
    }
}

// MARK: - Apple Sign In Service
/// Manages Sign In with Apple authentication
/// Uses ASAuthorizationController for the native Apple ID credential flow
class AppleSignInService: NSObject, ObservableObject {
    static let shared = AppleSignInService()
    
    // Current nonce for replay attack prevention
    private var currentNonce: String?
    
    // Completion handler for async bridge
    private var completionHandler: ((Result<AppleSignInResult, AppleSignInError>) -> Void)?
    
    // MARK: - Public API
    
    /// Initiates Sign In with Apple flow
    /// Returns an AppleSignInResult on success
    func signIn() async throws -> AppleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            let nonce = Self.randomNonceString()
            currentNonce = nonce
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            self.completionHandler = { result in
                switch result {
                case .success(let signInResult):
                    continuation.resume(returning: signInResult)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    /// Check if an existing Apple ID credential is still valid
    func checkCredentialState(userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        return await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userId) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
    
    // MARK: - Nonce Generation (Replay Attack Prevention)
    
    /// Generates a random nonce string for OAuth security
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    /// SHA256 hash of the nonce for OIDC
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInService: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completionHandler?(.failure(.invalidCredential))
            completionHandler = nil
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            completionHandler?(.failure(.missingIdentityToken))
            completionHandler = nil
            return
        }
        
        guard let authCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authCodeData, encoding: .utf8) else {
            completionHandler?(.failure(.missingAuthorizationCode))
            completionHandler = nil
            return
        }
        
        let result = AppleSignInResult(
            userId: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: appleIDCredential.fullName,
            identityToken: identityToken,
            authorizationCode: authorizationCode
        )
        
        // Store the user ID for credential state checks
        UserDefaults.standard.set(result.userId, forKey: "appleSignIn_userId")
        
        // Store name/email locally since Apple only sends them on first sign-in
        if let name = result.displayName {
            UserDefaults.standard.set(name, forKey: "appleSignIn_displayName")
        }
        if let email = result.email {
            UserDefaults.standard.set(email, forKey: "appleSignIn_email")
        }
        
        completionHandler?(.success(result))
        completionHandler = nil
    }
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let authError = error as? ASAuthorizationError
        
        if authError?.code == .canceled {
            completionHandler?(.failure(.cancelled))
        } else {
            completionHandler?(.failure(.authorizationFailed(error)))
        }
        completionHandler = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window for presenting the Apple Sign In sheet
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
