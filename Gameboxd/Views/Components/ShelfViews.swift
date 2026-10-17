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
    /// Real cases are all 170 mm tall; Switch ones are thinner (11 mm against 14 mm).
    /// Spines are drawn a little wider than life so the title stays readable.
    var spineWidth: CGFloat { label == "SWITCH" ? 21 : 25 }
    var caseHeight: CGFloat { 204 }
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
            // The printed sleeve sits in a coloured plastic case: a thin lip shows round it.
            .padding(.vertical, 1.5)
            .padding(.horizontal, 0.5)
            .background(band.plastic)
            // The spine is rounded: shaded at both folds, a soft highlight just off-centre.
            .overlay(
                LinearGradient(stops: [
                    .init(color: .black.opacity(0.5), location: 0),
                    .init(color: .black.opacity(0.06), location: 0.16),
                    .init(color: .white.opacity(0.16), location: 0.3),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.2), location: 0.84),
                    .init(color: .black.opacity(0.55), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
            // The clear plastic catches the light from above.
            .overlay(alignment: .top) {
                LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 34)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(.black.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 1.5, x: 1)
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

/// A printed case spine, as on European cases: the platform's band at the top, the cover's
/// key art running down the spine, the title reading bottom to top, and the PEGI mark
/// at the foot. Shared by the shelf and the 3D box, so both show the same spine.
struct SpineFace: View {
    let title: String
    let band: PlatformBand
    let cover: UIImage?
    let tint: UIColor
    let pegi: Int?
    let width: CGFloat
    let height: CGFloat

    private var bandHeight: CGFloat { max(width * 1.15, height * 0.1).rounded() }
    private var badgeSize: CGFloat { (width * 0.62).rounded() }
    private var footHeight: CGFloat { pegi == nil ? (width * 0.4).rounded() : badgeSize + (width * 0.5).rounded() }

    var body: some View {
        let base = Color(tint)
        let artHeight = height - bandHeight
        let titleZone = artHeight - footHeight
        VStack(spacing: 0) {
            bandMark
                .frame(width: width, height: bandHeight)
                .background(band.color)

            ZStack(alignment: .top) {
                // The key art, continued round the spine as publishers print it.
                Group {
                    if let cover {
                        Image(uiImage: cover).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [base, base.mix(with: .black, by: 0.5)], startPoint: .top, endPoint: .bottom)
                    }
                }
                .frame(width: width, height: artHeight)
                .clipped()

                // Ink laid over the art so the title reads on any cover.
                LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.5), .black.opacity(0.62)],
                               startPoint: .top, endPoint: .bottom)

                VStack(spacing: 0) {
                    Text(title.uppercased())
                        .font(DS.Typography.spine(width * 0.56, weight: .black, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.5) // long titles shrink rather than lose their end
                        .shadow(color: .black.opacity(0.7), radius: 1)
                        .frame(width: titleZone - width * 0.5)
                        .rotationEffect(.degrees(-90))
                        .frame(width: width, height: titleZone)

                    Group {
                        if let pegi {
                            PEGIBadge(age: pegi, size: badgeSize)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: width, height: footHeight)
                }
            }
            .frame(width: width, height: artHeight)
        }
        .frame(width: width, height: height)
        .background(base)
    }

    /// The platform's logo at the top of the spine: across it when it fits, along it when not.
    @ViewBuilder private var bandMark: some View {
        if band.label.count <= 3 {
            Text(band.label)
                .font(.system(size: width * 0.38, weight: .heavy).width(.condensed))
                .foregroundStyle(band.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 2)
        } else {
            Text(band.label)
                .font(.system(size: width * 0.42, weight: .heavy).width(.condensed))
                .foregroundStyle(band.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(width: bandHeight - 4)
                .rotationEffect(.degrees(-90))
        }
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
    /// Width of the printed cover; the case keeps real proportions around it.
    var coverWidth: CGFloat = 115
    var showsProgress = true

    private var band: PlatformBand { PlatformBand(platform: game.platform) }
    private var coverHeight: CGFloat { (coverWidth * 1.39).rounded() }
    /// The clear-plastic lip round the sleeve, and the hinge on the left.
    private var rim: CGFloat { max(1, (coverWidth * 0.018).rounded()) }
    private var hinge: CGFloat { max(2, (coverWidth * 0.055).rounded()) }
    private var bandHeight: CGFloat { (coverWidth * 0.085).rounded() }

    var body: some View {
        HStack(spacing: 0) {
            // The hinge: a ridge of the case plastic, lit on its edge.
            ZStack(alignment: .trailing) {
                LinearGradient(colors: [band.plastic.mix(with: .black, by: 0.35), band.plastic, band.plastic.mix(with: .black, by: 0.2)],
                               startPoint: .leading, endPoint: .trailing)
                Color.white.opacity(0.18).frame(width: 0.5)
            }
            // Fixed height: a bare Color is flexible and would stretch to whatever height
            // the parent offers (e.g. the Discover endcap).
            .frame(width: hinge, height: coverHeight + rim * 2)

            ZStack(alignment: .top) {
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

                // The platform band printed across the top of the sleeve.
                if coverWidth >= 60 {
                    Text(band.label)
                        .font(.system(size: bandHeight * 0.62, weight: .heavy).width(.condensed))
                        .foregroundStyle(band.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, bandHeight * 0.4)
                        .frame(height: bandHeight)
                        .background(band.color)
                }
            }
            .frame(width: coverWidth, height: coverHeight)
            .overlay(alignment: .bottomLeading) {
                if showsProgress && game.completionPercentage > 0 {
                    Color.accent
                        .frame(width: coverWidth * CGFloat(min(game.completionPercentage, 100)) / 100, height: 3)
                }
            }
            // Under clear plastic: a broad diagonal sheen and a bright top edge.
            .overlay(
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.22), location: 0),
                    .init(color: .white.opacity(0.04), location: 0.35),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.12), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .padding(.vertical, rim)
            .padding(.trailing, rim)
            .background(band.plastic)
        }
        .clipShape(RoundedRectangle(cornerRadius: max(2, coverWidth * 0.035), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: max(2, coverWidth * 0.035), style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 7, y: 6)
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
                    // Games in progress stand face out, cover forward, like the new releases
                    // in a shop; the rest are spines packed tight.
                    let facesOut = section.id == "playing"
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .bottom, spacing: facesOut ? DS.Spacing.md : 1) {
                            ForEach(section.games) { game in
                                NavigationLink {
                                    GameDetailView(game: game)
                                        .navigationTransition(.zoom(sourceID: game.id, in: namespace))
                                } label: {
                                    if facesOut {
                                        FaceOutCase(game: game, coverWidth: 132)
                                    } else {
                                        GameSpine(game: game)
                                    }
                                }
                                .buttonStyle(PressableCardStyle())
                                .matchedTransitionSource(id: game.id, in: namespace)
                                .contextMenu { contextMenu(game) }
                                // Cases dim and shrink a touch as they slide off the edge.
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.55)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.94, anchor: .bottom)
                                }
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
