//
//  UsernameSetupView.swift
//  Gameboxd
//
//  Shown after first social login (Apple/Google) to let user choose a username,
//  pick an avatar, and select preferred platforms
//

import SwiftUI

struct UsernameSetupView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String = ""
    @State private var selectedEmoji: String = "🎮"
    @State private var selectedPlatforms: Set<String> = []
    @State private var isAnimating = false
    @State private var currentStep = 0
    
    let emojiOptions = ["🎮", "🕹️", "👾", "🎯", "🏆", "⚡", "🔥", "💎", "🌟", "🎲", "🐉", "🦊", "🐺", "🦅", "🤖", "👻", "💀", "🧙‍♂️", "🥷", "🏴‍☠️"]
    let platformOptions = ["PC", "PlayStation 5", "PlayStation 4", "Xbox Series X|S", "Xbox One", "Nintendo Switch", "iOS", "Android", "Steam Deck"]
    
    var body: some View {
        ZStack {
            Color.gbDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.gbGreen : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                TabView(selection: $currentStep) {
                    // Step 1: Username
                    usernameStep
                        .tag(0)
                    
                    // Step 2: Avatar
                    avatarStep
                        .tag(1)
                    
                    // Step 3: Platforms
                    platformStep
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button(action: {
                            withAnimation { currentStep -= 1 }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Retour")
                            }
                            .foregroundColor(.gray)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: handleNext) {
                        HStack {
                            Text(currentStep < 2 ? "Suivant" : "C'est parti !")
                                .fontWeight(.semibold)
                            
                            Image(systemName: currentStep < 2 ? "arrow.right" : "rocket.fill")
                        }
                        .frame(minWidth: 160)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(canProceed ? Color.gbGreen : Color.gray.opacity(0.3))
                        .foregroundColor(canProceed ? .black : .gray)
                        .cornerRadius(14)
                    }
                    .disabled(!canProceed)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            // Pre-fill from social auth data
            if store.userProfile.username != "Gamer" && store.userProfile.username != "Joueur Apple" && store.userProfile.username != "Joueur Google" {
                username = store.userProfile.username
            }
        }
    }
    
    // MARK: - Step 1: Username
    var usernameStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.gbGreen.gradient)
                        .frame(width: 100, height: 100)
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                    
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.gbDark)
                }
                .shadow(color: .gbGreen.opacity(0.3), radius: 20)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
                
                Text("Choisis ton pseudo")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("C'est comme ça que les autres joueurs te verront")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 8) {
                TextField("Ton pseudo gaming", text: $username)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gbCard)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                if !username.isEmpty {
                    if username.count < 3 {
                        Label("Minimum 3 caractères", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if username.count > 20 {
                        Label("Maximum 20 caractères", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("Super pseudo !", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gbGreen)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Step 2: Avatar
    var avatarStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.gbGreen.gradient)
                        .frame(width: 100, height: 100)
                    
                    Text(selectedEmoji)
                        .font(.system(size: 50))
                }
                .shadow(color: .gbGreen.opacity(0.3), radius: 20)
                
                Text("Choisis ton avatar")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Exprime ta personnalité gaming")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(emojiOptions, id: \.self) { emoji in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedEmoji = emoji
                        }
                    }) {
                        Text(emoji)
                            .font(.system(size: 30))
                            .frame(width: 55, height: 55)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedEmoji == emoji ? Color.gbGreen.opacity(0.25) : Color.gbCard)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedEmoji == emoji ? Color.gbGreen : Color.clear, lineWidth: 2)
                            )
                            .scaleEffect(selectedEmoji == emoji ? 1.1 : 1.0)
                    }
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Step 3: Platforms
    var platformStep: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.gbGreen.gradient)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gbDark)
                }
                .shadow(color: .gbGreen.opacity(0.3), radius: 20)
                
                Text("Tes plateformes")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Sur quoi tu joues ? (optionnel)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            FlowLayout(spacing: 10) {
                ForEach(platformOptions, id: \.self) { platform in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: platformIcon(for: platform))
                                .font(.caption)
                            Text(platform)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selectedPlatforms.contains(platform) ? Color.gbGreen.opacity(0.2) : Color.gbCard)
                        .foregroundColor(selectedPlatforms.contains(platform) ? .gbGreen : .gray)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedPlatforms.contains(platform) ? Color.gbGreen : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Logic
    
    var canProceed: Bool {
        switch currentStep {
        case 0:
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count >= 3 && trimmed.count <= 20
        default:
            return true
        }
    }
    
    func handleNext() {
        if currentStep < 2 {
            withAnimation { currentStep += 1 }
        } else {
            completeSetup()
        }
    }
    
    func completeSetup() {
        store.userProfile.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        store.userProfile.avatarEmoji = selectedEmoji
        store.userProfile.preferredPlatforms = Array(selectedPlatforms)
        store.userProfile.needsUsernameSetup = false
        store.saveUserProfile()
        dismiss()
    }
    
    func platformIcon(for name: String) -> String {
        switch name {
        case "PC": return "desktopcomputer"
        case "PlayStation 5", "PlayStation 4": return "playstation.logo"
        case "Xbox Series X|S", "Xbox One": return "xbox.logo"
        case "Nintendo Switch": return "gamecontroller"
        case "iOS": return "iphone"
        case "Android": return "phone"
        case "Steam Deck": return "gamecontroller.fill"
        default: return "gamecontroller"
        }
    }
}

#Preview {
    UsernameSetupView()
        .environmentObject(GameStore())
}
