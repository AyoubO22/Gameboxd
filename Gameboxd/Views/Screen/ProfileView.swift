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
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Rétrospective \(String(Calendar.current.component(.year, from: Date())))")
                                    .font(.headline)
                                Text("Tes statistiques de l'année")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.gbCard)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Logout Button
                    Button(action: { showingLogoutConfirm = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)
                            Text("Déconnexion")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(12)
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
                            .foregroundColor(.gbGreen)
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
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
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Statistics
                NavigationLink(destination: StatisticsView()) {
                    ProfileNavCard(
                        icon: "chart.bar.fill",
                        title: "Statistiques",
                        subtitle: "Graphiques détaillés",
                        color: .blue
                    )
                }
                
                // Achievements
                NavigationLink(destination: AchievementsView()) {
                    ProfileNavCard(
                        icon: "trophy.fill",
                        title: "Succès",
                        subtitle: "Tes badges",
                        color: .yellow
                    )
                }
            }
            
            HStack(spacing: 12) {
                // Goals
                NavigationLink(destination: GoalsView()) {
                    ProfileNavCard(
                        icon: "target",
                        title: "Objectifs",
                        subtitle: "Défis mensuels",
                        color: .green
                    )
                }
                
                // Backlog
                NavigationLink(destination: BacklogView()) {
                    ProfileNavCard(
                        icon: "tray.full.fill",
                        title: "Backlog",
                        subtitle: "À quoi jouer?",
                        color: .orange
                    )
                }
            }
            
            HStack(spacing: 12) {
                // Recommendations
                NavigationLink(destination: RecommendationsView()) {
                    ProfileNavCard(
                        icon: "sparkles",
                        title: "Pour toi",
                        subtitle: "Recommandations",
                        color: .pink
                    )
                }
                
                // Social
                NavigationLink(destination: SocialView()) {
                    ProfileNavCard(
                        icon: "person.2.fill",
                        title: "Social",
                        subtitle: "Amis & Activité",
                        color: .purple
                    )
                }
            }
            
            HStack(spacing: 12) {
                // Settings
                NavigationLink(destination: SettingsView()) {
                    ProfileNavCard(
                        icon: "gearshape.fill",
                        title: "Paramètres",
                        subtitle: "Thèmes, Tags...",
                        color: .gray
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

struct ProfileNavCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(12)
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    @EnvironmentObject var store: GameStore
    @Binding var showingEditProfile: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gbGreen.gradient)
                    .frame(width: 100, height: 100)
                
                Text(store.userProfile.avatarEmoji)
                    .font(.system(size: 50))
            }
            
            // Username
            Text(store.userProfile.username)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Bio
            if !store.userProfile.bio.isEmpty {
                Text(store.userProfile.bio)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Edit Button
            Button(action: { showingEditProfile = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Modifier le profil")
                }
                .font(.subheadline)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gbCard)
                .foregroundColor(.gbGreen)
                .cornerRadius(20)
            }
        }
        .padding()
    }
}

// MARK: - Yearly Goal Card
struct YearlyGoalCard: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🎯 Objectif \(String(Calendar.current.component(.year, from: Date())))")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(store.completedThisYear)/\(store.userProfile.yearlyGoal) jeux")
                    .font(.subheadline)
                    .foregroundColor(.gbGreen)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gbDark)
                        .frame(height: 20)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gbGreen.gradient)
                        .frame(width: geometry.size.width * store.yearlyProgress, height: 20)
                }
            }
            .frame(height: 20)
            
            // Encouragement text
            Text(progressMessage)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
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
        ], spacing: 12) {
            StatCard(value: "\(store.totalGames)", label: "Jeux", icon: "gamecontroller.fill", color: .blue)
            StatCard(value: store.totalPlayTimeFormatted, label: "Temps joué", icon: "clock.fill", color: .orange)
            StatCard(value: String(format: "%.1f", store.averageRating), label: "Note moy.", icon: "star.fill", color: .yellow)
            StatCard(value: "\(store.gamesCount(for: .completed))", label: "Terminés", icon: "checkmark.circle.fill", color: .green)
            StatCard(value: "\(store.gamesCount(for: .playing))", label: "En cours", icon: "play.fill", color: .gbGreen)
            StatCard(value: "\(store.backlog.count)", label: "Backlog", icon: "tray.full.fill", color: .purple)
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Favorite Games Section
struct FavoriteGamesSection: View {
    @EnvironmentObject var store: GameStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("⭐ Jeux favoris")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(store.favoriteGames().count)/4")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            if store.favoriteGames().isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "heart")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Épingle tes 4 jeux préférés")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
                .background(Color.gbCard)
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.favoriteGames()) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                FavoriteGameCard(game: game)
                            }
                        }
                        
                        // Add more slot
                        if store.favoriteGames().count < 4 {
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
            if let coverURL = game.coverImageURL, let url = URL(string: coverURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(game.coverColor.gradient)
                }
                .frame(width: 100, height: 130)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(game.coverColor.gradient)
                    .frame(width: 100, height: 130)
                    .cornerRadius(8)
            }
            
            Text(game.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 100)
        }
    }
}

struct AddFavoriteSlot: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: 100, height: 130)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.gray.opacity(0.5))
                )
            
            Text("Ajouter")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - My Lists Section
struct MyListsSection: View {
    @EnvironmentObject var store: GameStore
    @Binding var showingLists: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📚 Mes listes")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showingLists = true }) {
                    Text("Voir tout")
                        .font(.caption)
                        .foregroundColor(.gbGreen)
                }
            }
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
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 120, height: 80)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(.gray.opacity(0.5))
                                )
                            
                            Text("Nouvelle liste")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                    .foregroundColor(list.color)
                
                Text("\(list.gameIds.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 120, alignment: .leading)
        .padding()
        .background(Color.gbCard)
        .cornerRadius(12)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var avatarEmoji: String = ""
    @State private var yearlyGoal: Int = 12
    
    let avatarOptions = ["🎮", "👾", "🕹️", "🎯", "🏆", "⭐", "🔥", "💜", "🌟", "🎲"]
    
    var body: some View {
        NavigationStack {
            Form {
                // Avatar
                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(avatarOptions, id: \.self) { emoji in
                                Button(action: { avatarEmoji = emoji }) {
                                    Text(emoji)
                                        .font(.system(size: 40))
                                        .padding(8)
                                        .background(avatarEmoji == emoji ? Color.gbGreen.opacity(0.3) : Color.clear)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.gbCard)
                }
                
                // Info
                Section("Informations") {
                    TextField("Pseudo", text: $username)
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                // Goal
                Section("Objectif annuel") {
                    Stepper("\(yearlyGoal) jeux à terminer", value: $yearlyGoal, in: 1...100)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Modifier le profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sauvegarder") {
                        saveProfile()
                    }
                    .foregroundColor(.gbGreen)
                }
            }
            .onAppear {
                username = store.userProfile.username
                bio = store.userProfile.bio
                avatarEmoji = store.userProfile.avatarEmoji
                yearlyGoal = store.userProfile.yearlyGoal
            }
        }
    }
    
    private func saveProfile() {
        var profile = store.userProfile
        profile.username = username
        profile.bio = bio
        profile.avatarEmoji = avatarEmoji
        profile.yearlyGoal = yearlyGoal
        store.updateProfile(profile)
        dismiss()
    }
}

// MARK: - Year In Review View
struct YearInReviewView: View {
    @EnvironmentObject var store: GameStore
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    var stats: YearStats {
        store.getYearStats(for: selectedYear)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Year Picker
                Picker("Année", selection: $selectedYear) {
                    ForEach((2020...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Main Stats
                VStack(spacing: 20) {
                    Text("\(selectedYear)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.gbGreen)
                    
                    Text("EN REVUE")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .tracking(4)
                }
                .padding(.vertical, 20)
                
                // Stats Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    YearStatCard(value: "\(stats.gamesPlayed)", label: "Jeux joués", icon: "gamecontroller.fill")
                    YearStatCard(value: "\(stats.gamesCompleted)", label: "Terminés", icon: "checkmark.circle.fill")
                    YearStatCard(value: "\(stats.totalPlayTime / 60)h", label: "Temps de jeu", icon: "clock.fill")
                    YearStatCard(value: String(format: "%.1f", stats.averageRating), label: "Note moyenne", icon: "star.fill")
                }
                .padding(.horizontal)
                
                // Top Genres
                if !stats.topGenres.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Genres")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(stats.topGenres.prefix(3), id: \.0) { genre, count in
                            HStack {
                                Text(genre)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(count) jeux")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gbCard)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Favorite Game
                if let favorite = stats.favoriteGame {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🏆 Jeu préféré")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Rectangle()
                                .fill(favorite.coverColor.gradient)
                                .frame(width: 60, height: 80)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text(favorite.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if favorite.rating > 0 {
                                HStack {
                                    ForEach(1...favorite.rating, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(.gbGreen)
                                    }
                                }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.gbCard)
                    .cornerRadius(12)
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

struct YearStatCard: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.gbGreen)
            
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.gbCard)
        .cornerRadius(12)
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
                        .font(.system(size: 50))
                        .foregroundColor(list.color)
                    
                    Text(list.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !list.description.isEmpty {
                        Text(list.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("\(gamesInList.count) jeux")
                        .font(.caption)
                        .foregroundColor(.gbGreen)
                }
                .padding()
                
                // Games
                if gamesInList.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("Liste vide")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Ajoute des jeux depuis leur page de détail")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.top, 40)
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
