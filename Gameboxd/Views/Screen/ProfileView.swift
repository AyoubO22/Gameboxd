//
//  ProfileView.swift
//  Gameboxd
//
//  User profile with stats, favorites, and settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: GameStore
    @State private var showingLogoutConfirm = false
    @State private var showingEditProfile = false
    @State private var showingStats = false
    @State private var showingLists = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeaderView(showingEditProfile: $showingEditProfile)
                    
                    // Yearly Goal Progress
                    YearlyGoalCard()
                    
                    // Quick Stats
                    QuickStatsGrid()
                    
                    // Feature Navigation Cards
                    ProfileNavigationSection()
                    
                    // Favorite Games
                    FavoriteGamesSection()
                    
                    // My Lists
                    MyListsSection(showingLists: $showingLists)
                    
                    // Year in Review Button
                    NavigationLink(destination: YearInReviewView()) {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "calendar.badge.clock")
                                .font(DS.Typography.title)
                                .foregroundStyle(Color.accent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rétrospective \(String(Calendar.current.component(.year, from: Date())))")
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.textPrimary)
                                Text("Tes statistiques de l'année")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.textTertiary)
                        }
                        .cardStyle()
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .stroke(Color.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)

                    // Logout Button
                    Button(action: { showingLogoutConfirm = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(DS.Typography.title3)
                            Text("Déconnexion")
                                .font(DS.Typography.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(Color(hex: "D9695A"))
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.gbDark.ignoresSafeArea())
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.accent)
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                NavigationStack { EditProfileView() }
            }
            .sheet(isPresented: $showingLists) {
                ListsView()
            }
            .alert("Déconnexion", isPresented: $showingLogoutConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Se déconnecter", role: .destructive) {
                    store.logout()
                }
            } message: {
                Text("És-tu sûr de vouloir te déconnecter ?")
            }
        }
    }
}

// MARK: - Profile Navigation Section
struct ProfileNavigationSection: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: StatisticsView()) {
                ProfileNavRow(icon: "chart.bar.fill", title: "Statistiques", subtitle: "Graphiques détaillés", color: Color(hex: "8EA9C9"))
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: AchievementsView()) {
                ProfileNavRow(icon: "trophy.fill", title: "Succès", subtitle: "Tes badges", color: Color(hex: "E3A24C"))
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: GoalsView()) {
                ProfileNavRow(icon: "target", title: "Objectifs", subtitle: "Défis mensuels", color: .accent)
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: BacklogView()) {
                ProfileNavRow(icon: "tray.full.fill", title: "Backlog", subtitle: "À quoi jouer?", color: Color(hex: "E3A24C"))
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: RecommendationsView()) {
                ProfileNavRow(icon: "sparkles", title: "Pour toi", subtitle: "Recommandations", color: .accent)
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: SocialView()) {
                ProfileNavRow(icon: "person.2.fill", title: "Social", subtitle: "Amis & Activité", color: Color(hex: "BCA5DB"))
            }
            Divider().overlay(Color.gbBorder)
            NavigationLink(destination: LinkedAccountsView()) {
                ProfileNavRow(
                    icon: "link.badge.plus",
                    title: "Comptes liés",
                    subtitle: "PlayStation, Steam",
                    color: Color(hex: "8EA9C9"),
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
    let color: Color
    var count: Int? = nil
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer(minLength: 0)
            
            if let count = count {
                Text("\(count)")
                    .font(DS.Typography.label)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.16))
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject var store: GameStore
    @Binding var showingEditProfile: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar (supports Google/Apple profile pic or emoji)
            ZStack {
                if let avatarURLString = store.userProfile.avatarURL,
                   let url = URL(string: avatarURLString) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gbBrass.gradient)
                            .overlay(
                                Text(store.userProfile.avatarEmoji)
                                    .font(.system(size: 50))
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gbBrass.gradient)
                        .frame(width: 100, height: 100)

                    Text(store.userProfile.avatarEmoji)
                        .font(.system(size: 50))
                }
            }
            .overlay(Circle().stroke(Color.accent, lineWidth: 2))

            // Username
            HStack(spacing: 6) {
                Text(store.userProfile.username)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(Color.textPrimary)

                // Auth provider badge
                if store.userProfile.authProvider == "apple" {
                    Image(systemName: "apple.logo")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                } else if store.userProfile.authProvider == "google" {
                    Image(systemName: "g.circle.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            // Linked platforms badges
            if !store.linkedAccounts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(store.linkedAccounts) { account in
                        TagPill(
                            label: account.platformUsername.isEmpty ? account.platformUserId : account.platformUsername,
                            icon: account.platform.sfSymbol,
                            isSelected: true,
                            tint: account.platform.accentColor
                        )
                    }
                }
            }

            // Bio
            if !store.userProfile.bio.isEmpty {
                Text(store.userProfile.bio)
                    .font(DS.Typography.body)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Edit Button
            Button(action: { showingEditProfile = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Modifier le profil")
                }
                .font(DS.Typography.body)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gbCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.gbBorder, lineWidth: 1))
            }
        }
        .padding()
    }
}

// MARK: - Yearly Goal Card
struct YearlyGoalCard: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Objectif \(String(Calendar.current.component(.year, from: Date())))")
                    .font(DS.Typography.label)
                    .foregroundStyle(Color.textTertiary)

                Spacer()

                Text("\(store.completedThisYear) / \(store.userProfile.yearlyGoal)")
                    .font(DS.Typography.stat)
                    .foregroundStyle(Color.textPrimary)
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gbSurface2)
                        .frame(height: 8)

                    Capsule()
                        .fill(Color.accent)
                        .frame(width: max(8, geometry.size.width * store.yearlyProgress), height: 8)
                }
            }
            .frame(height: 8)

            // Encouragement text
            Text(progressMessage)
                .font(DS.Typography.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .cardStyle()
        .padding(.horizontal)
    }
    
    var progressMessage: String {
        let progress = store.yearlyProgress
        if progress >= 1.0 {
            return "🎉 Objectif atteint ! Bravo !"
        } else if progress >= 0.75 {
            return "Presque ! Plus que \(store.userProfile.yearlyGoal - store.completedThisYear) jeux"
        } else if progress >= 0.5 {
            return "Tu es à mi-chemin, continue !"
        } else if progress >= 0.25 {
            return "Bon début, reste motivé !"
        } else {
            return "C'est parti pour cette année !"
        }
    }
}

// MARK: - Quick Stats Grid
struct QuickStatsGrid: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DS.Spacing.xs) {
            MetricCard(value: "\(store.totalGames)", label: "Jeux", icon: "gamecontroller.fill", tint: Color(hex: "8EA9C9"))
            MetricCard(value: store.totalPlayTimeFormatted, label: "Temps joué", icon: "clock.fill", tint: Color(hex: "E3A24C"))
            MetricCard(value: String(format: "%.1f", store.averageRating), label: "Note moy.", icon: "star.fill", tint: .accent)
            MetricCard(value: "\(store.gamesCount(for: .completed) + store.gamesCount(for: .platinum))", label: "Terminés", icon: "checkmark.circle.fill", tint: Color(hex: "E3A24C"))
            MetricCard(value: "\(store.gamesCount(for: .playing))", label: "En cours", icon: "play.fill", tint: .accent)
            MetricCard(value: "\(store.backlog.count)", label: "Backlog", icon: "tray.full.fill", tint: Color(hex: "BCA5DB"))
        }
        .padding(.horizontal)
    }
}

// MARK: - Favorite Games Section
struct FavoriteGamesSection: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        let favorites = store.favoriteGames()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Jeux favoris")

                Text("\(favorites.count)/4")
                    .font(DS.Typography.label)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal)

            if favorites.isEmpty {
                EmptyState(icon: "heart", title: "Épingle tes 4 jeux préférés")
                    .frame(height: 140)
                    .cardStyle()
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(favorites) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                FavoriteGameCard(game: game)
                            }
                        }

                        // Add more slot
                        if favorites.count < 4 {
                            AddFavoriteSlot()
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct FavoriteGameCard: View {
    let game: Game

    var body: some View {
        VStack(spacing: 8) {
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
            .frame(width: 100, height: 133)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.gbBorder, lineWidth: 1)
            )

            Text(game.title)
                .font(DS.Typography.captionMedium)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .frame(width: 100)
        }
    }
}

struct AddFavoriteSlot: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(Color.gbBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .frame(width: 100, height: 133)
                .overlay(
                    Image(systemName: "plus")
                        .font(DS.Typography.title)
                        .foregroundStyle(Color.textTertiary)
                )

            Text("Ajouter")
                .font(DS.Typography.captionMedium)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - My Lists Section
struct MyListsSection: View {
    @EnvironmentObject var store: GameStore
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
    @EnvironmentObject var store: GameStore

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
    @EnvironmentObject var store: GameStore
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
    @EnvironmentObject var store: GameStore
    
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
        .environmentObject(GameStore())
}
