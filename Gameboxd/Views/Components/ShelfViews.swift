//
//  ShelfViews.swift
//  Gameboxd
//
//  The collection as a real bookcase: games you're playing face out, everything else spine
//  out, standing on graphite planks under one room lamp. Cases are drawn to scale from real
//  European retail cases (CaseModel.swift) and printed like their sleeves (CasePrint.swift).
//

import SwiftUI

// MARK: - Shelf tokens

enum Shelf {
    /// The shelf's scale: 1.2 pt per millimetre, so a 170 mm console case stands 204 pt. Raise to
    /// 1.3 if spine titles read too small: every size follows.
    static let mm: CGFloat = 1.2
    /// Spines are drawn 1.2× thicker than life so a title stays readable; heights and fronts stay true.
    static let spineBoost: CGFloat = 1.2
    /// Spine titles run top to bottom, as on PAL PS4/PS5/Switch cases. Check one; -90 if not.
    static let titleAngle: Double = 90
    /// The plank's top face, seen from just above, and its front edge (an 18 mm board with an edge band).
    static let plankTopDepth: CGFloat = 8
    static let plankFront: CGFloat = 20
    /// How far above the plank's front edge a case's foot stands: spines are pushed a few
    /// centimetres in; face-out cases lean on the wall at the back.
    static let spineSeat: CGFloat = 4
    static let faceOutSeat: CGFloat = 7
    /// Wall above a row's tallest case, so a lean, a press or a shadow is never clipped.
    static let headroom: CGFloat = 8
    static let faceOutGap: CGFloat = 14
    /// Degrees: face-out cases lean back against the wall; the last spine of a row leans on its neighbour.
    static let faceOutLean: Double = 4
    static let lastCaseLean: Double = 6

    /// Other screens tint their background with the shelf's wall.
    static let wallTop = Color(hex: "161A1F")
    /// The back panel of one bay, top to bottom: dark under the plank above, lit in the middle,
    /// darker again in the corner behind the cases' feet.
    static let wallStops: [Gradient.Stop] = [
        .init(color: Color(hex: "07080A"), location: 0),
        .init(color: Color(hex: "0C0E12"), location: 0.06),
        .init(color: Color(hex: "13171C"), location: 0.2),
        .init(color: Color(hex: "1A1F26"), location: 0.45),
        .init(color: Color(hex: "171B21"), location: 0.8),
        .init(color: Color(hex: "0F1216"), location: 1),
    ]
    /// The plank's top, back (the crease with the wall) to front.
    static let plankTopStops: [Gradient.Stop] = [
        .init(color: Color(hex: "15181D"), location: 0),
        .init(color: Color(hex: "262B32"), location: 0.3),
        .init(color: Color(hex: "3A414A"), location: 0.85),
        .init(color: Color(hex: "4C5560"), location: 1),
    ]
    /// The plank's front edge, top to bottom: the rounded edge band catches the lamp, then falls dark.
    static let plankFrontStops: [Gradient.Stop] = [
        .init(color: Color(hex: "5F6875"), location: 0),
        .init(color: Color(hex: "3E4550"), location: 0.06),
        .init(color: Color(hex: "313740"), location: 0.4),
        .init(color: Color(hex: "262B32"), location: 0.85),
        .init(color: Color(hex: "1B1F25"), location: 0.96),
        .init(color: Color(hex: "0D0F12"), location: 1),
    ]

    /// FNV-1a over the title: unlike `hashValue` the same on every launch, so a game keeps its
    /// spine design, typeface and small imperfections.
    static func printSeed(_ title: String) -> UInt64 {
        title.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}

// MARK: - Bookcase

/// The plank's top face, seen from just above.
struct PlankTop: View {
    var body: some View {
        LinearGradient(stops: Shelf.plankTopStops, startPoint: .top, endPoint: .bottom)
            .accessibilityHidden(true)
    }
}

/// One graphite plank's front edge, matte (it reflects nothing), and its shadow on whatever lies
/// below; a bay underneath paints over that shadow with its own wall. Runs edge to edge,
/// whatever padding its parent has.
struct ShelfPlank: View {
    var body: some View {
        LinearGradient(stops: Shelf.plankFrontStops, startPoint: .top, endPoint: .bottom)
            .frame(height: Shelf.plankFront)
            .background(alignment: .bottom) {
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 14)
                    .offset(y: 14)
            }
            .padding(.horizontal, -DS.Spacing.md)
            .accessibilityHidden(true)
    }
}

/// The back panel of one bay of the bookcase.
struct ShelfWall: View {
    var body: some View {
        LinearGradient(stops: Shelf.wallStops, startPoint: .top, endPoint: .bottom)
            .overlay { Rectangle().fill(ImagePaint(image: PrintGrain.tile)).opacity(0.04) } // no banding in the dark
            .accessibilityHidden(true)
    }
}

/// The room's lamp is up and to the left: a row is brightest a little left of the middle and
/// falls off towards both ends, and each shelf further from the ceiling is a touch darker.
/// Fixed to the screen, so cases slide through the light (shelves don't fade out at the ends).
struct ShelfLight: View {
    let row: Int

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: .black.opacity(0.14), location: 0),
                .init(color: .black.opacity(0), location: 0.28),
                .init(color: .black.opacity(0), location: 0.58),
                .init(color: .black.opacity(0.24), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            Color.black.opacity(min(0.09, 0.03 * Double(row)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Stands a row of cases on a plank. The row must end with `Shelf.spineSeat` or
    /// `Shelf.faceOutSeat` of bottom padding: the plank's top face is drawn behind that strip,
    /// so feet and contact shadows land on it, and the front edge follows right underneath.
    func standingOnPlank() -> some View {
        VStack(spacing: 0) {
            self.background(alignment: .bottom) {
                PlankTop().frame(height: Shelf.plankTopDepth)
            }
            ShelfPlank()
                .padding(.horizontal, DS.Spacing.md) // ShelfPlank bleeds by md on its own
        }
    }

    /// Stands a row of face-out cases on a plank drawn behind it. The row must end with
    /// `Shelf.faceOutSeat` (over the plank's top face) then `Shelf.plankFront` (over its front
    /// edge), where the cases' shelf-edge labels go, scrolling with them.
    func labelledPlankBehind() -> some View {
        background(alignment: .bottom) {
            VStack(spacing: 0) {
                PlankTop().frame(height: Shelf.plankTopDepth)
                ShelfPlank()
                    .padding(.horizontal, DS.Spacing.md) // ShelfPlank bleeds by md on its own
            }
        }
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

// MARK: - Printed spine

/// A printed case spine as on European cases, top to bottom: the platform's header, the title,
/// the publisher's mark and the PEGI label, on the art that wraps round from the front or a
/// colour taken from it. Flat print only: the shelf and the 3D box light it themselves, and
/// ImageRenderer draws it for the box, so everything it shows arrives through its inputs.
struct SpineFace: View {
    let title: String
    let band: PlatformBand
    /// The whole cover: the 3D box cuts the spine's art from it when there's no `art`.
    let cover: UIImage?
    /// The spine's colour when there's no art to take it from.
    let tint: UIColor
    let pegi: Int?
    let width: CGFloat
    /// Height of the printed insert (on the shelf, the case's plastic shows above and below it).
    let height: CGFloat
    /// The cover's left edge, already cut for this platform (the shelf).
    var art: SpineArt?
    /// The developer, printed near the foot where publishers put their logo.
    var studio: String = ""

    /// What the spine is printed on. Real shelves mix them; each title gets one, the same on every launch.
    private enum Ground { case wrap, solid, black, nintendoRed }

    var body: some View {
        let seed = Shelf.printSeed(title)
        let ground = Self.groundKind(seed: seed, kind: band.kind)
        let paper = Self.paperColor(ground, art: art, tint: tint)
        let ink = paper.isLight ? Color(hex: "151515") : Color(hex: "F2F3F5")
        let mark = StudioMark.style(studio: studio, kind: band.kind)
        // Zones, top to bottom: header, margin, title, margin, publisher mark, margin, PEGI, foot.
        let header = SpineHeader.height(for: band.kind, width: width, printHeight: height)
        let margin = (width * 0.35).rounded()
        let markHeight: CGFloat = mark.map { $0 == .nintendo ? (width * 1.9).rounded() : (width * 0.62).rounded() } ?? 0
        let badge = (width * 0.62).rounded()
        let label: CGFloat = pegi == nil ? 0 : PEGIBadge.height(for: badge) + 1 // a 0.5 pt keyline each side
        let foot = (width * 0.2).rounded()
        let titleZone = max(width * 2, height - header - margin * 3 - markHeight - label - foot)

        VStack(spacing: 0) {
            SpineHeader(band: band, width: width, height: header)
            SpineTitle(title: title, face: SpineFont.pick(seed: seed, kind: band.kind), ink: ink, width: width, length: titleZone)
                .padding(.vertical, margin)
            if let mark {
                StudioMark(style: mark, ink: ink, width: width)
                    .frame(width: width, height: markHeight)
            }
            Spacer(minLength: margin)
            if let pegi {
                PEGIBadge(age: pegi, size: badge, keyline: true)
            }
            Color.clear.frame(height: foot)
        }
        .frame(width: width, height: height)
        .background { field(ground, paper: Color(paper)) }
        .clipped()
        // Printed card isn't flat colour.
        .overlay { Rectangle().fill(ImagePaint(image: PrintGrain.tile)).opacity(0.05) }
    }

    /// The colour a spine is printed on. A face-out case shows it too, where the insert rolls
    /// round its hinge.
    static func paper(title: String, kind: PlatformBand.Kind, art: SpineArt?, tint: UIColor) -> UIColor {
        paperColor(groundKind(seed: Shelf.printSeed(title), kind: kind), art: art, tint: tint)
    }

    private static func groundKind(seed: UInt64, kind: PlatformBand.Kind) -> Ground {
        switch kind {
        case .switch1: return .nintendoRed   // the "red wall": every Switch 1 spine
        case .switch2: return .wrap          // EU Switch 2 spines: plain type on the key art
        default:
            switch seed % 20 {
            case 0..<11: return .wrap
            case 11..<17: return .solid
            default: return .black
            }
        }
    }

    private static func paperColor(_ ground: Ground, art: SpineArt?, tint: UIColor) -> UIColor {
        switch ground {
        case .wrap, .solid: return art?.ground ?? tint
        case .black: return UIColor(red: 0.067, green: 0.071, blue: 0.078, alpha: 1)    // #111214
        case .nintendoRed: return UIColor(red: 0.902, green: 0, blue: 0.071, alpha: 1)  // #E60012
        }
    }

    /// What the spine is printed on, the whole height (opaque headers cover its top).
    @ViewBuilder private func field(_ ground: Ground, paper: Color) -> some View {
        if ground == .wrap, art?.strip != nil || cover != nil {
            ZStack {
                if let strip = art?.strip {
                    Image(uiImage: strip).resizable().scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                } else if let cover {
                    // The 3D box: the front laid out at its own size, its left edge kept.
                    Image(uiImage: cover).resizable().scaledToFill()
                        .frame(width: (width / band.kind.sleeve.spineFraction).rounded(), height: height)
                        .frame(width: width, height: height, alignment: .leading)
                        .clipped()
                }
                // The designer's plate behind the lettering: the art keeps its texture but evens out.
                LinearGradient(stops: [
                    .init(color: paper.opacity(0.15), location: 0),
                    .init(color: paper.opacity(0.6), location: 0.25),
                    .init(color: paper.opacity(0.6), location: 0.8),
                    .init(color: paper.opacity(0.3), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        } else {
            paper
        }
    }
}

// MARK: - Spine on the shelf

/// A case standing spine out: the printed spine between the case's own plastic, lit by the
/// room. No clip, shadow, blur, mask or blend mode: the silhouette is the rounded caps plus
/// the straight print, and every light layer is a fill of the same rounded rectangle, so a
/// shelf of 100+ spines renders without offscreen passes.
struct GameSpine: View {
    let game: Game
    /// Degrees the case leans left onto its neighbour, pivoting on its bottom-left corner.
    let lean: Double
    @State private var art: SpineArt?

    init(game: Game, lean: Double = 0) {
        self.game = game
        self.lean = lean
        // A spine scrolling back into view prints at once from memory, without a flash of flat colour.
        let kind = PlatformBand(platform: game.platform).kind
        _art = State(initialValue: game.artURL.flatMap { ImageCache.shared.cachedSpineArt(for: $0, kind: kind) })
    }

    var body: some View {
        let band = PlatformBand(platform: game.platform)
        let kind = band.kind
        let width = band.spineWidth
        let height = band.caseHeight
        let cap = band.capHeight
        let corner = band.spineCorner
        let seed = Shelf.printSeed(game.title)
        VStack(spacing: 0) {
            CaseCap(plastic: kind.plastic, corner: corner, isTop: true)
                .frame(height: cap)
            SpineFace(title: game.title, band: band, cover: nil, tint: UIColor(game.coverColor), pegi: game.pegi,
                      width: width, height: height - cap * 2, art: art, studio: game.developer)
                .overlay { InsertEdges() }
            CaseCap(plastic: kind.plastic, corner: corner, isTop: false)
                .frame(height: cap)
        }
        .frame(width: width, height: height)
        .overlay { SpineShading(corner: corner, seed: seed) }
        .overlay { SpineGlints(width: width, height: height, corner: corner, seed: seed) }
        .background(alignment: .bottomTrailing) { CaseCastShadow(height: height) }
        .rotationEffect(.degrees(-lean), anchor: .bottomLeading)
        // After the lean, so it lies flat on the plank. A leaning case stands on its left edge only.
        .background(alignment: lean == 0 ? Alignment.bottom : .bottomLeading) {
            CaseContactShadow(width: lean == 0 ? width + 1 : (width * 0.5).rounded()) // +1: no light seam between packed cases
        }
        .task(id: "\(kind.rawValue)|\(game.artURL?.absoluteString ?? "")") {
            guard let url = game.artURL else {
                art = nil
                return
            }
            let found = await ImageCache.shared.spineArt(for: url, kind: kind)
            if found !== art {
                withAnimation(.easeOut(duration: 0.2)) { art = found }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(game.title), \(band.label.capitalized)")
    }
}

/// The case's own plastic above or below the insert (5 mm on a 170 mm case). Its rounded rim
/// catches the lamp at the top; at the foot it rolls under, towards the plank's shadow.
private struct CaseCap: View {
    let plastic: CasePlastic
    let corner: CGFloat
    let isTop: Bool

    var body: some View {
        let stops: [Gradient.Stop] = isTop ? [
            .init(color: plastic.lit, location: 0),
            .init(color: plastic.base, location: 0.55),
            .init(color: plastic.base.mix(with: .black, by: 0.2), location: 1), // the lip over the insert's edge
        ] : [
            .init(color: plastic.base, location: 0),
            .init(color: plastic.shade, location: 0.6),
            .init(color: plastic.shade.mix(with: .black, by: 0.35), location: 1),
        ]
        let rimLight: [Color] = isTop ? [.white.opacity(0.55), .white.opacity(0.18)] : [.white.opacity(0.14), .white.opacity(0.06)]
        UnevenRoundedRectangle(topLeadingRadius: isTop ? corner : 0, bottomLeadingRadius: isTop ? 0 : corner,
                               bottomTrailingRadius: isTop ? 0 : corner, topTrailingRadius: isTop ? corner : 0,
                               style: .continuous)
            .fill(LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                // Top: the lamp's line along the rounded rim, stronger on the lamp's side.
                // Foot: the lip's upper edge, a faint line just under the print.
                LinearGradient(colors: rimLight, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 0.5)
                    .padding(.top, isTop ? 0.75 : 0)
                    .padding(.horizontal, isTop ? corner * 0.7 : 0)
            }
    }
}

/// Where the insert meets the plastic: the top rim stands ~1 mm proud and shades the paper
/// just under it; at the foot, the card's cut edge.
private struct InsertEdges: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.3), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 1.5)
            Spacer(minLength: 0)
            Color.black.opacity(0.3).frame(height: 0.5)
        }
        .allowsHitTesting(false)
    }
}

/// Room light on a spine, over print and plastic alike. The lamp is up and to the left (the 3D
/// box's key light): the left fold stays lit with a fine bright edge, the right fold turns away
/// into shade, and both edges sink into the V-groove where the next case touches. Stops from a
/// Lambert model of a rounded 14 mm spine (flat middle, outer fifth rolling round each side).
/// Down the length: a little shade from the plank above, the foot in the plank's shadow.
private struct SpineShading: View {
    let corner: CGFloat
    let seed: UInt64

    static let across = Gradient(stops: [
        .init(color: .black.opacity(0.62), location: 0),
        .init(color: .black.opacity(0.40), location: 0.015),
        .init(color: .black.opacity(0.18), location: 0.03),
        .init(color: .black.opacity(0.04), location: 0.05),
        .init(color: .white.opacity(0.07), location: 0.065), // the lit fold's bright edge
        .init(color: .white.opacity(0.03), location: 0.10),
        .init(color: .white.opacity(0), location: 0.20),
        .init(color: .black.opacity(0), location: 0.80),
        .init(color: .black.opacity(0.05), location: 0.85),
        .init(color: .black.opacity(0.12), location: 0.89),
        .init(color: .black.opacity(0.20), location: 0.92),
        .init(color: .black.opacity(0.29), location: 0.95),
        .init(color: .black.opacity(0.42), location: 0.97),
        .init(color: .black.opacity(0.54), location: 0.985),
        .init(color: .black.opacity(0.66), location: 1),
    ])
    static let along = Gradient(stops: [
        .init(color: .black.opacity(0.10), location: 0),
        .init(color: .black.opacity(0.03), location: 0.06),
        .init(color: .black.opacity(0), location: 0.16),
        .init(color: .black.opacity(0), location: 0.80),
        .init(color: .black.opacity(0.12), location: 0.93),
        .init(color: .black.opacity(0.22), location: 0.975),
        .init(color: .black.opacity(0.34), location: 1),
    ])

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        // ±2.5 % per case: some are pushed a few millimetres further back than others.
        let variance = Double(Int(seed % 11) - 5) * 0.005
        ZStack {
            shape.fill(Color.white.opacity(0.035)) // the clear film's veil: blacks never read #000
            shape.fill(LinearGradient(gradient: Self.across, startPoint: .leading, endPoint: .trailing))
            shape.fill(LinearGradient(gradient: Self.along, startPoint: .top, endPoint: .bottom))
            shape.fill(variance > 0 ? Color.black.opacity(variance) : Color.white.opacity(-variance))
        }
        .allowsHitTesting(false)
    }
}

/// The film over a spine reflects the lamp: a glint on the left fold, a fainter one of the
/// window on the right fold, and a sheen on the flat that is strongest under the lamp. Where
/// the case is on the shelf sets all three, so they drift as the row scrolls. Only offsets and
/// opacities change: nothing is redrawn. No device tilt on spines (25 readers at 30 Hz), so
/// screenshots are deterministic.
private struct SpineGlints: View {
    let width: CGFloat
    let height: CGFloat
    let corner: CGFloat
    let seed: UInt64

    var body: some View {
        // Plain values only: the visualEffect closures run off the main actor.
        let w = width
        let along = max(0, height - corner * 2)
        // The film never lies quite flat: each case's glints sit a hair off and differ in strength.
        let jitter = CGFloat(Int((seed >> 12) % 7) - 3) * 0.1
        let strength = 0.85 + Double((seed >> 20) % 7) * 0.05
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(colors: [.white, .white.opacity(0.4), .white.opacity(0.15)],
                                     startPoint: .top, endPoint: .bottom))
                .visualEffect { content, proxy in
                    content.opacity(CaseOptics.sheen(CaseOptics.across(proxy)))
                }
            Glint(length: along, peak: 0.5 * strength) // the lamp, on the left fold
                .offset(x: w * 0.153 + jitter - Glint.halo / 2, y: corner)
                .frame(width: w, height: height, alignment: .topLeading)
                .visualEffect { content, proxy in
                    content.offset(x: -0.033 * w * CaseOptics.across(proxy), y: 0)
                }
            Glint(length: along, peak: 0.18 * strength) // the window, on the right fold
                .offset(x: w * 0.886 + jitter - Glint.halo / 2, y: corner)
                .frame(width: w, height: height, alignment: .topLeading)
                .visualEffect { content, proxy in
                    content.offset(x: -0.027 * w * CaseOptics.across(proxy), y: 0)
                }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

/// A lamp's reflection on a rounded edge: a sharp core in a soft halo, brightest a fifth of the
/// way down (the lamp is above the shelf).
private struct Glint: View {
    static let halo: CGFloat = 3
    let length: CGFloat
    /// Opacity at its brightest.
    let peak: Double

    var body: some View {
        ZStack {
            // The halo fades down the spine with the core, gone before the foot. In the
            // halo's thin frame an ellipse this size also fades to nothing at its sides.
            EllipticalGradient(colors: [.white.opacity(0.3), .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.22),
                               startRadiusFraction: 0, endRadiusFraction: 0.55)
            LinearGradient(stops: [
                .init(color: .white.opacity(0.35), location: 0),
                .init(color: .white, location: 0.22),
                .init(color: .white.opacity(0.75), location: 0.5),
                .init(color: .white.opacity(0.3), location: 0.85),
                .init(color: .white.opacity(0.1), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: 0.75)
        }
        .frame(width: Self.halo, height: length)
        .opacity(peak)
    }
}

/// The foot of a case on the plank: a hard contact line, then the occlusion fading over the
/// strip of plank in front of it.
private struct CaseContactShadow: View {
    let width: CGFloat

    var body: some View {
        LinearGradient(stops: [
            .init(color: .black.opacity(0.7), location: 0),
            .init(color: .black.opacity(0.3), location: 0.3),
            .init(color: .black.opacity(0), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .frame(width: width, height: Shelf.spineSeat)
        .offset(y: Shelf.spineSeat)
        .allowsHitTesting(false)
    }
}

/// The lamp is on the left, so a case throws its shadow to the right. Packed cases hide it
/// under their neighbour (later items draw on top); only the last of a row shows it. Darkest
/// low against the case, it softens away from it and towards the top, like a penumbra.
private struct CaseCastShadow: View {
    static let width: CGFloat = 12
    let height: CGFloat

    var body: some View {
        EllipticalGradient(colors: [.black.opacity(0.4), .black.opacity(0)], center: UnitPoint(x: 0, y: 0.65),
                           startRadiusFraction: 0, endRadiusFraction: 0.8)
            .frame(width: Self.width, height: (height * 0.94).rounded())
            .offset(x: Self.width)
            .allowsHitTesting(false)
    }
}

// MARK: - Face-out case (games in progress)

struct FaceOutCase: View {
    let game: Game
    /// Width of a 135 mm case (PlayStation, Xbox, PC) at this size: the scale is coverWidth / 135
    /// points per millimetre, and every case keeps its real shape at it (a Switch case comes out
    /// narrower, a PC DVD case taller).
    let coverWidth: CGFloat
    /// Standing on a plank: it leans back on the wall, which takes its shadow, over a contact shadow.
    let onShelf: Bool
    @State private var art: SpineArt?

    init(game: Game, coverWidth: CGFloat = 115, onShelf: Bool = false) {
        self.game = game
        self.coverWidth = coverWidth
        self.onShelf = onShelf
        let kind = PlatformBand(platform: game.platform).kind
        _art = State(initialValue: game.artURL.flatMap { ImageCache.shared.cachedSpineArt(for: $0, kind: kind) })
    }

    /// Height of a 170 mm console case at this cover width, for placeholders holding its place.
    static func consoleHeight(coverWidth: CGFloat) -> CGFloat { (coverWidth * 170 / 135).rounded() }

    var body: some View {
        let band = PlatformBand(platform: game.platform)
        let kind = band.kind
        let front = CaseFront(kind: kind, mm: coverWidth / 135)
        let plastic = kind.plastic
        let shape = RoundedRectangle(cornerRadius: front.corner, style: .continuous)
        let details = coverWidth >= 60
        ZStack(alignment: .topLeading) {
            // The case round the insert: tinted plastic, lit through from the top, darker at the foot.
            LinearGradient(stops: [
                .init(color: plastic.lit, location: 0),
                .init(color: plastic.base, location: 0.06),
                .init(color: plastic.base, location: 0.9),
                .init(color: plastic.shade, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            // The opening edge: its inner face looks at the lamp, its outer edge rolls away.
            LinearGradient(stops: [
                .init(color: .white.opacity(0.22), location: 0),
                .init(color: .white.opacity(0), location: 0.3),
                .init(color: .black.opacity(0), location: 0.5),
                .init(color: .black.opacity(0.35), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: front.rim, height: front.size.height)
            .offset(x: front.size.width - front.rim)
            CaseInsert(game: game, band: band, front: front, art: art, details: details)
                .offset(y: front.cap)
            CaseFilm(front: front)
            if details {
                // Only the library's own shelf, at full scale, follows the phone's tilt: a few cases
                // on screen there, against twenty on Discover, each redrawn with every movement.
                FilmReflection(width: front.size.width, height: front.size.height,
                               followsTilt: onShelf && coverWidth >= 135 * Shelf.mm)
            }
        }
        .frame(width: front.size.width, height: front.size.height)
        .clipShape(shape)
        // The moulded rim stands proud of the face: its top edge catches the lamp.
        .overlay {
            shape.strokeBorder(LinearGradient(stops: [
                .init(color: .white.opacity(0.42), location: 0),
                .init(color: .white.opacity(0.12), location: 0.1),
                .init(color: .white.opacity(0.05), location: 0.9),
                .init(color: .black.opacity(0.35), location: 1),
            ], startPoint: .top, endPoint: .bottom), lineWidth: max(0.5, 0.6 * front.mm))
        }
        .background {
            if onShelf {
                // It leans on the wall: a tight shadow there, thrown right and down by the lamp.
                shape.fill(Color.black.opacity(0.45))
                    .offset(x: 1.5 * front.mm, y: 1.2 * front.mm)
                    .blur(radius: 2.5 * front.mm)
            }
        }
        // Leaning back on the wall: the foot stays on the plank, the top recedes.
        .rotation3DEffect(.degrees(onShelf ? Shelf.faceOutLean : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
        .background(alignment: .bottom) {
            if onShelf {
                // Where it meets the plank; added after the lean, so it lies flat.
                EllipticalGradient(colors: [.black.opacity(0.6), .black.opacity(0)], center: .center)
                    .frame(width: front.size.width * 1.04, height: (6 * front.mm).rounded())
                    .offset(y: (2.5 * front.mm).rounded())
            }
        }
        .task(id: "\(kind.rawValue)|\(game.artURL?.absoluteString ?? "")") {
            guard let url = game.artURL else {
                art = nil
                return
            }
            art = await ImageCache.shared.spineArt(for: url, kind: kind)
        }
        .accessibilityElement()
        .accessibilityLabel(game.completionPercentage > 0 ? "\(game.title), \(game.completionPercentage) % terminé" : game.title)
    }
}

/// The printed insert of a face-out case: the spine's print rolling round the hinge, then the
/// front panel with the cover art, the platform header and the PEGI label, as on a European case.
/// Publisher marks stay off the front: white type over arbitrary art reads pasted on.
private struct CaseInsert: View {
    let game: Game
    let band: PlatformBand
    let front: CaseFront
    let art: SpineArt?
    let details: Bool

    var body: some View {
        let tint = UIColor(game.coverColor)
        // The spine's print rolling round onto the front: its own ground (all red on a Switch case).
        let spine = Color(SpineFace.paper(title: game.title, kind: band.kind, art: art, tint: tint))
        // A box scan already carries the platform header and ratings: print nothing over it.
        let scanned = (art?.banner ?? 0) > 0
        let printsHeader = !scanned && front.mm >= 0.3
        let blank = BlankFront(title: game.title, ground: art?.ground ?? tint, kind: band.kind, size: front.panel,
                               header: printsHeader ? CaseHeader.height(for: band.kind, mm: front.mm) : 0,
                               showsTitle: details)
        HStack(spacing: 0) {
            spine.frame(width: front.fold)
            Group {
                if let url = game.artURL {
                    CachedAsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { blank }
                } else {
                    blank
                }
            }
            .frame(width: front.panel.width, height: front.panel.height)
            .clipped()
        }
        .frame(width: front.insert.width, height: front.insert.height)
        .overlay(alignment: .top) {
            if printsHeader {
                CaseHeader(band: band, mm: front.mm, showsMarks: details, studio: game.developer)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let pegi = game.pegi, !scanned, front.mm >= 0.6 {
                PEGIBadge(age: pegi, size: (12.5 * front.mm).rounded())
                    .padding(.leading, front.fold + (4 * front.mm).rounded())
                    .padding(.bottom, (4 * front.mm).rounded())
            }
        }
        .overlay { Rectangle().fill(ImagePaint(image: PrintGrain.tile)).opacity(0.05) }
        .overlay { Rectangle().strokeBorder(Color.black.opacity(0.22), lineWidth: 0.5) } // the card's cut edge
    }
}

/// A front with no art to show (still loading, or none at all): the title set like a logo on the
/// cover's colour, lit from the middle, so the case still reads as a printed sleeve, not a blank.
private struct BlankFront: View {
    let title: String
    let ground: UIColor
    let kind: PlatformBand.Kind
    let size: CGSize
    /// Room the platform header takes across the top.
    let header: CGFloat
    /// Small cases keep only the colour: lettering there would be a smudge.
    let showsTitle: Bool

    var body: some View {
        let face = SpineFont.pick(seed: Shelf.printSeed(title), kind: kind)
        // Measured luminance rather than `isLight`: a mid-tone cover takes the dark ink, which
        // reads better on it once the bloom behind the title lifts it.
        let ink = ground.relativeLuminance > 0.16 ? Color(hex: "151515") : Color(hex: "F2F3F5")
        let type = face.size(for: size.width * 0.25).rounded()
        ZStack(alignment: .top) {
            Color(ground)
            RadialGradient(colors: [.white.opacity(0.14), .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.4),
                           startRadius: 0, endRadius: size.height * 0.6)
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.3)],
                           startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom)
            if showsTitle {
                Text(face.cased(title))
                    .font(face.font(size: type))
                    .tracking(type * face.tracking)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(ink)
                    .padding(.horizontal, (size.width * 0.1).rounded())
                    .padding(.top, header + (size.width * 0.1).rounded())
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// The film over a case front, and the light on it.
private struct CaseFilm: View {
    let front: CaseFront

    var body: some View {
        ZStack(alignment: .topLeading) {
            // On the left the insert rolls round the spine, turning towards the lamp (up and to
            // the left, as on the spines beside it): brighter than the flat front, until it
            // turns edge on at the very edge...
            LinearGradient(stops: [
                .init(color: .black.opacity(0.35), location: 0),
                .init(color: .white.opacity(0.10), location: 0.3),
                .init(color: .white.opacity(0.05), location: 0.7),
                .init(color: .white.opacity(0), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: front.fold + 1, height: front.size.height)
            // ...with the lamp's glint along the roll.
            Color.white.opacity(0.3)
                .frame(width: 0.75, height: front.size.height)
                .offset(x: max(0.5, front.fold * 0.35))
            // The living hinge, seen through the film where the front goes flat.
            HStack(spacing: 0) {
                Color.black.opacity(0.3).frame(width: 0.5)
                Color.white.opacity(0.15).frame(width: 0.5)
            }
            .frame(height: front.size.height)
            .offset(x: front.fold)
            // The clear film: print greys a touch under it.
            Color.white.opacity(0.035)
            // The top rim stands about 1 mm proud and shades the paper just under it.
            LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(width: front.insert.width, height: max(1, 1.2 * front.mm))
                .offset(y: front.cap)
            // The case leans back towards the lamp: its upper half is brighter, its foot darker.
            LinearGradient(stops: [
                .init(color: .white.opacity(0.07), location: 0),
                .init(color: .white.opacity(0.025), location: 0.3),
                .init(color: .white.opacity(0), location: 0.7),
                .init(color: .black.opacity(0.12), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
    }
}

/// The lamp's reflection in the film over a face-out case. A flat mirror reflects the lamp at a
/// fixed place in the room, so the case slides under it as the shelf scrolls; with `followsTilt`,
/// tilting the phone moves it too.
private struct FilmReflection: View {
    let width: CGFloat
    let height: CGFloat
    /// Reading the tilt redraws the reflection with every movement of the phone: only for the
    /// handful of face-outs on the library's shelf.
    var followsTilt = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tracking = false

    var body: some View {
        // Plain values only: the visualEffect closure runs off the main actor. The tilt is only
        // read (and so observed) when followed.
        let tilt: CGFloat = followsTilt && !reduceMotion ? CGFloat(TiltMotion.shared.x) : 0
        LinearGradient(stops: [
            .init(color: .white.opacity(0), location: 0.3),
            .init(color: .white.opacity(0.05), location: 0.4),
            .init(color: .white.opacity(0.14), location: 0.47),
            .init(color: .white.opacity(0.17), location: 0.5), // the window's bright edge
            .init(color: .white.opacity(0.04), location: 0.53),
            .init(color: .white.opacity(0), location: 0.62),
        ], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
        .frame(width: width * 2.4, height: height)
        .visualEffect { content, proxy in
            content.offset(x: CaseOptics.lampOffset(proxy, tilt: tilt), y: 0)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .onAppear {
            guard followsTilt, !reduceMotion else { return }
            TiltMotion.shared.start()
            tracking = true
        }
        .onDisappear {
            if tracking {
                TiltMotion.shared.stop()
                tracking = false
            }
        }
    }
}

/// A shop's shelf-edge label, slid into the clear strip along the plank's front under a face-out
/// case: how far along the game is, kept off the cover so no logo hides behind it.
private struct ShelfTag: View {
    let percent: Int

    var body: some View {
        let share = CGFloat(min(max(percent, 0), 100)) / 100
        let bar: CGFloat = 22
        HStack(spacing: 5) {
            Text("\(min(percent, 100)) %")
                .font(.system(size: 9.5, weight: .heavy).width(.condensed))
                .monospacedDigit()
                .foregroundStyle(Color(hex: "1A1A1A"))
            Capsule().fill(Color(hex: "D8D2C4"))
                .frame(width: bar, height: 2.5)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color.accent).frame(width: bar * share)
                }
        }
        .fixedSize() // its slot under the case has no width of its own
        .padding(.horizontal, 6)
        .frame(height: 13)
        .background(Color(hex: "F4F1EA"), in: RoundedRectangle(cornerRadius: 1, style: .continuous))
        // The strip's plastic over the paper: a glint along its top edge, a faint sheen.
        .overlay(alignment: .top) { Color.white.opacity(0.55).frame(height: 0.5) }
        .overlay { RoundedRectangle(cornerRadius: 1, style: .continuous).fill(Color.white.opacity(0.06)) }
        .shadow(color: .black.opacity(0.35), radius: 0.5, y: 0.5)
        .accessibilityHidden(true) // the case's own label already says it
    }
}

// MARK: - The whole shelf

/// The collection as a bookcase, one shelf per status that scrolls sideways, spines packed
/// tight like real cases. Tapping a case opens the game's page.
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
        // One bookcase: bays stacked with no gap, each plank directly above the next bay's wall.
        VStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { row, section in
                bay(section, row: row)
            }
        }
    }

    /// One shelf of the bookcase: its back wall with the label on it, and the cases standing on
    /// the plank. Games in progress stand face out, like new releases in a shop; the rest are
    /// spines packed tight, touching: the groove between them comes from their rounded edges.
    private func bay(_ section: Section, row: Int) -> some View {
        let facesOut = section.id == "playing"
        // From every game, not only those the lazy row has built: a PC case further along
        // mustn't make the row jump when it scrolls in.
        let tallest = section.games.map { PlatformBand(platform: $0.platform).caseHeight }.max() ?? 204
        return VStack(alignment: .leading, spacing: 0) {
            ShelfLabel(title: section.title, count: section.games.count)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xs)
                // The same light on the wall behind the label as on the shelf below (both run
                // edge to edge), so the back panel has no seam; the label stays crisp on top.
                .background { ShelfLight(row: row) }
            if facesOut {
                // The cases' labels sit on the plank's front edge and scroll with them, so the
                // plank is drawn behind the row rather than under it.
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: Shelf.faceOutGap) {
                        ForEach(section.games) { game in
                            VStack(spacing: Shelf.faceOutSeat) {
                                // 135 mm at the shelf's scale: the whole bookcase is drawn to one scale.
                                caseLink(game) { FaceOutCase(game: game, coverWidth: 135 * Shelf.mm, onShelf: true) }
                                Color.clear
                                    .frame(height: Shelf.plankFront)
                                    .overlay {
                                        if game.completionPercentage > 0 {
                                            ShelfTag(percent: game.completionPercentage)
                                        }
                                    }
                            }
                        }
                    }
                    .frame(height: tallest + Shelf.faceOutSeat + Shelf.plankFront, alignment: .bottom)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, Shelf.headroom)
                }
                .labelledPlankBehind()
                .overlay { ShelfLight(row: row) }
            } else {
                let leaning: UUID? = section.games.count < 2 ? nil : section.games.last?.id
                let gap = Self.leanGap(section.games)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: 0) {
                        ForEach(section.games) { game in
                            let leans = game.id == leaning
                            caseLink(game) {
                                // The last case has room to fall: it pivots on its foot onto its neighbour.
                                GameSpine(game: game, lean: leans ? Shelf.lastCaseLean : 0)
                                    .padding(.leading, leans ? gap : 0)
                            }
                        }
                    }
                    .frame(height: tallest, alignment: .bottom)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, Shelf.headroom)
                    .padding(.bottom, Shelf.spineSeat)
                }
                .standingOnPlank()
                .overlay { ShelfLight(row: row) }
            }
        }
        .background { ShelfWall() }
    }

    /// A case on the shelf: it opens the game's page, zooming out of the case.
    private func caseLink<Label: View>(_ game: Game, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            GameDetailView(game: game)
                .navigationTransition(.zoom(sourceID: game.id, in: namespace))
        } label: {
            label()
        }
        .buttonStyle(PressableCardStyle())
        .matchedTransitionSource(id: game.id, in: namespace)
        .contextMenu { contextMenu(game) }
    }

    /// How far the leaning last case's foot stands from its neighbour: it pivots on its
    /// bottom-left corner until its side meets the neighbour's top corner (or its own top
    /// corner meets a taller neighbour's side). Rounded down, so the two overlap by under a
    /// point and touch, rather than stop a hair short.
    private static func leanGap(_ games: [Game]) -> CGFloat {
        guard games.count > 1 else { return 0 }
        let angle = Shelf.lastCaseLean * .pi / 180
        let leaning = PlatformBand(platform: games[games.count - 1].platform).caseHeight
        let neighbour = PlatformBand(platform: games[games.count - 2].platform).caseHeight
        return min(neighbour * CGFloat(tan(angle)), leaning * CGFloat(sin(angle))).rounded(.down)
    }
}
