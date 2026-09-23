//
//  EditProfileView.swift
//  Gameboxd
//
//  Full profile editing view
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedEmoji: String = ""
    @State private var yearlyGoal: Int = 12
    @State private var selectedPlatforms: Set<String> = []
    @State private var showingSaved = false
    
    let emojiOptions = ["🎮", "🕹️", "👾", "🎯", "🏆", "⚡", "🔥", "💎", "🌟", "🎲", "🐉", "🦊", "🐺", "🦅", "🤖", "👻", "💀", "🧙‍♂️", "🥷", "🏴‍☠️"]
    
    let platformOptions = ["PC", "PlayStation 5", "PlayStation 4", "Xbox Series X|S", "Xbox One", "Nintendo Switch", "iOS", "Android", "Steam Deck"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar Section
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.gbBrass.gradient)
                            .frame(width: 100, height: 100)
                        
                        Text(selectedEmoji)
                            .font(.system(size: 50))
                    }
                    
                    Text("Choisis ton avatar")
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary)
                    
                    // Emoji Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button(action: { selectedEmoji = emoji }) {
                                Text(emoji)
                                    .font(.system(size: 30))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedEmoji == emoji ? Color.gbBrass.opacity(0.3) : Color.gbCard)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedEmoji == emoji ? Color.gbBrass : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
                
                // Username & Bio
                VStack(alignment: .leading, spacing: 16) {
                    Text("Informations")
                        .font(DS.Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pseudo")
                            .font(DS.Typography.caption)
                            .foregroundColor(.textSecondary)
                        
                        TextField("Ton pseudo", text: $username)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gbDark)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio")
                            .font(DS.Typography.caption)
                            .foregroundColor(.textSecondary)
                        
                        TextEditor(text: $bio)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.gbDark)
                            .cornerRadius(8)
                            .foregroundColor(.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Objectif annuel de jeux terminés")
                            .font(DS.Typography.caption)
                            .foregroundColor(.textSecondary)
                        
                        HStack {
                            Text("\(yearlyGoal) jeux")
                                .font(DS.Typography.headline)
                                .foregroundColor(.gbBrass)
                                .frame(width: 80)
                            
                            Slider(value: Binding(
                                get: { Double(yearlyGoal) },
                                set: { yearlyGoal = Int($0) }
                            ), in: 1...100, step: 1)
                            .tint(.gbBrass)
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
                
                // Platforms
                VStack(alignment: .leading, spacing: 16) {
                    Text("Plateformes préférées")
                        .font(DS.Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(platformOptions, id: \.self) { platform in
                            PlatformChip(
                                name: platform,
                                isSelected: selectedPlatforms.contains(platform)
                            ) {
                                if selectedPlatforms.contains(platform) {
                                    selectedPlatforms.remove(platform)
                                } else {
                                    selectedPlatforms.insert(platform)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
                
                // Save Button
                Button(action: saveProfile) {
                    HStack {
                        Image(systemName: showingSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        Text(showingSaved ? "Sauvegardé !" : "Enregistrer les modifications")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(showingSaved ? Color.green : Color.gbBrass)
                    .foregroundColor(showingSaved ? .white : .black)
                    .cornerRadius(12)
                }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(username.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding()
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Modifier le profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
        }
        .onAppear {
            loadProfile()
        }
    }
    
    private func loadProfile() {
        username = store.userProfile.username
        bio = store.userProfile.bio
        selectedEmoji = store.userProfile.avatarEmoji
        yearlyGoal = store.userProfile.yearlyGoal
        selectedPlatforms = Set(store.userProfile.preferredPlatforms)
    }
    
    private func saveProfile() {
        store.userProfile.username = username.trimmingCharacters(in: .whitespaces)
        store.userProfile.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        store.userProfile.avatarEmoji = selectedEmoji
        store.userProfile.yearlyGoal = yearlyGoal
        store.userProfile.preferredPlatforms = Array(selectedPlatforms)
        
        // Persist
        store.saveUserProfile()
        
        withAnimation {
            showingSaved = true
        }
        
        // Brief confirmation, then close the sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }
}

// MARK: - Platform Chip
struct PlatformChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: platformIcon)
                    .font(DS.Typography.caption)
                Text(name)
                    .font(DS.Typography.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.gbBrass.opacity(0.2) : Color.gbDark)
            .foregroundColor(isSelected ? .gbBrass : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.gbBrass : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    var platformIcon: String {
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
