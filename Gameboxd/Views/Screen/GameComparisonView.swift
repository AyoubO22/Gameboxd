//
//  GameComparisonView.swift
//  Gameboxd
//
//  Side-by-side comparison of two games from the user's library.
//

import SwiftUI

// MARK: - Game Comparison View

struct GameComparisonView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var preselectedGame: Game? = nil
    @State private var leftGame: Game? = nil
    @State private var rightGame: Game? = nil
    @State private var showingPickerFor: PickerSide? = nil

    enum PickerSide {
        case left, right
    }

    private var bothSelected: Bool {
        leftGame != nil && rightGame != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        pickerRow
                            .padding(.horizontal, DS.Spacing.md)

                        if bothSelected, let left = leftGame, let right = rightGame {
                            comparisonContent(left: left, right: right)
                                .padding(.horizontal, DS.Spacing.md)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        } else {
                            emptyPrompt
                                .transition(.opacity)
                        }
                    }
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xl)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bothSelected)
                }
            }
            .navigationTitle("Comparer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bothSelected {
                        Button("Réinitialiser") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                leftGame = nil
                                rightGame = nil
                            }
                        }
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .sheet(item: $showingPickerFor) { side in
                GamePickerSheet(
                    excludedGame: side == .left ? rightGame : leftGame,
                    allGames: store.myGames
                ) { selected in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if side == .left {
                            leftGame = selected
                        } else {
                            rightGame = selected
                        }
                    }
                }
            }
            .onAppear {
                if let game = preselectedGame, leftGame == nil {
                    leftGame = game
                }
            }
        }
    }

    // MARK: - Picker Row

    private var pickerRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            GamePickerButton(game: leftGame) {
                showingPickerFor = .left
            }

            // VS badge
            ZStack {
                Circle()
                    .fill(Color.surfaceSecondary)
                    .frame(width: 32, height: 32)

                Text("VS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.textTertiary)
            }

            GamePickerButton(game: rightGame) {
                showingPickerFor = .right
            }
        }
    }

    // MARK: - Empty Prompt

    private var emptyPrompt: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer(minLength: DS.Spacing.xxl)

            Image(systemName: "arrow.left.arrow.right.square")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.textTertiary)

            Text("Choisis deux jeux")
                .font(DS.Typography.headline)
                .foregroundStyle(Color.textSecondary)

            Text("Sélectionne deux jeux depuis ta bibliothèque pour les comparer côte à côte.")
                .font(DS.Typography.body)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)

            Spacer(minLength: DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comparison Content

    @ViewBuilder
    private func comparisonContent(left: Game, right: Game) -> some View {
        VStack(spacing: DS.Spacing.md) {
            coverSection(left: left, right: right)
            ratingSection(left: left, right: right)
            subRatingsSection(left: left, right: right)
            playTimeSection(left: left, right: right)
            completionSection(left: left, right: right)
            statusSection(left: left, right: right)
            genreSection(left: left, right: right)
        }
    }

    // MARK: - Cover Section

    private func coverSection(left: Game, right: Game) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            ComparisonCover(game: left)
            Spacer(minLength: 0)
            ComparisonCover(game: right)
        }
    }

    // MARK: - Rating Section

    private func ratingSection(left: Game, right: Game) -> some View {
        ComparisonCard(label: "Note globale", icon: "star.fill") {
            HStack(spacing: 0) {
                // Left
                HStack(spacing: DS.Spacing.xxs) {
                    Spacer()
                    MiniStarRow(rating: left.rating, isWinner: left.rating >= right.rating && left.rating > 0)
                }
                .frame(maxWidth: .infinity)

                // Divider
                comparisonDivider

                // Right
                HStack(spacing: DS.Spacing.xxs) {
                    MiniStarRow(rating: right.rating, isWinner: right.rating >= left.rating && right.rating > 0)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Sub-ratings Section

    private func subRatingsSection(left: Game, right: Game) -> some View {
        ComparisonCard(label: "Sous-notes", icon: "slider.horizontal.3") {
            VStack(spacing: DS.Spacing.sm) {
                ComparisonSubRatingRow(
                    label: "Histoire",
                    leftValue: left.subRatings.story,
                    rightValue: right.subRatings.story
                )
                Divider().background(Color.separator)
                ComparisonSubRatingRow(
                    label: "Gameplay",
                    leftValue: left.subRatings.gameplay,
                    rightValue: right.subRatings.gameplay
                )
                Divider().background(Color.separator)
                ComparisonSubRatingRow(
                    label: "Graphismes",
                    leftValue: left.subRatings.graphics,
                    rightValue: right.subRatings.graphics
                )
                Divider().background(Color.separator)
                ComparisonSubRatingRow(
                    label: "Son",
                    leftValue: left.subRatings.sound,
                    rightValue: right.subRatings.sound
                )
            }
        }
    }

    // MARK: - Play Time Section

    private func playTimeSection(left: Game, right: Game) -> some View {
        ComparisonCard(label: "Temps de jeu", icon: "clock.fill") {
            HStack(spacing: 0) {
                ComparisonValueCell(
                    value: left.formattedPlayTime,
                    isWinner: left.playTimeMinutes > right.playTimeMinutes,
                    alignment: .trailing
                )

                comparisonDivider

                ComparisonValueCell(
                    value: right.formattedPlayTime,
                    isWinner: right.playTimeMinutes > left.playTimeMinutes,
                    alignment: .leading
                )
            }
        }
    }

    // MARK: - Completion Section

    private func completionSection(left: Game, right: Game) -> some View {
        ComparisonCard(label: "Complétion", icon: "chart.bar.fill") {
            HStack(spacing: 0) {
                ComparisonValueCell(
                    value: "\(left.completionPercentage)%",
                    isWinner: left.completionPercentage > right.completionPercentage,
                    alignment: .trailing
                )

                comparisonDivider

                ComparisonValueCell(
                    value: "\(right.completionPercentage)%",
                    isWinner: right.completionPercentage > left.completionPercentage,
                    alignment: .leading
                )
            }
        }
    }

    // MARK: - Status Section

    private func statusSection(left: Game, right: Game) -> some View {
        ComparisonCard(label: "Statut", icon: "tag.fill") {
            HStack(spacing: 0) {
                // Left status
                HStack(spacing: DS.Spacing.xxs) {
                    Spacer()
                    Image(systemName: left.status.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(left.status.color)
                    Text(left.status.rawValue)
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(left.status.color)
                }
                .frame(maxWidth: .infinity)

                comparisonDivider

                // Right status
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: right.status.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(right.status.color)
                    Text(right.status.rawValue)
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(right.status.color)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Genre Section

    private func genreSection(left: Game, right: Game) -> some View {
        let leftSet = Set(left.genres)
        let rightSet = Set(right.genres)
        let shared = leftSet.intersection(rightSet)

        return ComparisonCard(label: "Genres", icon: "theatermasks.fill") {
            HStack(alignment: .top, spacing: 0) {
                // Left genres
                GenrePillGroup(
                    genres: left.genres,
                    sharedGenres: shared,
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity)

                comparisonDivider

                // Right genres
                GenrePillGroup(
                    genres: right.genres,
                    sharedGenres: shared,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private var comparisonDivider: some View {
        Rectangle()
            .fill(Color.separator)
            .frame(width: 1)
            .padding(.vertical, DS.Spacing.xxs)
    }
}

// MARK: - Picker Side: Identifiable conformance

extension GameComparisonView.PickerSide: Identifiable {
    var id: Int {
        switch self {
        case .left: return 0
        case .right: return 1
        }
    }
}

// MARK: - Game Picker Button

private struct GamePickerButton: View {
    let game: Game?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                // Cover thumbnail or placeholder
                Group {
                    if let game, let urlString = game.coverImageURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.surfaceSecondary
                        }
                    } else if let game {
                        Rectangle()
                            .fill(game.coverColor.gradient)
                            .overlay(
                                Image(systemName: "gamecontroller")
                                    .font(.title3)
                                    .foregroundStyle(Color.white.opacity(0.6))
                            )
                    } else {
                        Color.surfaceSecondary
                            .overlay(
                                VStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 22, weight: .light))
                                        .foregroundStyle(Color.accent)
                                    Text("Choisir")
                                        .font(DS.Typography.captionMedium)
                                        .foregroundStyle(Color.accent)
                                }
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .stroke(
                            game == nil ? Color.accent.opacity(0.4) : Color.separator,
                            style: StrokeStyle(
                                lineWidth: game == nil ? 1.5 : 0.5,
                                dash: game == nil ? [6, 4] : []
                            )
                        )
                )

                // Title below cover
                if let game {
                    Text(game.title)
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(game.platform)
                        .font(DS.Typography.micro)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    Text("Sélectionner un jeu")
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Comparison Cover (full-size header covers)

private struct ComparisonCover: View {
    let game: Game

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Group {
                if let urlString = game.coverImageURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                } else {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .overlay(
                            Image(systemName: "gamecontroller")
                                .font(.title)
                                .foregroundStyle(Color.white.opacity(0.5))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.separator, lineWidth: 0.5)
            )

            VStack(spacing: DS.Spacing.xxs) {
                Text(game.title)
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("\(game.developer) · \(game.releaseYear)")
                    .font(DS.Typography.micro)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Comparison Card Container

private struct ComparisonCard<Content: View>: View {
    let label: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accent)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .kerning(0.6)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xs)

            Divider()
                .background(Color.separator)

            content()
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.xs)
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }
}

// MARK: - Mini Star Row

private struct MiniStarRow: View {
    let rating: Int
    let isWinner: Bool

    var body: some View {
        HStack(spacing: 3) {
            if rating > 0 {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(star <= rating
                            ? (isWinner ? Color.accent : Color.textTertiary)
                            : Color.surfaceSecondary
                        )
                }
            } else {
                Text("—")
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
}

// MARK: - Sub-rating Row (bar chart)

private struct ComparisonSubRatingRow: View {
    let label: String
    let leftValue: Int
    let rightValue: Int

    private let maxValue: Int = 5

    private var leftIsWinner: Bool { leftValue > rightValue }
    private var rightIsWinner: Bool { rightValue > leftValue }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Left bar + value
            HStack(spacing: DS.Spacing.xs) {
                Spacer(minLength: 0)

                Text(leftValue > 0 ? "\(leftValue)" : "—")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(leftIsWinner ? Color.accent : Color.textTertiary)
                    .frame(width: 14, alignment: .trailing)

                RatingBar(value: leftValue, maxValue: maxValue, isWinner: leftIsWinner, mirrored: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)

            // Category label (center)
            Text(label)
                .font(DS.Typography.micro)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 72, alignment: .center)
                .lineLimit(1)

            // Right bar + value
            HStack(spacing: DS.Spacing.xs) {
                RatingBar(value: rightValue, maxValue: maxValue, isWinner: rightIsWinner, mirrored: false)
                    .frame(maxWidth: .infinity)

                Text(rightValue > 0 ? "\(rightValue)" : "—")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(rightIsWinner ? Color.accent : Color.textTertiary)
                    .frame(width: 14, alignment: .leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Rating Bar (horizontal progress bar)

private struct RatingBar: View {
    let value: Int
    let maxValue: Int
    let isWinner: Bool
    let mirrored: Bool

    private var fraction: CGFloat {
        guard maxValue > 0, value > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue)
    }

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width * fraction
            ZStack(alignment: mirrored ? .trailing : .leading) {
                // Track
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .fill(Color.surfaceSecondary)
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .fill(isWinner ? Color.accent : Color.textTertiary)
                    .frame(width: barWidth, height: 4)
                    .frame(maxWidth: .infinity, alignment: mirrored ? .trailing : .leading)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Comparison Value Cell

private struct ComparisonValueCell: View {
    let value: String
    let isWinner: Bool
    let alignment: HorizontalAlignment

    var body: some View {
        HStack {
            if alignment == .leading { Spacer() }

            HStack(spacing: DS.Spacing.xxs) {
                if isWinner {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accent)
                }

                Text(value)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isWinner ? Color.accent : Color.textTertiary)
            }

            if alignment == .trailing { Spacer() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxs)
    }
}

// MARK: - Genre Pill Group

private struct GenrePillGroup: View {
    let genres: [String]
    let sharedGenres: Set<String>
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xxs) {
            if genres.isEmpty {
                Text("—")
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, DS.Spacing.xs)
            } else {
                ForEach(genres, id: \.self) { genre in
                    let isShared = sharedGenres.contains(genre)
                    Text(genre)
                        .font(DS.Typography.micro)
                        .foregroundStyle(isShared ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(isShared ? Color.accent.opacity(0.12) : Color.surfaceSecondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs)
    }
}

// MARK: - Game Picker Sheet

struct GamePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let excludedGame: Game?
    let allGames: [Game]
    let onSelect: (Game) -> Void

    @State private var searchText: String = ""

    private var filteredGames: [Game] {
        let available = allGames.filter { $0.id != excludedGame?.id }
        guard !searchText.isEmpty else { return available }
        return available.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.developer.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                Group {
                    if filteredGames.isEmpty {
                        EmptyState(
                            icon: "magnifyingglass",
                            title: searchText.isEmpty ? "Bibliothèque vide" : "Aucun résultat",
                            message: searchText.isEmpty
                                ? "Ajoute des jeux à ta bibliothèque d'abord."
                                : "Essaie un autre terme de recherche."
                        )
                    } else {
                        List(filteredGames) { game in
                            Button {
                                onSelect(game)
                                dismiss()
                            } label: {
                                PickerGameRow(game: game)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.surfacePrimary)
                            .listRowSeparatorTint(Color.separator)
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Choisir un jeu")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Rechercher dans ta bibliothèque"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Color.accent)
                }
            }
        }
    }
}

// MARK: - Picker Game Row

private struct PickerGameRow: View {
    let game: Game

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Thumbnail
            Group {
                if let urlString = game.coverImageURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(game.coverColor.gradient)
                    }
                } else {
                    Rectangle()
                        .fill(game.coverColor.gradient)
                        .overlay(
                            Image(systemName: "gamecontroller")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.5))
                        )
                }
            }
            .frame(width: 44, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm - 2, style: .continuous))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(game.title)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(game.developer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.xs) {
                    if game.rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...game.rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                            }
                        }
                        .foregroundStyle(Color.accent)
                    }

                    TagPill(
                        label: game.status.rawValue,
                        icon: game.status.icon
                    )
                    .scaleEffect(0.85, anchor: .leading)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.vertical, DS.Spacing.xxs)
    }
}

// MARK: - Preview

#Preview("Comparison — Both selected") {
    let store = GameStore()
    return GameComparisonView()
        .environmentObject(store)
}

#Preview("Comparison — Empty") {
    GameComparisonView()
        .environmentObject(GameStore())
}
