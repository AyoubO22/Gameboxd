//
//  GameDetailView.swift
//  Gameboxd
//
//  Comprehensive game detail view with all tracking options
//

import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject var store: GameStore
    @State var game: Game
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddToList = false
    @State private var showingSpoiler = false
    @State private var showingShareCard = false
    @State private var showingDeleteConfirm = false
    @State private var showingAddSession = false
    @State private var showingUnsavedChanges = false
    @State private var similarGames: [Game] = []
    @State private var isLoadingSimilar = false
    @State private var selectedTab = 0
    
    /// The original game state to detect unsaved changes
    @State private var originalGame: Game? = nil
    
    var isInLibrary: Bool {
        store.myGames.contains { $0.id == game.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with cover
                GameDetailHeader(game: game)
                
                // Quick Actions Bar
                QuickActionsBar(game: $game, showingAddToList: $showingAddToList, showingAddSession: $showingAddSession)
                
                // Tab Selector
                Picker("Section", selection: $selectedTab) {
                    Text("Infos").tag(0)
                    Text("Suivi").tag(1)
                    Text("Notes").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Tab Content
                switch selectedTab {
                case 0:
                    GameInfoSection(game: $game, similarGames: similarGames, isLoadingSimilar: isLoadingSimilar)
                case 1:
                    GameTrackingSection(game: $game)
                case 2:
                    GameNotesSection(game: $game, showingSpoiler: $showingSpoiler)
                default:
                    EmptyView()
                }
                
                // Save Button
                SaveButton(game: game, isInLibrary: isInLibrary) {
                    store.updateGame(game)
                    dismiss()
                }
                .padding()
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isInLibrary {
                        Button(action: { store.toggleFavorite(game) }) {
                            Label(game.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                                  systemImage: game.isFavorite ? "heart.slash" : "heart")
                        }
                        
                        Button(action: { showingAddToList = true }) {
                            Label("Ajouter à une liste", systemImage: "list.bullet")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showingDeleteConfirm = true
                        }) {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                    
                    Button(action: { shareGame() }) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingShareCard = true }) {
                        Label("Créer une carte", systemImage: "photo.artframe")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gbGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListSheet(game: game)
        }
        .sheet(isPresented: $showingShareCard) {
            ShareCardView(game: game)
        }
        .sheet(isPresented: $showingAddSession) {
            AddPlaySessionView(preselectedGame: game)
        }
        .alert("Supprimer ce jeu ?", isPresented: $showingDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                store.deleteGame(game)
                dismiss()
            }
        } message: {
            Text("\(game.title) sera définitivement supprimé de ta bibliothèque, y compris les sessions et notes associées.")
        }
        .task {
            await loadSimilarGames()
        }
        .onAppear {
            if originalGame == nil {
                originalGame = game
            }
        }
        .alert("Modifications non sauvegardées", isPresented: $showingUnsavedChanges) {
            Button("Quitter sans sauvegarder", role: .destructive) {
                dismiss()
            }
            Button("Sauvegarder et quitter") {
                store.updateGame(game)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tu as des modifications non sauvegardées. Que souhaites-tu faire ?")
        }
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingUnsavedChanges = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Retour")
                        }
                    }
                }
            }
        }
    }
    
    private var hasUnsavedChanges: Bool {
        guard let original = originalGame else { return false }
        return game.rating != original.rating ||
               game.status != original.status ||
               game.review != original.review ||
               game.notes != original.notes ||
               game.isFavorite != original.isFavorite ||
               game.isSpoiler != original.isSpoiler ||
               game.completionPercentage != original.completionPercentage ||
               game.difficulty != original.difficulty ||
               game.moodTags != original.moodTags ||
               game.priority != original.priority
    }
    
    private func loadSimilarGames() async {
        guard game.rawgId != nil else { return }
        isLoadingSimilar = true
        similarGames = await store.fetchSimilarGames(for: game)
        isLoadingSimilar = false
    }
    
    private func shareGame() {
        let text = "🎮 \(game.title) - \(game.rating > 0 ? String(repeating: "⭐", count: game.rating) : "Non noté") sur Gameboxd"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Header
struct GameDetailHeader: View {
    let game: Game
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image/Color
            if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .gbDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } placeholder: {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .frame(height: 250)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .gbDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: 250)
                .clipped()
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(height: 250)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .gbDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            // Game Info
            VStack(alignment: .leading, spacing: 8) {
                // Badges
                HStack(spacing: 8) {
                    // Platform
                    Text(game.platform)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                    
                    // Metacritic
                    if let score = game.metacriticScore {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("\(score)")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(metacriticColor(score).opacity(0.8))
                        .cornerRadius(6)
                    }
                    
                    // Status
                    if game.status != .none {
                        HStack(spacing: 4) {
                            Image(systemName: game.status.icon)
                            Text(game.status.rawValue)
                        }
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(game.status.color.opacity(0.8))
                        .cornerRadius(6)
                    }
                }
                .foregroundColor(.white)
                
                // Title
                Text(game.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                
                // Developer & Year
                HStack {
                    Text(game.developer)
                    Text("•")
                    Text(game.releaseYear)
                }
                .font(.subheadline)
                .foregroundColor(.gray)
                
                // Genres
                if !game.genres.isEmpty {
                    Text(game.genres.joined(separator: " • "))
                        .font(.caption)
                        .foregroundColor(.gbGreen)
                }
            }
            .padding()
        }
    }
    
    func metacriticColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Quick Actions Bar
struct QuickActionsBar: View {
    @Binding var game: Game
    @Binding var showingAddToList: Bool
    @Binding var showingAddSession: Bool
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Favorite
            QuickActionButton(
                icon: game.isFavorite ? "heart.fill" : "heart",
                label: "Favoris",
                color: game.isFavorite ? .red : .gray
            ) {
                game.isFavorite.toggle()
            }
            
            // Add to List
            QuickActionButton(
                icon: "list.bullet",
                label: "Listes",
                color: .blue
            ) {
                showingAddToList = true
            }
            
            // Log Session
            QuickActionButton(
                icon: "book.fill",
                label: "Journal",
                color: .orange
            ) {
                showingAddSession = true
            }
            
            // Share
            QuickActionButton(
                icon: "square.and.arrow.up",
                label: "Partager",
                color: .gbGreen
            ) {
                shareGame()
            }
        }
        .padding()
        .background(Color.gbCard)
    }
    
    private func shareGame() {
        let text = "🎮 \(game.title) - \(game.rating > 0 ? String(repeating: "⭐", count: game.rating) : "Non noté") sur Gameboxd"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Info Section
struct GameInfoSection: View {
    @Binding var game: Game
    let similarGames: [Game]
    let isLoadingSimilar: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Description
            if let description = game.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
            }
            
            // Screenshots
            if !game.screenshotURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Captures d'écran")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(game.screenshotURLs, id: \.self) { urlString in
                                if let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 250, height: 140)
                                            .cornerRadius(8)
                                            .clipped()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gbCard)
                                            .frame(width: 250, height: 140)
                                            .overlay(ProgressView())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
            }
            
            // Game Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Détails")
                    .font(.headline)
                    .foregroundColor(.white)
                
                DetailRow(label: "Développeur", value: game.developer)
                DetailRow(label: "Plateforme", value: game.platform)
                DetailRow(label: "Année de sortie", value: game.releaseYear)
                
                if let estimated = game.estimatedPlaytime, estimated > 0 {
                    DetailRow(label: "Durée estimée", value: "\(estimated)h")
                }
                
                if !game.genres.isEmpty {
                    DetailRow(label: "Genres", value: game.genres.joined(separator: ", "))
                }
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Similar Games
            if !similarGames.isEmpty || isLoadingSimilar {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Jeux similaires")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isLoadingSimilar {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(similarGames) { similar in
                                    NavigationLink(destination: GameDetailView(game: similar)) {
                                        SimilarGameCard(game: similar)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
}

struct SimilarGameCard: View {
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(game.coverColor.gradient)
                }
                .frame(width: 100, height: 130)
                .cornerRadius(8)
                .clipped()
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(width: 100, height: 130)
                    .cornerRadius(8)
            }
            
            Text(game.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}

// MARK: - Tracking Section
struct GameTrackingSection: View {
    @Binding var game: Game
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Statut")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GameStatus.allCases.filter { $0 != .none }, id: \.self) { status in
                            StatusButton(status: status, currentStatus: $game.status)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Rating
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Note globale")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if game.rating > 0 {
                        Text(ratingLabel(game.rating))
                            .font(.caption)
                            .foregroundColor(.gbGreen)
                    }
                }
                
                HStack {
                    Spacer()
                    StarRating(rating: $game.rating, editable: true, size: 36)
                    Spacer()
                }
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Sub Ratings
            VStack(alignment: .leading, spacing: 16) {
                Text("Notes détaillées")
                    .font(.headline)
                    .foregroundColor(.white)
                
                SubRatingRow(label: "Histoire", icon: "book.fill", rating: $game.subRatings.story)
                SubRatingRow(label: "Gameplay", icon: "gamecontroller.fill", rating: $game.subRatings.gameplay)
                SubRatingRow(label: "Graphismes", icon: "paintbrush.fill", rating: $game.subRatings.graphics)
                SubRatingRow(label: "Musique/Son", icon: "speaker.wave.3.fill", rating: $game.subRatings.sound)
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Progress
            VStack(alignment: .leading, spacing: 12) {
                Text("Progression")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Completion Percentage
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Complétion")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(game.completionPercentage)%")
                            .foregroundColor(.gbGreen)
                    }
                    .font(.subheadline)
                    
                    Slider(value: Binding(
                        get: { Double(game.completionPercentage) },
                        set: { game.completionPercentage = Int($0) }
                    ), in: 0...100, step: 5)
                    .tint(.gbGreen)
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Play Time
                HStack {
                    Text("Temps de jeu")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(game.formattedPlayTime)
                        .foregroundColor(.white)
                }
                .font(.subheadline)
                
                // Playthrough Count
                Stepper("Partie n°\(game.playthroughCount)", value: $game.playthroughCount, in: 1...10)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Backlog Priority (only for want to play)
            if game.status == .wantToPlay {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Priorité dans le backlog")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 10) {
                        ForEach(BacklogPriority.allCases, id: \.self) { priority in
                            Button(action: { game.priority = priority }) {
                                Text(priority.rawValue)
                                    .font(.subheadline)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(game.priority == priority ? priority.color : Color.gbDark)
                                    .foregroundColor(game.priority == priority ? .white : .gray)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
            }
            
            // Difficulty
            VStack(alignment: .leading, spacing: 12) {
                Text("Difficulté jouée")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GameDifficulty.allCases, id: \.self) { difficulty in
                            Button(action: { game.difficulty = difficulty }) {
                                Text(difficulty.rawValue)
                                    .font(.caption)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(game.difficulty == difficulty ? Color.gbGreen : Color.gbDark)
                                    .foregroundColor(game.difficulty == difficulty ? .gbDark : .gray)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
        }
        .padding()
    }
    
    func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "Mauvais"
        case 2: return "Moyen"
        case 3: return "Bon"
        case 4: return "Excellent"
        case 5: return "Chef d'œuvre"
        default: return ""
        }
    }
}

struct SubRatingRow: View {
    let label: String
    let icon: String
    @Binding var rating: Int
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gbGreen)
                .frame(width: 25)
            
            Text(label)
                .foregroundColor(.gray)
            
            Spacer()
            
            StarRating(rating: $rating, editable: true, size: 18)
        }
    }
}

// MARK: - Notes Section
struct GameNotesSection: View {
    @Binding var game: Game
    @Binding var showingSpoiler: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Mood Tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Ressenti")
                    .font(.headline)
                    .foregroundColor(.white)
                
                FlowLayout(spacing: 8) {
                    ForEach(MoodTag.allCases, id: \.self) { tag in
                        Button(action: {
                            if game.moodTags.contains(tag) {
                                game.moodTags.removeAll { $0 == tag }
                            } else {
                                game.moodTags.append(tag)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: tag.icon)
                                Text(tag.rawValue)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(game.moodTags.contains(tag) ? tag.color.opacity(0.3) : Color.gbDark)
                            .foregroundColor(game.moodTags.contains(tag) ? tag.color : .gray)
                            .cornerRadius(20)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Review
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Critique")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle(isOn: $game.isSpoiler) {
                        Label("Spoiler", systemImage: "eye.slash")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(game.isSpoiler ? .orange : .gray)
                }
                
                TextField("Écris ta critique du jeu...", text: $game.review, axis: .vertical)
                    .padding()
                    .background(Color.gbDark)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .lineLimit(4...10)
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Personal Notes
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes personnelles")
                    .font(.headline)
                    .foregroundColor(.white)
                
                TextField("Notes privées (astuces, rappels...)", text: $game.notes, axis: .vertical)
                    .padding()
                    .background(Color.gbDark)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .lineLimit(3...6)
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
            
            // Dates
            VStack(alignment: .leading, spacing: 12) {
                Text("Dates")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Started Date
                DatePicker(
                    "Commencé le",
                    selection: Binding(
                        get: { game.startedDate ?? Date() },
                        set: { game.startedDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .tint(.gbGreen)
                
                // Completed Date (only if completed)
                if game.status == .completed || game.status == .platinum {
                    DatePicker(
                        "Terminé le",
                        selection: Binding(
                            get: { game.completedDate ?? Date() },
                            set: { game.completedDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .tint(.gbGreen)
                }
            }
            .padding()
            .background(Color.gbCard)
            .cornerRadius(12)
        }
        .padding()
    }
}

// MARK: - Save Button
struct SaveButton: View {
    let game: Game
    let isInLibrary: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isInLibrary ? "Mettre à jour" : "Ajouter à ma collection")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gbGreen)
            .foregroundColor(.gbDark)
            .cornerRadius(12)
        }
    }
}

// MARK: - Add to List Sheet
struct AddToListSheet: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(store.gameLists) { list in
                Button(action: {
                    store.addGameToList(game, list: list)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: list.iconName)
                            .foregroundColor(list.color)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(list.name)
                                .foregroundColor(.white)
                            Text("\(list.gameIds.count) jeux")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if list.gameIds.contains(game.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.gbGreen)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Ajouter à une liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Status Button
struct StatusButton: View {
    let status: GameStatus
    @Binding var currentStatus: GameStatus
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                currentStatus = status
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.title3)
                Text(status.rawValue)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 75, height: 60)
            .background(currentStatus == status ? status.color.opacity(0.25) : Color.gbDark)
            .foregroundColor(currentStatus == status ? status.color : .gray)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(currentStatus == status ? status.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        GameDetailView(game: Game(
            title: "The Legend of Zelda: TOTK",
            developer: "Nintendo",
            platform: "Switch",
            releaseYear: "2023",
            coverColor: .green,
            rating: 5,
            status: .playing,
            review: "Une liberté totale",
            playTime: "45h",
            genres: ["Action", "Adventure"]
        ))
        .environmentObject(GameStore())
    }
}