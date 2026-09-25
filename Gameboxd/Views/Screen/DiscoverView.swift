//
//  DiscoverView.swift
//  Gameboxd
//
//  Discover new games with trending, new releases, and recommendations
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var store: GameStore
    @State private var randomPick: Game?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // API Key Warning
                    if !RAWGService.shared.hasValidAPIKey {
                        APIKeyWarningView()
                    }

                    // Hero: top trending game
                    if let hero = store.trendingGames.first {
                        DiscoverHeroCard(game: hero)
                            .padding(.horizontal)
                    }

                    // Trending Section
                    DiscoverSection(
                        title: "Tendances",
                        subtitle: "Les jeux du moment",
                        games: store.trendingGames,
                        isLoading: store.isLoadingTrending
                    )
                    
                    // New Releases Section
                    DiscoverSection(
                        title: "Sorties récentes",
                        subtitle: "Jeux fraîchement sortis",
                        games: store.newReleases,
                        isLoading: store.isLoadingNewReleases
                    )
                    
                    // Top Rated Section
                    DiscoverSection(
                        title: "Les mieux notés",
                        subtitle: "Plébiscités par la critique",
                        games: store.topRated,
                        isLoading: store.isLoadingTopRated
                    )
                    
                    // Upcoming Section
                    DiscoverSection(
                        title: "À venir",
                        subtitle: "Bientôt disponibles",
                        games: store.upcomingGames,
                        isLoading: store.isLoadingUpcoming
                    )
                    
                    // Random Backlog Pick
                    if let randomGame = randomPick {
                        RandomPickSection(game: randomGame)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Découvrir")
            .onAppear {
                // Pick once per visit (not in body, which re-rolls on every store update);
                // re-pick if the game left the backlog.
                if randomPick == nil || !store.backlog.contains(where: { $0.id == randomPick?.id }) {
                    randomPick = store.randomBacklogPick()
                }
            }
            .task {
                await store.refreshDiscoverIfStale()
            }
            .refreshable {
                await store.loadDiscoverData()
            }
        }
    }
}

// MARK: - Discover Hero Card
struct DiscoverHeroCard: View {
    let game: Game

    var body: some View {
        NavigationLink(destination: GameDetailView(game: game)) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let url = game.coverImageURL.flatMap(URL.init(string:)) { // landscape banner: keep RAWG art
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(game.coverColor.gradient)
                        }
                    } else {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                }
                .aspectRatio(16/9, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(LinearGradient(colors: [.gbDark.opacity(0.05), .gbDark.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(Color.gbBorder, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tendance")
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.accent)
                    Text(game.title)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                }
                .padding(DS.Spacing.md)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - API Key Warning
struct APIKeyWarningView: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "key.fill")
                .font(DS.Typography.title)
                .foregroundStyle(Color(hex: "E3A24C"))

            VStack(alignment: .leading, spacing: 4) {
                Text("Clé API manquante")
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                Text("Ajoute ta clé RAWG.io dans RAWGService.swift pour voir les vrais jeux")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)

                if let url = URL(string: "https://rawg.io/apidocs") {
                    Link("Obtenir une clé gratuite", destination: url)
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(Color.accent)
                }
            }

            Spacer()
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color(hex: "E3A24C").opacity(0.4), lineWidth: 1)
        )
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
            SectionHeader(title: title, subtitle: subtitle)
                .padding(.horizontal)

            // Content
            if isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(0..<5), id: \.self) { _ in
                            ShimmerCard()
                        }
                    }
                    .padding(.horizontal)
                }
            } else if games.isEmpty {
                EmptyDiscoverSection()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
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
                Group {
                    if let url = game.artURL {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(game.coverColor.gradient)
                                .overlay(ProgressView().tint(.textSecondary))
                        }
                    } else {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                    }
                }
                .frame(width: 132, height: 176)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(Color.gbBorder, lineWidth: 1)
                )

                // Metacritic badge
                if let score = game.metacriticScore {
                    Text("\(score)")
                        .font(DS.Typography.label)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DS.Colors.score(score).opacity(0.2))
                        .background(Color.gbDark.opacity(0.85))
                        .foregroundStyle(DS.Colors.score(score))
                        .clipShape(Capsule())
                        .padding(6)
                }

                // In Library badge
                if store.isInLibrary(game) {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.gbDark)
                                .padding(5)
                                .background(Color.accent)
                                .clipShape(Circle())
                                .padding(6)
                            Spacer()
                        }
                    }
                }
            }

            // Title
            Text(game.title)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Info
            HStack(spacing: 4) {
                Text("\(game.releaseYear), \(game.platform)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 132)
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
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.gbSurface2)
                .frame(width: 132, height: 176)

            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(Color.gbSurface2)
                .frame(width: 112, height: 14)

            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(Color.gbSurface2)
                .frame(width: 76, height: 10)
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Empty Discover Section
struct EmptyDiscoverSection: View {
    var body: some View {
        EmptyState(icon: "gamecontroller", title: "Aucun jeu disponible")
            .frame(height: 160)
            .cardStyle()
            .padding(.horizontal)
    }
}

// MARK: - Random Pick Section
struct RandomPickSection: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pas d'inspiration ?")
                .padding(.horizontal)

            NavigationLink(destination: GameDetailView(game: game)) {
                HStack(spacing: DS.Spacing.md) {
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
                    .frame(width: 72, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(Color.gbBorder, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("JOUE À…")
                            .font(DS.Typography.label)
                            .foregroundStyle(Color.textTertiary)

                        Text(game.title)
                            .font(DS.Typography.headline)
                            .foregroundStyle(Color.textPrimary)

                        TagPill(label: game.priority.rawValue, icon: game.priority.color == .red ? "flame.fill" : "clock", isSelected: true, tint: game.priority.color)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textTertiary)
                }
                .cardStyle()
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
