//
//  LinkedAccountsView.swift
//  Gameboxd
//
//  Manage linked gaming platform accounts (PlayStation, Steam)
//  Import game libraries from connected platforms
//

import SwiftUI

struct LinkedAccountsView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingLinkSheet: GamingPlatform?
    @State private var showingUnlinkConfirm: LinkedAccount?
    @State private var showingSyncResult = false
    @State private var syncResultMessage = ""
    @State private var isSyncing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Connected Accounts
                if !store.linkedAccounts.isEmpty {
                    connectedAccountsSection
                }
                
                // Available Platforms to Link
                availablePlatformsSection
                
                // Imported Games Section
                if !store.importedGames.isEmpty {
                    importedGamesSection
                }
            }
            .padding(.vertical)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Comptes liés")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showingLinkSheet) { platform in
            LinkPlatformSheet(platform: platform)
        }
        .alert("Délier le compte ?", isPresented: Binding(
            get: { showingUnlinkConfirm != nil },
            set: { if !$0 { showingUnlinkConfirm = nil } }
        )) {
            Button("Annuler", role: .cancel) {}
            Button("Délier", role: .destructive) {
                if let account = showingUnlinkConfirm {
                    store.unlinkAccount(account)
                }
            }
        } message: {
            if let account = showingUnlinkConfirm {
                Text("Les jeux importés depuis \(account.platform.rawValue) resteront dans ta bibliothèque.")
            }
        }
        .alert("Synchronisation", isPresented: $showingSyncResult) {
            Button("OK") {}
        } message: {
            Text(syncResultMessage)
        }
    }
    
    // MARK: - Header
    var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gbGreen.gradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 35))
                    .foregroundColor(.gbDark)
            }
            
            Text("Lie tes comptes gaming")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Importe ta bibliothèque PlayStation ou Steam\npour retrouver tous tes jeux ici")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Connected Accounts
    var connectedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comptes connectés")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(store.linkedAccounts) { account in
                ConnectedAccountCard(
                    account: account,
                    onSync: { syncAccount(account) },
                    onUnlink: { showingUnlinkConfirm = account },
                    isSyncing: isSyncing
                )
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Available Platforms
    var availablePlatformsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.linkedAccounts.isEmpty ? "Plateformes disponibles" : "Ajouter un compte")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(GamingPlatform.allCases) { platform in
                let isLinked = store.linkedAccounts.contains { $0.platform == platform }
                
                if !isLinked {
                    PlatformLinkCard(platform: platform) {
                        showingLinkSheet = platform
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Imported Games
    var importedGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Jeux importés")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(store.importedGames.count) jeux")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            ForEach(store.importedGames.prefix(10)) { game in
                ImportedGameRow(game: game) {
                    store.addImportedGameToLibrary(game)
                }
                .padding(.horizontal)
            }
            
            if store.importedGames.count > 10 {
                NavigationLink(destination: AllImportedGamesView()) {
                    HStack {
                        Text("Voir les \(store.importedGames.count) jeux importés")
                            .font(.subheadline)
                            .foregroundColor(.gbGreen)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gbGreen)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gbCard)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Actions
    func syncAccount(_ account: LinkedAccount) {
        isSyncing = true
        
        Task {
            do {
                let result = try await store.syncLinkedAccount(account)
                await MainActor.run {
                    isSyncing = false
                    syncResultMessage = result.summary
                    showingSyncResult = true
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncResultMessage = error.localizedDescription
                    showingSyncResult = true
                }
            }
        }
    }
}

// MARK: - Connected Account Card
struct ConnectedAccountCard: View {
    let account: LinkedAccount
    let onSync: () -> Void
    let onUnlink: () -> Void
    let isSyncing: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Platform Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(account.platform.accentColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: account.platform.sfSymbol)
                        .font(.title2)
                        .foregroundColor(account.platform.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(account.platform.rawValue)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.gbGreen)
                    }
                    
                    Text(account.platformUsername.isEmpty ? account.platformUserId : account.platformUsername)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    if let lastSync = account.lastSyncDate {
                        Text("Sync: \(lastSync.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(account.importedGameCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.gbGreen)
                    
                    Text("jeux")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Divider().overlay(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                // Sync button
                Button(action: onSync) {
                    HStack(spacing: 6) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.gbGreen)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Synchroniser")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gbDark)
                    .foregroundColor(.gbGreen)
                    .cornerRadius(10)
                }
                .disabled(isSyncing)
                
                // Unlink button
                Button(action: onUnlink) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.badge.minus")
                        Text("Délier")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(16)
    }
}

// MARK: - Platform Link Card
struct PlatformLinkCard: View {
    let platform: GamingPlatform
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(platform.accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: platform.sfSymbol)
                        .font(.title2)
                        .foregroundColor(platform.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(platform.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(platform.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(platform.accentColor)
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(platform.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Link Platform Sheet
struct LinkPlatformSheet: View {
    let platform: GamingPlatform
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    @State private var platformId = ""
    @State private var isLinking = false
    @State private var errorMessage: String?
    @State private var linkSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Platform icon
                    ZStack {
                        Circle()
                            .fill(platform.accentColor.gradient)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: platform.sfSymbol)
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    Text("Lier \(platform.rawValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(platform.setupInstructions)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.gbCard)
                    .cornerRadius(12)
                    
                    // ID Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(platform == .steam ? "Steam ID ou URL de profil" : "PSN ID (Online ID)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        TextField(
                            platform == .steam ? "Ex: 76561198000000000 ou nom_perso" : "Ex: MonPSN_ID",
                            text: $platformId
                        )
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.gbCard)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    }
                    .padding(.horizontal)
                    
                    if let error = errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if linkSuccess {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gbGreen)
                            
                            Text("Compte lié avec succès !")
                                .font(.headline)
                                .foregroundColor(.gbGreen)
                        }
                        .padding()
                    }
                    
                    // Link Button
                    Button(action: linkAccount) {
                        HStack {
                            if isLinking {
                                ProgressView()
                                    .tint(.black)
                            } else if linkSuccess {
                                Image(systemName: "checkmark")
                                Text("Terminé")
                            } else {
                                Image(systemName: "link")
                                Text("Lier le compte")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(linkSuccess ? Color.green : Color.gbGreen)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                    }
                    .disabled(platformId.trimmingCharacters(in: .whitespaces).isEmpty || isLinking)
                    .opacity(platformId.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .padding(.horizontal)
                }
                .padding()
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gbGreen)
                }
            }
        }
    }
    
    func linkAccount() {
        isLinking = true
        errorMessage = nil
        
        Task {
            do {
                try await store.linkPlatformAccount(
                    platform: platform,
                    platformId: platformId.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                await MainActor.run {
                    isLinking = false
                    linkSuccess = true
                    
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLinking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Imported Game Row
struct ImportedGameRow: View {
    let game: ImportedGame
    let onImport: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gbCard.gradient)
                }
                .frame(width: 60, height: 35)
                .cornerRadius(6)
                .clipped()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gbCard.gradient)
                    .frame(width: 60, height: 35)
                    .overlay(
                        Image(systemName: game.platform.sfSymbol)
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if game.playtimeMinutes > 0 {
                        Label(game.formattedPlaytime, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    if game.achievementsTotal > 0 {
                        Label("\(game.achievementsEarned)/\(game.achievementsTotal)", systemImage: "trophy")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            if game.isImportedToLibrary {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.gbGreen)
            } else {
                Button(action: onImport) {
                    Text("Ajouter")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gbGreen.opacity(0.2))
                        .foregroundColor(.gbGreen)
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - All Imported Games View
struct AllImportedGamesView: View {
    @EnvironmentObject var store: GameStore
    @State private var searchText = ""
    @State private var selectedPlatform: GamingPlatform?
    
    var filteredGames: [ImportedGame] {
        var games = store.importedGames
        
        if let platform = selectedPlatform {
            games = games.filter { $0.platform == platform }
        }
        
        if !searchText.isEmpty {
            games = games.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return games.sorted { ($0.playtimeMinutes) > ($1.playtimeMinutes) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Platform Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "Tout", isSelected: selectedPlatform == nil) {
                        selectedPlatform = nil
                    }
                    
                    ForEach(GamingPlatform.allCases) { platform in
                        let count = store.importedGames.filter { $0.platform == platform }.count
                        if count > 0 {
                            FilterChip(
                                label: "\(platform.rawValue) (\(count))",
                                isSelected: selectedPlatform == platform
                            ) {
                                selectedPlatform = platform
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Games list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredGames) { game in
                        ImportedGameRow(game: game) {
                            store.addImportedGameToLibrary(game)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Jeux importés (\(filteredGames.count))")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Rechercher un jeu...")
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.gbGreen.opacity(0.2) : Color.gbCard)
                .foregroundColor(isSelected ? .gbGreen : .gray)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.gbGreen : Color.clear, lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        LinkedAccountsView()
            .environmentObject(GameStore())
    }
}
