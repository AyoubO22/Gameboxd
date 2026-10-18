//
//  DemoShelf.swift
//  Gameboxd
//
//  Launch argument `-debugDemoShelf 1`: a shelf of well-known games on every kind of case,
//  for simulator screenshots. Debug builds only; nothing is saved to the real library or synced.
//

#if DEBUG
import SwiftUI

enum DemoShelf {
    /// `1`, `YES` or `true` turns it on; `0` or `NO` (a scheme argument switched off) doesn't.
    static let isOn = UserDefaults.standard.bool(forKey: "debugDemoShelf")

    /// The demo games live in memory. The store saves to a throwaway folder, so a status changed
    /// while looking round can't overwrite the real library; ContentView skips the account
    /// restore, and sync and sharing need a signed-in profile, so nothing goes online.
    static func makeStore() -> GameStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DemoShelf-\(UUID().uuidString)", isDirectory: true)
        let store = GameStore(fileStore: FileStore(directory: folder, legacyDefaults: nil))
        store.setICloudObservation(false) // iCloud would merge the real collection in
        store.myGames = games
        store.isLoggedIn = true // in memory: the real setting stays as it is
        Task { await fillCovers(in: store) }
        return store
    }

    /// Portrait covers from IGDB (Supabase function, keys from Secrets.xcconfig), applied in one
    /// go and never saved: a save runs the achievement check, whose toasts would cover the shelf.
    private static func fillCovers(in store: GameStore) async {
        var found: [UUID: String] = [:]
        for game in games {
            if let url = try? await IGDBService.shared.boxArtURL(title: game.title, year: game.releaseYear) {
                found[game.id] = url.absoluteString
            }
            try? await Task.sleep(for: .milliseconds(260)) // IGDB allows 4 requests a second
        }
        store.myGames = store.myGames.map { game in
            var updated = game
            if let art = found[game.id] { updated.boxArtURL = art }
            return updated
        }
    }

    private static func daysAgo(_ days: Double) -> Date { Date(timeIntervalSinceNow: -days * 86_400) }

    // boxArtURL "" reads as "already looked up", so GameStore.fetchMissingBoxArt (which saves)
    // leaves these alone; rawgId nil keeps fillMissingAgeRatings away too. ageRating is the ESRB
    // slug RAWG gives; the spine prints its PEGI.
    private static let games: [Game] = [
        // En cours: face out, one of each case size (PS, Switch, PC DVD).
        Game(title: "Elden Ring", developer: "FromSoftware", platform: "PlayStation 5", releaseYear: "2022", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "7A6A45"), status: .playing, playTimeMinutes: 58 * 60, completionPercentage: 62, isFavorite: true, startedDate: daysAgo(40), genres: ["Action", "RPG"]),
        Game(title: "The Legend of Zelda: Tears of the Kingdom", developer: "Nintendo EPD", platform: "Nintendo Switch", releaseYear: "2023", ageRating: "everyone-10-plus", boxArtURL: "", coverColor: Color(hex: "3E7A8C"), status: .playing, playTimeMinutes: 41 * 60, completionPercentage: 45, startedDate: daysAgo(25), genres: ["Action", "Adventure"]),
        Game(title: "Baldur's Gate 3", developer: "Larian Studios", platform: "PC", releaseYear: "2023", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "6B3F2A"), status: .playing, playTimeMinutes: 34 * 60, completionPercentage: 28, startedDate: daysAgo(12), genres: ["RPG", "Strategy"]),
        // À jouer
        Game(title: "Final Fantasy VII Rebirth", developer: "Square Enix", platform: "PlayStation 5", releaseYear: "2024", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "3C5B8A"), status: .wantToPlay, genres: ["RPG"]),
        Game(title: "Astro Bot", developer: "Team Asobi", platform: "PlayStation 5", releaseYear: "2024", ageRating: "everyone-10-plus", boxArtURL: "", coverColor: Color(hex: "2D6FD6"), status: .wantToPlay, genres: ["Platformer"]),
        Game(title: "Alan Wake 2", developer: "Remedy Entertainment", platform: "PlayStation 5", releaseYear: "2023", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "2E3A3F"), status: .wantToPlay, genres: ["Action"]),
        Game(title: "Metroid Dread", developer: "MercurySteam", platform: "Nintendo Switch", releaseYear: "2021", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "B3402A"), status: .wantToPlay, genres: ["Action", "Platformer"]),
        Game(title: "Hades", developer: "Supergiant Games", platform: "Nintendo Switch", releaseYear: "2020", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "8C2A1E"), status: .wantToPlay, genres: ["Action", "Indie"]),
        Game(title: "Mario Kart World", developer: "Nintendo EPD", platform: "Nintendo Switch 2", releaseYear: "2025", ageRating: "everyone", boxArtURL: "", coverColor: Color(hex: "E2382F"), status: .wantToPlay, genres: ["Racing"]),
        Game(title: "Forza Horizon 5", developer: "Playground Games", platform: "Xbox Series X|S", releaseYear: "2021", ageRating: "everyone", boxArtURL: "", coverColor: Color(hex: "D9662B"), status: .wantToPlay, genres: ["Racing"]),
        Game(title: "Starfield", developer: "Bethesda Game Studios", platform: "Xbox Series X|S", releaseYear: "2023", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "3B4A63"), status: .wantToPlay, genres: ["RPG"]),
        Game(title: "Ghost of Tsushima", developer: "Sucker Punch Productions", platform: "PlayStation 4", releaseYear: "2020", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "8E1F1F"), status: .wantToPlay, genres: ["Action", "Adventure"]),
        Game(title: "Cyberpunk 2077", developer: "CD Projekt Red", platform: "PC", releaseYear: "2020", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "D8D23A"), status: .wantToPlay, genres: ["RPG", "Shooter"]),
        // Terminés
        Game(title: "God of War Ragnarök", developer: "Santa Monica Studio", platform: "PlayStation 5", releaseYear: "2022", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "3E6C8F"), rating: 5, status: .platinum, playTimeMinutes: 52 * 60, completionPercentage: 100, isFavorite: true, startedDate: daysAgo(300), completedDate: daysAgo(250), genres: ["Action", "Adventure"]),
        Game(title: "Marvel's Spider-Man 2", developer: "Insomniac Games", platform: "PlayStation 5", releaseYear: "2023", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "A3202A"), rating: 4, status: .completed, playTimeMinutes: 31 * 60, startedDate: daysAgo(200), completedDate: daysAgo(180), genres: ["Action"]),
        Game(title: "Horizon Forbidden West", developer: "Guerrilla Games", platform: "PlayStation 5", releaseYear: "2022", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "C46A3A"), rating: 4, status: .completed, playTimeMinutes: 48 * 60, startedDate: daysAgo(420), completedDate: daysAgo(380), genres: ["Action", "RPG"]),
        Game(title: "Red Dead Redemption 2", developer: "Rockstar Games", platform: "PlayStation 4", releaseYear: "2018", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "B8321F"), rating: 5, status: .completed, playTimeMinutes: 74 * 60, isFavorite: true, startedDate: daysAgo(700), completedDate: daysAgo(640), genres: ["Action", "Adventure"]),
        Game(title: "The Last of Us Part II", developer: "Naughty Dog", platform: "PlayStation 4", releaseYear: "2020", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "3F4B3A"), rating: 5, status: .completed, playTimeMinutes: 27 * 60, startedDate: daysAgo(500), completedDate: daysAgo(480), genres: ["Action", "Adventure"]),
        Game(title: "Bloodborne", developer: "FromSoftware", platform: "PlayStation 4", releaseYear: "2015", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "2B2F3A"), rating: 5, status: .completed, playTimeMinutes: 44 * 60, startedDate: daysAgo(1300), completedDate: daysAgo(1250), genres: ["Action", "RPG"]),
        Game(title: "Uncharted 4: A Thief's End", developer: "Naughty Dog", platform: "PlayStation 4", releaseYear: "2016", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "3A6E8F"), rating: 4, status: .completed, playTimeMinutes: 18 * 60, startedDate: daysAgo(1600), completedDate: daysAgo(1580), genres: ["Action", "Adventure"]),
        Game(title: "Super Mario Bros. Wonder", developer: "Nintendo EPD", platform: "Nintendo Switch", releaseYear: "2023", ageRating: "everyone", boxArtURL: "", coverColor: Color(hex: "E2382F"), rating: 4, status: .completed, playTimeMinutes: 14 * 60, startedDate: daysAgo(150), completedDate: daysAgo(130), genres: ["Platformer"]),
        Game(title: "Hollow Knight", developer: "Team Cherry", platform: "Nintendo Switch", releaseYear: "2017", ageRating: "everyone-10-plus", boxArtURL: "", coverColor: Color(hex: "2B3A55"), rating: 5, status: .completed, playTimeMinutes: 38 * 60, isFavorite: true, startedDate: daysAgo(900), completedDate: daysAgo(860), genres: ["Action", "Platformer", "Indie"]),
        Game(title: "Animal Crossing: New Horizons", developer: "Nintendo EPD", platform: "Nintendo Switch", releaseYear: "2020", ageRating: "everyone", boxArtURL: "", coverColor: Color(hex: "6FB37A"), rating: 4, status: .completed, playTimeMinutes: 120 * 60, startedDate: daysAgo(1000), completedDate: daysAgo(900), genres: ["Simulation"]),
        Game(title: "Halo Infinite", developer: "343 Industries", platform: "Xbox Series X|S", releaseYear: "2021", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "4B6A3A"), rating: 4, status: .completed, playTimeMinutes: 16 * 60, startedDate: daysAgo(400), completedDate: daysAgo(390), genres: ["Shooter"]),
        Game(title: "Forza Horizon 4", developer: "Playground Games", platform: "Xbox One", releaseYear: "2018", ageRating: "everyone", boxArtURL: "", coverColor: Color(hex: "2D89C8"), rating: 4, status: .completed, playTimeMinutes: 45 * 60, startedDate: daysAgo(1200), completedDate: daysAgo(1100), genres: ["Racing"]),
        Game(title: "Gears 5", developer: "The Coalition", platform: "Xbox One", releaseYear: "2019", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "6E2B22"), rating: 4, status: .completed, playTimeMinutes: 12 * 60, startedDate: daysAgo(1100), completedDate: daysAgo(1090), genres: ["Shooter"]),
        Game(title: "The Witcher 3: Wild Hunt", developer: "CD Projekt Red", platform: "PC", releaseYear: "2015", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "5E6670"), rating: 5, status: .completed, playTimeMinutes: 96 * 60, startedDate: daysAgo(1500), completedDate: daysAgo(1400), genres: ["RPG"]),
        // Abandonnés
        Game(title: "Death Stranding", developer: "Kojima Productions", platform: "PlayStation 4", releaseYear: "2019", ageRating: "mature", boxArtURL: "", coverColor: Color(hex: "2F3B44"), status: .shelved, playTimeMinutes: 9 * 60, startedDate: daysAgo(600), genres: ["Action"]),
        Game(title: "Sea of Thieves", developer: "Rare", platform: "Xbox One", releaseYear: "2018", ageRating: "teen", boxArtURL: "", coverColor: Color(hex: "2E7D8C"), status: .shelved, playTimeMinutes: 6 * 60, startedDate: daysAgo(800), genres: ["Adventure"]),
    ]
}
#endif
