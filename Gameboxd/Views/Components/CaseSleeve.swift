//
//  CaseSleeve.swift
//  Gameboxd
//
//  The game page's case print, laid flat as it leaves the printer: back, spine and front on one
//  sheet, which the 3D box wraps round its shell. Drawn at 2 points per millimetre and rendered
//  to a texture (ImageRenderer), so everything here is synchronous: images are already loaded.
//

import SwiftUI
import UIKit

/// The whole insert, [back | spine | front], at `mm` points per millimetre.
struct CaseSleeve: View {
    let game: Game
    let band: PlatformBand
    let solid: CaseSolid
    let cover: UIImage?
    /// The cover's colour, as printed: the spine's ground and the back's.
    let tint: UIColor
    /// The art is a box scan, already carrying the platform's header and the PEGI label.
    let scanned: Bool
    let screenshots: [UIImage]
    let mm: CGFloat

    var body: some View {
        let panel = CGSize(width: (solid.panel * mm).rounded(), height: (solid.insertHeight * mm).rounded())
        HStack(spacing: 0) {
            SleeveBack(game: game, band: band, cover: cover, screenshots: screenshots, ground: tint, size: panel, mm: mm)
            SpineFace(title: game.title, band: band, cover: cover, tint: tint, pegi: game.pegi,
                      width: (solid.spineRun * mm).rounded(), height: panel.height, studio: game.developer)
            SleeveFront(game: game, band: band, cover: cover, scanned: scanned, ground: tint, size: panel, mm: mm)
        }
        // The card's cut edges, all round.
        .overlay { Rectangle().strokeBorder(Color.black.opacity(0.22), lineWidth: 0.5) }
    }
}

/// The front panel: the cover art (or the title on its colour) under the platform's header and
/// the PEGI label, as on the shelf's face-out cases.
private struct SleeveFront: View {
    let game: Game
    let band: PlatformBand
    let cover: UIImage?
    let scanned: Bool
    let ground: UIColor
    let size: CGSize
    let mm: CGFloat

    var body: some View {
        Group {
            if let cover {
                Image(uiImage: cover).resizable().scaledToFill()
            } else {
                BlankFront(title: game.title, ground: ground, kind: band.kind, size: size,
                           header: FrontPrint.printsHeader(scanned: scanned, mm: mm) ? CaseHeader.height(for: band.kind, mm: mm) : 0,
                           showsTitle: true)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .modifier(FrontPrint(band: band, mm: mm, pegi: game.pegi, scanned: scanned, details: true, studio: game.developer))
    }
}

/// The back, as a European publisher prints it: the platform's header, the title, screenshots and
/// the blurb on the cover's colour, then a white strip of small print with the PEGI label, the
/// credits and the barcode.
private struct SleeveBack: View {
    let game: Game
    let band: PlatformBand
    let cover: UIImage?
    let screenshots: [UIImage]
    let ground: UIColor
    let size: CGSize
    let mm: CGFloat

    private var text: String? {
        guard let text = game.description?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// The description's opening sentence, set large like the slogan on a back, when it is short
    /// enough to read as one.
    private var tagline: String? {
        guard let text, let end = text.firstIndex(where: { ".!?".contains($0) }) else { return nil }
        let sentence = String(text[...end])
        return (12...110).contains(sentence.count) ? sentence : nil
    }

    /// As much of the rest of the description as the back holds, cut on the last sentence end
    /// before the limit so it never stops mid-word.
    private var blurb: String? {
        guard var rest = text else { return nil }
        if let tagline { rest = String(rest.dropFirst(tagline.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !rest.isEmpty else { return nil }
        let limit = 340
        guard rest.count > limit else { return rest }
        let cut = rest.prefix(limit)
        if let end = cut.lastIndex(where: { ".!?".contains($0) }) { return String(cut[...end]) }
        return cut + "…"
    }

    /// The facts a back lists as pictograms: genres, the usual length, the critics' score, the year.
    private var features: [BackFeature] {
        var list: [BackFeature] = []
        let genres = game.genres.prefix(2).joined(separator: " · ")
        if !genres.isEmpty { list.append(BackFeature(icon: "gamecontroller.fill", label: genres)) }
        if let hours = game.estimatedPlaytime, hours > 0 { list.append(BackFeature(icon: "clock.fill", label: "≈ \(hours) h")) }
        if let score = game.metacriticScore, score > 0 { list.append(BackFeature(icon: "star.fill", label: "Metacritic \(score)")) }
        if let year { list.append(BackFeature(icon: "calendar", label: year)) }
        return list
    }

    private var year: String? {
        let year = game.releaseYear
        return year.isEmpty || year == "—" || year == "TBA" ? nil : year
    }

    private var studio: String? {
        let name = game.developer
        return name.isEmpty || name == "Unknown" || name == "—" ? nil : name
    }

    var body: some View {
        let face = SpineFont.pick(seed: Shelf.printSeed(game.title), kind: band.kind)
        let type = (7.5 * mm).rounded()
        VStack(spacing: 0) {
            CaseHeader(band: band, mm: mm, studio: game.developer)
            VStack(spacing: 3 * mm) {
                Text(face.cased(game.title))
                    .font(face.font(size: type))
                    .tracking(type * face.tracking)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 0.6 * mm, y: 0.3 * mm)
                if let tagline {
                    Text(tagline)
                        .font(.system(size: 4.6 * mm, weight: .heavy).italic())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                }
                pictures
                    .overlay(alignment: .topTrailing) {
                        PlaySticker(game: game, mm: mm)
                            .offset(x: 2 * mm, y: -2.5 * mm)
                    }
                if !features.isEmpty {
                    HStack(spacing: 1.5 * mm) {
                        ForEach(features, id: \.label) { $0.tile(mm: mm) }
                    }
                }
                if let blurb {
                    Text(blurb)
                        .font(.system(size: 3.7 * mm))
                        .lineSpacing(0.5 * mm)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 6 * mm)
            .padding(.top, 4 * mm)
            .padding(.bottom, 3 * mm)
            .frame(maxHeight: .infinity, alignment: .top)
            smallPrint
        }
        .frame(width: size.width, height: size.height)
        .background {
            LinearGradient(colors: [Color(ground.darker(0.3)), Color(ground.darker(0.5))], startPoint: .top, endPoint: .bottom)
        }
        .clipped()
    }

    /// Screenshots: a wide one over two small ones, as backs lay them out; the cover's art only when
    /// there are none, since its logo would repeat the printed title. The wide one grows into
    /// whatever the blurb leaves, so a game with little text still has a full back.
    @ViewBuilder private var pictures: some View {
        let fromCover = screenshots.isEmpty
        let shots = Array((fromCover ? [cover].compactMap { $0 } : screenshots).prefix(3))
        if let first = shots.first {
            VStack(spacing: 1.5 * mm) {
                // The cover's logo sits near its top: crop from the bottom of the art and fade the
                // cut edge into the sleeve, so no half logo shows under the printed title.
                picture(first, height: 36 * mm, grows: true, anchor: fromCover ? .bottom : .center)
                    .mask {
                        LinearGradient(stops: [.init(color: fromCover ? .clear : .black, location: 0),
                                               .init(color: .black, location: fromCover ? 0.35 : 0)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                if shots.count == 3 {
                    HStack(spacing: 1.5 * mm) {
                        picture(shots[1], height: 19 * mm)
                        picture(shots[2], height: 19 * mm)
                    }
                } else if shots.count == 2 {
                    picture(shots[1], height: 24 * mm)
                }
            }
        }
    }

    private func picture(_ image: UIImage, height: CGFloat, grows: Bool = false, anchor: Alignment = .center) -> some View {
        Image(uiImage: image).resizable().scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: height, maxHeight: grows ? .infinity : height, alignment: anchor)
            .clipped()
            .overlay { Rectangle().strokeBorder(Color.white.opacity(0.5), lineWidth: 0.25 * mm) }
    }

    private var smallPrint: some View {
        HStack(alignment: .bottom, spacing: 3 * mm) {
            if let pegi = game.pegi {
                PEGIBadge(age: pegi, size: (10 * mm).rounded())
            }
            VStack(alignment: .leading, spacing: 0.8 * mm) {
                if let studio {
                    Text(studio.uppercased())
                        .font(.system(size: 2.4 * mm, weight: .heavy).width(.condensed))
                        .foregroundStyle(Color(hex: "1A1A1A"))
                }
                Text([year.map { "© \($0)" }, studio].compactMap { $0 }.joined(separator: " ") + ". Tous droits réservés.")
                    .font(.system(size: 1.7 * mm))
                    .foregroundStyle(Color(hex: "555555"))
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            Barcode(digits: Barcode.digits(for: game.title), module: 0.33 * mm, height: 15 * mm)
        }
        .padding(.horizontal, 4 * mm)
        .padding(.vertical, 3.5 * mm)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }
}

/// One pictogram of the back's facts row: an icon over a short label, in a hairline frame.
private struct BackFeature {
    let icon: String
    let label: String

    func tile(mm: CGFloat) -> some View {
        VStack(spacing: 0.8 * mm) {
            Image(systemName: icon).font(.system(size: 3.6 * mm, weight: .bold))
            Text(label)
                .font(.system(size: 2.5 * mm, weight: .bold).width(.condensed))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 1.4 * mm)
        .padding(.horizontal, 1 * mm)
        .frame(maxWidth: .infinity)
        .overlay { RoundedRectangle(cornerRadius: 1.2 * mm).strokeBorder(Color.white.opacity(0.6), lineWidth: 0.25 * mm) }
    }
}

/// The player's own label, stuck on the case like a shop's price sticker: where they are with the
/// game and what they made of it. Only once they have started it or rated it.
private struct PlaySticker: View {
    let game: Game
    let mm: CGFloat

    private var shows: Bool {
        game.rating > 0 || [.playing, .completed, .platinum, .shelved].contains(game.status)
    }

    var body: some View {
        if shows {
            VStack(spacing: 0.6 * mm) {
                Text("TA PARTIE")
                    .font(.system(size: 1.9 * mm, weight: .heavy).width(.expanded))
                    .opacity(0.85)
                if game.status != .none {
                    Label(game.status.rawValue, systemImage: game.status.icon)
                        .font(.system(size: 2.9 * mm, weight: .heavy))
                }
                if game.rating > 0 {
                    HStack(spacing: 0.3 * mm) {
                        ForEach(0..<5, id: \.self) { star in
                            Image(systemName: star < game.rating ? "star.fill" : "star")
                        }
                    }
                    .font(.system(size: 2.4 * mm, weight: .bold))
                }
                if game.playTimeMinutes > 0 {
                    Text(formatDuration(minutes: game.playTimeMinutes) + " jouées")
                        .font(.system(size: 2.2 * mm, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 2.4 * mm)
            .padding(.vertical, 1.8 * mm)
            .background {
                RoundedRectangle(cornerRadius: 1.6 * mm)
                    .fill(game.status == .none ? Color(hex: "5B7CFA") : game.status.color)
                    .overlay { RoundedRectangle(cornerRadius: 1.6 * mm).strokeBorder(Color.white.opacity(0.7), lineWidth: 0.35 * mm) }
                    .shadow(color: .black.opacity(0.35), radius: 0.8 * mm, y: 0.4 * mm)
            }
            .rotationEffect(.degrees(-6))
        }
    }
}

/// An EAN-13 barcode, as on every retail case. The number comes from the title (the same on every
/// launch) with a valid check digit, and the bars are its real encoding.
private struct Barcode: View {
    let digits: [Int]
    /// Width of one bar module.
    let module: CGFloat
    let height: CGFloat

    static func digits(for title: String) -> [Int] {
        var seed = Shelf.printSeed(title)
        var digits = [3, 7] // a European prefix
        for _ in 0..<10 {
            digits.append(Int(seed % 10))
            seed /= 10
        }
        let sum = digits.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) }
        digits.append((10 - sum % 10) % 10)
        return digits
    }

    /// The 95 modules: start guard, six left digits (odd or even parity, set by the first digit),
    /// centre guard, six right digits, end guard.
    private static func modules(_ digits: [Int]) -> [Bool] {
        let odd = ["0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"]
        let even = ["0100111", "0110011", "0011011", "0100001", "0011101", "0111001", "0000101", "0010001", "0001001", "0010111"]
        let right = ["1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100"]
        let parity = ["OOOOOO", "OOEOEE", "OOEEOE", "OOEEEO", "OEOOEE", "OEEOOE", "OEEEOO", "OEOEOE", "OEOEEO", "OEEOEO"]
        let sides = Array(parity[digits[0]])
        var bits = "101"
        for index in 1...6 {
            bits += sides[index - 1] == "O" ? odd[digits[index]] : even[digits[index]]
        }
        bits += "01010"
        for index in 7...12 {
            bits += right[digits[index]]
        }
        bits += "101"
        return bits.map { $0 == "1" }
    }

    var body: some View {
        let quiet: CGFloat = 7 // modules left of the bars, where the first digit is printed
        let numerals = module * 9
        Canvas { context, size in
            let bars = size.height - numerals
            for (index, on) in Self.modules(digits).enumerated() where on {
                let guarding = index < 3 || (45..<50).contains(index) || index >= 92
                let rect = CGRect(x: (quiet + CGFloat(index)) * module, y: 0,
                                  width: module, height: guarding ? bars + numerals * 0.5 : bars)
                context.fill(Path(rect), with: .color(.black))
            }
            let line = bars + numerals * 0.55
            let type = Font.system(size: numerals * 0.95, weight: .medium).monospacedDigit()
            let groups = [(String(digits[0]), quiet / 2),
                          (digits[1...6].map(String.init).joined(), quiet + 3 + 21),
                          (digits[7...12].map(String.init).joined(), quiet + 50 + 21)]
            for (text, centre) in groups {
                context.draw(Text(text).font(type).tracking(module * 1.6), at: CGPoint(x: centre * module, y: line))
            }
        }
        .frame(width: (quiet + 95 + 2) * module, height: height)
        .padding(.horizontal, module)
        .background(Color.white)
    }
}

// MARK: - Studio

/// What the case's film and plastic reflect: a photographer's dark studio, lit by a broad softbox
/// overhead and two tall strip lights, as a 2:1 panorama (an equirectangular environment map).
struct StudioBackdrop: View {
    static let size = CGSize(width: 1024, height: 512)

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Color(white: 0.42), location: 0),
                .init(color: Color(white: 0.16), location: 0.35),
                .init(color: Color(white: 0.08), location: 0.5),   // the horizon
                .init(color: Color(white: 0.03), location: 1),     // the floor
            ], startPoint: .top, endPoint: .bottom)
            // The overhead softbox: the whole sky near the zenith.
            Rectangle().fill(Color.white)
                .frame(height: 70)
                .blur(radius: 26)
                .frame(maxHeight: .infinity, alignment: .top)
            // Strip lights at either side of the camera, and a dimmer pair behind the case.
            strip(x: 0.36, width: 90, brightness: 1)
            strip(x: 0.64, width: 60, brightness: 0.55)
            strip(x: 0.86, width: 70, brightness: 0.4)
            strip(x: 0.14, width: 70, brightness: 0.4)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func strip(x: CGFloat, width: CGFloat, brightness: Double) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(white: brightness))
            .frame(width: width, height: 230)
            .blur(radius: 12)
            .position(x: Self.size.width * x, y: Self.size.height * 0.4)
    }
}
