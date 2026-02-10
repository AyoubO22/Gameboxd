//
//  AuthView.swift
//  Gameboxd
//
//  Login and Registration screens
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var store: GameStore
    private let securityManager = SecurityManager.shared
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
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
                                .fill(Color.gbGreen.gradient)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gbDark)
                        }
                        .shadow(color: .gbGreen.opacity(0.4), radius: 20)
                        
                        Text("Gameboxd")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Ton journal de jeux vidéo")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                    
                    // Toggle Login/Register
                    Picker("Mode", selection: $isLogin) {
                        Text("Connexion").tag(true)
                        Text("Inscription").tag(false)
                    }
                    .pickerStyle(.segmented)
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
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.gbDark)
                            } else {
                                Text(isLogin ? "Se connecter" : "Créer un compte")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gbGreen)
                        .foregroundColor(.gbDark)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1 : 0.6)
                    .padding(.horizontal, 24)
                    
                    // Forgot password (login only)
                    if isLogin {
                        Button(action: {}) {
                            Text("Mot de passe oublié ?")
                                .font(.subheadline)
                                .foregroundColor(.gbGreen)
                        }
                    }
                    
                    // Social login
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("ou continuer avec")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        
                        HStack(spacing: 20) {
                            SocialLoginButton(icon: "apple.logo", label: "Apple") {
                                // Apple Sign In
                            }
                            
                            SocialLoginButton(icon: "g.circle.fill", label: "Google") {
                                // Google Sign In
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Skip login
                    Button(action: skipLogin) {
                        Text("Continuer sans compte")
                            .font(.subheadline)
                            .foregroundColor(.gray)
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
        isLoading = true
        
        // Simulate authentication delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            
            if isLogin {
                // Login logic
                if email.isEmpty || password.isEmpty {
                    errorMessage = "Veuillez remplir tous les champs"
                    showingError = true
                } else {
                    // Success - update profile and mark as logged in
                    store.userProfile.username = email.components(separatedBy: "@").first ?? "Joueur"
                    store.setLoggedIn(true)
                }
            } else {
                // Registration logic
                if password != confirmPassword {
                    errorMessage = "Les mots de passe ne correspondent pas"
                    showingError = true
                } else if password.count < 6 {
                    errorMessage = "Le mot de passe doit contenir au moins 6 caractères"
                    showingError = true
                } else {
                    // Success - create account
                    store.userProfile.username = username
                    store.setLoggedIn(true)
                }
            }
        }
    }
    
    func skipLogin() {
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
                .foregroundColor(.gray)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .foregroundColor(.white)
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
                .foregroundColor(.gray)
                .frame(width: 24)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .foregroundColor(.white)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
            
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.gray)
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
                    .font(.title2)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gbCard)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
#Preview {
    AuthView()
        .environmentObject(GameStore())
}
