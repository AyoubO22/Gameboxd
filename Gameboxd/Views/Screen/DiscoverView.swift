//
//  DiscoverView.swift
//  Gameboxd
//
//  Discover new games with trending, new releases, and recommendations
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedCategory = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // API Key Warning
                    if !RAWGService.shared.hasValidAPIKey {
                        APIKeyWarningView()
                    }
                    
                    // Trending Section
                    DiscoverSection(
                        title: "🔥 Tendances",
                        subtitle: "Les jeux du moment",
                        games: store.trendingGames,
                        isLoading: store.isLoadingTrending
                    )
                    
                    // New Releases Section
                    DiscoverSection(
                        title: "🆕 Sorties récentes",
                        subtitle: "Jeux fraîchement sortis",
                        games: store.newReleases,
                        isLoading: store.isLoadingNewReleases
                    )
                    
                    // Top Rated Section
                    DiscoverSection(
                        title: "⭐ Les mieux notés",
                        subtitle: "Plébiscités par la critique",
                        games: store.topRated,
                        isLoading: store.isLoadingTopRated
                    )
                    
                    // Upcoming Section
                    DiscoverSection(
                        title: "📅 À venir",
                        subtitle: "Bientôt disponibles",
                        games: store.upcomingGames,
                        isLoading: store.isLoadingUpcoming
                    )
                    
                    // Random Backlog Pick
                    if let randomGame = store.randomBacklogPick() {
                        RandomPickSection(game: randomGame)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Découvrir")
            .refreshable {
                await store.loadDiscoverData()
            }
        }
    }
}

// MARK: - API Key Warning
struct APIKeyWarningView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Clé API manquante")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Ajoute ta clé RAWG.io dans RAWGService.swift pour voir les vrais jeux")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            if let url = URL(string: "https://rawg.io/apidocs") {
                Link("Obtenir une clé gratuite", destination: url)
                    .font(.caption)
                    .foregroundColor(.gbGreen)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gbCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Discover Section
struct DiscoverSection: View {
    let title: String
    let subtitle: String
    let games: [Game]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            // Content
            if isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<5) { _ in
                            ShimmerCard()
                        }
                    }
                    .padding(.horizontal)
                }
            } else if games.isEmpty {
                EmptyDiscoverSection()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(games) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                DiscoverGameCard(game: game)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Discover Game Card
struct DiscoverGameCard: View {
    let game: Game
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            ZStack(alignment: .topTrailing) {
                if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .overlay(ProgressView().tint(.white))
                    }
                } else {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                }
                
                // Metacritic badge
                if let score = game.metacriticScore {
                    Text("\(score)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(metacriticColor(score))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(6)
                }
                
                // In Library badge
                if store.isInLibrary(game) {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.gbGreen)
                                .padding(6)
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: 140, height: 180)
            .cornerRadius(10)
            .clipped()
            
            // Title
            Text(game.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Info
            HStack(spacing: 4) {
                Text(game.releaseYear)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text("•")
                    .foregroundColor(.gray)
                
                Text(game.platform)
                    .font(.caption2)
                    .foregroundColor(.gbGreen)
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.title), \(game.platform)")
        .accessibilityHint("Ouvre la fiche du jeu")
    }
}

// MARK: - Shimmer Loading Card
struct ShimmerCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gbCard)
                .frame(width: 140, height: 180)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gbCard)
                .frame(width: 120, height: 14)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gbCard)
                .frame(width: 80, height: 10)
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Empty Discover Section
struct EmptyDiscoverSection: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "gamecontroller")
                    .font(.title)
                    .foregroundColor(.gray.opacity(0.5))
                Text("Aucun jeu disponible")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 40)
            Spacer()
        }
        .background(Color.gbCard.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Random Pick Section
struct RandomPickSection: View {
    let game: Game
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎲 Pas d'inspiration ?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal)
            
            NavigationLink(destination: GameDetailView(game: game)) {
                HStack(spacing: 16) {
                    // Cover
                    if let imageURL = game.coverImageURL, let url = URL(string: imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(game.coverColor.gradient)
                        }
                        .frame(width: 80, height: 100)
                        .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .frame(width: 80, height: 100)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Joue à...")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(game.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Image(systemName: game.priority.color == .red ? "flame.fill" : "clock")
                                .foregroundColor(game.priority.color)
                            Text(game.priority.rawValue)
                                .font(.caption)
                                .foregroundColor(game.priority.color)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gbCard)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Preview
#Preview {
    DiscoverView()
        .environmentObject(GameStore())
}
