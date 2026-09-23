//
//  LibraryView.swift
//  Gameboxd
//
//  Game collection view with filters and sorting
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedFilter: GameStatus = .playing
    @State private var showingStats = false
    @State private var sortOption: SortOption = .title
    @State private var showingSortMenu = false
    @State private var viewStyle: ViewStyle = .shelf
    @Namespace private var shelfNamespace
    @State private var showingAdvancedFilters = false
    @State private var gameToDelete: Game? = nil
    @State private var showingDeleteConfirm = false
    @State private var showingComparison = false
    
    // Advanced Filters
    @State private var selectedPlatform: String? = nil
    @State private var selectedGenre: String? = nil
    @State private var minimumRating: Int = 0
    @State private var selectedYear: String? = nil
    
    enum SortOption: String, CaseIterable {
        case title = "Titre"
        case rating = "Note"
        case recent = "Récent"
        case playtime = "Temps de jeu"
        case priority = "Priorité"
        case year = "Année"
    }
    
    enum ViewStyle {
        case shelf, grid, list
    }
    
    // Get unique platforms
    var availablePlatforms: [String] {
        Array(Set(store.myGames.map { $0.platform })).sorted()
    }
    
    // Get unique genres
    var availableGenres: [String] {
        Array(Set(store.myGames.flatMap { $0.genres })).sorted()
    }
    
    // Get unique years
    var availableYears: [String] {
        Array(Set(store.myGames.map { $0.releaseYear })).sorted(by: >)
    }
    
    // Active filters count
    var activeFiltersCount: Int {
        var count = 0
        if selectedPlatform != nil { count += 1 }
        if selectedGenre != nil { count += 1 }
        if minimumRating > 0 { count += 1 }
        if selectedYear != nil { count += 1 }
        return count
    }
    
    // Filtre dynamique des jeux
    var filteredGames: [Game] {
        filteredAndSorted(store.myGames.filter { $0.status == selectedFilter })
    }

    /// The shelf shows every status, grouped by plank; advanced filters and sort still apply.
    var shelfGames: [Game] {
        filteredAndSorted(store.myGames)
    }

    private func filteredAndSorted(_ games: [Game]) -> [Game] {
        var filtered = games
        
        // Apply advanced filters
        if let platform = selectedPlatform {
            filtered = filtered.filter { $0.platform == platform }
        }
        
        if let genre = selectedGenre {
            filtered = filtered.filter { $0.genres.contains(genre) }
        }
        
        if minimumRating > 0 {
            filtered = filtered.filter { $0.rating >= minimumRating }
        }
        
        if let year = selectedYear {
            filtered = filtered.filter { $0.releaseYear == year }
        }
        
        // Apply sorting
        switch sortOption {
        case .title:
            return filtered.sorted { $0.title < $1.title }
        case .rating:
            return filtered.sorted { $0.rating > $1.rating }
        case .recent:
            return filtered.sorted { ($0.startedDate ?? .distantPast) > ($1.startedDate ?? .distantPast) }
        case .playtime:
            return filtered.sorted { $0.playTimeMinutes > $1.playTimeMinutes }
        case .priority:
            return filtered.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
        case .year:
            return filtered.sorted { $0.releaseYear > $1.releaseYear }
        }
    }
    
    func clearAllFilters() {
        selectedPlatform = nil
        selectedGenre = nil
        minimumRating = 0
        selectedYear = nil
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats rapides (collapsible)
                if showingStats {
                    StatsHeaderView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Barre de filtres avec compteur (the shelf groups by status itself)
                if viewStyle != .shelf {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach([GameStatus.playing, GameStatus.wantToPlay, GameStatus.completed, GameStatus.platinum, GameStatus.shelved], id: \.self) { status in
                            FilterButton(
                                status: status,
                                count: store.gamesCount(for: status),
                                isSelected: selectedFilter == status
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedFilter = status
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                }
                
                // Sort and View Options Bar
                HStack {
                    // Advanced Filters Button
                    Button(action: { showingAdvancedFilters = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filtres")
                            if activeFiltersCount > 0 {
                                Text("\(activeFiltersCount)")
                                    .font(DS.Typography.label)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accent)
                                    .foregroundStyle(Color.gbDark)
                                    .clipShape(Capsule())
                            }
                        }
                        .font(DS.Typography.caption)
                        .foregroundStyle(activeFiltersCount > 0 ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(Color.gbCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .stroke(Color.gbBorder, lineWidth: 1)
                        )
                    }

                    // Sort Menu
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(action: { sortOption = option }) {
                                HStack {
                                    Text(option.rawValue)
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOption.rawValue)
                        }
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(Color.gbCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .stroke(Color.gbBorder, lineWidth: 1)
                        )
                    }

                    Spacer()

                    let count = viewStyle == .shelf ? shelfGames.count : filteredGames.count
                    Text("\(count) jeu\(count > 1 ? "x" : "")")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    // View Style Toggle
                    HStack(spacing: 0) {
                        Button(action: { viewStyle = .shelf }) {
                            Image(systemName: "books.vertical")
                                .foregroundStyle(viewStyle == .shelf ? Color.accent : Color.textSecondary)
                                .padding(8)
                        }
                        .accessibilityLabel("Affichage en étagère")

                        Button(action: { viewStyle = .grid }) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundStyle(viewStyle == .grid ? Color.accent : Color.textSecondary)
                                .padding(8)
                        }
                        .accessibilityLabel("Affichage en grille")

                        Button(action: { viewStyle = .list }) {
                            Image(systemName: "list.bullet")
                                .foregroundStyle(viewStyle == .list ? Color.accent : Color.textSecondary)
                                .padding(8)
                        }
                        .accessibilityLabel("Affichage en liste")
                    }
                    .background(Color.gbCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(Color.gbBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Active Filters Pills
                if activeFiltersCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let platform = selectedPlatform {
                                FilterPill(label: platform, onRemove: { selectedPlatform = nil })
                            }
                            if let genre = selectedGenre {
                                FilterPill(label: genre, onRemove: { selectedGenre = nil })
                            }
                            if minimumRating > 0 {
                                FilterPill(label: "★ \(minimumRating)+", onRemove: { minimumRating = 0 })
                            }
                            if let year = selectedYear {
                                FilterPill(label: year, onRemove: { selectedYear = nil })
                            }

                            Button(action: clearAllFilters) {
                                Text("Tout effacer")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color(hex: "D9695A"))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    .background(Color.gbDark)
                }
                
                // Grille de contenu
                ScrollView {
                    let games = viewStyle == .shelf ? shelfGames : filteredGames
                    if games.isEmpty && viewStyle == .shelf {
                        EmptyState(icon: "books.vertical", title: "Ton étagère est vide", message: "Cherche un jeu dans l'onglet Recherche pour poser ta première boîte.")
                            .frame(minHeight: 420)
                    } else if viewStyle == .shelf {
                        ShelfLibrary(games: games, namespace: shelfNamespace) { game in
                            GameContextMenu(game: game) { g in
                                gameToDelete = g
                                showingDeleteConfirm = true
                            }
                        }
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, 110)
                    } else if games.isEmpty {
                        EmptyStateView(status: selectedFilter)
                    } else {
                        if viewStyle == .grid {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.sm)], spacing: DS.Spacing.md) {
                                ForEach(games) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        GameCard(game: game)
                                    }
                                    .contextMenu {
                                        GameContextMenu(game: game) { g in
                                            gameToDelete = g
                                            showingDeleteConfirm = true
                                        }
                                    }
                                }
                            }
                            .padding()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(games) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        GameListRow(game: game)
                                    }
                                    .contextMenu {
                                        GameContextMenu(game: game) { g in
                                            gameToDelete = g
                                            showingDeleteConfirm = true
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Ma collection")
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(colors: [Shelf.wallTop, Color.gbDark], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingComparison = true }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(Color.accent)
                    }
                    .disabled(store.myGames.count < 2)
                    .accessibilityLabel("Comparer deux jeux")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showingStats.toggle()
                        }
                    }) {
                        Image(systemName: showingStats ? "chart.bar.fill" : "chart.bar")
                            .foregroundStyle(Color.accent)
                    }
                    .accessibilityLabel(showingStats ? "Masquer les statistiques" : "Afficher les statistiques")
                }
            }
            .sheet(isPresented: $showingComparison) {
                GameComparisonView()
            }
            .sheet(isPresented: $showingAdvancedFilters) {
                AdvancedFiltersSheet(
                    selectedPlatform: $selectedPlatform,
                    selectedGenre: $selectedGenre,
                    minimumRating: $minimumRating,
                    selectedYear: $selectedYear,
                    availablePlatforms: availablePlatforms,
                    availableGenres: availableGenres,
                    availableYears: Array(availableYears)
                )
            }
            .alert("Supprimer ce jeu ?", isPresented: $showingDeleteConfirm) {
                Button("Annuler", role: .cancel) { gameToDelete = nil }
                Button("Supprimer", role: .destructive) {
                    if let game = gameToDelete {
                        store.deleteGame(game)
                    }
                    gameToDelete = nil
                }
            } message: {
                Text("\(gameToDelete?.title ?? "Ce jeu") sera définitivement supprimé de ta bibliothèque.")
            }
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        TagPill(label: label, isSelected: true, onRemove: onRemove)
    }
}

// MARK: - Advanced Filters Sheet
struct AdvancedFiltersSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPlatform: String?
    @Binding var selectedGenre: String?
    @Binding var minimumRating: Int
    @Binding var selectedYear: String?
    
    let availablePlatforms: [String]
    let availableGenres: [String]
    let availableYears: [String]
    
    var body: some View {
        NavigationStack {
            List {
                // Platform Filter
                Section("Plateforme") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "Toutes", isSelected: selectedPlatform == nil) {
                                selectedPlatform = nil
                            }
                            ForEach(availablePlatforms, id: \.self) { platform in
                                FilterChip(label: platform, isSelected: selectedPlatform == platform) {
                                    selectedPlatform = platform
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Genre Filter
                Section("Genre") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "Tous", isSelected: selectedGenre == nil) {
                                selectedGenre = nil
                            }
                            ForEach(availableGenres, id: \.self) { genre in
                                FilterChip(label: genre, isSelected: selectedGenre == genre) {
                                    selectedGenre = genre
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Rating Filter
                Section("Note minimale") {
                    HStack {
                        ForEach(0...5, id: \.self) { rating in
                            Button(action: { minimumRating = rating }) {
                                VStack(spacing: 4) {
                                    if rating == 0 {
                                        Image(systemName: "star.slash")
                                            .font(DS.Typography.title)
                                    } else {
                                        HStack(spacing: 1) {
                                            ForEach(1...rating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(DS.Typography.micro)
                                            }
                                        }
                                    }
                                    Text(rating == 0 ? "Tous" : "\(rating)+")
                                        .font(DS.Typography.micro)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(minimumRating == rating ? Color.accent : Color.gbCard)
                                .foregroundStyle(minimumRating == rating ? Color.gbDark : Color.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                        .stroke(minimumRating == rating ? Color.clear : Color.gbBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Year Filter
                Section("Année de sortie") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "Toutes", isSelected: selectedYear == nil) {
                                selectedYear = nil
                            }
                            ForEach(availableYears, id: \.self) { year in
                                FilterChip(label: year, isSelected: selectedYear == year) {
                                    selectedYear = year
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Filtres avancés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Réinitialiser") {
                        selectedPlatform = nil
                        selectedGenre = nil
                        minimumRating = 0
                        selectedYear = nil
                    }
                    .foregroundStyle(Color(hex: "D9695A"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Appliquer") { dismiss() }
                        .foregroundStyle(Color.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TagPill(label: label, isSelected: isSelected)
        }
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let status: GameStatus
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(DS.Typography.caption)

                Text(status.rawValue)
                    .font(DS.Typography.bodyMedium)

                if count > 0 {
                    Text("\(count)")
                        .font(DS.Typography.label)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? status.color.opacity(0.3) : Color.gbSurface2)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? status.color : Color.textSecondary)
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.sm)
            .background(isSelected ? status.color.opacity(0.16) : Color.gbCard)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? status.color.opacity(0.4) : Color.gbBorder, lineWidth: 1)
            )
        }
        .accessibilityLabel("\(status.rawValue), \(count) jeux")
    }
}

// MARK: - Game List Row
struct GameListRow: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Cover
            Group {
                if let url = game.artURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                } else {
                    Rectangle().fill(game.coverColor.gradient)
                }
            }
            .frame(width: 44, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .stroke(Color.gbBorder, lineWidth: 1)
            )

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(game.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    if game.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color(hex: "D9695A"))
                    }
                }

                Text(game.developer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: 8) {
                    // Rating
                    if game.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...game.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(Color.accent)
                    }

                    // Play time
                    if game.playTimeMinutes > 0 {
                        Text(game.formattedPlayTime)
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.textTertiary)
                    }

                    // Completion
                    if game.completionPercentage > 0 {
                        Text("\(game.completionPercentage)%")
                            .font(DS.Typography.label)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accent.opacity(0.16))
                            .foregroundStyle(Color.accent)
                            .clipShape(Capsule())
                    }
                }

                // Mood tags
                if !game.moodTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(game.moodTags.prefix(3), id: \.self) { tag in
                            Image(systemName: tag.icon)
                                .font(DS.Typography.micro)
                                .foregroundStyle(tag.color)
                        }
                    }
                }
            }

            Spacer()

            // Priority indicator for backlog
            if game.status == .wantToPlay {
                Circle()
                    .fill(game.priority.color)
                    .frame(width: 10, height: 10)
            }

            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .cardStyle()
    }
}

// MARK: - Game Context Menu
struct GameContextMenu: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    var onDelete: ((Game) -> Void)? = nil
    
    var body: some View {
        Group {
            // Quick status change
            Menu("Changer le statut") {
                ForEach(GameStatus.allCases.filter { $0 != .none }, id: \.self) { status in
                    Button(action: {
                        var updatedGame = game
                        updatedGame.status = status
                        if status == .completed || status == .platinum {
                            updatedGame.completedDate = Date()
                        }
                        store.updateGame(updatedGame)
                    }) {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }
            }
            
            // Favorite toggle
            Button(action: {
                store.toggleFavorite(game)
            }) {
                Label(game.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                      systemImage: game.isFavorite ? "heart.slash" : "heart")
            }
            
            // Add to list
            Menu("Ajouter à une liste") {
                ForEach(store.gameLists) { list in
                    Button(action: {
                        store.addGameToList(game, list: list)
                    }) {
                        Label(list.name, systemImage: list.iconName)
                    }
                }
            }
            
            Divider()
            
            // Delete
            Button(role: .destructive, action: {
                onDelete?(game)
            }) {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }
}

// Vue des statistiques
struct StatsHeaderView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            MetricCard(value: "\(store.totalGames)", label: "Jeux", icon: "gamecontroller.fill", tint: Color(hex: "8EA9C9"), compact: true)
            MetricCard(value: store.totalPlayTimeFormatted, label: "Joué", icon: "clock.fill", tint: Color(hex: "E3A24C"), compact: true)
            MetricCard(value: String(format: "%.1f", store.averageRating), label: "Moyenne", icon: "star.fill", tint: .accent, compact: true)
            MetricCard(value: "\(store.gamesCount(for: .completed) + store.gamesCount(for: .platinum))", label: "Finis", icon: "checkmark.circle.fill", tint: Color(hex: "E3A24C"), compact: true)
        }
        .padding(DS.Spacing.md)
        .background(Color.gbDark)
    }
}

// Vue pour l'état vide
struct EmptyStateView: View {
    let status: GameStatus

    var body: some View {
        EmptyState(icon: status.icon, title: "Aucun jeu dans « \(status.rawValue) »", message: emptyMessage)
            .frame(height: 300)
    }

    var emptyMessage: String {
        switch status {
        case .playing:
            return "Lance-toi dans une nouvelle aventure !"
        case .wantToPlay:
            return "Ajoute des jeux depuis la recherche"
        case .completed:
            return "Termine des jeux pour les voir ici"
        case .platinum:
            return "Les jeux platinés apparaîtront ici"
        case .shelved:
            return "Les jeux abandonnés seront ici"
        case .none:
            return ""
        }
    }
}

// MARK: - Preview
#Preview {
    LibraryView()
        .environmentObject(GameStore())
}