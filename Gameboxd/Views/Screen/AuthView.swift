//
//  AuthView.swift
//  Gameboxd
//
//  Sign in / sign up with an online account (Supabase), or carry on without one:
//  the collection lives on the phone either way; the account adds the social side.
//

import SwiftUI

struct AuthView: View {
    @Environment(GameStore.self) private var store
    private let account = AccountService.shared
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var usernameStatus: UsernameStatus = .unknown
    @State private var isWorking = false
    @State private var alert: AlertContent?

    private enum UsernameStatus { case unknown, checking, available, taken }

    private struct AlertContent: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedUsername: String { username.trimmingCharacters(in: .whitespaces).lowercased() }

    var body: some View {
        ZStack {
            Color.gbDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.gbCoral.gradient)
                                .frame(width: 110, height: 110)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 46))
                                .foregroundColor(.gbDark)
                        }
                        .shadow(color: .gbCoral.opacity(0.4), radius: 20)

                        Text("Gameboxd")
                            .font(DS.Typography.display(44))
                            .foregroundColor(.textPrimary)

                        Text("Ton journal de jeux vidéo")
                            .font(DS.Typography.body)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 56)

                    Picker("Mode", selection: $isLogin) {
                        Text("Connexion").tag(true)
                        Text("Inscription").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)

                    VStack(spacing: 14) {
                        if !isLogin {
                            AuthTextField(icon: "at", placeholder: "Pseudo", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            usernameHint
                        }

                        AuthTextField(icon: "envelope.fill", placeholder: "E-mail", text: $email, keyboardType: .emailAddress)
                            .textContentType(.emailAddress)

                        AuthSecureField(icon: "lock.fill", placeholder: "Mot de passe", text: $password)
                            .textContentType(isLogin ? .password : .newPassword)

                        if !isLogin {
                            Text("8 caractères minimum, avec des lettres et des chiffres.")
                                .font(DS.Typography.caption)
                                .foregroundColor(.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24)

                    Button(action: submit) {
                        ZStack {
                            Text(isLogin ? "Se connecter" : "Créer mon compte")
                                .fontWeight(.semibold)
                                .opacity(isWorking ? 0 : 1)
                            if isWorking { ProgressView().tint(.gbDark) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gbCoral)
                        .foregroundColor(.gbDark)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isWorking)
                    .opacity(isFormValid ? 1 : 0.6)
                    .padding(.horizontal, 24)

                    if isLogin {
                        Button("Mot de passe oublié ?", action: resetPassword)
                            .font(DS.Typography.captionMedium)
                            .foregroundColor(.accent)
                            .disabled(isWorking)
                    }

                    VStack(spacing: 6) {
                        Button(action: { store.setLoggedIn(true) }) {
                            Text("Continuer sans compte")
                                .font(DS.Typography.body)
                                .foregroundColor(.textSecondary)
                                .underline()
                        }
                        Text("Ta collection reste sur ce téléphone. Un compte sert à suivre tes amis.")
                            .font(DS.Typography.caption)
                            .foregroundColor(.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: normalizedUsername) { _, name in checkUsername(name) }
        .alert(item: $alert) { content in
            Alert(title: Text(content.title), message: Text(content.message), dismissButton: .default(Text("OK")))
        }
    }

    @ViewBuilder private var usernameHint: some View {
        let name = normalizedUsername
        Group {
            if name.isEmpty {
                Text("Ton nom public : minuscules, chiffres et _ (3 à 20).")
                    .foregroundColor(.textTertiary)
            } else if !AccountService.isValidUsername(name) {
                Text("3 à 20 caractères : minuscules, chiffres ou _.")
                    .foregroundColor(DS.Colors.warning)
            } else {
                switch usernameStatus {
                case .checking: Text("Vérification…").foregroundColor(.textTertiary)
                case .available: Label("@\(name) est libre", systemImage: "checkmark.circle.fill").foregroundColor(DS.Colors.success)
                case .taken: Label("@\(name) est déjà pris", systemImage: "xmark.circle.fill").foregroundColor(DS.Colors.error)
                case .unknown: EmptyView()
                }
            }
        }
        .font(DS.Typography.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isFormValid: Bool {
        guard SecurityManager.shared.isValidEmail(trimmedEmail), !password.isEmpty else { return false }
        if isLogin { return true }
        return password.count >= 8 && AccountService.isValidUsername(normalizedUsername) && usernameStatus != .taken
    }

    /// Asks the server once typing pauses (0.4 s), not on every key.
    private func checkUsername(_ name: String) {
        usernameStatus = .unknown
        guard AccountService.isValidUsername(name) else { return }
        usernameStatus = .checking
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard name == normalizedUsername else { return }
            let free = try? await account.isUsernameAvailable(name)
            guard name == normalizedUsername else { return }
            usernameStatus = free.map { $0 ? .available : .taken } ?? .unknown
        }
    }

    private func submit() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                if isLogin {
                    try await account.signIn(email: trimmedEmail, password: password)
                } else {
                    try await account.signUp(email: trimmedEmail, password: password, username: normalizedUsername)
                }
                enterApp()
            } catch AccountError.confirmEmail {
                alert = AlertContent(title: "Vérifie tes e-mails", message: AccountError.confirmEmail.localizedDescription)
                isLogin = true
                password = ""
            } catch {
                alert = AlertContent(title: "Oups", message: error.localizedDescription)
            }
        }
    }

    private func resetPassword() {
        guard SecurityManager.shared.isValidEmail(trimmedEmail) else {
            alert = AlertContent(title: "Mot de passe oublié", message: "Entre d'abord ton adresse e-mail.")
            return
        }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await account.sendPasswordReset(email: trimmedEmail)
                alert = AlertContent(title: "E-mail envoyé", message: "Un lien pour choisir un nouveau mot de passe t'attend dans ta boîte mail.")
            } catch {
                alert = AlertContent(title: "Oups", message: error.localizedDescription)
            }
        }
    }

    /// Mirrors the online profile into the local one, then opens the app.
    private func enterApp() {
        guard let profile = account.profile else { return }
        store.userProfile.username = profile.displayName ?? profile.username
        store.userProfile.email = trimmedEmail
        store.userProfile.authProvider = "supabase"
        store.userProfile.authProviderUserId = profile.id.uuidString
        store.userProfile.needsUsernameSetup = false
        store.setLoggedIn(true)
    }
}

// MARK: - Auth Text Field
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.textSecondary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .foregroundColor(.textPrimary)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Auth Secure Field
struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var showPassword = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.textSecondary)
                .frame(width: 24)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .foregroundColor(.textPrimary)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.textPrimary)
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}


#Preview {
    AuthView()
        .environment(GameStore())
}
