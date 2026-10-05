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
    static let plankTop = Color(hex: "A0714A")
    static let plankFace = Color(hex: "74492C")
    static let plankEdge = Color(hex: "4A2D1A")
    static let wallTop = Color(hex: "36221A")
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
    @State private var cover: UIImage?
    @State private var color: UIColor?

    private var band: PlatformBand { PlatformBand(platform: game.platform) }

    var body: some View {
        SpineFace(title: game.title, band: band, cover: cover, tint: color ?? UIColor(game.coverColor),
                  pegi: game.pegi, width: band.spineWidth, height: band.caseHeight)
            // Printed-plastic sheen and the edge where the case folds.
            .overlay(
                LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.22)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 1, bottomTrailingRadius: 1, topTrailingRadius: 3))
            .task(id: game.artURL) {
                guard let url = game.artURL else { return }
                let image = await ImageCache.shared.load(url)
                let tint = await ImageCache.shared.dominantColor(for: url)
                withAnimation(.easeOut(duration: 0.25)) {
                    cover = image
                    color = tint
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(game.title), \(band.label.capitalized)")
    }
}

/// A printed case spine, as on European cases: the platform band, a slice of the cover art
/// under the title (fading into the cover's own colour), and the PEGI badge at the foot.
/// Shared by the shelf and the 3D box, so both show the same spine.
struct SpineFace: View {
    let title: String
    let band: PlatformBand
    let cover: UIImage?
    let tint: UIColor
    let pegi: Int?
    let width: CGFloat
    let height: CGFloat

    private var bandHeight: CGFloat { (height * 0.105).rounded() }
    private var badgeZone: CGFloat { pegi == nil ? 0 : (width * 0.95).rounded() }

    var body: some View {
        let bodyHeight = height - bandHeight
        VStack(spacing: 0) {
            Text(band.label)
                .font(DS.Typography.text(max(7, width * 0.2), weight: .bold, relativeTo: .caption2))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width, height: bandHeight)
                .background(band.color)

            ZStack(alignment: .bottom) {
                // A vertical slice through the middle of the cover art…
                Group {
                    if let cover {
                        Image(uiImage: cover).resizable().scaledToFill()
                    } else {
                        Color(tint)
                    }
                }
                .frame(width: width, height: bodyHeight)
                .clipped()

                // …fading into the cover's own colour towards the foot, and dimmed under the title.
                LinearGradient(colors: [Color(tint).opacity(0.2), Color(tint).opacity(0.95)], startPoint: .top, endPoint: .bottom)
                Color.black.opacity(0.2)

                Text(title.uppercased())
                    .font(DS.Typography.display(width * 0.44, weight: .black, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: bodyHeight - badgeZone - width * 0.3)
                    .rotationEffect(.degrees(90))
                    .frame(width: width, height: bodyHeight - badgeZone)
                    .frame(maxHeight: .infinity, alignment: .top)

                if let pegi {
                    PEGIBadge(age: pegi, size: (width * 0.62).rounded())
                        .padding(.bottom, (width * 0.18).rounded())
                }
            }
            .frame(width: width, height: bodyHeight)
        }
        .frame(width: width, height: height)
    }
}

/// The PEGI age mark printed at the foot of European game cases.
struct PEGIBadge: View {
    let age: Int
    let size: CGFloat

    private var color: Color {
        switch age {
        case ..<8: return Color(hex: "7AB829")    // PEGI 3, 7
        case ..<17: return Color(hex: "F7A600")   // PEGI 12, 16
        default: return Color(hex: "E3001B")      // PEGI 18
        }
    }

    var body: some View {
        Text("\(age)")
            .font(DS.Typography.text(size * 0.52, weight: .bold, relativeTo: .caption2))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous).stroke(.white.opacity(0.9), lineWidth: max(0.8, size * 0.05)))
            .accessibilityLabel("PEGI \(age)")
    }
}

// MARK: - Face-out case (games in progress)

struct FaceOutCase: View {
    let game: Game
    /// Width of the printed cover; the case keeps DVD-case proportions around it.
    var coverWidth: CGFloat = 115
    var showsProgress = true
    @State private var spineColor: UIColor?

    private var coverHeight: CGFloat { (coverWidth * 1.39).rounded() }

    var body: some View {
        HStack(spacing: 0) {
            // Fixed height: a bare Color is flexible and would stretch to whatever height
            // the parent offers (e.g. the Discover endcap).
            Color(spineColor ?? UIColor(game.coverColor))
                .frame(width: max(4, (coverWidth * 0.06).rounded()), height: coverHeight)
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
                .frame(width: coverWidth, height: coverHeight)
                .clipped()

                LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .center)

                if showsProgress && game.completionPercentage > 0 {
                    ProgressView(value: Double(game.completionPercentage), total: 100)
                        .tint(Color.accent)
                        .background(Color.black.opacity(0.5), in: Capsule())
                        .padding(8)
                }
            }
            .frame(width: coverWidth, height: coverHeight)
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
