# Gameboxd

**Letterboxd for video games.** An iOS app to rate, review and track the games you play, built with SwiftUI.

[![CI](https://github.com/AyoubO22/Gameboxd/actions/workflows/ci.yml/badge.svg)](https://github.com/AyoubO22/Gameboxd/actions/workflows/ci.yml)
![iOS 26+](https://img.shields.io/badge/iOS-26%2B-blue)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)

## What it does

- **Your library as a shelf.** Games you're playing stand face out, everything else spine out, on walnut planks. Each game has a status: playing, want to play, completed, platinum or shelved.
- **The box in 3D.** Open a game and its case turns in RealityKit: cover on the front, a spine in the cover's color, your notes on the back. Drag it and it keeps its momentum.
- **Ratings and reviews.** Star ratings, written reviews with a spoiler flag, mood tags, custom tags and your own lists.
- **Play sessions.** A live play timer, and a diary with a calendar of every session you logged.
- **Stats.** Swift Charts of games per month, genres and platforms, plus total play time, for any period.
- **Goals and achievements.** Monthly goals and 19 achievements to unlock.
- **Backlog picker.** Can't choose what to play next? Spin the wheel.
- **Discover.** Trending games, new releases, top rated, upcoming and similar games from RAWG's database of 500,000+ titles, with portrait box art from IGDB.
- **The rest.** Share cards in four styles, a home screen widget, Sign in with Apple, and an interface in English and French.

## Under the hood

- **SwiftUI and MVVM.** A `@MainActor` store injected with `@EnvironmentObject`, and async/await networking.
- **Storage.** Collections are saved as JSON files in Application Support with atomic writes (`FileStore`). Data from older versions is migrated from UserDefaults on first launch, and games, sessions, lists and goals can sync across devices through iCloud key-value storage.
- **Security.** Face ID and Touch ID, Keychain storage, and AES-GCM encryption and key derivation with CryptoKit (`SecurityManager`).
- **No secrets in the repo.** API keys are injected at build time from a gitignored `Secrets.xcconfig`.
- **Tests and CI.** 26 unit tests cover the store, file storage, IGDB title matching, security and the play timer. GitHub Actions builds, tests and runs SwiftLint on every push, and a release workflow archives the app and uploads it to TestFlight on version tags.

## Project status

| Part | Status |
| --- | --- |
| iOS app: library, diary, stats, goals, achievements, discover | ✅ Works |
| RAWG game data | ✅ Works with your own API key |
| IGDB box art | ✅ Optional, needs a Twitch app ID and secret |
| Home screen widget | ✅ Separate target, shares data through an App Group |
| Steam | ⚠️ Real REST client, needs your own Steam Web API key |
| PlayStation, Google sign-in | ⚠️ Stubs that show the intended API shape |
| Social feed | ⚠️ Local demo data, no backend yet |
| `Docker/` | ⚠️ Deployment sketch for a future backend, which isn't in this repo |

## Getting started

You need Xcode 26 and the iOS 26 SDK.

```bash
git clone https://github.com/AyoubO22/Gameboxd.git
cd Gameboxd
cp Secrets.xcconfig.example Secrets.xcconfig
```

Put your RAWG key in `Secrets.xcconfig` (free at [rawg.io/apidocs](https://rawg.io/apidocs)). The IGDB keys are optional and only add portrait box art. Then open `Gameboxd.xcodeproj`, pick an iPhone simulator and run.

The app also builds without any key: RAWG calls then return empty results.

## Project structure

```text
Gameboxd/
├── Models/             Game, Achievement, Goal, LinkedAccount
├── ViewModels/         GameStore (app state), TimerManager (play sessions)
├── Views/Screen/       Library, Diary, Discover, Statistics, Goals, Backlog, Profile…
├── Views/Components/   ShelfViews, GameBox3DView, PlayTimerView, StarRating, GameCard
├── Services/           RAWG, IGDB, Steam, FileStore, SecurityManager, sign-in
└── Utils/              DesignSystem, CachedAsyncImage, haptics
GameboxdWidget/         home screen widget
GameboxdTests/          unit tests
```

## Credits

Game data from [RAWG](https://rawg.io), box art from [IGDB](https://www.igdb.com), and the idea from [Letterboxd](https://letterboxd.com).
