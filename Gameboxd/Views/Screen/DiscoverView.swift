//
//  DiscoverView.swift
//  Gameboxd
//
//  Discover as a game shop's aisle: an endcap for the game of the moment,
//  then bins of cases on planks, with the shop's stickers on the boxes.
//

import SwiftUI

struct DiscoverView: View {
    @Environment(GameStore.self) private var store
    @State private var randomPick: Game?
    @Namespace private var aisle

    private static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    if !RAWGService.shared.hasValidAPIKey {
                        APIKeyWarningView()
                    }

                    if let featured = store.trendingGames.first {
                        EndcapFeature(game: featured, namespace: aisle)
                    }

                    // Picked from your own tastes (genres, ratings), next to what's popular.
                    NavigationLink(destination: RecommendationsView()) {
                        ProfileNavRow(icon: "sparkles", title: "Pour toi", subtitle: "Des jeux choisis selon tes goûts")
                            .background(Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    StoreShelf(title: "Tendances", subtitle: "Ce qui se joue en ce moment",
                               games: Array(store.trendingGames.dropFirst()), isLoading: store.isLoadingTrending,
                               namespace: aisle) { _, index in
                        // Ranks continue after the endcap's n° 1.
                        StoreSticker(text: "N° \(index + 2)")
                    }

                    StoreShelf(title: "Sorties récentes", subtitle: "Arrivés ces deux derniers mois",
                               games: store.newReleases, isLoading: store.isLoadingNewReleases,
                               namespace: aisle) { game, _ in
                        releaseSticker(game, tint: DS.Colors.success)
                    }

                    StoreShelf(title: "Les mieux notés", subtitle: "Plébiscités par la critique",
                               games: store.topRated, isLoading: store.isLoadingTopRated,
                               namespace: aisle) { game, _ in
                        if let score = game.metacriticScore {
                            StoreSticker(text: "\(score)", tint: DS.Colors.score(score))
                        }
                    }

                    StoreShelf(title: "Bientôt", subtitle: "Les sorties des prochains mois",
                               games: store.upcomingGames, isLoading: store.isLoadingUpcoming,
                               namespace: aisle) { game, _ in
                        releaseSticker(game, tint: GameStatus.completed.color)
                    }

                    if let randomGame = randomPick {
                        BacklogSuggestion(game: randomGame, namespace: aisle)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 90)
            }
            .background(
                LinearGradient(colors: [Shelf.wallTop, Color.gbDark], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
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

    @ViewBuilder
    private func releaseSticker(_ game: Game, tint: Color) -> some View {
        if let string = game.releaseDate, let date = Self.isoDate.date(from: string) {
            StoreSticker(text: Self.shortDate.string(from: date), tint: tint)
        }
    }
}

// MARK: - Sticker

/// The price-tag sticker a shop slaps on a case, slightly crooked.
struct StoreSticker: View {
    let text: String
    var tint: Color = .accent

    var body: some View {
        Text(text)
            .font(DS.Typography.text(11, weight: .bold, relativeTo: .caption2))
            .foregroundStyle(Color.gbDark)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            .rotationEffect(.degrees(-6))
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
    }
}

// MARK: - A bin of cases

struct StoreShelf<Sticker: View>: View {
    @Environment(GameStore.self) private var store
    let title: String
    let subtitle: String
    let games: [Game]
    let isLoading: Bool
    let namespace: Namespace.ID
    @ViewBuilder let sticker: (Game, Int) -> Sticker

    private let coverWidth: CGFloat = 98

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.title3)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: DS.Spacing.md) {
                    if isLoading && games.isEmpty {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.gbSurface2)
                                .frame(width: coverWidth * 1.06, height: (coverWidth * 1.39).rounded())
                        }
                    } else {
                        ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                            NavigationLink {
                                GameDetailView(game: store.libraryGame(for: game) ?? game)
                                    .navigationTransition(.zoom(sourceID: game.id, in: namespace))
                            } label: {
                                FaceOutCase(game: game, coverWidth: coverWidth, showsProgress: false)
                                    .overlay(alignment: .topTrailing) {
                                        Group {
                                            if store.isInLibrary(game) {
                                                StoreSticker(text: "À toi", tint: Color.accent)
                                            } else {
                                                sticker(game, index)
                                            }
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: game.id, in: namespace)
                            .accessibilityLabel(game.title)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, DS.Spacing.sm)
            }
            ShelfPlank()
                .padding(.horizontal, DS.Spacing.md)
        }
    }
}

// MARK: - Endcap

/// The endcap at the head of the aisle: the n° 1 trending game, its case standing
/// in front of its own artwork.
struct EndcapFeature: View {
    @Environment(GameStore.self) private var store
    let game: Game
    let namespace: Namespace.ID

    var body: some View {
        let owned = store.isInLibrary(game)
        ZStack(alignment: .bottomLeading) {
            // Backdrop: the landscape artwork, dimmed to walnut at the bottom.
            Group {
                if let url = game.coverImageURL.flatMap(URL.init(string:)) {
                    CachedAsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Shelf.wallTop }
                } else {
                    Shelf.wallTop
                }
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(LinearGradient(colors: [.clear, Color.gbDark.opacity(0.55), Color.gbDark],
                                    startPoint: .top, endPoint: .bottom))

            HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                NavigationLink {
                    GameDetailView(game: store.libraryGame(for: game) ?? game)
                        .navigationTransition(.zoom(sourceID: "endcap", in: namespace))
                } label: {
                    FaceOutCase(game: game, coverWidth: 118, showsProgress: false)
                        .overlay(alignment: .topTrailing) {
                            StoreSticker(text: "N° 1").offset(x: 8, y: -8)
                        }
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: "endcap", in: namespace)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Le plus ajouté par les joueurs ce mois-ci")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textSecondary)
                    Text(game.title)
                        .font(DS.Typography.display(32))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    if let score = game.metacriticScore {
                        Text("Metacritic \(score)")
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(DS.Colors.score(score))
                    }
                    Button {
                        guard !owned else { return }
                        store.updateGame(game)
                        HapticManager.notification(.success)
                    } label: {
                        Label(owned ? "Dans ta collection" : "Ajouter", systemImage: owned ? "checkmark" : "plus")
                            .font(DS.Typography.bodyMedium)
                            .foregroundStyle(owned ? Color.textSecondary : Color.gbDark)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(owned ? Color.gbSurface2 : Color.accent, in: Capsule())
                    }
                    .disabled(owned)
                    .padding(.top, 4)
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, DS.Spacing.md)
        }
        .frame(height: 300)
    }
}

// MARK: - From your backlog

struct BacklogSuggestion: View {
    let game: Game
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Pas d'inspiration ?")
                .font(DS.Typography.title3)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal)

            NavigationLink {
                GameDetailView(game: game)
                    .navigationTransition(.zoom(sourceID: "backlog-\(game.id)", in: namespace))
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    FaceOutCase(game: game, coverWidth: 64, showsProgress: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Et si tu lançais")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                        Text("\(game.title) ?")
                            .font(DS.Typography.display(24, weight: .heavy, relativeTo: .title3))
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text("Il attend dans ton backlog.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: "backlog-\(game.id)", in: namespace)
        }
    }
}

// MARK: - API Key Warning

struct APIKeyWarningView: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "key.fill")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Clé API manquante")
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.textPrimary)

                Text("Ajoute ta clé RAWG dans Secrets.xcconfig (RAWG_API_KEY) pour voir les vrais jeux.")
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
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview {
    DiscoverView()
        .environment(GameStore())
}
