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
    @State private var showingComparison = false
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
                PillSegmentedControl(options: [0, 1, 2], selection: $selectedTab) {
                    ["Infos", "Suivi", "Notes"][$0]
                }
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

                        Button(action: { showingComparison = true }) {
                            Label("Comparer avec…", systemImage: "arrow.left.arrow.right")
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
                        .foregroundStyle(Color.accent)
                }
            }
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListSheet(game: game)
        }
        .sheet(isPresented: $showingComparison) {
            GameComparisonView(preselectedGame: game)
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
                // Opened from Discover/Search/similar: show the owned copy, not the RAWG one.
                if let owned = store.libraryGame(for: game) {
                    game = owned
                }
                originalGame = game
            }
        }
        .onReceive(store.$myGames) { games in
            // Sessions and the toolbar favorite button change the stored game directly.
            // Pull those fields in so Save doesn't write the stale values back.
            guard let stored = games.first(where: { $0.id == game.id }), var original = originalGame else { return }
            if stored.playTimeMinutes != original.playTimeMinutes {
                game.playTimeMinutes = stored.playTimeMinutes
                original.playTimeMinutes = stored.playTimeMinutes
            }
            if stored.isFavorite != original.isFavorite {
                game.isFavorite = stored.isFavorite
                original.isFavorite = stored.isFavorite
            }
            originalGame = original
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
        return game != original
    }
    
    private func loadSimilarGames() async {
        guard game.rawgId != nil else { return }
        isLoadingSimilar = true
        similarGames = await store.fetchSimilarGames(for: game)
        isLoadingSimilar = false
    }
    
    private func shareGame() {
        let text = "\(game.title) - \(game.rating > 0 ? String(repeating: "★", count: game.rating) : "Non noté") sur Gameboxd"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
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
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    // Metacritic
                    if let score = game.metacriticScore {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("\(score)")
                        }
                        .font(DS.Typography.label)
                        .foregroundStyle(DS.Colors.score(score))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(DS.Colors.score(score).opacity(0.16))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(DS.Colors.score(score).opacity(0.4), lineWidth: 1))
                    }

                    // Status
                    if game.status != .none {
                        TagPill(label: game.status.rawValue, icon: game.status.icon, isSelected: true, tint: game.status.color)
                    }
                }

                // Title
                Text(game.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(Color.textPrimary)
                    .shadow(radius: 2)

                // Developer & Year
                HStack {
                    Text(game.developer)
                    Text("•")
                    Text(game.releaseYear)
                }
                .font(DS.Typography.body)
                .foregroundStyle(Color.textSecondary)

                // Genres
                if !game.genres.isEmpty {
                    Text(game.genres.joined(separator: " • "))
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.accent)
                }
            }
            .padding()
        }
    }
}

// MARK: - Quick Actions Bar
struct QuickActionsBar: View {
    @Binding var game: Game
    @Binding var showingAddToList: Bool
    @Binding var showingAddSession: Bool
    @EnvironmentObject var store: GameStore
    @Environment(TimerManager.self) private var timerManager

    private var isTimingThisGame: Bool {
        timerManager.isRunning && timerManager.activeGame?.id == game.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Favorite
            QuickActionButton(
                icon: game.isFavorite ? "heart.fill" : "heart",
                label: "Favoris",
                color: game.isFavorite ? Color(hex: "FF5C5C") : Color.textPrimary
            ) {
                game.isFavorite.toggle()
            }

            // Add to List
            QuickActionButton(icon: "list.bullet", label: "Listes", color: .textPrimary) {
                showingAddToList = true
            }

            // Log Session
            QuickActionButton(icon: "book.fill", label: "Journal", color: .textPrimary) {
                showingAddSession = true
            }

            // Live play timer (sharing stays in the toolbar menu)
            QuickActionButton(
                icon: isTimingThisGame ? "timer.circle.fill" : "timer",
                label: isTimingThisGame ? "En cours" : "Chrono",
                color: .accent
            ) {
                timerManager.start(game: game)
            }
            // One session at a time, and only for games in the library.
            .disabled(timerManager.isRunning || !store.myGames.contains { $0.id == game.id })
        }
        .padding()
        .background(Color.gbDark)
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
                ZStack {
                    Circle()
                        .fill(Color.gbCard)
                        .overlay(Circle().stroke(Color.gbBorder, lineWidth: 1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Info Section
struct GameInfoSection: View {
    @Binding var game: Game
    let similarGames: [Game]
    let isLoadingSimilar: Bool
    @State private var enrichedData: EnrichedGameData?
    @State private var isLoadingEnriched = false

    var body: some View {
        VStack(spacing: 20) {
            // Enriched Data: Playtime & Metacritic
            EnrichedDataSection(enrichedData: enrichedData, isLoading: isLoadingEnriched)

            // Description
            if let description = game.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Description")

                    Text(description)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }

            // Screenshots
            if !game.screenshotURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Captures d'écran")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(game.screenshotURLs, id: \.self) { urlString in
                                if let url = URL(string: urlString) {
                                    CachedAsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 250, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                            .clipped()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                            .fill(Color.gbSurface2)
                                            .frame(width: 250, height: 140)
                                            .overlay(ProgressView())
                                    }
                                }
                            }
                        }
                    }
                }
                .cardStyle()
            }

            // Game Details
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Détails")

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
            .cardStyle()

            // Similar Games
            if !similarGames.isEmpty || isLoadingSimilar {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Jeux similaires")

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
                .cardStyle()
            }
        }
        .padding()
        .task {
            guard enrichedData == nil, !isLoadingEnriched else { return }
            isLoadingEnriched = true
            enrichedData = await GameEnrichmentService.shared.enrich(
                gameId: game.id,
                title: game.title
            )
            isLoadingEnriched = false
        }
    }
}

// MARK: - Enriched Data Section
struct EnrichedDataSection: View {
    let enrichedData: EnrichedGameData?
    let isLoading: Bool

    var body: some View {
        if isLoading {
            // Skeleton placeholders
            HStack(spacing: 12) {
                SkeletonBox(width: .infinity, height: 70)
                SkeletonBox(width: .infinity, height: 70)
            }
            .cardStyle()
        } else if let data = enrichedData,
                  data.hltbMainStory != nil || data.hltbCompletionist != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Color.accent)
                    Text("Durée (HowLongToBeat)")
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.textPrimary)
                }

                HStack(spacing: 16) {
                    if let main = data.hltbMainStory {
                        MetricCard(value: String(format: "%.0fh", main), label: "Histoire", icon: "book.fill", tint: Color(hex: "5B8DEF"), compact: true)
                    }
                    if let comp = data.hltbCompletionist {
                        MetricCard(value: String(format: "%.0fh", comp), label: "Complétionniste", icon: "star.fill", tint: Color(hex: "B98EFF"), compact: true)
                    }
                }
            }
            .cardStyle()
        }
        // If enrichedData is nil and not loading, show nothing (silent failure)
    }
}

// MARK: - Enriched Subviews

struct SkeletonBox: View {
    let width: CGFloat
    let height: CGFloat
    @State private var isAnimating = false

    init(width: CGFloat = .infinity, height: CGFloat) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
            .fill(Color.gbSurface2)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .frame(width: width == .infinity ? nil : width, height: height)
            .opacity(isAnimating ? 0.4 : 0.8)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.textPrimary)
        }
        .font(DS.Typography.body)
    }
}

struct SimilarGameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                } else {
                    Rectangle().fill(game.coverColor.gradient)
                }
            }
            .frame(width: 100, height: 133)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.gbBorder, lineWidth: 1)
            )

            Text(game.title)
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textPrimary)
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
                SectionHeader(title: "Statut")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GameStatus.allCases.filter { $0 != .none }, id: \.self) { status in
                            StatusButton(status: status, currentStatus: $game.status)
                        }
                    }
                }
            }
            .cardStyle()

            // Rating
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Note globale")
                    if game.rating > 0 {
                        Text(ratingLabel(game.rating))
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.accent)
                    }
                }

                HStack {
                    Spacer()
                    StarRating(rating: $game.rating, editable: true, size: 36)
                    Spacer()
                }
            }
            .cardStyle()

            // Sub Ratings
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Notes détaillées")

                SubRatingRow(label: "Histoire", icon: "book.fill", rating: $game.subRatings.story)
                SubRatingRow(label: "Gameplay", icon: "gamecontroller.fill", rating: $game.subRatings.gameplay)
                SubRatingRow(label: "Graphismes", icon: "paintbrush.fill", rating: $game.subRatings.graphics)
                SubRatingRow(label: "Musique/Son", icon: "speaker.wave.3.fill", rating: $game.subRatings.sound)
            }
            .cardStyle()

            // Progress
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Progression")

                // Completion Percentage
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Complétion")
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("\(game.completionPercentage)%")
                            .foregroundStyle(Color.accent)
                    }
                    .font(DS.Typography.body)

                    Slider(value: Binding(
                        get: { Double(game.completionPercentage) },
                        set: { game.completionPercentage = Int($0) }
                    ), in: 0...100, step: 5)
                    .tint(.accent)
                }

                Divider().overlay(Color.gbBorder)

                // Play Time
                HStack {
                    Text("Temps de jeu")
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(game.formattedPlayTime)
                        .foregroundStyle(Color.textPrimary)
                }
                .font(DS.Typography.body)

                // Playthrough Count
                Stepper("Partie n°\(game.playthroughCount)", value: $game.playthroughCount, in: 1...10)
                    .foregroundStyle(Color.textPrimary)
                    .tint(.accent)
            }
            .cardStyle()

            // Backlog Priority (only for want to play)
            if game.status == .wantToPlay {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Priorité dans le backlog")

                    HStack(spacing: 10) {
                        ForEach(BacklogPriority.allCases, id: \.self) { priority in
                            Button(action: { game.priority = priority }) {
                                Text(priority.rawValue)
                                    .font(DS.Typography.body)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(game.priority == priority ? priority.color.opacity(0.16) : Color.gbSurface2)
                                    .foregroundStyle(game.priority == priority ? priority.color : Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                            .stroke(game.priority == priority ? priority.color.opacity(0.4) : Color.clear, lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
                .cardStyle()
            }

            // Difficulty
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Difficulté jouée")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GameDifficulty.allCases, id: \.self) { difficulty in
                            Button(action: { game.difficulty = difficulty }) {
                                TagPill(label: difficulty.rawValue, isSelected: game.difficulty == difficulty)
                            }
                        }
                    }
                }
            }
            .cardStyle()
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
                .foregroundStyle(Color.accent)
                .frame(width: 25)

            Text(label)
                .foregroundStyle(Color.textSecondary)

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
                SectionHeader(title: "Ressenti")

                FlowLayout(spacing: 8) {
                    ForEach(MoodTag.allCases, id: \.self) { tag in
                        Button(action: {
                            if game.moodTags.contains(tag) {
                                game.moodTags.removeAll { $0 == tag }
                            } else {
                                game.moodTags.append(tag)
                            }
                        }) {
                            TagPill(label: tag.rawValue, icon: tag.icon, isSelected: game.moodTags.contains(tag), tint: tag.color)
                        }
                    }
                }
            }
            .cardStyle()

            // Review
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Critique")

                    Toggle(isOn: $game.isSpoiler) {
                        Label("Spoiler", systemImage: "eye.slash")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(game.isSpoiler ? Color(hex: "FF8A3D") : Color.textSecondary)
                }

                TextField("Écris ta critique du jeu...", text: $game.review, axis: .vertical)
                    .padding()
                    .background(Color.gbSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(4...10)
            }
            .cardStyle()

            // Personal Notes
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Notes personnelles")

                TextField("Notes privées (astuces, rappels...)", text: $game.notes, axis: .vertical)
                    .padding()
                    .background(Color.gbSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3...6)
            }
            .cardStyle()

            // Dates
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Dates")

                // Started Date
                DatePicker(
                    "Commencé le",
                    selection: Binding(
                        get: { game.startedDate ?? Date() },
                        set: { game.startedDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .tint(.accent)
                .foregroundStyle(Color.textSecondary)

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
                    .tint(.accent)
                    .foregroundStyle(Color.textSecondary)
                }
            }
            .cardStyle()
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
        PrimaryButton(
            title: isInLibrary ? "Mettre à jour" : "Ajouter à ma collection",
            icon: isInLibrary ? "checkmark.circle.fill" : "plus.circle.fill",
            action: action
        )
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
                            .foregroundStyle(list.color)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
                            Text(list.name)
                                .foregroundStyle(Color.textPrimary)
                            Text("\(list.gameIds.count) jeux")
                                .font(DS.Typography.label)
                                .foregroundStyle(Color.textTertiary)
                        }

                        Spacer()

                        if list.gameIds.contains(game.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accent)
                        }
                    }
                }
                .listRowBackground(Color.gbCard)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Ajouter à une liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
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
            .background(currentStatus == status ? status.color.opacity(0.16) : Color.gbSurface2)
            .foregroundStyle(currentStatus == status ? status.color : Color.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(currentStatus == status ? status.color.opacity(0.4) : Color.clear, lineWidth: 1)
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