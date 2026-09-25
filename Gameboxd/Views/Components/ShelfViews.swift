//
//  ShelfViews.swift
//  Gameboxd
//
//  The collection as a real shelf: games you're playing face out,
//  everything else spine out, on walnut planks.
//

import SwiftUI

// MARK: - Shelf palette

enum Shelf {
    static let plankTop = Color(hex: "54473C")
    static let plankFace = Color(hex: "43382F")
    static let plankEdge = Color(hex: "342B24")
    static let wallTop = Color(hex: "2E2620")
}

/// One walnut plank. Runs edge to edge, whatever padding its parent has.
struct ShelfPlank: View {
    var body: some View {
        VStack(spacing: 0) {
            Shelf.plankTop.frame(height: 1)
            LinearGradient(colors: [Shelf.plankFace, Shelf.plankEdge], startPoint: .top, endPoint: .bottom)
                .frame(height: 13)
        }
        .shadow(color: .black.opacity(0.45), radius: 8, y: 8)
        .padding(.horizontal, -DS.Spacing.md)
        .accessibilityHidden(true)
    }
}

/// The small title above a shelf, like a label pinned to the plank.
struct ShelfLabel: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.Typography.title3)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text("\(count)")
                .font(DS.Typography.body)
                .foregroundStyle(Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Case geometry

extension PlatformBand {
    /// Switch cases are narrower and shorter than PlayStation, Xbox and PC ones.
    var spineWidth: CGFloat { label == "SWITCH" ? 30 : 40 }
    var caseHeight: CGFloat { label == "SWITCH" ? 150 : 172 }
}

// MARK: - Spine

struct GameSpine: View {
    let game: Game
    @State private var color: UIColor?

    private var band: PlatformBand { PlatformBand(platform: game.platform) }

    var body: some View {
        let base = color ?? UIColor(game.coverColor)
        VStack(spacing: 0) {
            Text(band.label)
                .font(DS.Typography.text(8, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .frame(height: 18)
                .background(band.color)

            Text(game.title.uppercased())
                .font(DS.Typography.display(16, weight: .black, relativeTo: .headline))
                .foregroundStyle(base.isLight ? Color.black.opacity(0.82) : Color.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: band.caseHeight - 30)
                .rotationEffect(.degrees(90))
                .frame(width: band.spineWidth, height: band.caseHeight - 18)
        }
        .frame(width: band.spineWidth, height: band.caseHeight)
        .background(Color(base))
        // Printed-plastic sheen and the edge where the case folds.
        .overlay(
            LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.22)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 1, bottomTrailingRadius: 1, topTrailingRadius: 3))
        .task(id: game.artURL) {
            guard let url = game.artURL else { return }
            let loaded = await ImageCache.shared.dominantColor(for: url)
            withAnimation(.easeOut(duration: 0.25)) { color = loaded }
        }
        .accessibilityElement()
        .accessibilityLabel("\(game.title), \(band.label.capitalized)")
    }
}

// MARK: - Face-out case (games in progress)

struct FaceOutCase: View {
    let game: Game
    @State private var spineColor: UIColor?

    var body: some View {
        HStack(spacing: 0) {
            Color(spineColor ?? UIColor(game.coverColor)).frame(width: 7)
            ZStack(alignment: .bottom) {
                Group {
                    if let url = game.artURL {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            game.coverColor
                        }
                    } else {
                        game.coverColor
                    }
                }
                .frame(width: 115, height: 160)
                .clipped()

                LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .center)

                if game.completionPercentage > 0 {
                    ProgressView(value: Double(game.completionPercentage), total: 100)
                        .tint(Color.accent)
                        .background(Color.black.opacity(0.5), in: Capsule())
                        .padding(8)
                }
            }
            .frame(width: 115, height: 160)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 7, y: 6)
        .task(id: game.artURL) {
            guard let url = game.artURL else { return }
            spineColor = await ImageCache.shared.dominantColor(for: url)
        }
        .accessibilityElement()
        .accessibilityLabel("\(game.title), \(game.completionPercentage) % terminé")
    }
}

// MARK: - The whole shelf

struct ShelfLibrary<Menu: View>: View {
    let games: [Game]
    let namespace: Namespace.ID
    @ViewBuilder let contextMenu: (Game) -> Menu

    @State private var width: CGFloat = 358

    private struct Section: Identifiable {
        let id: String
        let title: String
        let games: [Game]
        let faceOut: Bool
    }

    private var sections: [Section] {
        [
            Section(id: "playing", title: "En cours", games: games.filter { $0.status == .playing }, faceOut: true),
            Section(id: "backlog", title: "À jouer", games: games.filter { $0.status == .wantToPlay || $0.status == .none }, faceOut: false),
            Section(id: "done", title: "Terminés", games: games.filter { $0.status == .completed || $0.status == .platinum }, faceOut: false),
            Section(id: "shelved", title: "Abandonnés", games: games.filter { $0.status == .shelved }, faceOut: false),
        ].filter { !$0.games.isEmpty }
    }

    /// Greedy wrap: as many spines as fit on one plank, then the next plank.
    private func rows(_ games: [Game]) -> [[Game]] {
        var rows: [[Game]] = [[]]
        var used: CGFloat = 0
        for game in games {
            let w = PlatformBand(platform: game.platform).spineWidth + 3
            if used + w > width, !rows[rows.count - 1].isEmpty {
                rows.append([])
                used = 0
            }
            rows[rows.count - 1].append(game)
            used += w
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ShelfLabel(title: section.title, count: section.games.count)

                    if section.faceOut {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .bottom, spacing: DS.Spacing.md) {
                                ForEach(section.games) { game in
                                    link(game) { FaceOutCase(game: game) }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, DS.Spacing.xs)
                        }
                        .padding(.horizontal, -DS.Spacing.md)
                        ShelfPlank()
                    } else {
                        let rows = rows(section.games)
                        ForEach(rows.indices, id: \.self) { index in
                            let row = rows[index]
                            let isLastRow = index == rows.count - 1
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(row) { game in
                                    let leans = isLastRow && game.id == row.last?.id && row.count > 1
                                    link(game) {
                                        GameSpine(game: game)
                                            // The last case on a half-empty plank leans on its neighbour:
                                            // pivots on its bottom-right corner, top resting to the left.
                                            .rotationEffect(.degrees(leans ? -9 : 0), anchor: .bottomTrailing)
                                    }
                                    .padding(.leading, leans ? 24 : 0)
                                }
                            }
                            .padding(.top, DS.Spacing.xs)
                            ShelfPlank()
                                .padding(.bottom, isLastRow ? 0 : DS.Spacing.lg)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 - DS.Spacing.md * 2 }
    }

    private func link<Content: View>(_ game: Game, @ViewBuilder content: () -> Content) -> some View {
        NavigationLink {
            GameDetailView(game: game)
                .navigationTransition(.zoom(sourceID: game.id, in: namespace))
        } label: {
            content()
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: game.id, in: namespace)
        .contextMenu { contextMenu(game) }
    }
}
