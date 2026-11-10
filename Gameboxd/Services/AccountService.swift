//
//  AccountService.swift
//  Gameboxd
//
//  Online accounts (Gameboxd server, see Backend): sign up with a unique pseudo, sign in, reset the
//  password, sign out, delete the account. The collection itself stays on the phone.
//

import Foundation

/// A player's public profile, as stored on the `users` collection of the server.
nonisolated struct RemoteProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var username: String
    var displayName: String?
    var bio: String?
    var avatarURL: String?
    /// Public 64-bit Steam id, set when the player links Steam (finds Steam friends).
    var steamId: String?
    /// "Profil public": while false, the server hides this player's collection and activity.
    var isPublic: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case steamId = "steam_id"
        case isPublic = "is_public"
    }
}

enum AccountError: LocalizedError {
    case notConfigured
    case usernameTaken
    case invalidUsername
    case confirmEmail
    case noMailServer
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Les comptes en ligne ne sont pas encore configurés dans cette version."
        case .usernameTaken: "Ce pseudo est déjà pris."
        case .invalidUsername: "Le pseudo doit faire 3 à 20 caractères : lettres minuscules, chiffres ou _."
        case .confirmEmail: "Compte créé ! Confirme ton adresse avec le lien reçu par e-mail, puis connecte-toi."
        case .noMailServer: "Le serveur Gameboxd n'envoie pas encore d'e-mails : la réinitialisation n'est pas disponible. Demande à la personne qui gère le serveur de changer ton mot de passe."
        case .message(let text): text
        }
    }
}

@MainActor
@Observable
final class AccountService {
    static let shared = AccountService()

    private let backend = Backend.shared
    /// The signed-in player's profile; nil when signed out (or playing without an account).
    private(set) var profile: RemoteProfile?

    var isSignedIn: Bool { profile != nil }

    /// Pseudo rule, mirrored by the database constraint.
    static func isValidUsername(_ name: String) -> Bool {
        name.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    /// Restores the saved session at launch (the token is kept in the Keychain).
    func restore() async {
        guard BackendConfig.isConfigured, backend.token != nil else { return }
        do {
            try await authenticate("auth-refresh", body: nil)
        } catch let error as BackendError where error.status == 401 || error.status == 404 {
            backend.token = nil // expired or account gone; offline keeps it for next launch
        } catch {}
    }

    /// Reads the profile again (after the server changed it, e.g. a verified Steam link).
    func reloadProfile() async {
        guard let id = profile?.id, let fresh = try? await fetchProfile(id: id) else { return }
        profile = fresh
    }

    func signUp(email: String, password: String, username: String) async throws {
        try requireServer()
        let name = username.lowercased()
        guard Self.isValidUsername(name) else { throw AccountError.invalidUsername }
        guard try await isUsernameAvailable(name) else { throw AccountError.usernameTaken }
        do {
            try await backend.send("POST", "/api/collections/users/records",
                                   body: ["email": email, "password": password, "passwordConfirm": password, "username": name])
            try await authenticate("auth-with-password", body: ["identity": email, "password": password])
        } catch {
            throw Self.translate(error)
        }
    }

    func signIn(email: String, password: String) async throws {
        try requireServer()
        do {
            try await authenticate("auth-with-password", body: ["identity": email, "password": password])
        } catch {
            throw Self.translate(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        try requireServer()
        do {
            // The server answers "sent" even when it has no mail server: ask first.
            let mail: MailStatus = try await backend.send("GET", "/api/gameboxd/mail-enabled")
            guard mail.enabled else { throw AccountError.noMailServer }
            try await backend.send("POST", "/api/collections/users/request-password-reset", body: ["email": email])
        } catch {
            throw Self.translate(error)
        }
    }

    func signOut() async {
        backend.token = nil
        profile = nil
    }

    /// Deletes the account and everything shared with it (profile, follows, activity,
    /// library mirror). The games on this phone are left alone.
    func deleteAccount() async throws {
        try requireServer()
        guard let id = profile?.id else { return }
        do {
            try await backend.send("DELETE", "/api/collections/users/records/\(id.serverId)")
        } catch {
            throw Self.translate(error)
        }
        await signOut()
    }

    /// Shows or hides your collection and activity to other players. Applied right away on
    /// the phone, rolled back if the server refuses.
    func setPublic(_ value: Bool) async throws {
        try requireServer()
        guard let id = profile?.id else { return }
        let previous = profile?.isPublic
        profile?.isPublic = value
        do {
            try await backend.send("PATCH", "/api/collections/users/records/\(id.serverId)", body: ["is_public": value])
        } catch {
            profile?.isPublic = previous
            throw Self.translate(error)
        }
    }

    func isUsernameAvailable(_ name: String) async throws -> Bool {
        try requireServer()
        let answer: Availability = try await backend.send("GET", "/api/gameboxd/username-available", query: ["name": name.lowercased()])
        return answer.available
    }

    // MARK: - Helpers

    private nonisolated struct Availability: Decodable { let available: Bool }
    private nonisolated struct MailStatus: Decodable { let enabled: Bool }
    private nonisolated struct AuthAnswer: Decodable {
        let token: String
        let record: RemoteProfile
    }

    private func requireServer() throws {
        guard BackendConfig.isConfigured else { throw AccountError.notConfigured }
    }

    /// Signs in (or refreshes the session) and keeps the token for the next launch.
    private func authenticate(_ action: String, body: [String: String]?) async throws {
        let answer: AuthAnswer = try await backend.send("POST", "/api/collections/users/\(action)", body: body)
        backend.token = answer.token
        profile = answer.record
    }

    private func fetchProfile(id: UUID) async throws -> RemoteProfile {
        try await backend.send("GET", "/api/collections/users/records/\(id.serverId)")
    }

    /// Server answers to French messages.
    static func translate(_ error: Error) -> AccountError {
        if let error = error as? AccountError { return error }
        if let error = error as? BackendError {
            let fields = error.fields
            let message = error.message.lowercased()
            if fields["email"] == "validation_not_unique" { return .message("Un compte existe déjà avec cet e-mail.") }
            if fields["username"] == "validation_not_unique" { return .usernameTaken }
            if fields["username"] != nil || message.contains("reserved name") { return .invalidUsername }
            if fields["email"] != nil { return .message("Cette adresse e-mail n'est pas valide.") }
            if fields["password"] != nil { return .message("Mot de passe trop faible : 8 caractères minimum.") }
            if message.contains("failed to authenticate") { return .message("E-mail ou mot de passe incorrect.") }
            if error.status == 429 { return .message("Trop de tentatives. Réessaie dans quelques minutes.") }
            return .message("Une erreur est survenue. Réessaie.")
        }
        if error is URLError {
            // The server runs on the Mac: off, asleep, or not on this Wi-Fi.
            return .message("Serveur Gameboxd injoignable. Vérifie que le Mac est allumé et sur le même Wi‑Fi.")
        }
        return .message("Une erreur est survenue. Réessaie.")
    }
}
