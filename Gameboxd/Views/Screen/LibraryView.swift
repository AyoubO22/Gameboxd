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
    @State private var viewStyle: ViewStyle = .grid
    @State private var showingAdvancedFilters = false
    @State private var gameToDelete: Game? = nil
    @State private var showingDeleteConfirm = false
    
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
        case grid, list
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
        var filtered = store.myGames.filter { $0.status == selectedFilter }
        
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
                
                // Barre de filtres avec compteur
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
                .background(Color.gbDark)
                
                // Sort and View Options Bar
                HStack {
                    // Advanced Filters Button
                    Button(action: { showingAdvancedFilters = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filtres")
                            if activeFiltersCount > 0 {
                                Text("\(activeFiltersCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gbGreen)
                                    .foregroundColor(.gbDark)
                                    .cornerRadius(10)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(activeFiltersCount > 0 ? .gbGreen : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gbCard)
                        .cornerRadius(8)
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
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gbCard)
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    let count = filteredGames.count
                    Text("\(count) jeu\(count > 1 ? "x" : "")")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // View Style Toggle
                    HStack(spacing: 0) {
                        Button(action: { viewStyle = .grid }) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(viewStyle == .grid ? .gbGreen : .gray)
                                .padding(8)
                        }
                        
                        Button(action: { viewStyle = .list }) {
                            Image(systemName: "list.bullet")
                                .foregroundColor(viewStyle == .list ? .gbGreen : .gray)
                                .padding(8)
                        }
                    }
                    .background(Color.gbCard)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gbDark)
                
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
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    .background(Color.gbDark)
                }
                
                // Grille de contenu
                ScrollView {
                    let games = filteredGames
                    if games.isEmpty {
                        EmptyStateView(status: selectedFilter)
                    } else {
                        if viewStyle == .grid {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
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
                .background(Color.gbDark)
            }
            .navigationTitle("Gameboxd")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.gbDark.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showingStats.toggle()
                        }
                    }) {
                        Image(systemName: showingStats ? "chart.bar.fill" : "chart.bar")
                            .foregroundColor(.gbGreen)
                    }
                    .accessibilityLabel(showingStats ? "Masquer les statistiques" : "Afficher les statistiques")
                }
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
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gbGreen.opacity(0.2))
        .foregroundColor(.gbGreen)
        .cornerRadius(20)
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
                                            .font(.title2)
                                    } else {
                                        HStack(spacing: 1) {
                                            ForEach(1...rating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                    Text(rating == 0 ? "Tous" : "\(rating)+")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(minimumRating == rating ? Color.gbGreen : Color.gbCard)
                                .foregroundColor(minimumRating == rating ? .gbDark : .gray)
                                .cornerRadius(8)
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
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Appliquer") { dismiss() }
                        .foregroundColor(.gbGreen)
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
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.gbGreen : Color.gbCard)
                .foregroundColor(isSelected ? .gbDark : .gray)
                .cornerRadius(20)
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
                    .font(.caption)
                
                Text(status.rawValue)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                        .cornerRadius(10)
                }
            }
            .font(.subheadline)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(isSelected ? status.color : Color.gbCard)
            .foregroundColor(isSelected ? .white : .gray)
            .cornerRadius(20)
        }
        .accessibilityLabel("\(status.rawValue), \(count) jeux")
    }
}

// MARK: - Game List Row
struct GameListRow: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(game.coverColor.gradient)
                }
                .frame(width: 60, height: 80)
                .cornerRadius(8)
                .clipped()
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(game.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if game.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Text(game.developer)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 8) {
                    // Rating
                    if game.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...game.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundColor(.gbGreen)
                    }
                    
                    // Play time
                    if game.playTimeMinutes > 0 {
                        Text(game.formattedPlayTime)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Completion
                    if game.completionPercentage > 0 {
                        Text("\(game.completionPercentage)%")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gbGreen.opacity(0.2))
                            .foregroundColor(.gbGreen)
                            .cornerRadius(4)
                    }
                }
                
                // Mood tags
                if !game.moodTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(game.moodTags.prefix(3), id: \.self) { tag in
                            Image(systemName: tag.icon)
                                .font(.caption2)
                                .foregroundColor(tag.color)
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
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.gbCard)
        .cornerRadius(12)
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
        HStack(spacing: 16) {
            StatItem(value: "\(store.totalGames)", label: "Jeux", icon: "gamecontroller.fill", color: .blue)
            StatItem(value: store.totalPlayTimeFormatted, label: "Joué", icon: "clock.fill", color: .orange)
            StatItem(value: String(format: "%.1f", store.averageRating), label: "Moyenne", icon: "star.fill", color: .yellow)
            StatItem(value: "\(store.gamesCount(for: .completed) + store.gamesCount(for: .platinum))", label: "Finis", icon: "checkmark.circle.fill", color: .green)
        }
        .padding()
        .background(Color.gbCard)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// Vue pour l'état vide
struct EmptyStateView: View {
    let status: GameStatus
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: status.icon)
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("Aucun jeu dans '\(status.rawValue)'")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
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