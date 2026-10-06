//
//  GameDetailView.swift
//  Gameboxd
//
//  Comprehensive game detail view with all tracking options
//

import SwiftUI

struct GameDetailView: View {
    @Environment(GameStore.self) private var store
    @State var game: Game
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddToList = false
    @State private var showingShareCard = false
    @State private var showingDeleteConfirm = false
    @State private var showingAddSession = false
    @State private var showingComparison = false
    @State private var similarGames: [Game] = []
    @State private var isLoadingSimilar = false
    @State private var openShot: ShotIndex?
    @Namespace private var pageNamespace

    /// Which screenshot the full-screen viewer opens on.
    struct ShotIndex: Identifiable { let id: Int }
    
    /// The last saved state; edits are compared against it to autosave.
    @State private var originalGame: Game? = nil
    
    var isInLibrary: Bool {
        store.myGames.contains { $0.id == game.id }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            // One page in the order you need it: no tabs hiding the controls you use most.
            VStack(alignment: .leading, spacing: 32) {
                GameDetailHeader(game: $game)

                YourGameSection(game: $game, isInLibrary: isInLibrary, onAdd: addToLibrary) {
                    showingAddSession = true
                }

                if isInLibrary {
                    ReviewSection(game: $game)
                    StickersSection(game: game)
                }

                AboutSection(game: game)
                    .id("about")

                let shots = game.screenshotURLs.compactMap(URL.init(string:))
                if !shots.isEmpty {
                    ScreenshotStrip(urls: shots, namespace: pageNamespace) { openShot = ShotIndex(id: $0) }
                }

                if isInLibrary {
                    GameJournalSection(sessions: store.sessionsForGame(game)) { showingAddSession = true }
                        .id("journal")
                    PlayDetailsSection(game: $game)
                }

                SimilarGamesShelf(games: similarGames, isLoading: isLoadingSimilar, namespace: pageNamespace)
            }
            .padding(.bottom, 48)
        }
        #if DEBUG
        // Launch arguments for simulator checks: `-debugScrollTo about|journal`, `-debugOpenShot 0`.
        .task {
            try? await Task.sleep(for: .seconds(2))
            if let section = UserDefaults.standard.string(forKey: "debugScrollTo") { proxy.scrollTo(section, anchor: .top) }
            if let shot = UserDefaults.standard.string(forKey: "debugOpenShot").flatMap(Int.init) { openShot = ShotIndex(id: shot) }
        }
        #endif
        }
        .background(Color.gbDark.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $openShot) { shot in
            ScreenshotViewer(urls: game.screenshotURLs.compactMap(URL.init(string:)), index: shot.id)
                .navigationTransition(.zoom(sourceID: "shot-\(shot.id)", in: pageNamespace))
        }
        .toolbar {
            if isInLibrary {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.toggleFavorite(game)
                    } label: {
                        Image(systemName: game.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(game.isFavorite ? DS.Colors.error : Color.accent)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: game.isFavorite)
                    .accessibilityLabel(game.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isInLibrary {
                        Button(action: { showingAddToList = true }) {
                            Label("Ajouter à une liste", systemImage: "list.bullet")
                        }

                        Button(action: { showingComparison = true }) {
                            Label("Comparer avec…", systemImage: "arrow.left.arrow.right")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            showingDeleteConfirm = true
                        }) {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                    
                    Button(action: { shareGame() }) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingShareCard = true }) {
                        Label("Créer une carte", systemImage: "photo.artframe")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.accent)
                }
                .accessibilityLabel("Plus d'actions")
            }
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListSheet(game: game)
        }
        .sheet(isPresented: $showingComparison) {
            GameComparisonView(preselectedGame: game)
        }
        .sheet(isPresented: $showingShareCard) {
            ShareCardView(game: game)
        }
        .sheet(isPresented: $showingAddSession) {
            AddPlaySessionView(preselectedGame: game)
        }
        .alert("Supprimer ce jeu ?", isPresented: $showingDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                store.deleteGame(game)
                dismiss()
            }
        } message: {
            Text("\(game.title) sera définitivement supprimé de ta bibliothèque, y compris les sessions et notes associées.")
        }
        .task {
            await loadSimilarGames()
        }
        // Description, screenshots and developer for the page and the back of the box.
        .task(id: game.rawgId) {
            guard game.rawgId != nil, game.description == nil || game.screenshotURLs.isEmpty || game.ageRating == nil else { return }
            guard let details = await store.fetchGameDetails(for: game) else { return }
            // Copy only these fields: the user may have edited others meanwhile.
            game.description = details.description
            game.screenshotURLs = details.screenshotURLs
            game.developer = details.developer
            game.ageRating = details.ageRating
        }
        .onAppear {
            if originalGame == nil {
                // Opened from Discover/Search/similar: show the owned copy, not the RAWG one.
                if let owned = store.libraryGame(for: game) {
                    game = owned
                }
                originalGame = game
            }
        }
        .onChange(of: store.myGames) { _, games in
            // Sessions and the toolbar favorite button change the stored game directly.
            // Pull those fields in so Save doesn't write the stale values back.
            guard let stored = games.first(where: { $0.id == game.id }), var original = originalGame else { return }
            if stored.playTimeMinutes != original.playTimeMinutes {
                game.playTimeMinutes = stored.playTimeMinutes
                original.playTimeMinutes = stored.playTimeMinutes
            }
            if stored.isFavorite != original.isFavorite {
                game.isFavorite = stored.isFavorite
                original.isFavorite = stored.isFavorite
            }
            originalGame = original
        }
        // Autosave: shortly after the last edit (typing stays smooth), and at once on leaving.
        .task(id: game) {
            guard isInLibrary, hasUnsavedChanges else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            save()
        }
        .onDisappear {
            if isInLibrary && hasUnsavedChanges { save() }
        }
    }
    
    private var hasUnsavedChanges: Bool {
        guard let original = originalGame else { return false }
        return game != original
    }

    /// "Où le ranges-tu ?": adds the game with the status tapped.
    private func addToLibrary(_ status: GameStatus) {
        game.status = status
        save()
        HapticManager.notification(.success)
    }

    private func save() {
        store.updateGame(game)
        // The store fills in dates (started, completed): take them back so the next
        // save doesn't see them as missing and stamp them again.
        if let stored = store.myGames.first(where: { $0.id == game.id || ($0.rawgId != nil && $0.rawgId == game.rawgId) }) {
            game.id = stored.id
            game.startedDate = stored.startedDate
            game.completedDate = stored.completedDate
            game.status = stored.status
            game.boxArtURL = stored.boxArtURL
        }
        originalGame = game
    }
    
    private func loadSimilarGames() async {
        guard game.rawgId != nil else { return }
        isLoadingSimilar = true
        similarGames = await store.fetchSimilarGames(for: game)
        isLoadingSimilar = false
    }
    
    private func shareGame() {
        let text = "\(game.title) - \(game.rating > 0 ? String(repeating: "★", count: game.rating) : "Non noté") sur Gameboxd"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Header
struct GameDetailHeader: View {
    @Binding var game: Game
    /// The cover's own colour, glowing behind the box.
    @State private var glow: Color?

    private var subtitle: String {
        [game.developer, game.releaseYear].filter { !$0.isEmpty && $0 != "Unknown" && $0 != "—" }.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 18) {
            GameBox3DView(game: game, height: 340)
                // Rebuild the box when what's printed on it changes (not on every edit).
                .id("\(game.platform)|\(game.description?.count ?? 0)|\(game.screenshotURLs.count)|\(game.boxArtURL ?? "")|\(game.ageRating ?? "")")

            VStack(spacing: 6) {
                Text(game.title)
                    .font(DS.Typography.display(40))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                }

                PlatformPicker(platform: $game.platform)
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            RadialGradient(
                colors: [(glow ?? Shelf.wallTop).opacity(0.45), Color.gbDark],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 10,
                endRadius: 360
            )
            .animation(.easeOut(duration: 0.4), value: glow)
        )
        .task(id: game.artURL) {
            guard let url = game.artURL,
                  let color = await ImageCache.shared.dominantColor(for: url) else { return }
            glow = Color(color)
        }
    }
}

struct SubRatingRow: View {
    let label: String
    let icon: String
    @Binding var rating: Int
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.accent)
                .frame(width: 25)

            Text(label)
                .foregroundStyle(Color.textSecondary)

            Spacer()

            StarRating(rating: $rating, editable: true, size: 18)
        }
    }
}

// MARK: - Add to List Sheet
struct AddToListSheet: View {
    let game: Game
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(store.gameLists) { list in
                Button(action: {
                    store.addGameToList(game, list: list)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: list.iconName)
                            .foregroundStyle(list.color)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
                            Text(list.name)
                                .foregroundStyle(Color.textPrimary)
                            Text("\(list.gameIds.count) jeux")
                                .font(DS.Typography.label)
                                .foregroundStyle(Color.textTertiary)
                        }

                        Spacer()

                        if list.gameIds.contains(game.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accent)
                        }
                    }
                }
                .listRowBackground(Color.gbCard)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.gbDark)
            .navigationTitle("Ajouter à une liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        GameDetailView(game: Game(
            title: "The Legend of Zelda: TOTK",
            developer: "Nintendo",
            platform: "Switch",
            releaseYear: "2023",
            coverColor: .green,
            rating: 5,
            status: .playing,
            review: "Une liberté totale",
            playTime: "45h",
            genres: ["Action", "Adventure"]
        ))
        .environment(GameStore())
    }
}

// MARK: - Platform picker

/// "Tu y joues sur : PS5 ▾". The case's band (front, spine, shelf) follows the choice.
struct PlatformPicker: View {
    @Binding var platform: String

    private var band: PlatformBand { PlatformBand(platform: platform) }

    private var choices: [String] {
        // Keep RAWG's own name (e.g. "Xbox Series S/X") if it isn't one of ours.
        PlatformBand.choices.contains(platform) ? PlatformBand.choices : [platform] + PlatformBand.choices
    }

    var body: some View {
        Menu {
            ForEach(choices, id: \.self) { choice in
                Button {
                    platform = choice
                    HapticManager.selection()
                } label: {
                    if choice == platform {
                        Label(choice, systemImage: "checkmark")
                    } else {
                        Text(choice)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Tu y joues sur")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textSecondary)
                Text(band.label)
                    .font(DS.Typography.text(12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(band.color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                Image(systemName: "chevron.down")
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel("Plateforme : \(platform). Toucher pour changer.")
    }
}
