//
//  EditProfileView.swift
//  Gameboxd
//
//  Full profile editing view
//

import SwiftUI

struct EditProfileView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) var dismiss

    /// Edited copy of the profile: the preview at the top shows it live, Save writes it back.
    @State private var draft = UserProfile()
    @State private var showingSaved = false

    let emojiOptions = ["🎮", "🕹️", "👾", "🎯", "🏆", "⚡", "🔥", "💎", "🌟", "🎲", "🐉", "🦊", "🐺", "🦅", "🤖", "👻", "💀", "🧙‍♂️", "🥷", "🏴‍☠️",
                        "🐱", "🐼", "🦁", "🐸", "🦄", "🍄", "🚀", "🌙", "👑", "🗡️"]

    let platformOptions = ["PC", "PlayStation 5", "PlayStation 4", "Xbox Series X|S", "Xbox One", "Nintendo Switch", "iOS", "Android", "Steam Deck"]

    /// Games to pick a cover or a banner from: the showcase first, then the rest of the shelf.
    private var games: [Game] {
        let favorites = store.favoriteGames()
        let others = store.myGames.filter { game in game.artURL != nil && !favorites.contains { $0.id == game.id } }
        return favorites + others
    }

    private var trimmedName: String { draft.username.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                preview

                card("Ton avatar") {
                    Picker("Avatar", selection: $draft.avatarKind) {
                        Text("Emoji").tag(UserProfile.AvatarKind.emoji)
                        if !games.isEmpty { Text("Un de mes jeux").tag(UserProfile.AvatarKind.game) }
                        if store.accountPhotoURL != nil { Text("Ma photo").tag(UserProfile.AvatarKind.photo) }
                    }
                    .pickerStyle(.segmented)

                    switch draft.avatarKind {
                    case .emoji:
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button { draft.avatarEmoji = emoji } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 48, height: 48)
                                        .background(draft.avatarEmoji == emoji ? draft.themeColor.opacity(0.3) : Color.gbDark, in: .rect(cornerRadius: 10))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(draft.avatarEmoji == emoji ? draft.themeColor : .clear, lineWidth: 2)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(emoji)
                                .accessibilityAddTraits(draft.avatarEmoji == emoji ? .isSelected : [])
                            }
                        }
                    case .game:
                        GameArtPicker(games: games, selection: $draft.avatarGameId, tint: draft.themeColor)
                    case .photo:
                        Text("La photo de ton compte, ou celle de ta PlayStation ou de Steam.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                card("Ta couleur") {
                    HStack(spacing: 0) {
                        ForEach(UserProfile.themePalette, id: \.self) { hex in
                            let isSelected = (draft.themeHex ?? UserProfile.themePalette[0]) == hex
                            Button { draft.themeHex = hex == UserProfile.themePalette[0] ? nil : hex } label: {
                                Circle()
                                    .fill(Color(hex: hex).gradient)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if isSelected {
                                            Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                        }
                                    }
                                    .padding(4)
                                    .overlay { Circle().strokeBorder(isSelected ? Color.textPrimary : .clear, lineWidth: 2) }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(UserProfile.themeName(hex))
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }

                if !games.isEmpty {
                    card("Ta bannière", subtitle: "Un jeu qui s'affiche en grand en haut de ton profil.") {
                        GameArtPicker(games: games, selection: $draft.bannerGameId, tint: draft.themeColor, allowsNone: true)
                    }
                }

                card("Informations") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pseudo")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                        TextField("Ton pseudo", text: $draft.username)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.gbDark, in: .rect(cornerRadius: 8))
                            .foregroundStyle(Color.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                        TextEditor(text: $draft.bio)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.gbDark, in: .rect(cornerRadius: 8))
                            .foregroundStyle(Color.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Objectif annuel de jeux terminés")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                        HStack {
                            Text("\(draft.yearlyGoal) jeux")
                                .font(DS.Typography.headline)
                                .foregroundStyle(draft.themeColor)
                                .frame(width: 80)
                            Slider(value: Binding(
                                get: { Double(draft.yearlyGoal) },
                                set: { draft.yearlyGoal = Int($0) }
                            ), in: 1...100, step: 1)
                        }
                    }
                }

                card("Sur mon profil", subtitle: "Choisis ce que tu montres. Ton nom et ta vitrine restent toujours.") {
                    ForEach(UserProfile.ProfileSection.allCases) { section in
                        Toggle(isOn: Binding(
                            get: { !draft.hiddenSections.contains(section) },
                            set: { shown in
                                draft.hiddenSections.removeAll { $0 == section }
                                if !shown { draft.hiddenSections.append(section) }
                            }
                        )) {
                            Label(section.title, systemImage: section.icon)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }

                card("Plateformes préférées") {
                    FlowLayout(spacing: 8) {
                        ForEach(platformOptions, id: \.self) { platform in
                            PlatformChip(name: platform, isSelected: draft.preferredPlatforms.contains(platform)) {
                                if let index = draft.preferredPlatforms.firstIndex(of: platform) {
                                    draft.preferredPlatforms.remove(at: index)
                                } else {
                                    draft.preferredPlatforms.append(platform)
                                }
                            }
                        }
                    }
                }

                Button(action: saveProfile) {
                    Label(showingSaved ? "Sauvegardé !" : "Enregistrer",
                          systemImage: showingSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(DS.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.glassProminent)
                .tint(showingSaved ? .green : draft.themeColor)
                .disabled(trimmedName.isEmpty)
            }
            .padding()
        }
        .background(Color.gbDark.ignoresSafeArea())
        .tint(draft.themeColor)
        .animation(.smooth, value: draft.themeHex)
        .animation(.smooth, value: draft.avatarKind)
        .sensoryFeedback(.selection, trigger: draft.themeHex)
        .navigationTitle("Personnaliser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
        }
        .onAppear { draft = store.userProfile }
    }

    /// The profile's top as it will look, updated as the player picks.
    private var preview: some View {
        VStack(spacing: DS.Spacing.sm) {
            ProfileAvatar(profile: draft, size: 100)
            Text(trimmedName.isEmpty ? "Ton pseudo" : trimmedName)
                .font(DS.Typography.title)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .background {
            ZStack {
                Color.gbCard
                if let id = draft.bannerGameId, let game = store.myGames.first(where: { $0.id == id }),
                   let url = game.screenshotURLs.first.flatMap(URL.init(string:)) ?? game.artURL {
                    CachedAsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                        .opacity(0.55)
                }
                LinearGradient(colors: [draft.themeColor.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    private func card<Content: View>(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gbCard, in: .rect(cornerRadius: 12))
    }

    private func saveProfile() {
        var profile = draft
        profile.username = trimmedName
        profile.bio = draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        // A game avatar with no game chosen falls back to the emoji.
        if profile.avatarKind == .game && profile.avatarGameId == nil { profile.avatarKind = .emoji }
        store.userProfile = profile
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

// MARK: - Game Art Picker

/// A row of the player's game covers to pick one from.
private struct GameArtPicker: View {
    let games: [Game]
    @Binding var selection: UUID?
    let tint: Color
    var allowsNone = false

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                if allowsNone {
                    tile(isSelected: selection == nil, label: "Aucune") {
                        Image(systemName: "nosign")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gbDark)
                    } action: { selection = nil }
                }
                ForEach(games) { game in
                    tile(isSelected: selection == game.id, label: game.title) {
                        CachedAsyncImage(url: game.artURL) { $0.resizable().scaledToFill() } placeholder: { Color.gbDark }
                    } action: { selection = game.id }
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tile<Art: View>(isSelected: Bool, label: String, @ViewBuilder art: () -> Art, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            art()
                .frame(width: 66, height: 88)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? tint : .clear, lineWidth: 3)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, tint)
                            .font(.system(size: 20))
                            .offset(x: 6, y: -6)
                    }
                }
                .scaleEffect(isSelected ? 1.05 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            .background(isSelected ? Color.gbCoral.opacity(0.2) : Color.gbDark)
            .foregroundColor(isSelected ? .gbCoral : .gray)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.gbCoral : Color.gray.opacity(0.3), lineWidth: 1)
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
