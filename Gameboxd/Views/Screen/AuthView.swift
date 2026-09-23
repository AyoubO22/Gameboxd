//
//  AuthView.swift
//  Gameboxd
//
//  Login and Registration screens
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var store: GameStore
    private let securityManager = SecurityManager.shared
    private let appleSignInService = AppleSignInService.shared
    private let googleSignInService = GoogleSignInService.shared
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSocialLoading = false
    
    var body: some View {
        ZStack {
            // Background
            Color.gbDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.gbBrass.gradient)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gbDark)
                        }
                        .shadow(color: .gbBrass.opacity(0.4), radius: 20)
                        
                        Text("Gameboxd")
                            .font(DS.Typography.display(48))
                            .foregroundColor(.textPrimary)
                        
                        Text("Ton journal de jeux vidéo")
                            .font(DS.Typography.body)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 60)
                    
                    // Toggle Login/Register
                    Picker("Mode", selection: $isLogin) {
                        Text("Connexion").tag(true)
                        Text("Inscription").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)

                    Text("Profil local : tes identifiants restent sur cet appareil, aucun compte en ligne n'est créé.")
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Form
                    VStack(spacing: 16) {
                        if !isLogin {
                            // Username field (registration only)
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "Nom d'utilisateur",
                                text: $username
                            )
                        }
                        
                        // Email field
                        AuthTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress
                        )
                        
                        // Password field
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "Mot de passe",
                            text: $password
                        )
                        
                        if !isLogin {
                            // Confirm password (registration only)
                            AuthSecureField(
                                icon: "lock.fill",
                                placeholder: "Confirmer le mot de passe",
                                text: $confirmPassword
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Action Button
                    Button(action: handleAuth) {
                        Text(isLogin ? "Se connecter" : "Créer un profil local")
                            .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gbBrass)
                        .foregroundColor(.gbDark)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.6)
                    .padding(.horizontal, 24)
                    
                    // Social login
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("ou continuer avec")
                                .font(DS.Typography.caption)
                                .foregroundColor(.textSecondary)
                            
                            Rectangle()
                                .fill(Color.textSecondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        
                        HStack(spacing: 20) {
                            SocialLoginButton(icon: "apple.logo", label: "Apple") {
                                handleAppleSignIn()
                            }
                            .disabled(isSocialLoading)
                            
                            SocialLoginButton(icon: "g.circle.fill", label: "Google") {
                                handleGoogleSignIn()
                            }
                            .disabled(isSocialLoading)
                        }
                        .padding(.horizontal, 24)
                        
                        if isSocialLoading {
                            ProgressView()
                                .tint(.gbBrass)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Skip login
                    Button(action: skipLogin) {
                        Text("Continuer sans compte")
                            .font(DS.Typography.body)
                            .foregroundColor(.textSecondary)
                            .underline()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert("Erreur", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmailValid = securityManager.isValidEmail(trimmedEmail)
        let passwordStrength = securityManager.validatePasswordStrength(password)
        let isPasswordStrongEnough = passwordStrength == .medium || passwordStrength == .strong || passwordStrength == .veryStrong
        if isLogin {
            return !trimmedEmail.isEmpty && isEmailValid && !password.isEmpty
        } else {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedEmail.isEmpty && isEmailValid && !password.isEmpty && 
                   !trimmedUsername.isEmpty && password == confirmPassword &&
                   isPasswordStrongEnough
        }
    }
    
    func handleAuth() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLogin {
            guard securityManager.hasLocalCredentials else {
                errorMessage = "Aucun profil local sur cet appareil. Crée-le dans l'onglet Inscription."
                showingError = true
                return
            }
            guard securityManager.verifyLocalCredentials(email: trimmedEmail, password: password) else {
                errorMessage = "Email ou mot de passe incorrect."
                showingError = true
                return
            }
            store.userProfile.email = trimmedEmail
            store.userProfile.authProvider = "email"
            store.setLoggedIn(true)
        } else {
            guard password == confirmPassword else {
                errorMessage = "Les mots de passe ne correspondent pas"
                showingError = true
                return
            }
            do {
                try securityManager.saveLocalCredentials(email: trimmedEmail, password: password)
            } catch {
                errorMessage = "Impossible d'enregistrer le profil : \(error.localizedDescription)"
                showingError = true
                return
            }
            store.userProfile.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            store.userProfile.email = trimmedEmail
            store.userProfile.authProvider = "email"
            store.setLoggedIn(true)
        }
    }
    
    func skipLogin() {
        store.setLoggedIn(true)
    }
    
    // MARK: - Apple Sign In
    func handleAppleSignIn() {
        isSocialLoading = true
        
        Task {
            do {
                let result = try await appleSignInService.signIn()
                
                // Use the display name or stored name, fallback to "Joueur Apple"
                let displayName = result.displayName
                    ?? UserDefaults.standard.string(forKey: "appleSignIn_displayName")
                    ?? "Joueur Apple"
                
                let userEmail = result.email
                    ?? UserDefaults.standard.string(forKey: "appleSignIn_email")
                    ?? ""
                
                await MainActor.run {
                    store.userProfile.username = displayName
                    store.userProfile.email = userEmail
                    store.userProfile.authProvider = "apple"
                    store.userProfile.authProviderUserId = result.userId
                    store.userProfile.needsUsernameSetup = true
                    store.setLoggedIn(true)
                    isSocialLoading = false
                }
                
                // Optional: Exchange identityToken with your backend / Cognito
                // try await CognitoAuthService.shared.federatedSignIn(
                //     provider: .apple,
                //     token: result.identityToken
                // )
                
            } catch let error as AppleSignInError {
                await MainActor.run {
                    isSocialLoading = false
                    if case .cancelled = error {
                        // User cancelled — don't show error
                        return
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            } catch {
                await MainActor.run {
                    isSocialLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Google Sign In
    func handleGoogleSignIn() {
        isSocialLoading = true
        
        Task {
            do {
                let result = try await googleSignInService.signIn()
                
                await MainActor.run {
                    store.userProfile.username = result.displayName ?? result.email.components(separatedBy: "@").first ?? "Joueur Google"
                    store.userProfile.email = result.email
                    store.userProfile.authProvider = "google"
                    store.userProfile.authProviderUserId = result.userId
                    if let profileURL = result.profileImageURL {
                        store.userProfile.avatarURL = profileURL.absoluteString
                    }
                    store.userProfile.needsUsernameSetup = true
                    store.setLoggedIn(true)
                    isSocialLoading = false
                }
                
                // Optional: Exchange idToken with your backend / Cognito
                // try await CognitoAuthService.shared.federatedSignIn(
                //     provider: .google,
                //     token: result.idToken
                // )
                
            } catch let error as GoogleSignInError {
                await MainActor.run {
                    isSocialLoading = false
                    if case .cancelled = error {
                        return
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            } catch {
                await MainActor.run {
                    isSocialLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
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

// MARK: - Social Login Button
struct SocialLoginButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(DS.Typography.title)
                Text(label)
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gbCard)
            .foregroundColor(.textPrimary)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(GameStore())
}
