//
//  OnboardingView.swift
//  Gameboxd
//
//  First launch: the player fills their shelf instead of reading about it. They tap the games
//  they have played, say where they are with each one, and land on a shelf that is already theirs.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @Binding var hasCompletedOnboarding: Bool

    private enum Step { case welcome, pick, status, done }

    @State private var step = Step.welcome
    @State private var picked: [Game] = []
    /// Index of the picked game whose status is being asked.
    @State private var asking = 0
    @State private var loading = false

    /// Well-known games to choose from: the top rated and the trending ones, once each.
    private var choices: [Game] {
        var seen = Set<Int>()
        return (store.topRated + store.trendingGames)
            .filter { game in game.rawgId.map { seen.insert($0).inserted } ?? false }
            .prefix(18)
            .map { $0 }
    }

    /// The welcome fan: games whose box art has arrived (the others show a screenshot until then).
    private var fanGames: [Game] {
        let withArt = choices.filter { !($0.boxArtURL ?? "").isEmpty }
        return Array((withArt.count >= 3 ? withArt : choices).prefix(3))
    }

    var body: some View {
        ZStack {
            Color.gbDark.ignoresSafeArea()
            switch step {
            case .welcome: welcome.transition(.push(from: .trailing))
            case .pick: pick.transition(.push(from: .trailing))
            case .status: status.transition(.push(from: .trailing))
            case .done: done.transition(.push(from: .trailing))
            }
        }
        .animation(.smooth(duration: 0.45), value: step)
        .task {
            if choices.count < 9 {
                loading = true
                await store.loadDiscoverData()
                loading = false
            }
            // Cached Discover lists can still lack box art: fetch it so cases show their covers.
            await store.fillDiscoverBoxArt()
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            CaseFan(games: fanGames)
                .frame(height: 220)
            Text("Gameboxd")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(Color.textPrimary)
            Text("Range tous tes jeux sur une étagère, comme à la maison.")
                .font(DS.Typography.bodyLarge)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
            BigButton(title: "C'est parti", icon: "arrow.right") { step = .pick }
        }
        .padding(.bottom, DS.Spacing.xl)
    }

    // MARK: - Pick the games already played

    private var pick: some View {
        VStack(spacing: DS.Spacing.md) {
            StepTitle(title: "Touche les jeux auxquels tu as joué",
                      subtitle: "Ils iront sur ton étagère. Tu pourras en ajouter d'autres plus tard.")
            if choices.isEmpty {
                Spacer()
                if loading {
                    ProgressView().tint(.gbCoral)
                } else {
                    Label("Pas de connexion pour l'instant. Tu ajouteras tes jeux plus tard.", systemImage: "wifi.slash")
                        .font(DS.Typography.body)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: 3),
                              spacing: DS.Spacing.lg) {
                        ForEach(choices) { game in
                            PickableCase(game: game, isPicked: picked.contains { $0.id == game.id }) { toggle(game) }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .scrollIndicators(.hidden)
            }
            BigButton(title: picked.isEmpty ? "Passer" : "Ajouter \(picked.count) jeu\(picked.count > 1 ? "x" : "")",
                      icon: picked.isEmpty ? "forward.fill" : "plus",
                      quiet: picked.isEmpty) {
                asking = 0
                step = picked.isEmpty ? .done : .status
            }
        }
        .padding(.bottom, DS.Spacing.xl)
        .sensoryFeedback(.selection, trigger: picked.count)
    }

    private func toggle(_ game: Game) {
        if let index = picked.firstIndex(where: { $0.id == game.id }) {
            picked.remove(at: index)
        } else {
            picked.append(game)
        }
    }

    // MARK: - Where are you with each one

    private var status: some View {
        let game = picked[min(asking, picked.count - 1)]
        return VStack(spacing: DS.Spacing.lg) {
            StepTitle(title: "Où en es-tu avec ce jeu ?", subtitle: "\(asking + 1) sur \(picked.count)")
            Spacer(minLength: 0)
            FaceOutCase(game: game, coverWidth: 170)
                .id(game.id)
                .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            Text(game.title)
                .font(DS.Typography.title3)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
            Spacer(minLength: 0)
            VStack(spacing: DS.Spacing.sm) {
                StatusChoice(title: "J'y joue en ce moment", status: .playing) { answer(.playing) }
                StatusChoice(title: "Je l'ai fini", status: .completed) { answer(.completed) }
                StatusChoice(title: "Je veux y jouer", status: .wantToPlay) { answer(.wantToPlay) }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.bottom, DS.Spacing.xl)
        .animation(.smooth(duration: 0.35), value: asking)
        .sensoryFeedback(.success, trigger: asking)
    }

    private func answer(_ status: GameStatus) {
        var game = picked[asking]
        game.status = status
        store.updateGame(game)
        if asking + 1 < picked.count {
            asking += 1
        } else {
            step = .done
        }
    }

    // MARK: - Done

    private var done: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            if picked.isEmpty {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.gbCoral.gradient)
            } else {
                CaseFan(games: Array(picked.suffix(3)))
                    .frame(height: 220)
            }
            Text(picked.isEmpty ? "Ton étagère t'attend" : "Ton étagère est prête !")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Hint(icon: "hand.tap.fill", text: "Touche un boîtier pour le noter et suivre ta partie.")
                Hint(icon: "magnifyingglass", text: "Cherche un jeu pour l'ajouter à ton étagère.")
                Hint(icon: "playstation.logo", text: "Relie ta PlayStation ou Steam dans Profil pour tout importer.")
            }
            .padding(.horizontal, DS.Spacing.xl)
            Spacer()
            BigButton(title: "Voir mon étagère", icon: "books.vertical.fill") { finish() }
        }
        .padding(.bottom, DS.Spacing.xl)
    }

    private func finish() {
        // The app is already built underneath: this only fades the onboarding away.
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Pieces

/// Three cases fanned out like a hand of cards, the middle one in front.
private struct CaseFan: View {
    let games: [Game]
    @State private var shown = false

    var body: some View {
        ZStack {
            if games.isEmpty {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.gbCoral.gradient)
            }
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                let offset = Double(index) - Double(games.count - 1) / 2
                FaceOutCase(game: game, coverWidth: 130)
                    .rotationEffect(.degrees(shown ? offset * 12 : 0), anchor: .bottom)
                    .offset(x: shown ? offset * 70 : 0, y: shown ? abs(offset) * 14 : 0)
                    .zIndex(-abs(offset))
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.15)) { shown = true }
        }
    }
}

private struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.title)
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .font(DS.Typography.body)
                .foregroundStyle(Color.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.lg)
    }
}

/// A case in the picking grid: tapped, it lifts and takes a tick.
private struct PickableCase: View {
    let game: Game
    let isPicked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(spacing: DS.Spacing.xs) {
                FaceOutCase(game: game, coverWidth: 96)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.gbCoral)
                            .offset(x: 8, y: -8)
                            .scaleEffect(isPicked ? 1 : 0.2)
                            .opacity(isPicked ? 1 : 0)
                    }
                    .scaleEffect(isPicked ? 1.06 : 1)
                    .opacity(isPicked ? 1 : 0.85)
                Text(game.title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isPicked ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPicked)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(game.title)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

/// One answer to "where are you with this game", as big as a thumb.
private struct StatusChoice: View {
    let title: String
    let status: GameStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: status.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 32)
                Text(title)
                    .font(DS.Typography.headline)
                Spacer()
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: 60)
            .background(status.color.opacity(0.22), in: .rect(cornerRadius: DS.Radius.lg))
            .overlay { RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(status.color.opacity(0.7), lineWidth: 1.5) }
        }
        .buttonStyle(.plain)
    }
}

private struct Hint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.gbCoral)
                .frame(width: 28)
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

/// The step's one action, across the bottom of the screen.
private struct BigButton: View {
    let title: String
    let icon: String
    var quiet = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DS.Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.glassProminent)
        .tint(quiet ? Color.gbSurface2 : Color.gbCoral)
        .padding(.horizontal, DS.Spacing.xl)
    }
}

// MARK: - Preview
#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environment(GameStore())
}
