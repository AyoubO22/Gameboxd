//
//  ProfileView.swift
//  Gameboxd
//
//  User profile with stats, favorites, and settings
//

import SwiftUI

struct ProfileView: View {
    @Environment(GameStore.self) private var store
    @State private var showingEditProfile = false
    @State private var showingLists = false
    @Namespace private var showcaseNamespace

    var body: some View {
        NavigationStack {
            // Width read from outside the scroll view: it's fixed by the screen, so sizing
            // the showcase from it can't loop (measuring the content itself did).
            GeometryReader { page in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    ProfileNameplate(showingEditProfile: $showingEditProfile)

                    ShowcaseSection(namespace: showcaseNamespace, rowWidth: page.size.width - DS.Spacing.md * 2)

                    YearStorySection()

                    StickerAlbumSection()

                    ProfileNavigationSection()

                    MyListsSection(showingLists: $showingLists)
                }
                .padding(.vertical)
                .padding(.bottom, 90)
            }
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.accent)
                    }
                    .accessibilityLabel("Réglages")
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                NavigationStack { EditProfileView() }
            }
            .sheet(isPresented: $showingLists) {
                ListsView()
            }
        }
    }
}

// MARK: - Profile Navigation Section
struct ProfileNavigationSection: View {
    @Environment(GameStore.self) private var store
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: StatisticsView()) {
                ProfileNavRow(icon: "chart.bar.fill", title: "Statistiques", subtitle: "Graphiques détaillés")
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: AchievementsView()) {
                ProfileNavRow(icon: "trophy.fill", title: "Succès", subtitle: "Tes badges")
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: GoalsView()) {
                ProfileNavRow(icon: "target", title: "Objectifs", subtitle: "Défis mensuels")
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: LinkedAccountsView()) {
                ProfileNavRow(
                    icon: "link.badge.plus",
                    title: "Comptes liés",
                    subtitle: "PlayStation, Steam",
                    count: store.linkedAccounts.isEmpty ? nil : store.linkedAccounts.count
                )
            }
        }
        .background(Color.gbCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.gbBorder, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct ProfileNavRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var count: Int? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.bodyLarge)
                .foregroundStyle(Color.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: 0)

            if let count {
                Text("\(count)")
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(Color.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - My Lists Section
struct MyListsSection: View {
    @Environment(GameStore.self) private var store
    @Binding var showingLists: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mes listes", trailing: "Voir tout") { showingLists = true }
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.gameLists.prefix(5)) { list in
                        NavigationLink(destination: ListDetailViewFromProfile(list: list)) {
                            ListPreviewCard(list: list)
                        }
                    }

                    // Create new list
                    Button(action: { showingLists = true }) {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(Color.gbBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .frame(width: 120, height: 80)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(DS.Typography.title)
                                        .foregroundStyle(Color.textTertiary)
                                )

                            Text("Nouvelle liste")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct ListPreviewCard: View {
    let list: GameList
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: list.iconName)
                    .foregroundStyle(list.color)

                Text("\(list.gameIds.count)")
                    .font(DS.Typography.label)
                    .foregroundStyle(Color.textTertiary)
            }

            Text(list.name)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 120, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Year In Review View
struct YearInReviewView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    var stats: YearStats {
        store.getYearStats(for: selectedYear)
    }
    
    var years: [Int] {
        Array((2020...Calendar.current.component(.year, from: Date())).reversed())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Year Picker
                PillSegmentedControl(options: years, selection: $selectedYear) { String($0) }
                    .padding(.horizontal)
                
                // Main Stats
                VStack(spacing: 8) {
                    Text("\(selectedYear)")
                        .font(DS.Typography.display(64))
                        .foregroundStyle(Color.accent)
                    
                    Text("Ton année en jeux")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.vertical, 20)
                
                // Stats Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.xs) {
                    MetricCard(value: "\(stats.gamesPlayed)", label: "Jeux joués", icon: "gamecontroller.fill")
                    MetricCard(value: "\(stats.gamesCompleted)", label: "Terminés", icon: "checkmark.circle.fill")
                    MetricCard(value: "\(stats.totalPlayTime / 60)h", label: "Temps de jeu", icon: "clock.fill")
                    MetricCard(value: String(format: "%.1f", stats.averageRating), label: "Note moyenne", icon: "star.fill")
                }
                .padding(.horizontal)
                
                // Top Genres
                if !stats.topGenres.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Top Genres")
                        
                        ForEach(stats.topGenres.prefix(3), id: \.0) { genre, count in
                            HStack {
                                Text(genre)
                                    .font(DS.Typography.body)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Text("\(count) jeux")
                                    .font(DS.Typography.label)
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
                
                // Favorite Game
                if let favorite = stats.favoriteGame {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Jeu préféré")
                        
                        HStack {
                            Rectangle()
                                .fill(favorite.coverColor.gradient)
                                .frame(width: 60, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                        .stroke(Color.gbBorder, lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading) {
                                Text(favorite.title)
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.textPrimary)
                                
                                if favorite.rating > 0 {
                                HStack {
                                    ForEach(1...favorite.rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(Color.accent)
                                    }
                                }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .cardStyle()
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationTitle("Rétrospective")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - List Detail View (from Profile)
struct ListDetailViewFromProfile: View {
    let list: GameList
    @Environment(GameStore.self) private var store
    
    var gamesInList: [Game] {
        store.myGames.filter { list.gameIds.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: list.iconName)
                        .font(.system(size: 44))
                        .foregroundStyle(list.color)

                    Text(list.name)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(Color.textPrimary)

                    if !list.description.isEmpty {
                        Text(list.description)
                            .font(DS.Typography.body)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("\(gamesInList.count) jeux")
                        .font(DS.Typography.label)
                        .foregroundStyle(Color.accent)
                }
                .padding()

                // Games
                if gamesInList.isEmpty {
                    EmptyState(icon: "tray", title: "Liste vide", message: "Ajoute des jeux depuis leur page de détail")
                        .frame(height: 220)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(gamesInList) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                CompactGameCard(game: game)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview
#Preview {
    ProfileView()
        .environment(GameStore())
}

// MARK: - Nameplate

/// Your name set large, like an engraved plate: the page is about you, not a stats dashboard.
struct ProfileNameplate: View {
    @Environment(GameStore.self) private var store
    @Binding var showingEditProfile: Bool

    private var profile: UserProfile { store.userProfile }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.username)
                    .font(DS.Typography.display(48))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !profile.bio.isEmpty {
                    Text(profile.bio)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }
                Button("Modifier le profil") { showingEditProfile = true }
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(Color.accent)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
            avatar
        }
        .padding(.horizontal)
    }

    @ViewBuilder private var avatar: some View {
        Group {
            if let string = profile.avatarURL, let url = URL(string: string) {
                CachedAsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { emoji }
            } else {
                emoji
            }
        }
        .frame(width: 64, height: 64)
        .background(Color.gbCard)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.accent.opacity(0.5), lineWidth: 1.5))
        .accessibilityHidden(true)
    }

    private var emoji: some View {
        Text(profile.avatarEmoji).font(.system(size: 32))
    }
}

// MARK: - Showcase (favourites)

/// Your four favourite games, face out on a lit plank, like a shop's display case.
struct ShowcaseSection: View {
    @Environment(GameStore.self) private var store
    let namespace: Namespace.ID
    /// Width available to the row of cases.
    let rowWidth: CGFloat
    @State private var showingPicker = false

    private let slots = 4
    private let gap: CGFloat = 10

    var body: some View {
        let favorites = store.favoriteGames()
        // Four cases fill the row: each slot is a quarter of it minus the gaps,
        // and a case is its cover plus a spine of ~6 % of that width.
        let slotWidth = (rowWidth - gap * CGFloat(slots - 1)) / CGFloat(slots)
        let coverWidth = (slotWidth / 1.06).rounded(.down)

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ShelfLabel(title: "Ma vitrine", count: favorites.count)

            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(favorites) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                                .navigationTransition(.zoom(sourceID: game.id, in: namespace))
                        } label: {
                            FaceOutCase(game: game, coverWidth: coverWidth, showsProgress: false)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: game.id, in: namespace)
                        .contextMenu {
                            Button(role: .destructive) { store.removeFavoriteGame(game) } label: {
                                Label("Retirer de la vitrine", systemImage: "xmark.circle")
                            }
                        }
                    }
                    ForEach(favorites.count..<slots, id: \.self) { _ in
                        Button { showingPicker = true } label: {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.textTertiary.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                                .frame(width: slotWidth, height: (coverWidth * 1.39).rounded())
                                .overlay(Image(systemName: "plus").foregroundStyle(Color.textTertiary))
                        }
                        .accessibilityLabel("Ajouter un jeu à la vitrine")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.md)
                // The display case: a soft spot from above on a slightly lighter back wall.
                .background(
                    ZStack {
                        Shelf.wallTop
                        RadialGradient(colors: [Color.white.opacity(0.10), .clear],
                                       center: .top, startRadius: 0, endRadius: 220)
                    }
                )
                ShelfPlank().padding(.horizontal, DS.Spacing.md)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: DS.Radius.md, topTrailingRadius: DS.Radius.md))
            .padding(.horizontal, -DS.Spacing.md)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingPicker) {
            ShowcasePicker()
        }
    }
}

/// Picks a library game to put in the showcase.
struct ShowcasePicker: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var candidates: [Game] {
        let pinned = Set(store.favoriteGames().map(\.id))
        return store.myGames.filter { !pinned.contains($0.id) }.sorted { $0.rating > $1.rating }
    }

    var body: some View {
        NavigationStack {
            List(candidates) { game in
                Button {
                    store.addFavoriteGame(game)
                    HapticManager.notification(.success)
                    dismiss()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        FaceOutCase(game: game, coverWidth: 36, showsProgress: false)
                        Text(game.title)
                            .font(DS.Typography.bodyMedium)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        if game.rating > 0 {
                            Text("\(game.rating)/5")
                                .font(DS.Typography.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                .listRowBackground(Color.gbCard)
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Ajouter à la vitrine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
            .overlay {
                if candidates.isEmpty {
                    EmptyState(icon: "books.vertical", title: "Ta collection est vide",
                               message: "Ajoute des jeux depuis Recherche pour les exposer ici.")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Your year, told in sentences

struct YearStorySection: View {
    @Environment(GameStore.self) private var store
    private let year = Calendar.current.component(.year, from: Date())

    private var headline: String {
        let done = store.completedThisYear
        let goal = store.userProfile.yearlyGoal
        let jeux = done > 1 ? "jeux" : "jeu"
        if goal > 0 && done >= goal { return "Objectif \(year) atteint : \(done) \(jeux) terminés." }
        if done == 0 { return goal > 0 ? "Aucun jeu terminé en \(year) pour l'instant. Ton objectif : \(goal)." : "Aucun jeu terminé en \(year) pour l'instant." }
        return goal > 0 ? "En \(year), tu as terminé \(done) \(jeux) sur \(goal)." : "En \(year), tu as terminé \(done) \(jeux)."
    }

    private var detail: String {
        var parts: [String] = []
        let hours = store.totalPlayTimeMinutes / 60
        if hours > 0 { parts.append("\(hours) h de jeu au compteur.") }
        if let genre = store.topGenres.first?.0 { parts.append("Genre favori : \(genre).") }
        if store.averageRating > 0 {
            parts.append("Note moyenne : \(store.averageRating.formatted(.number.precision(.fractionLength(1)))) sur 5.")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Ton année")
                .font(DS.Typography.title3)
                .foregroundStyle(Color.textPrimary)

            Text(headline)
                .font(DS.Typography.text(22, relativeTo: .title3))
                .foregroundStyle(Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            GoalNotches(done: store.completedThisYear, goal: store.userProfile.yearlyGoal)
                .padding(.vertical, 4)

            if !detail.isEmpty {
                Text(detail)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink(destination: YearInReviewView()) {
                HStack(spacing: 4) {
                    Text("Voir ta rétrospective \(String(year))")
                    Image(systemName: "chevron.right").font(DS.Typography.caption)
                }
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(Color.accent)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
}

/// One notch per game of the yearly goal, filled for each game finished.
/// Past 24 the notches would be too thin to read, so it becomes a plain bar.
struct GoalNotches: View {
    let done: Int
    let goal: Int

    var body: some View {
        Group {
            if goal > 0 && goal <= 24 {
                HStack(spacing: 4) {
                    ForEach(0..<goal, id: \.self) { index in
                        Capsule()
                            .fill(index < done ? Color.accent : Color.gbSurface2)
                            .frame(height: 10)
                    }
                }
            } else if goal > 0 {
                ProgressView(value: Double(min(done, goal)), total: Double(goal))
                    .tint(Color.accent)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(done) jeux terminés sur un objectif de \(goal)")
    }
}
