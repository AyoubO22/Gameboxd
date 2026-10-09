//
//  AccountService.swift
//  Gameboxd
//
//  Online accounts (Supabase): sign up with a unique pseudo, sign in, reset the
//  password, sign out, delete the account. The collection itself stays on the phone.
//

import Foundation
import Supabase

enum SupabaseConfig {
    /// SUPABASE_HOST / SUPABASE_ANON_KEY in Secrets.xcconfig. The host is stored without
    /// "https://" because "//" starts a comment in .xcconfig files.
    static var url: URL? {
        guard let host = value("SUPABASE_HOST"), !host.isEmpty else { return nil }
        return URL(string: "https://\(host)")
    }
    static var anonKey: String { value("SUPABASE_ANON_KEY") ?? "" }
    static var isConfigured: Bool { url != nil && !anonKey.isEmpty }

    private static func value(_ key: String) -> String? {
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty { return v }
        return ProcessInfo.processInfo.environment[key]
    }
}

/// A player's public profile, as stored in `public.profiles`.
nonisolated struct RemoteProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var username: String
    var displayName: String?
    var bio: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

enum AccountError: LocalizedError {
    case notConfigured
    case usernameTaken
    case invalidUsername
    case confirmEmail
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Les comptes en ligne ne sont pas encore configurés dans cette version."
        case .usernameTaken: "Ce pseudo est déjà pris."
        case .invalidUsername: "Le pseudo doit faire 3 à 20 caractères : lettres minuscules, chiffres ou _."
        case .confirmEmail: "Compte créé ! Confirme ton adresse avec le lien reçu par e-mail, puis connecte-toi."
        case .message(let text): text
        }
    }
}

@MainActor
@Observable
final class AccountService {
    static let shared = AccountService()

    let client: SupabaseClient?
    /// The signed-in player's profile; nil when signed out (or playing without an account).
    private(set) var profile: RemoteProfile?

    var isSignedIn: Bool { profile != nil }

    init() {
        if let url = SupabaseConfig.url {
            client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
        } else {
            client = nil
        }
    }

    /// Pseudo rule, mirrored by the database constraint.
    static func isValidUsername(_ name: String) -> Bool {
        name.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    /// Restores the saved session at launch (the SDK keeps it in the Keychain).
    func restore() async {
        guard let client, let session = try? await client.auth.session else { return }
        profile = try? await fetchProfile(id: session.user.id)
    }

    func signUp(email: String, password: String, username: String) async throws {
        let client = try requireClient()
        let name = username.lowercased()
        guard Self.isValidUsername(name) else { throw AccountError.invalidUsername }
        guard try await isUsernameAvailable(name) else { throw AccountError.usernameTaken }
        do {
            let response = try await client.auth.signUp(email: email, password: password,
                                                        data: ["username": .string(name)])
            // With email confirmation on (Supabase's default) there's no session yet.
            guard response.session != nil else { throw AccountError.confirmEmail }
            profile = try await fetchProfile(id: response.user.id)
        } catch let error as AccountError {
            throw error
        } catch {
            throw Self.translate(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        let client = try requireClient()
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            profile = try await fetchProfile(id: session.user.id)
        } catch {
            throw Self.translate(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        let client = try requireClient()
        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            throw Self.translate(error)
        }
    }

    func signOut() async {
        try? await client?.auth.signOut()
        profile = nil
    }

    /// Deletes the account and everything shared with it (profile, follows, activity).
    /// The games on this phone are left alone.
    func deleteAccount() async throws {
        let client = try requireClient()
        do {
            try await client.rpc("delete_account").execute()
        } catch {
            throw Self.translate(error)
        }
        await signOut()
    }

    func isUsernameAvailable(_ name: String) async throws -> Bool {
        let client = try requireClient()
        return try await client.rpc("username_available", params: ["name": name.lowercased()]).execute().value
    }

    // MARK: - Helpers

    private func requireClient() throws -> SupabaseClient {
        guard let client else { throw AccountError.notConfigured }
        return client
    }

    private func fetchProfile(id: UUID) async throws -> RemoteProfile {
        try await requireClient().from("profiles").select().eq("id", value: id).single().execute().value
    }

    /// Supabase answers in English; the app speaks French.
    static func translate(_ error: Error) -> AccountError {
        let text = String(describing: error).lowercased()
        if text.contains("invalid login credentials") || text.contains("invalid_credentials") {
            return .message("E-mail ou mot de passe incorrect.")
        }
        if text.contains("already registered") || text.contains("user_already_exists") {
            return .message("Un compte existe déjà avec cet e-mail.")
        }
        if text.contains("email not confirmed") || text.contains("email_not_confirmed") {
            return .message("Confirme d'abord ton adresse avec le lien reçu par e-mail.")
        }
        if text.contains("weak") || text.contains("password should be") {
            return .message("Mot de passe trop faible : 8 caractères minimum, avec des lettres et des chiffres.")
        }
        if text.contains("rate limit") || text.contains("too many") {
            return .message("Trop de tentatives. Réessaie dans quelques minutes.")
        }
        if (error as? URLError) != nil || text.contains("offline") || text.contains("network") {
            return .message("Pas de connexion Internet.")
        }
        return .message("Une erreur est survenue. Réessaie.")
    }
}
