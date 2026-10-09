//
//  SocialView.swift
//  Gameboxd
//
//  Friends: the activity of the players you follow, finding players by pseudo, and a
//  player's public page. Backed by Supabase (SocialService); needs an account.
//

import SwiftUI

struct SocialView: View {
    @Environment(GameStore.self) private var store
    private let account = AccountService.shared
    private let social = SocialService.shared

    @State private var tab: Tab = .feed
    @State private var feed: [RemoteActivity] = []
    @State private var isLoadingFeed = true
    @State private var query = ""
    @State private var results: [RemoteProfile] = []
    @State private var followed: [RemoteProfile] = []
    @State private var error: String?

    enum Tab: String, CaseIterable { case feed = "Fil", players = "Joueurs" }

    var body: some View {
        Group {
            if account.isSignedIn {
                content
            } else {
                signedOut
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Amis")
        .alert("Oups", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    // MARK: - Signed in

    private var content: some View {
        VStack(spacing: 0) {
            PillSegmentedControl(options: Tab.allCases, selection: $tab) { $0.rawValue }
                .padding()

            switch tab {
            case .feed: feedList
            case .players: playersList
            }
        }
        .task {
            await social.loadFollowing()
            await reloadFeed()
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isLoadingFeed && feed.isEmpty {
                    ProgressView().tint(.accent).frame(maxWidth: .infinity).padding(.top, 60)
                } else if feed.isEmpty {
                    EmptyState(icon: "person.2", title: "Ton fil est vide",
                               message: "Suis des joueurs dans l'onglet Joueurs pour voir ce qu'ils jouent. Ton activité apparaît aussi ici.")
                        .frame(minHeight: 360)
                } else {
                    ForEach(feed) { activity in
                        ActivityRow(activity: activity, isMine: activity.userId == account.profile?.id)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 90)
        }
        .refreshable { await reloadFeed() }
    }

    private var playersList: some View {
        List {
            Section {
                ForEach(query.count >= 2 ? results : followed) { player in
                    NavigationLink(destination: PlayerProfileView(player: player)) {
                        PlayerRow(player: player)
                    }
                    .listRowBackground(Color.gbCard)
                }
            } header: {
                if query.count < 2 {
                    Text(followed.isEmpty ? "Cherche un pseudo pour suivre quelqu'un" : "Tes abonnements")
                } else if results.isEmpty {
                    Text("Aucun joueur trouvé")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Chercher un pseudo")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .task(id: query) {
            // Wait for a pause in typing before asking the server.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            do {
                results = try await social.searchPlayers(query)
            } catch {
                self.error = AccountService.translate(error).localizedDescription
            }
        }
        .task(id: social.following) {
            followed = (try? await social.profiles(ids: social.following)) ?? []
        }
    }

    private func reloadFeed() async {
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        do {
            feed = try await social.feed()
        } catch {
            self.error = AccountService.translate(error).localizedDescription
        }
    }

    // MARK: - Signed out

    private var signedOut: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accent)
            Text("Suis tes amis")
                .font(DS.Typography.title)
                .foregroundStyle(Color.textPrimary)
            Text("Crée un compte gratuit pour suivre des joueurs et partager ce que tu joues. Ta collection reste sur ton téléphone.")
                .font(DS.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Button("Créer un compte ou se connecter") { store.logout() }
                .font(DS.Typography.headline)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(Color.accent, in: Capsule())
                .foregroundStyle(Color.gbDark)
            Spacer()
        }
    }
}

// MARK: - Player page

struct PlayerProfileView: View {
    let player: RemoteProfile
    private let social = SocialService.shared

    @State private var activities: [RemoteActivity] = []
    @State private var library: [RemoteLibraryGame] = []
    @State private var counts: (followers: Int, following: Int) = (0, 0)
    @State private var error: String?

    private var isFollowing: Bool { social.following.contains(player.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.md) {
                    PlayerAvatar(name: player.username, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.displayName ?? player.username)
                            .font(DS.Typography.title)
                            .foregroundStyle(Color.textPrimary)
                        Text("@\(player.username)")
                            .font(DS.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }

                if let bio = player.bio, !bio.isEmpty {
                    Text(bio).font(DS.Typography.body).foregroundStyle(Color.textSecondary)
                }

                HStack(spacing: DS.Spacing.lg) {
                    Label("\(counts.followers) abonné\(counts.followers > 1 ? "s" : "")", systemImage: "person.2")
                    Label("\(counts.following) abonnement\(counts.following > 1 ? "s" : "")", systemImage: "person.badge.plus")
                }
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textSecondary)

                FollowButton(player: player, followerCount: $counts.followers, error: $error)

                PlayerLibrarySection(games: library)

                Text("Activité récente")
                    .font(DS.Typography.title3)
                    .foregroundStyle(Color.textPrimary)
                if activities.isEmpty {
                    Text("Rien de partagé pour l'instant.")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(activities) { ActivityRow(activity: $0, isMine: false, showsAuthor: false) }
                    }
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("@\(player.username)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let list = social.activities(of: player.id)
            async let numbers = social.counts(for: player.id)
            async let games = LibrarySync.shared.library(of: player.id)
            library = (try? await games) ?? []
            activities = (try? await list) ?? []
            counts = (try? await numbers) ?? (0, 0)
        }
        .alert("Oups", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }
}

private struct FollowButton: View {
    let player: RemoteProfile
    @Binding var followerCount: Int
    @Binding var error: String?
    private let social = SocialService.shared

    var body: some View {
        let isFollowing = social.following.contains(player.id)
        Button {
            Task {
                do {
                    if isFollowing {
                        try await social.unfollow(player.id)
                        followerCount -= 1
                    } else {
                        try await social.follow(player.id)
                        followerCount += 1
                    }
                    HapticManager.selection()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        } label: {
            Label(isFollowing ? "Abonné" : "Suivre", systemImage: isFollowing ? "checkmark" : "plus")
                .font(DS.Typography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(isFollowing ? Color.surfacePrimary : Color.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .foregroundStyle(isFollowing ? Color.textPrimary : Color.gbDark)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - A player's collection

private struct PlayerLibrarySection: View {
    let games: [RemoteLibraryGame]
    @State private var filter: GameStatus?
    @State private var opened: RemoteLibraryGame?

    private static let filters: [GameStatus?] = [nil, .playing, .completed, .platinum, .wantToPlay, .shelved]

    var body: some View {
        let shown = games.filter { filter == nil || $0.gameStatus == filter }
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Collection")
                    .font(DS.Typography.title3)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(games.count) jeu\(games.count > 1 ? "x" : "")")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            if games.isEmpty {
                Text("Sa collection n'est pas encore en ligne.")
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(Self.filters.filter { status in status == nil || games.contains { $0.gameStatus == status } }, id: \.self) { status in
                            let count = status.map { s in games.filter { $0.gameStatus == s }.count } ?? games.count
                            Button { filter = status } label: {
                                Text("\(status?.rawValue ?? "Tout") \(count)")
                                    .font(DS.Typography.captionMedium)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, 6)
                                    .background(filter == status ? Color.textPrimary : Color.surfacePrimary, in: Capsule())
                                    .foregroundStyle(filter == status ? Color.gbDark : Color.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                    ForEach(shown) { game in
                        Button { opened = game } label: { RemoteCover(game: game) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $opened) { RemoteGameSheet(game: $0) }
    }
}

private struct RemoteCover: View {
    let game: RemoteLibraryGame

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CachedAsyncImage(url: game.coverURL.flatMap(URL.init(string:))) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.surfaceSecondary.overlay(
                    Text(game.title).font(DS.Typography.micro).foregroundStyle(Color.textTertiary).padding(4)
                )
            }
            .aspectRatio(0.72, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if game.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DS.Colors.error)
                        .padding(4)
                }
            }

            if game.rating > 0 {
                HStack(spacing: 1) {
                    ForEach(1...game.rating, id: \.self) { _ in Image(systemName: "star.fill") }
                }
                .font(.system(size: 8))
                .foregroundStyle(DS.Colors.warning)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(game.title), \(game.gameStatus.rawValue)\(game.rating > 0 ? ", \(game.rating) étoiles" : "")")
    }
}

/// A friend's game, read-only: their status, rating, hours and review.
private struct RemoteGameSheet: View {
    let game: RemoteLibraryGame
    @State private var revealSpoiler = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        CachedAsyncImage(url: game.coverURL.flatMap(URL.init(string:))) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.surfaceSecondary }
                        .frame(width: 96, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(game.title)
                                .font(DS.Typography.title)
                                .foregroundStyle(Color.textPrimary)
                            Text([game.platform, game.releaseYear].compactMap { $0 }.joined(separator: " · "))
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                            HStack(spacing: 5) {
                                Circle().fill(game.gameStatus.color).frame(width: 7, height: 7)
                                Text(game.gameStatus.rawValue)
                            }
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(Color.textSecondary)
                        }
                    }

                    HStack(spacing: DS.Spacing.lg) {
                        if game.rating > 0 {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(star <= game.rating ? DS.Colors.warning : Color.surfaceSecondary)
                                }
                            }
                            .accessibilityLabel("\(game.rating) étoiles sur 5")
                        }
                        if game.playMinutes > 0 {
                            Label("\(game.playMinutes / 60) h", systemImage: "clock")
                        }
                        if game.completion > 0 {
                            Label("\(game.completion) %", systemImage: "checkmark.circle")
                        }
                    }
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textSecondary)

                    if let review = game.review {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Sa critique")
                                .font(DS.Typography.title3)
                                .foregroundStyle(Color.textPrimary)
                            if game.isSpoiler && !revealSpoiler {
                                Button { revealSpoiler = true } label: {
                                    Label("Contient des spoilers — toucher pour lire", systemImage: "eye.slash")
                                        .font(DS.Typography.body)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(DS.Colors.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                        .foregroundStyle(DS.Colors.warning)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(review)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color.textPrimary)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Rows

private struct PlayerRow: View {
    let player: RemoteProfile
    private let social = SocialService.shared

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            PlayerAvatar(name: player.username, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.displayName ?? player.username)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Text("@\(player.username)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            if social.following.contains(player.id) {
                Text("Abonné")
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}

struct ActivityRow: View {
    let activity: RemoteActivity
    let isMine: Bool
    var showsAuthor = true

    private var who: String {
        if isMine { return "Tu" }
        return activity.author.map { "@\($0.username)" } ?? "Un joueur"
    }

    private var verb: String {
        // "Tu a terminé" → "Tu as terminé".
        isMine ? activity.kind.verb.replacingOccurrences(of: "a ", with: "as ", options: .anchored) : activity.kind.verb
    }

    /// Capitalised when there's no author before it ("A terminé …").
    private var sentenceVerb: String {
        showsAuthor ? verb : verb.prefix(1).uppercased() + verb.dropFirst()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            CachedAsyncImage(url: activity.gameCoverURL.flatMap(URL.init(string:))) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.surfaceSecondary
            }
            .frame(width: 40, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(Text(showsAuthor ? "\(who) " : "").font(DS.Typography.bodyMedium).foregroundStyle(Color.textPrimary))\(Text(sentenceVerb + " ").font(DS.Typography.body).foregroundStyle(Color.textSecondary))\(Text(activity.gameTitle).font(DS.Typography.bodyMedium).foregroundStyle(Color.textPrimary))")
                    .lineLimit(2)

                HStack(spacing: DS.Spacing.xs) {
                    if let rating = activity.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: "star.fill")
                                    .foregroundStyle(star <= rating ? DS.Colors.warning : Color.surfaceSecondary)
                            }
                        }
                        .font(.system(size: 9))
                        .accessibilityLabel("\(rating) étoiles sur 5")
                    }
                    if let minutes = activity.minutes, minutes > 0 {
                        Text(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60 > 0 ? "\(minutes % 60)" : "")" : "\(minutes) min")
                    }
                    Text(activity.createdAt, format: .relative(presentation: .named))
                }
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textTertiary)

                if let review = activity.review, !review.isEmpty {
                    Text(review)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.gbBorder).frame(height: 0.5).padding(.leading, 52)
        }
    }
}

/// Initial on a coloured disc (no photos yet): the colour is stable per pseudo.
struct PlayerAvatar: View {
    let name: String
    let size: CGFloat

    private var color: Color {
        let palette: [Color] = [.accent, DS.Colors.success, GameStatus.completed.color, DS.Colors.warning, Color(hex: "C79BFF")]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        Text(name.prefix(1).uppercased())
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(Color.gbDark)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack { SocialView() }
        .environment(GameStore())
}
