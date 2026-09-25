//
//  RecommendationsView.swift
//  Gameboxd
//
//  Personalized game recommendations based on user preferences
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var store: GameStore
    @State private var recommendations: [RecommendationSection] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                LoadingRecommendationsView()
            } else {
                LazyVStack(spacing: 24) {
                    ForEach(recommendations) { section in
                        RecommendationSectionView(section: section)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Pour toi")
        .task {
            // Recommendations are built from Discover data; fetch it if Discover
            // hasn't been opened yet this session.
            if store.trendingGames.isEmpty && store.topRated.isEmpty {
                await store.loadDiscoverData()
            }
            generateRecommendations()
        }
        .refreshable {
            await refreshRecommendations()
        }
    }
    
    func generateRecommendations() {
        // Generate recommendations based on user's library
        var sections: [RecommendationSection] = []
        
        // Based on favorite genres
        if let topGenre = store.topGenres.first {
            let genreGames = store.trendingGames.filter { $0.genres.contains(topGenre.0) }
            if !genreGames.isEmpty {
                sections.append(RecommendationSection(
                    title: "Parce que tu aimes \(topGenre.0)",
                    icon: "heart.fill",
                    reason: "Basé sur tes \(topGenre.1) jeux de \(topGenre.0)",
                    games: Array(genreGames.prefix(10))
                ))
            }
        }
        
        // Similar to highly rated games
        if let favoriteGame = store.myGames.max(by: { $0.rating < $1.rating }),
           favoriteGame.rating > 0, !store.topRated.isEmpty {
            sections.append(RecommendationSection(
                title: "Si tu as aimé \(favoriteGame.title)",
                icon: "sparkles",
                reason: "Des jeux similaires",
                games: Array(store.topRated.prefix(10))
            ))
        }
        
        // Based on platform
        if let topPlatform = store.topPlatforms.first {
            let platformGames = store.newReleases.filter { $0.platform.contains(topPlatform.0) || topPlatform.0.contains($0.platform) }
            if !platformGames.isEmpty {
                sections.append(RecommendationSection(
                    title: "Nouveautés \(topPlatform.0)",
                    icon: "gamecontroller.fill",
                    reason: "Les dernières sorties sur ta plateforme préférée",
                    games: Array(platformGames.prefix(10))
                ))
            }
        }
        
        // Quick plays for backlog
        if store.backlog.count > 5 {
            let quickGames = store.backlog.filter { ($0.estimatedPlaytime ?? 100) < 15 }
            if !quickGames.isEmpty {
                sections.append(RecommendationSection(
                    title: "Jeux courts de ton backlog",
                    icon: "clock.fill",
                    reason: "Parfait pour une session rapide",
                    games: Array(quickGames.prefix(10))
                ))
            }
        }
        
        // Upcoming games in favorite genres
        if store.topGenres.first != nil, !store.upcomingGames.isEmpty {
            sections.append(RecommendationSection(
                title: "Prochainement",
                icon: "calendar",
                reason: "Les sorties à venir qui pourraient te plaire",
                games: Array(store.upcomingGames.prefix(10))
            ))
        }
        
        // Hidden gems (less popular but highly rated)
        let hiddenGems = store.topRated.filter { !store.isInLibrary($0) }
        if !hiddenGems.isEmpty {
            sections.append(RecommendationSection(
                title: "Pépites à découvrir",
                icon: "diamond.fill",
                reason: "Des jeux bien notés que tu n'as pas encore",
                games: Array(hiddenGems.prefix(10))
            ))
        }
        
        recommendations = sections
        isLoading = false
    }
    
    func refreshRecommendations() async {
        isLoading = true
        await store.loadDiscoverData()
        generateRecommendations()
    }
}

// MARK: - Recommendation Section Model
struct RecommendationSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let reason: String
    let games: [Game]
}

// MARK: - Recommendation Section View
struct RecommendationSectionView: View {
    let section: RecommendationSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: section.icon)
                    .foregroundColor(.gbBrass)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(DS.Typography.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text(section.reason)
                        .font(DS.Typography.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Games Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(section.games) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            RecommendationGameCard(game: game)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Recommendation Game Card
struct RecommendationGameCard: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    
    var isInLibrary: Bool {
        store.isInLibrary(game)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            ZStack(alignment: .topTrailing) {
                if let url = game.artURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                    .frame(width: 130, height: 170)
                    .cornerRadius(10)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .frame(width: 130, height: 170)
                        .cornerRadius(10)
                }
                
                // In Library Badge
                if isInLibrary {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.gbBrass)
                        .background(Circle().fill(Color.gbDark))
                        .padding(6)
                }
            }
            
            // Title
            Text(game.title)
                .font(DS.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)
            
            // Platform & Rating
            HStack {
                Text(game.platform)
                    .font(DS.Typography.micro)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                if game.rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(DS.Typography.micro)
                        Text("\(game.rating)")
                            .font(DS.Typography.micro)
                    }
                    .foregroundColor(.yellow)
                }
            }
            .frame(width: 130)
        }
    }
}

// MARK: - Loading View
struct LoadingRecommendationsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gbBrass))
                .scaleEffect(1.5)
            
            Text("Analyse de tes goûts...")
                .font(DS.Typography.body)
                .foregroundColor(.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { RecommendationsView() }
        .environmentObject(GameStore())
}
