//
//  GoogleSignInService.swift
//  Gameboxd
//
//  Handles Google Sign-In authentication flow
//  Requires: GoogleSignIn SPM package (https://github.com/google/GoogleSignIn-iOS)
//
//  Setup steps:
//  1. Add GoogleSignIn-iOS package via SPM (url: https://github.com/google/GoogleSignIn-iOS, version: 8.0.0+)
//  2. Create OAuth 2.0 Client ID in Google Cloud Console (https://console.cloud.google.com)
//  3. Add the reversed client ID as a URL scheme in Info.plist
//  4. Set your clientID in GoogleSignInConfig below
//

import Foundation
import Combine

// MARK: - Google Sign In Configuration
struct GoogleSignInConfig {
    /// Replace with your actual Google OAuth 2.0 Client ID from Google Cloud Console
    /// Format: XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com
    static let clientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    
    /// The reversed client ID used as URL scheme
    /// Format: com.googleusercontent.apps.XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    static var reversedClientID: String {
        let parts = clientID.components(separatedBy: ".")
        return parts.reversed().joined(separator: ".")
    }
}

// MARK: - Google Sign In Result
struct GoogleSignInResult {
    let userId: String
    let email: String
    let displayName: String?
    let profileImageURL: URL?
    let idToken: String
    let accessToken: String
}

// MARK: - Google Sign In Errors
enum GoogleSignInError: LocalizedError {
    case notConfigured
    case cancelled
    case failed(String)
    case noRootViewController
    case missingIdToken
    case sdkNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Sign-In n'est pas configuré. Veuillez ajouter votre Client ID."
        case .cancelled:
            return "Connexion Google annulée."
        case .failed(let message):
            return "Échec de la connexion Google : \(message)"
        case .noRootViewController:
            return "Impossible de présenter l'écran de connexion Google."
        case .missingIdToken:
            return "Le jeton d'identité Google est manquant."
        case .sdkNotAvailable:
            return "Le SDK Google Sign-In n'est pas installé. Ajoutez-le via Swift Package Manager."
        }
    }
}

// MARK: - Google Sign In Service
/// Manages Google Sign-In authentication
/// 
/// ## Setup Instructions:
/// 
/// ### 1. Add the GoogleSignIn-iOS SPM package
/// In Xcode: File → Add Package Dependencies...
/// URL: `https://github.com/google/GoogleSignIn-iOS`
/// Version: 8.0.0 or later
///
/// ### 2. Create OAuth Client ID
/// Go to: https://console.cloud.google.com/apis/credentials
/// - Create an iOS OAuth 2.0 Client ID
/// - Set your app's bundle identifier
/// - Download the plist and get the CLIENT_ID
///
/// ### 3. Configure URL Scheme
/// Add the reversed client ID as a URL scheme in your Xcode project:
/// Target → Info → URL Types → Add → URL Schemes: `com.googleusercontent.apps.YOUR_CLIENT_ID`
///
/// ### 4. Update GoogleSignInConfig
/// Replace `YOUR_GOOGLE_CLIENT_ID` with your actual client ID
///
class GoogleSignInService: ObservableObject {
    static let shared = GoogleSignInService()
    
    @Published var isSignedIn = false
    @Published var currentUser: GoogleSignInResult?
    
    // MARK: - Sign In
    
    /// Initiates Google Sign-In flow
    /// Once GoogleSignIn SDK is added via SPM, uncomment the GIDSignIn code below
    func signIn() async throws -> GoogleSignInResult {
        // Validate configuration
        guard GoogleSignInConfig.clientID != "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" else {
            throw GoogleSignInError.notConfigured
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.performGoogleSignIn { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
    /// Performs the actual Google Sign-In
    /// 
    /// IMPORTANT: Uncomment the GIDSignIn code after adding the GoogleSignIn SPM package
    private func performGoogleSignIn(completion: @escaping (Result<GoogleSignInResult, GoogleSignInError>) -> Void) {
        // Placeholder until SDK is added:
        completion(.failure(.sdkNotAvailable))
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // UNCOMMENT THE FOLLOWING CODE after adding GoogleSignIn SPM package:
        //
        // import GoogleSignIn  ← Add this import at the top of the file
        //
        // let config = GIDConfiguration(clientID: GoogleSignInConfig.clientID)
        // GIDSignIn.sharedInstance.configuration = config
        //
        // GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
        //     if let error = error {
        //         let nsError = error as NSError
        //         if nsError.code == GIDSignInError.canceled.rawValue {
        //             completion(.failure(.cancelled))
        //         } else {
        //             completion(.failure(.failed(error.localizedDescription)))
        //         }
        //         return
        //     }
        //
        //     guard let user = result?.user,
        //           let idToken = user.idToken?.tokenString else {
        //         completion(.failure(.missingIdToken))
        //         return
        //     }
        //
        //     let signInResult = GoogleSignInResult(
        //         userId: user.userID ?? UUID().uuidString,
        //         email: user.profile?.email ?? "",
        //         displayName: user.profile?.name,
        //         profileImageURL: user.profile?.imageURL(withDimension: 200),
        //         idToken: idToken,
        //         accessToken: user.accessToken.tokenString
        //     )
        //
        //     DispatchQueue.main.async {
        //         self?.isSignedIn = true
        //         self?.currentUser = signInResult
        //     }
        //
        //     completion(.success(signInResult))
        // }
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    }
    
    // MARK: - Handle URL (Required for Google Sign-In redirect)
    
    /// Call this from your App's `onOpenURL` to handle Google Sign-In redirects
    /// 
    /// Usage in GameboxdApp.swift:
    /// ```swift
    /// .onOpenURL { url in
    ///     GoogleSignInService.shared.handleURL(url)
    /// }
    /// ```
    func handleURL(_ url: URL) -> Bool {
        // UNCOMMENT after adding GoogleSignIn SPM package:
        // return GIDSignIn.sharedInstance.handle(url)
        return false
    }
    
    // MARK: - Restore Previous Sign-In
    
    /// Attempts to restore a previous Google Sign-In session
    /// Call this on app launch
    func restorePreviousSignIn() async -> GoogleSignInResult? {
        // UNCOMMENT after adding GoogleSignIn SPM package:
        //
        // return await withCheckedContinuation { continuation in
        //     GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
        //         guard let user = user, error == nil,
        //               let idToken = user.idToken?.tokenString else {
        //             continuation.resume(returning: nil)
        //             return
        //         }
        //
        //         let result = GoogleSignInResult(
        //             userId: user.userID ?? UUID().uuidString,
        //             email: user.profile?.email ?? "",
        //             displayName: user.profile?.name,
        //             profileImageURL: user.profile?.imageURL(withDimension: 200),
        //             idToken: idToken,
        //             accessToken: user.accessToken.tokenString
        //         )
        //
        //         DispatchQueue.main.async {
        //             self.isSignedIn = true
        //             self.currentUser = result
        //         }
        //
        //         continuation.resume(returning: result)
        //     }
        // }
        
        return nil
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        // UNCOMMENT after adding GoogleSignIn SPM package:
        // GIDSignIn.sharedInstance.signOut()
        
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.currentUser = nil
        }
    }
}

