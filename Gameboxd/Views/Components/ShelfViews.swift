//
//  ShelfViews.swift
//  Gameboxd
//
//  The collection as a real shelf: games you're playing face out,
//  everything else spine out, on graphite planks.
//

import SwiftUI

// MARK: - Shelf palette

enum Shelf {
    static let plankTop = Color(hex: "4A525D")
    static let plankFace = Color(hex: "2E343C")
    static let plankEdge = Color(hex: "1A1E24")
    static let wallTop = Color(hex: "161A1F")
}

/// One graphite plank. Runs edge to edge, whatever padding its parent has.
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
    var spineWidth: CGFloat { label == "SWITCH" ? 32 : 40 }
    var caseHeight: CGFloat { label == "SWITCH" ? 176 : 200 }
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

/// A printed case spine, as on European cases: the platform band, a small square of the
/// cover art, the title on the cover's own colour, and the PEGI badge at the foot.
/// Shared by the shelf and the 3D box, so both show the same spine.
struct SpineFace: View {
    let title: String
    let band: PlatformBand
    let cover: UIImage?
    let tint: UIColor
    let pegi: Int?
    let width: CGFloat
    let height: CGFloat

    private var bandHeight: CGFloat { (height * 0.09).rounded() }
    private var badgeSize: CGFloat { (width * 0.42).rounded() }
    private var badgeZone: CGFloat { pegi == nil ? 0 : badgeSize + (width * 0.3).rounded() }

    var body: some View {
        let base = Color(tint)
        // The cover's key art, taller than wide: enough of it to recognise the game.
        let artHeight = (width * 1.5).rounded()
        let titleHeight = height - bandHeight - artHeight - badgeZone
        VStack(spacing: 0) {
            Text(band.label)
                .font(DS.Typography.text(max(7, width * 0.18), weight: .bold, relativeTo: .caption2))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width, height: bandHeight)
                .background(band.color)

            // The cover's key art, under the band.
            Group {
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    base
                }
            }
            .frame(width: width, height: artHeight)
            .clipped()

            Text(title.uppercased())
                .font(DS.Typography.spine(width * 0.4, weight: .black, relativeTo: .headline))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.55) // long titles shrink rather than lose their end
                .frame(width: titleHeight - width * 0.3)
                .rotationEffect(.degrees(90))
                .frame(width: width, height: titleHeight)

            if let pegi {
                PEGIBadge(age: pegi, size: badgeSize)
                    .frame(width: width, height: badgeZone)
            }
        }
        .frame(width: width, height: height)
        // Solid printed colour, darkened so white titles always read.
        .background(LinearGradient(colors: [base.mix(with: .black, by: 0.3), base.mix(with: .black, by: 0.55)],
                                   startPoint: .top, endPoint: .bottom))
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
            .font(DS.Typography.text(size * 0.55, weight: .heavy, relativeTo: .caption2))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.15, style: .continuous))
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
            Color(spineColor ?? UIColor(game.coverColor)).mix(with: .black, by: 0.45)
                .frame(width: 4, height: coverHeight)
            ZStack(alignment: .bottomLeading) {
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
                    Color.accent
                        .frame(width: coverWidth * CGFloat(min(game.completionPercentage, 100)) / 100, height: 3)
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

/// The collection as a packed shelf, one row per status that scrolls sideways, spines
/// touching like real cases. Tapping a spine opens the game's page.
struct ShelfLibrary<Menu: View>: View {
    let games: [Game]
    let namespace: Namespace.ID
    @ViewBuilder let contextMenu: (Game) -> Menu

    private struct Section: Identifiable {
        let id: String
        let title: String
        let games: [Game]
    }

    private var sections: [Section] {
        [
            Section(id: "playing", title: "En cours", games: games.filter { $0.status == .playing }),
            Section(id: "backlog", title: "À jouer", games: games.filter { $0.status == .wantToPlay || $0.status == .none }),
            Section(id: "done", title: "Terminés", games: games.filter { $0.status == .completed || $0.status == .platinum }),
            Section(id: "shelved", title: "Abandonnés", games: games.filter { $0.status == .shelved }),
        ].filter { !$0.games.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    ShelfLabel(title: section.title, count: section.games.count)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: 1) {
                            ForEach(section.games) { game in
                                NavigationLink {
                                    GameDetailView(game: game)
                                        .navigationTransition(.zoom(sourceID: game.id, in: namespace))
                                } label: {
                                    GameSpine(game: game)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: game.id, in: namespace)
                                .contextMenu { contextMenu(game) }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.xs)
                    }
                    .padding(.horizontal, -DS.Spacing.md)
                    ShelfPlank()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}
